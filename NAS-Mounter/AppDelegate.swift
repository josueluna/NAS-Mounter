import SwiftUI

@main
struct NAS_MounterApp: App {
    // Asociamos AppDelegate a la aplicación
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
