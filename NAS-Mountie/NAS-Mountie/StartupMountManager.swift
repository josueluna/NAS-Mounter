import Foundation
import Network

final class StartupMountManager {
    private let defaults: UserDefaults

    private var networkMonitor: NWPathMonitor?
    private var retryTimer: DispatchSourceTimer?

    private var hasMountedThisSession = false
    private var isAttemptInProgress = false
    private var retryCount = 0

    // Single serialized queue. Eliminates the currentPathStatus data race.
    private let workQueue = DispatchQueue(label: "com.nasmountie.startup.work", qos: .utility)

    private let maxRetryCount: Int = 30       // 30s de ventana total
    private let retryInterval: TimeInterval = 1.0

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    // MARK: - Public API

    func scheduleStartupMountIfNeeded() {
        guard shouldAttemptStartupMount else {
            log("runOnStartup is off or session already mounted. Skipping.")
            return
        }
        log("scheduleStartupMountIfNeeded: authorized. Starting network monitor.")
        startNetworkMonitor()
    }

    func resetSessionState() {
        defaults.removeObject(forKey: "_sessionMountDone")
        workQueue.async { [weak self] in self?.stop() }
    }

    // MARK: - Private: Guards

    private var shouldAttemptStartupMount: Bool {
        defaults.bool(forKey: "runOnStartup")
            && !defaults.bool(forKey: "_sessionMountDone")
    }

    // MARK: - Private: Network Monitor

    private func startNetworkMonitor() {
        let monitor = NWPathMonitor()
        networkMonitor = monitor

        // pathUpdateHandler and timer both run on the same serialized workQueue.
        // No shared property across queues — data race eliminated.
        monitor.pathUpdateHandler = { [weak self] path in
            guard let self else { return }
            if path.status == .satisfied {
                // FIX: only start the timer if it does not exist yet AND we have not mounted.
                // This prevents the duplicate timer seen in the log after a successful mount.
                guard !self.hasMountedThisSession else { return }
                self.startRetryTimer()
            } else {
                log("Network path not satisfied (\(path.status)). Waiting.")
            }
        }

        monitor.start(queue: workQueue)
    }

    // MARK: - Private: Retry Timer

    private func startRetryTimer() {
        // Siempre corre en workQueue. El guard evita timer duplicado.
        guard retryTimer == nil else { return }

        log("Starting retry timer: every \(retryInterval)s, max \(maxRetryCount) attempts.")

        let timer = DispatchSource.makeTimerSource(queue: workQueue)
        timer.schedule(deadline: .now(), repeating: retryInterval)
        timer.setEventHandler { [weak self] in self?.attemptStartupMount() }
        retryTimer = timer
        timer.resume()
    }

    // MARK: - Private: Attempt

    private func attemptStartupMount() {
        // Corre en workQueue. Sin concurrencia, sin necesidad de locks.
        guard shouldAttemptStartupMount else {
            log("Guard: shouldAttemptStartupMount = false. Stopping.")
            stop()
            return
        }
        guard !hasMountedThisSession else {
            log("Guard: already mounted this session. Stopping.")
            stop()
            return
        }
        guard !isAttemptInProgress else {
            log("Guard: attempt already in progress. Skipping tick.")
            return
        }

        retryCount += 1
        log("Attempt #\(retryCount) of \(maxRetryCount).")

        if retryCount > maxRetryCount {
            log("Max retries reached. Giving up.")
            stop()
            return
        }

        isAttemptInProgress = true
        defer { isAttemptInProgress = false }

        // ── Paso 1: perfil por SSID actual ───────────────────────────────────
        if let ssid = NetworkHelper.currentSSID() {
            log("SSID detected: '\(ssid)'.")
            if let profile = NetworkProfileManager.profile(for: ssid) {
                log("Profile matched by SSID. Host: \(profile.host). Shares: \(profile.shares.joined(separator: ", ")).")
                tryMount(profile: profile)
                return
            } else {
                log("No saved profile for SSID '\(ssid)'. Trying host fallback.")
            }
        } else {
            log("SSID not available yet. Trying host fallback.")
        }

        // ── Paso 2: fallback por host alcanzable ─────────────────────────────
        // FIX: nc has a 1s timeout per host. With few profiles this is fast.
        // If the NAS is not reachable yet, the attempt finishes in <1s and the
        // timer retries on the next tick — without blocking the flow.
        let allProfiles = NetworkProfileManager.loadProfiles()

        guard !allProfiles.isEmpty else {
            log("No saved profiles. Stopping.")
            stop()
            return
        }

        log("Fallback: testing \(allProfiles.count) profile(s): \(allProfiles.keys.sorted().joined(separator: ", ")).")

        for (ssid, profile) in allProfiles {
            guard let host = parsedHost(from: profile.host) else {
                log("Cannot parse host for profile '\(ssid)'. Skipping.")
                continue
            }
            guard !profile.shares.isEmpty else {
                log("Profile '\(ssid)' has no shares. Skipping.")
                continue
            }
            log("Testing port 445 on \(host) (profile '\(ssid)').")
            if isSMBPortReachable(host: host) {
                log("Port 445 reachable on \(host). Mounting via profile '\(ssid)'.")
                tryMount(profile: profile)
                return
            } else {
                log("Port 445 not reachable on \(host) yet.")
            }
        }

        log("No reachable host this attempt. Will retry.")
    }

    // MARK: - Private: tryMount

    private func tryMount(profile: NetworkProfile) {
        guard let credentials = KeychainHelper.load() else {
            log("Keychain credentials not found. Stopping.")
            stop()
            return
        }
        guard let host = parsedHost(from: profile.host) else {
            log("Cannot parse host '\(profile.host)'. Stopping.")
            stop()
            return
        }
        guard !profile.shares.isEmpty else {
            log("Profile has no shares. Stopping.")
            stop()
            return
        }

        // Mark as mounted and stop the timer BEFORE launching the mount.
        // This prevents NWPathMonitor (which may receive a new path event
        // when the SMB volume mounts) from starting a second timer.
        hasMountedThisSession = true
        defaults.set(true, forKey: "_sessionMountDone")
        stop()

        log("Launching mount for \(profile.shares.count) share(s) on \(host).")

        let sharesCopy   = profile.shares
        let usernameCopy = profile.username
        let passwordCopy = credentials.password

        // mount() is blocking (waits for osascript). Launch on background
        // to avoid blocking workQueue.
        DispatchQueue.global(qos: .background).async { [weak self] in
            self?.mount(host: host, username: usernameCopy,
                        password: passwordCopy, shares: sharesCopy)
        }
    }

    // MARK: - Private: Mount

    /// Mounts shares silently via osascript/Finder.
    /// - Does not open Finder windows.
    /// - Does not show native macOS connection dialogs.
    /// - Single script for all shares = one osascript invocation.
    /// - Script passed via stdin: safe with special-character passwords,
    ///   not visible in `ps aux`.
    private func mount(host: String, username: String, password: String, shares: [String]) {
        let encodedUser = username.addingPercentEncoding(withAllowedCharacters: .urlUserAllowed)
                          ?? username
        let encodedPass = password.addingPercentEncoding(withAllowedCharacters: .urlPasswordAllowed)
                          ?? password

        let mountLines = shares.map { share in
            let url = "smb://\(encodedUser):\(encodedPass)@\(host)/\(share)"
            return """
                try
                    mount volume "\(url)"
                on error errMsg
                end try
            """
        }.joined(separator: "\n")

        let script = """
        tell application "Finder"
        \(mountLines)
        end tell
        """

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-"]   // read script from stdin

        let inputPipe  = Pipe()
        let outputPipe = Pipe()
        let errorPipe  = Pipe()
        process.standardInput  = inputPipe
        process.standardOutput = outputPipe
        process.standardError  = errorPipe

        do {
            try process.run()
            if let data = script.data(using: .utf8) {
                inputPipe.fileHandleForWriting.write(data)
            }
            inputPipe.fileHandleForWriting.closeFile()
            process.waitUntilExit()

            let code = process.terminationStatus
            log("osascript finished. Exit code: \(code). Shares: \(shares.joined(separator: ", ")).")

            if code != 0 {
                let errData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                let errMsg  = String(data: errData, encoding: .utf8) ?? "(no stderr)"
                log("osascript stderr: \(errMsg)")
            }
        } catch {
            log("Failed to launch osascript: \(error.localizedDescription).")
        }
    }

    // MARK: - Private: Helpers

    private func isSMBPortReachable(host: String, timeout: Int = 1) -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/nc")
        process.arguments = ["-z", "-G", "\(timeout)", host, "445"]
        process.standardOutput = FileHandle.nullDevice
        process.standardError  = FileHandle.nullDevice
        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }

    private func parsedHost(from rawHost: String) -> String? {
        let trimmed    = rawHost.trimmingCharacters(in: .whitespacesAndNewlines)
        let withScheme = trimmed.lowercased().hasPrefix("smb://") ? trimmed : "smb://\(trimmed)"
        guard let host = URL(string: withScheme)?.host, !host.isEmpty else { return nil }
        return host
    }

    private func stop() {
        retryTimer?.cancel()
        retryTimer = nil
        networkMonitor?.cancel()
        networkMonitor = nil
    }

    // MARK: - Private: Logging

    private func log(_ message: String) {
        StartupLogger.log(message, source: "StartupMountManager")
    }
}
