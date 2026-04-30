import Foundation
import UserNotifications

enum StartupNotificationHelper {

    static func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            if let error {
                StartupLogger.log(
                    "Notification authorization error: \(error.localizedDescription)",
                    source: "StartupNotificationHelper"
                )
                return
            }

            StartupLogger.log(
                "Notification authorization granted: \(granted)",
                source: "StartupNotificationHelper"
            )
        }
    }

    static func notify(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "nas-mountie-startup-mount-failed-\(UUID().uuidString)",
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                StartupLogger.log(
                    "Notification delivery error: \(error.localizedDescription)",
                    source: "StartupNotificationHelper"
                )
            } else {
                StartupLogger.log(
                    "Startup failure notification delivered.",
                    source: "StartupNotificationHelper"
                )
            }
        }
    }
}
