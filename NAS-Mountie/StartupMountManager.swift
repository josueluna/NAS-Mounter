import Foundation
import AppKit
import Network

final class StartupMountManager {
    private let defaults: UserDefaults
    private var networkMonitor: NWPathMonitor?
    private var hasMountedThisSession = false
    
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }
    
    func scheduleStartupMountIfNeeded() {
        guard shouldAttemptStartupMount else { return }
        waitForNetworkThenMount()
    }
    
    func resetSessionState() {
        defaults.removeObject(forKey: "_sessionMountDone")
        networkMonitor?.cancel()
        networkMonitor = nil
    }
    
    // MARK: - Private
    
    private var shouldAttemptStartupMount: Bool {
        let runOnStartup = defaults.bool(forKey: "runOnStartup")
        let alreadyMountedThisSession = defaults.bool(forKey: "_sessionMountDone")
        return runOnStartup && !alreadyMountedThisSession
    }
    
    /// Observes network reachability and fires mountLastSharesSilentlyIfAllowed()
    /// as soon as a usable path is available. Cancels the monitor after first attempt.
    private func waitForNetworkThenMount() {
        let monitor = NWPathMonitor()
        networkMonitor = monitor
        
        monitor.pathUpdateHandler = { [weak self] path in
            guard let self else { return }
            
            // Wait until the network is actually up
            guard path.status == .satisfied else { return }
            
            // Only mount once per session
            guard !self.hasMountedThisSession else { return }
            self.hasMountedThisSession = true
            self.defaults.set(true, forKey: "_sessionMountDone")
            
            // Cancel monitor — we only need the first successful connection
            monitor.cancel()
            self.networkMonitor = nil
            
            // Give the system a moment to stabilize SMB routing after network comes up
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                self.mountLastSharesSilentlyIfAllowed()
            }
        }
        
        // Use a background queue so it doesn't block the main thread
        monitor.start(queue: DispatchQueue(label: "com.nasmountie.networkmonitor"))
    }
    
    private func mountLastSharesSilentlyIfAllowed() {
        guard let credentials = KeychainHelper.load() else { return }
        guard let host = parsedHost(from: credentials.host) else { return }
        
        let shares = lastMountedShares()
        guard !shares.isEmpty else { return }
        
        // Check allowed networks — if list is empty, any network is allowed
        guard isAllowedOnCurrentNetwork() else { return }
        
        let encodedUser =
        credentials.username.addingPercentEncoding(withAllowedCharacters: .urlUserAllowed)
        ?? credentials.username
        let encodedPass =
        credentials.password.addingPercentEncoding(withAllowedCharacters: .urlPasswordAllowed)
        ?? credentials.password
        
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
    
    private func lastMountedShares() -> [String] {
        let storedShares = defaults.string(forKey: "lastMountedShares") ?? "[]"
        guard let data = storedShares.data(using: .utf8),
              let shares = try? JSONDecoder().decode([String].self, from: data)
        else { return [] }
        return shares
    }
    
    private func isAllowedOnCurrentNetwork() -> Bool {
        let allowedNetworksRaw = defaults.string(forKey: "allowedWiFiNetworks") ?? "[]"
        let allowedNetworks = NetworkHelper.decodeNetworks(from: allowedNetworksRaw)
        
        // Empty list = mount on any network
        guard !allowedNetworks.isEmpty else { return true }
        
        guard let currentSSID = NetworkHelper.currentSSID() else { return false }
        return allowedNetworks.contains(currentSSID)
    }
    
    private func parsedHost(from rawHost: String) -> String? {
        let trimmed = rawHost.trimmingCharacters(in: .whitespaces)
        let withScheme = trimmed.lowercased().hasPrefix("smb://") ? trimmed : "smb://\(trimmed)"
        guard let host = URL(string: withScheme)?.host, !host.isEmpty else { return nil }
        return host
    }
}

