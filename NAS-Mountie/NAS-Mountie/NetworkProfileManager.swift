import Foundation

struct NetworkProfile: Codable, Equatable {
    let ssid: String
    let host: String
    let username: String
    let shares: [String]
}

enum NetworkProfileManager {

    private static let storageKey = "networkProfiles"

    static func loadProfiles() -> [String: NetworkProfile] {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let profiles = try? JSONDecoder().decode([String: NetworkProfile].self, from: data)
        else {
            return [:]
        }

        return profiles
    }

    static func profile(for ssid: String) -> NetworkProfile? {
        let profiles = loadProfiles()
        return profiles[ssid]
    }

    static func saveProfile(
        ssid: String,
        host: String,
        username: String,
        shares: [String]
    ) {
        var profiles = loadProfiles()

        let cleanedShares = shares
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .sorted {
                $0.localizedCaseInsensitiveCompare($1) == .orderedAscending
            }

        let profile = NetworkProfile(
            ssid: ssid,
            host: host,
            username: username,
            shares: cleanedShares
        )

        profiles[ssid] = profile
        saveProfiles(profiles)
    }

    static func deleteProfile(for ssid: String) {
        var profiles = loadProfiles()
        profiles.removeValue(forKey: ssid)
        saveProfiles(profiles)
    }

    static func deleteAllProfiles() {
        UserDefaults.standard.removeObject(forKey: storageKey)
    }

    private static func saveProfiles(_ profiles: [String: NetworkProfile]) {
        guard let data = try? JSONEncoder().encode(profiles) else {
            return
        }

        UserDefaults.standard.set(data, forKey: storageKey)
    }
}
