import Cocoa

class AppDelegate: NSObject, NSApplicationDelegate {

    var statusBar: StatusBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Obtener la preferencia de "Show Dock Icon" desde UserDefaults
        let showDockIcon = UserDefaults.standard.bool(forKey: "showDockIcon")

        // Verificar si se debe mostrar el ícono del Dock
        if showDockIcon {
            // Si el usuario ha activado la opción, se muestra el ícono en el Dock
            NSApp.setActivationPolicy(.regular)  // Activar el ícono del Dock
        } else {
            // Si el usuario ha desactivado la opción, se oculta el ícono del Dock
            NSApp.setActivationPolicy(.accessory)  // Ocultar el ícono del Dock
        }

        // Inicializar la barra de menús
        statusBar = StatusBarController()
    }
}
