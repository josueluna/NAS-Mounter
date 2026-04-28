import Cocoa
import SwiftUI
import Security

class AppDelegate: NSObject, NSApplicationDelegate {

    var statusBar: StatusBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let showDockIcon = UserDefaults.standard.bool(forKey: "showDockIcon")
        NSApp.setActivationPolicy(showDockIcon ? .regular : .accessory)

        statusBar = StatusBarController()

        // Attempt silent mount if runOnStartup is enabled.
        // SMAppService environment detection is unreliable across macOS versions,
        // so we use runOnStartup preference + a session flag to avoid re-mounting
        // when the user manually opens the popover after launch.
        let runOnStartup = UserDefaults.standard.bool(forKey: "runOnStartup")
        let alreadyMountedThisSession = UserDefaults.standard.bool(forKey: "_sessionMountDone")

        if runOnStartup && !alreadyMountedThisSession {
            UserDefaults.standard.set(true, forKey: "_sessionMountDone")
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.attemptSilentMount()
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Reset session flag so next launch mounts again
        UserDefaults.standard.removeObject(forKey: "_sessionMountDone")
    }

    // MARK: - Silent mount

    func attemptSilentMount() {
        guard let creds = loadCredentialsFromKeychain() else { return }

        let defaults = UserDefaults.standard
        let storedShares = defaults.string(forKey: "lastMountedShares") ?? "[]"
        guard let data = storedShares.data(using: .utf8),
              let shares = try? JSONDecoder().decode([String].self, from: data),
              !shares.isEmpty else { return }

        // Check allowed networks
        let allowedNetworksRaw = defaults.string(forKey: "allowedWiFiNetworks") ?? "[]"
        let allowedNetworks = NetworkHelper.decodeNetworks(from: allowedNetworksRaw)
        if !allowedNetworks.isEmpty {
            guard let currentSSID = NetworkHelper.currentSSID(),
                  allowedNetworks.contains(currentSSID) else { return }
        }

        let raw = creds.host.trimmingCharacters(in: .whitespaces)
        let withScheme = raw.lowercased().hasPrefix("smb://") ? raw : "smb://\(raw)"
        guard let host = URL(string: withScheme)?.host, !host.isEmpty else { return }

        let encodedUser = creds.username.addingPercentEncoding(
            withAllowedCharacters: .urlUserAllowed) ?? creds.username
        let encodedPass = creds.password.addingPercentEncoding(
            withAllowedCharacters: .urlPasswordAllowed) ?? creds.password

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

    // MARK: - Keychain

    private func loadCredentialsFromKeychain() -> (host: String, username: String, password: String)? {
        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrService as String: "com.nasmounter.credentials",
            kSecAttrAccount as String: "nas-credentials",
            kSecReturnData as String:  true,
            kSecMatchLimit as String:  kSecMatchLimitOne
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data,
              let decoded = try? JSONDecoder().decode([String: String].self, from: data),
              let host     = decoded["host"],
              let username = decoded["username"],
              let password = decoded["password"]
        else { return nil }
        return (host, username, password)
    }
}
