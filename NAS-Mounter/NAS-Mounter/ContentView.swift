import SwiftUI
import AppKit

struct ContentView: View {
    
    @State private var smbURL = "smb://192.168.68.110/Cronos"
    @State private var username = ""
    @State private var password = ""
    @State private var remember = false
    @State private var status = ""
    
    var body: some View {
        
        VStack(spacing: 16) {
            
            // 🔹 Título
            Text("NAS Mounter")
                .font(.title3)
                .fontWeight(.semibold)
            
            VStack(spacing: 10) {
                
                inputField("SMB URL", text: $smbURL)
                inputField("Usuario", text: $username)
                
                SecureField("Contraseña", text: $password)
                    .textFieldStyle(.roundedBorder)
                
                Toggle("Recordar credenciales", isOn: $remember)
                    .font(.system(size: 12))
            }
            
            // 🔹 Botón
            Button(action: mountNAS) {
                Text("Conectar")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            
            // 🔹 Status
            Text(status)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(20)
    }
    
    // 🔧 Campo reutilizable
    func inputField(_ placeholder: String, text: Binding<String>) -> some View {
        TextField(placeholder, text: text)
            .textFieldStyle(.roundedBorder)
    }
    
    // 🚀 Lógica de conexión SMB
    func mountNAS() {
        guard let url = URL(string: smbURL) else {
            status = "URL inválida"
            return
        }
        
        let workspace = NSWorkspace.shared
        
        workspace.open(
            [url],
            withApplicationAt: URL(fileURLWithPath: "/System/Library/CoreServices/Finder.app"),
            configuration: NSWorkspace.OpenConfiguration()
        ) { _, error in
            if let error = error {
                status = "Error: \(error.localizedDescription)"
            } else {
                status = "Conectado correctamente ✅"
            }
        }
    }
}
