import Foundation
import Network

final class StartupMountManager {
    private let defaults: UserDefaults

    private var networkMonitor: NWPathMonitor?
    private var retryTimer: DispatchSourceTimer?

    private var hasMountedThisSession = false
    private var isAttemptInProgress = false
    private var currentPathStatus: NWPath.Status = .requiresConnection
    private var retryCount = 0

    private let monitorQueue = DispatchQueue(label: "com.nasmountie.startup.network-monitor")
    private let retryQueue = DispatchQueue(label: "com.nasmountie.startup.retry", qos: .utility)

    private let maxRetryCount = 24
    private let retryInterval: TimeInterval = 1

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func scheduleStartupMountIfNeeded() {
        guard shouldAttemptStartupMount else {
            return
        }

        startNetworkMonitor()
        startRetryTimer()
    }

    func resetSessionState() {
        defaults.removeObject(forKey: "_sessionMountDone")
        stop()
    }

    // MARK: - Private

    private var shouldAttemptStartupMount: Bool {
        let runOnStartup = defaults.bool(forKey: "runOnStartup")
        let alreadyMountedThisSession = defaults.bool(forKey: "_sessionMountDone")

        return runOnStartup && !alreadyMountedThisSession
    }

    private func startNetworkMonitor() {
        let monitor = NWPathMonitor()
        networkMonitor = monitor

        monitor.pathUpdateHandler = { [weak self] path in
            guard let self else { return }

            self.currentPathStatus = path.status

            if path.status == .satisfied {
                self.startRetryTimer()
            }
        }

        monitor.start(queue: monitorQueue)
    }

    private func startRetryTimer() {
        retryQueue.async { [weak self] in
            guard let self else { return }

            guard self.retryTimer == nil else {
                return
            }

            let timer = DispatchSource.makeTimerSource(queue: self.retryQueue)

            timer.schedule(
                deadline: .now(),
                repeating: self.retryInterval
            )

            timer.setEventHandler { [weak self] in
                self?.attemptStartupMount()
            }

            self.retryTimer = timer
            timer.resume()
        }
    }

    private func attemptStartupMount() {
        guard shouldAttemptStartupMount else {
            stop()
            return
        }

        guard !hasMountedThisSession else {
            stop()
            return
        }

        guard !isAttemptInProgress else {
            return
        }

        retryCount += 1

        if retryCount > maxRetryCount {
            stop()
            return
        }

        guard currentPathStatus == .satisfied else {
            return
        }

        isAttemptInProgress = true

        defer {
            isAttemptInProgress = false
        }

        guard let currentSSID = NetworkHelper.currentSSID() else {
            return
        }

        guard let profile = NetworkProfileManager.profile(for: currentSSID) else {
            stop()
            return
        }

        guard let credentials = KeychainHelper.load() else {
            stop()
            return
        }

        guard let host = parsedHost(from: profile.host) else {
            stop()
            return
        }

        guard !profile.shares.isEmpty else {
            stop()
            return
        }

        guard isSMBPortReachable(host: host) else {
            return
        }

        hasMountedThisSession = true
        defaults.set(true, forKey: "_sessionMountDone")

        stop()

        mount(
            host: host,
            username: profile.username,
            password: credentials.password,
            shares: profile.shares
        )
    }

    private func stop() {
        retryTimer?.cancel()
        retryTimer = nil

        networkMonitor?.cancel()
        networkMonitor = nil
    }

    private func mount(
        host: String,
        username: String,
        password: String,
        shares: [String]
    ) {
        let encodedUser =
            username.addingPercentEncoding(withAllowedCharacters: .urlUserAllowed)
            ?? username

        let encodedPass =
            password.addingPercentEncoding(withAllowedCharacters: .urlPasswordAllowed)
            ?? password

        DispatchQueue.global(qos: .background).async {
            for share in shares {
                let fullURL = "smb://\(encodedUser):\(encodedPass)@\(host)/\(share)"

                let script = """
                tell application "Finder"
                    try
                        mount volume "\(fullURL)"
                    on error
                    end try
                end tell
                """

                NSAppleScript(source: script)?.executeAndReturnError(nil)
            }
        }
    }

    private func isSMBPortReachable(host: String, timeout: Int = 1) -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/nc")
        process.arguments = ["-z", "-G", "\(timeout)", host, "445"]

        do {
            try process.run()
            process.waitUntilExit()

            return process.terminationStatus == 0
        } catch {
            return false
        }
    }

    private func parsedHost(from rawHost: String) -> String? {
        let trimmed = rawHost.trimmingCharacters(in: .whitespacesAndNewlines)
        let withScheme = trimmed.lowercased().hasPrefix("smb://")
            ? trimmed
            : "smb://\(trimmed)"

        guard let host = URL(string: withScheme)?.host, !host.isEmpty else {
            return nil
        }

        return host
    }
}
