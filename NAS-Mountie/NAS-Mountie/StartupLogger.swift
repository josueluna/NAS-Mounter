import Foundation

enum StartupLogger {
    private static let queue = DispatchQueue(label: "com.nasmountie.startup.logger", qos: .utility)

    private static var logURL: URL? {
        let fileManager = FileManager.default

        guard let applicationSupportURL = fileManager.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first else {
            return nil
        }

        let folderURL = applicationSupportURL.appendingPathComponent(
            "NAS-Mountie",
            isDirectory: true
        )

        do {
            try fileManager.createDirectory(
                at: folderURL,
                withIntermediateDirectories: true
            )
        } catch {
            return nil
        }

        return folderURL.appendingPathComponent("startup.log")
    }

    static func log(_ message: String, source: String = "NAS-Mountie") {
        let timestamp = timestamp()
        let line = "[\(timestamp)] [\(source)] \(message)\n"

        queue.async {
            guard let logURL else { return }
            guard let data = line.data(using: .utf8) else { return }

            if FileManager.default.fileExists(atPath: logURL.path) {
                if let handle = try? FileHandle(forWritingTo: logURL) {
                    defer { try? handle.close() }
                    try? handle.seekToEnd()
                    try? handle.write(contentsOf: data)
                }
            } else {
                try? data.write(to: logURL)
            }
        }
    }

    static func resetLog() {
        let timestamp = timestamp()
        let line = "[\(timestamp)] [StartupLogger] Log reset\n"

        queue.async {
            guard let logURL else { return }
            try? line.write(to: logURL, atomically: true, encoding: .utf8)
        }
    }

    private static func timestamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        return formatter.string(from: Date())
    }
}
