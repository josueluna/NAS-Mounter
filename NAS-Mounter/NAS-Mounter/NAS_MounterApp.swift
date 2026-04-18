import SwiftUI

@main
struct NASMounterApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowResizability(.contentSize)
        .defaultSize(width: 380, height: 1)
    }
}
