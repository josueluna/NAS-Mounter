import Foundation
import AppKit
import Network

final class StartupMountManager {
    private let defaults: UserDefaults
    private var networkMonitor: NWPathMonitor?
    private var currentPathStatus: NWPath.Status = .requiresConnection
    private var pollTimer: DispatchSourceTimer?
    private var hasMountedThisSession = false
    private var isMountAttemptInProgress = false

    private let monitorQueue = DispatchQueue(label: "com.nasmountie.networkmonitor")
    private let pollQueue = DispatchQueue(label: "com.nasmountie.startup-poller", qos: .utility)
    private let mountQueue = DispatchQueue(label: "com.nasmountie.startup-mount", qos: .utility)

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func scheduleStartupMountIfNeeded() {
        guard shouldAttemptStartupMount else { return }
        startNetworkMonitor()
        startPolling()
    }

    func resetSessionState() {
        defaults.removeObject(forKey: "_sessionMountDone")
        stopPolling()
        networkMonitor?.cancel()
        networkMonitor = nil
        currentPathStatus = .requiresConnection
        hasMountedThisSession = false
        isMountAttemptInProgress = false
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
        }

        monitor.start(queue: monitorQueue)
    }

    private func startPolling() {
        stopPolling()

        let timer = DispatchSource.makeTimerSource(queue: pollQueue)
        timer.schedule(deadline: .now(), repeating: .seconds(1))
        timer.setEventHandler { [weak self] in
            self?.pollStartupAutoMount()
        }
        pollTimer = timer
        timer.resume()
    }

    private func stopPolling() {
        pollTimer?.setEventHandler {}
        pollTimer?.cancel()
        pollTimer = nil
    }

    private func pollStartupAutoMount() {
        guard shouldAttemptStartupMount else {
            stopPolling()
            return
        }

        guard !hasMountedThisSession else {
            stopPolling()
            return
        }

        guard !isMountAttemptInProgress else { return }
        guard currentPathStatus == .satisfied else { return }

        isMountAttemptInProgress = true
        let mounted = mountLastSharesSilentlyIfAllowed()
        isMountAttemptInProgress = false

        if mounted {
            hasMountedThisSession = true
            defaults.set(true, forKey: "_sessionMountDone")
            stopPolling()
            networkMonitor?.cancel()
            networkMonitor = nil
        }
    }

    private func mountLastSharesSilentlyIfAllowed() -> Bool {
        guard let currentSSID = NetworkHelper.currentSSID() else { return false }
        guard isAllowedOnCurrentNetwork(currentSSID) else { return false }

        guard let profile = NetworkProfileManager.profile(for: currentSSID) else {
            return false
        }

        guard let credentials = KeychainHelper.load() else { return false }
        guard let host = parsedHost(from: profile.host) else { return false }

        let shares = profile.shares
        guard !shares.isEmpty else { return false }

        let encodedUser =
            profile.username.addingPercentEncoding(withAllowedCharacters: .urlUserAllowed)
            ?? profile.username

        let encodedPass =
            credentials.password.addingPercentEncoding(withAllowedCharacters: .urlPasswordAllowed)
            ?? credentials.password

        guard isSMBPortReachable(host: host) else { return false }

        return mountSharesConcurrently(
            shares: shares,
            host: host,
            encodedUser: encodedUser,
            encodedPass: encodedPass
        )
    }

    private func parsedHost(from rawHost: String) -> String? {
        let trimmed = rawHost.trimmingCharacters(in: .whitespaces)
        let withScheme = trimmed.lowercased().hasPrefix("smb://") ? trimmed : "smb://\(trimmed)"
        guard let host = URL(string: withScheme)?.host, !host.isEmpty else { return nil }
        return host
    }

    private func isAllowedOnCurrentNetwork(_ currentSSID: String) -> Bool {
        let raw = defaults.string(forKey: "allowedWiFiNetworks") ?? "[]"
        let allowed = NetworkHelper.decodeNetworks(from: raw)
        guard !allowed.isEmpty else { return true }
        return allowed.contains(currentSSID)
    }

    private func isSMBPortReachable(host: String, timeout: TimeInterval = 1.5) -> Bool {
        let semaphore = DispatchSemaphore(value: 0)
        var reachable = false

        let params = NWParameters.tcp
        params.prohibitExpensivePaths = false

        let connection = NWConnection(
            host: NWEndpoint.Host(host),
            port: 445,
            using: params
        )

        connection.stateUpdateHandler = { state in
            switch state {
            case .ready:
                reachable = true
                connection.cancel()
                semaphore.signal()
            case .failed(_), .cancelled:
                semaphore.signal()
            default:
                break
            }
        }

        connection.start(queue: mountQueue)
        let result = semaphore.wait(timeout: .now() + timeout)
        connection.cancel()

        return result == .success && reachable
    }

    private func mountSharesConcurrently(
        shares: [String],
        host: String,
        encodedUser: String,
        encodedPass: String
    ) -> Bool {
        let queue = OperationQueue()
        queue.qualityOfService = .utility
        queue.maxConcurrentOperationCount = 2

        let lock = NSLock()
        var mountedCount = 0

        for share in shares {
            queue.addOperation {
                let fullURL = "smb://\(encodedUser):\(encodedPass)@\(host)/\(share)"
                let script = """
                tell application "Finder"
                    try
                        mount volume "\(fullURL)"
                        return "ok"
                    on error
                        return "error"
                    end try
                end tell
                """

                var errorDict: NSDictionary?
                let result = NSAppleScript(source: script)?.executeAndReturnError(&errorDict)
                let succeeded = (errorDict == nil) && (result?.stringValue == "ok")

                if succeeded {
                    lock.lock()
                    mountedCount += 1
                    lock.unlock()
                }
            }
        }

        queue.waitUntilAllOperationsAreFinished()
        return mountedCount > 0
    }
}
