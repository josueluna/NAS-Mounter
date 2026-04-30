import Foundation
import CoreWLAN

enum NetworkHelper {

    // MARK: - SSID detection

    static func currentSSID() -> String? {
        if let ssid = currentSSIDUsingCoreWLAN() {
            return ssid
        }

        return currentSSIDUsingNetworkSetup()
    }

    static func currentSSIDFast() -> String? {
        currentSSIDUsingCoreWLAN()
    }

    private static func currentSSIDUsingCoreWLAN() -> String? {
        if let interface = CWWiFiClient.shared().interface(),
           let ssid = interface.ssid(),
           !ssid.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return ssid.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        for interfaceName in CWWiFiClient.shared().interfaceNames() ?? [] {
            if let interface = CWWiFiClient.shared().interface(withName: interfaceName),
               let ssid = interface.ssid(),
               !ssid.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return ssid.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        return nil
    }

    private static func currentSSIDUsingNetworkSetup() -> String? {
        let devices = wifiDevices()

        for device in devices {
            if let ssid = ssid(for: device) {
                return ssid
            }
        }

        return nil
    }

    // MARK: - Network list helpers

    static func encodeNetworks(_ networks: [String]) -> String {
        guard let data = try? JSONEncoder().encode(networks),
              let string = String(data: data, encoding: .utf8)
        else {
            return "[]"
        }

        return string
    }

    static func decodeNetworks(from rawValue: String) -> [String] {
        guard let data = rawValue.data(using: .utf8),
              let networks = try? JSONDecoder().decode([String].self, from: data)
        else {
            return []
        }

        return networks
    }

    // MARK: - networksetup fallback

    private static func wifiDevices() -> [String] {
        let output = runCommand(
            path: "/usr/sbin/networksetup",
            arguments: ["-listallhardwareports"]
        )

        let lines = output.components(separatedBy: .newlines)

        var devices: [String] = []
        var currentHardwarePort: String?

        for line in lines {
            if line.hasPrefix("Hardware Port:") {
                currentHardwarePort = line
                    .replacingOccurrences(of: "Hardware Port:", with: "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            }

            if line.hasPrefix("Device:") {
                let device = line
                    .replacingOccurrences(of: "Device:", with: "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)

                if currentHardwarePort == "Wi-Fi" || currentHardwarePort == "AirPort" {
                    devices.append(device)
                }
            }
        }

        return devices.isEmpty ? ["en0"] : devices
    }

    private static func ssid(for device: String) -> String? {
        let output = runCommand(
            path: "/usr/sbin/networksetup",
            arguments: ["-getairportnetwork", device]
        )

        let cleaned = output.trimmingCharacters(in: .whitespacesAndNewlines)

        guard cleaned.contains("Current Wi-Fi Network:") else {
            return nil
        }

        let ssid = cleaned
            .replacingOccurrences(of: "Current Wi-Fi Network:", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return ssid.isEmpty ? nil : ssid
    }

    private static func runCommand(path: String, arguments: [String]) -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = arguments

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
            process.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return String(data: data, encoding: .utf8) ?? ""
        } catch {
            return ""
        }
    }
}
