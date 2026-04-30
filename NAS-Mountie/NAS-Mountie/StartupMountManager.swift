import Foundation
import Network

final class StartupMountManager {

    private let defaults: UserDefaults
    private var networkMonitor: NWPathMonitor?

    private var hasMountedThisSession = false
    private var retryCount = 0
    private var isAttemptInProgress = false

    private let maxRetryCount = 60
    private let retryDelay: TimeInterval = 3.0

    private let monitorQueue = DispatchQueue(
        label: "com.nasmountie.startup.network-monitor",
        qos: .utility
    )

    private let startupQueue = DispatchQueue(
        label: "com.nasmountie.startup.mount",
        qos: .userInitiated
    )

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    // MARK: - Public

    func scheduleStartupMountIfNeeded() {
        StartupLogger.log("scheduleStartupMountIfNeeded called", source: "StartupMountManager")

        guard shouldAttemptStartupMount else {
            StartupLogger.log(
                "Startup mount skipped. runOnStartup disabled or already mounted this session.",
                source: "StartupMountManager"
            )
            return
        }

        StartupLogger.log(
            "Startup mount allowed. Starting repeated attempts every \(retryDelay)s, max \(maxRetryCount) attempts.",
            source: "StartupMountManager"
        )

        startNetworkMonitor()

        startupQueue.async {
            self.attemptMountWithRetry()
        }
    }

    func resetSessionState() {
        StartupLogger.log("Resetting startup mount session state.", source: "StartupMountManager")

        hasMountedThisSession = false
        retryCount = 0
        isAttemptInProgress = false
        stopMonitor()
    }

    // MARK: - Private

    private var shouldAttemptStartupMount: Bool {
        defaults.bool(forKey: "runOnStartup") && !hasMountedThisSession
    }

    private func startNetworkMonitor() {
        stopMonitor()

        StartupLogger.log("Starting NWPathMonitor.", source: "StartupMountManager")

        let monitor = NWPathMonitor()
        networkMonitor = monitor

        monitor.pathUpdateHandler = { [weak self] path in
            guard let self else { return }

            StartupLogger.log(
                "Network path status changed: \(path.status)",
                source: "StartupMountManager"
            )

            guard path.status == .satisfied else {
                return
            }

            guard !self.hasMountedThisSession else {
                StartupLogger.log(
                    "Network satisfied, but startup mount already completed this session.",
                    source: "StartupMountManager"
                )
                return
            }

            self.startupQueue.async {
                StartupLogger.log(
                    "Network satisfied. Triggering immediate mount attempt.",
                    source: "StartupMountManager"
                )

                self.attemptMountWithRetry()
            }
        }

        monitor.start(queue: monitorQueue)
    }

    private func stopMonitor() {
        networkMonitor?.cancel()
        networkMonitor = nil
    }

    // MARK: - Retry flow

    private func attemptMountWithRetry() {
        guard shouldAttemptStartupMount else {
            StartupLogger.log(
                "Retry stopped. shouldAttemptStartupMount is false.",
                source: "StartupMountManager"
            )
            return
        }

        guard !isAttemptInProgress else {
            StartupLogger.log(
                "Attempt skipped. Another startup mount attempt is already in progress.",
                source: "StartupMountManager"
            )
            return
        }

        retryCount += 1

        StartupLogger.log(
            "Startup mount attempt #\(retryCount) of \(maxRetryCount).",
            source: "StartupMountManager"
        )

        guard retryCount <= maxRetryCount else {
            StartupLogger.log(
                "Max retry count reached. Startup automount stopped.",
                source: "StartupMountManager"
            )

            StartupNotificationHelper.notify(
                title: "NAS-Mountie couldn't auto-mount shares",
                body: "Open NAS-Mountie to check your network connection or saved credentials."
            )

            return
        }

        isAttemptInProgress = true

        let didMount = attemptMount()

        isAttemptInProgress = false

        if didMount {
            hasMountedThisSession = true
            stopMonitor()

            StartupLogger.log(
                "Startup automount completed successfully.",
                source: "StartupMountManager"
            )

            return
        }

        guard retryCount < maxRetryCount else {
            StartupLogger.log(
                "Startup mount attempt failed. No retries left.",
                source: "StartupMountManager"
            )

            StartupNotificationHelper.notify(
                title: "NAS-Mountie couldn't auto-mount shares",
                body: "Open NAS-Mountie to check your network connection or saved credentials."
            )

            return
        }

        StartupLogger.log(
            "Startup mount attempt failed. Retrying in \(retryDelay)s.",
            source: "StartupMountManager"
        )

        startupQueue.asyncAfter(deadline: .now() + retryDelay) {
            self.attemptMountWithRetry()
        }
    }

    // MARK: - Mount strategy

    @discardableResult
    private func attemptMount() -> Bool {
        let profiles = NetworkProfileManager.loadProfiles()

        guard !profiles.isEmpty else {
            StartupLogger.log(
                "No saved network profiles available.",
                source: "StartupMountManager"
            )
            return false
        }

        let profilesToTry = prioritizedProfiles(from: profiles)

        StartupLogger.log(
            "Profiles to try: \(profilesToTry.map { $0.ssid }.joined(separator: ", "))",
            source: "StartupMountManager"
        )

        for profile in profilesToTry {
            if attemptMount(profile: profile) {
                return true
            }
        }

        return false
    }

    private func prioritizedProfiles(from profiles: [String: NetworkProfile]) -> [NetworkProfile] {
        StartupLogger.log(
            "Reading current SSID using fast CoreWLAN path.",
            source: "StartupMountManager"
        )

        if let ssid = NetworkHelper.currentSSIDFast() {
            StartupLogger.log("Current SSID from fast path: \(ssid)", source: "StartupMountManager")

            if let currentProfile = profiles[ssid] {
                let otherProfiles = profiles
                    .values
                    .filter { $0.ssid != ssid }
                    .sorted {
                        $0.ssid.localizedCaseInsensitiveCompare($1.ssid) == .orderedAscending
                    }

                return [currentProfile] + otherProfiles
            }

            StartupLogger.log(
                "No saved profile matched current SSID: \(ssid). Will try saved profiles by reachable host.",
                source: "StartupMountManager"
            )
        } else {
            StartupLogger.log(
                "Current SSID not available from fast path. Will try saved profiles by reachable host.",
                source: "StartupMountManager"
            )
        }

        return profiles
            .values
            .sorted {
                $0.ssid.localizedCaseInsensitiveCompare($1.ssid) == .orderedAscending
            }
    }

    private func attemptMount(profile: NetworkProfile) -> Bool {
        StartupLogger.log(
            "Trying profile: \(profile.ssid). Host: \(profile.host). Shares: \(profile.shares.joined(separator: ", "))",
            source: "StartupMountManager"
        )

        guard !profile.shares.isEmpty else {
            StartupLogger.log(
                "Profile \(profile.ssid) has no saved shares.",
                source: "StartupMountManager"
            )
            return false
        }

        guard let credentials = KeychainHelper.load() else {
            StartupLogger.log(
                "Keychain credentials not available.",
                source: "StartupMountManager"
            )
            return false
        }

        guard let host = parsedHost(from: profile.host) else {
            StartupLogger.log(
                "Could not parse host from profile host: \(profile.host)",
                source: "StartupMountManager"
            )
            return false
        }

        StartupLogger.log(
            "Checking SMB port 445 for profile \(profile.ssid), host: \(host).",
            source: "StartupMountManager"
        )

        guard isSMBPortReachable(host: host) else {
            StartupLogger.log(
                "SMB port not reachable for profile \(profile.ssid), host: \(host).",
                source: "StartupMountManager"
            )
            return false
        }

        StartupLogger.log(
            "SMB port reachable for profile \(profile.ssid). Mounting shares.",
            source: "StartupMountManager"
        )

        mount(
            host: host,
            username: profile.username,
            password: credentials.password,
            shares: profile.shares
        )

        return true
    }

    private func mount(
        host: String,
        username: String,
        password: String,
        shares: [String]
    ) {
        StartupLogger.log(
            "Mount requested for shares using open: \(shares.joined(separator: ", "))",
            source: "StartupMountManager"
        )

        let encodedUser =
            username.addingPercentEncoding(withAllowedCharacters: .urlUserAllowed)
            ?? username

        let encodedPass =
            password.addingPercentEncoding(withAllowedCharacters: .urlPasswordAllowed)
            ?? password

        for share in shares {
            let fullURL = "smb://\(encodedUser):\(encodedPass)@\(host)/\(share)"

            StartupLogger.log(
                "Opening SMB URL for share: \(share)",
                source: "StartupMountManager"
            )

            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
            process.arguments = [fullURL]

            do {
                try process.run()

                StartupLogger.log(
                    "open command launched for share: \(share)",
                    source: "StartupMountManager"
                )
            } catch {
                StartupLogger.log(
                    "open command failed for share \(share): \(error.localizedDescription)",
                    source: "StartupMountManager"
                )
            }
        }

        StartupLogger.log("Mount flow dispatched.", source: "StartupMountManager")
    }

    // MARK: - Helpers

    private func isSMBPortReachable(host: String) -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/nc")
        process.arguments = ["-z", "-G", "1", host, "445"]

        do {
            try process.run()
            process.waitUntilExit()

            return process.terminationStatus == 0
        } catch {
            StartupLogger.log(
                "SMB port check failed with error: \(error.localizedDescription)",
                source: "StartupMountManager"
            )
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
