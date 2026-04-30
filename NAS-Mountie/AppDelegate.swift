import Cocoa
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {

    var statusBar: StatusBarController?
    private let startupMountManager = StartupMountManager()

    func applicationDidFinishLaunching(_ notification: Notification) {
        StartupLogger.resetLog()
        StartupLogger.log("App did finish launching", source: "AppDelegate")

        let showDockIcon = UserDefaults.standard.bool(forKey: "showDockIcon")
        StartupLogger.log("Loaded showDockIcon setting: \(showDockIcon)", source: "AppDelegate")

        NSApp.setActivationPolicy(showDockIcon ? .regular : .accessory)
        StartupLogger.log("Activation policy applied", source: "AppDelegate")

        StartupLogger.log("Creating StatusBarController", source: "AppDelegate")
        statusBar = StatusBarController()
        StartupLogger.log("StatusBarController created", source: "AppDelegate")

        StartupLogger.log("Requesting notification authorization", source: "AppDelegate")
        StartupNotificationHelper.requestAuthorization()

        StartupLogger.log("Calling scheduleStartupMountIfNeeded", source: "AppDelegate")
        startupMountManager.scheduleStartupMountIfNeeded()
    }

    func applicationWillTerminate(_ notification: Notification) {
        startupMountManager.resetSessionState()
    }
}
