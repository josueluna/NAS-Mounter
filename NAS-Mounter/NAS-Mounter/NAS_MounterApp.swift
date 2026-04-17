import SwiftUI

@main
struct NAS_MounterApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(width: 380, height: 260)
                .onAppear {
                    if let window = NSApplication.shared.windows.first {
                        window.title = "NAS Mounter"  // Establece el título de la ventana
                    }
                }
        }
    }
}
