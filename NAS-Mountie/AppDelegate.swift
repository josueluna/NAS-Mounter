import Cocoa
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {

    var statusBar: StatusBarController?
    private let startupMountManager = StartupMountManager()

    func applicationDidFinishLaunching(_ notification: Notification) {
        let showDockIcon = UserDefaults.standard.bool(forKey: "showDockIcon")
        NSApp.setActivationPolicy(showDockIcon ? .regular : .accessory)

        statusBar = StatusBarController()
        startupMountManager.scheduleStartupMountIfNeeded()
    }

    func applicationWillTerminate(_ notification: Notification) {
        startupMountManager.resetSessionState()
    }
}
