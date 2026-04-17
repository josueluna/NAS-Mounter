import SwiftUI
import AppKit

struct ContentView: View {
    
    @State private var smbURL = ""
    @State private var username = ""
    @State private var password = ""
    @State private var remember = false
    @State private var status = ""
    
    var body: some View {
        VStack(spacing: 20.0) {
            
            Text("NAS Mounter")
                .font(.title2)
                .fontWeight(.semibold)
                .padding(.bottom, 0)
            
            VStack(spacing: 15) {
                
                // SMB input field
                fieldRow(title: "SMB", placeholder: "smb://192.168.xx.xxx // NAS IP adress", text: $smbURL)
                    .frame(width: 250)  // Ajustar el ancho del campo
                
                // Username input field
                fieldRow(title: "User", placeholder: "Username", text: $username)
                    .frame(width: 250)  // Ajustar el ancho del campo

                // Password input field
                secureRow(title: "Password", placeholder: "Password", text: $password)
                    .frame(width: 250)  // Ajustar el ancho del campo
            }
            
            // Remember me toggle
            Toggle("Remember in Keychain", isOn: $remember)
                .toggleStyle(.checkbox)
                .padding(.top, 4)
            
            // Mount button
            Button(action: mountNAS) {
                Text("Mount Volume")
                    .frame(width: 220)  // Ajustar el ancho del botón
                    .padding(.vertical, 8)
            }
            .buttonStyle(PlainButtonStyle())  // Style for more custom button appearance
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(20)
            .padding(.top, 10)
            .disabled(smbURL.isEmpty || username.isEmpty)
            
            // Status message
            if !status.isEmpty {
                Text(status)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 20.0)  // Reducir margen horizontal para hacerlo más compacto
        .frame(width: 450.0, height: 300.0) // Ajustar el tamaño de la ventana
    }
    
    // 🔥 FUNCIÓN CORREGIDA
    func mountNAS() {
        
        guard !smbURL.isEmpty, !username.isEmpty else {
            status = "Missing required fields"
            return
        }
        
        let cleanURL = smbURL.replacingOccurrences(of: "smb://", with: "")
        
        // 🔥 Escapar usuario y password (CLAVE)
        let userEncoded = username.addingPercentEncoding(withAllowedCharacters: .urlUserAllowed) ?? username
        let passEncoded = password.addingPercentEncoding(withAllowedCharacters: .urlPasswordAllowed) ?? password
        
        let fullURLString = "smb://\(userEncoded):\(passEncoded)@\(cleanURL)"
        
        print("DEBUG URL:", fullURLString) // 👈 útil
        
        guard let url = URL(string: fullURLString) else {
            status = "Invalid URL"
            return
        }
        
        NSWorkspace.shared.open(url)
        
        status = "Connecting..."
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            NSApplication.shared.terminate(nil)
        }
    }
}

// 🔹 Campo normal
func fieldRow(title: String, placeholder: String, text: Binding<String>) -> some View {
    HStack {
        Text(title)
            .frame(width: 80, alignment: .leading)
        
        TextField(placeholder, text: text)
            .textFieldStyle(RoundedBorderTextFieldStyle())
    }
}

// 🔹 Campo seguro (password)
func secureRow(title: String, placeholder: String, text: Binding<String>) -> some View {
    HStack {
        Text(title)
            .frame(width: 80, alignment: .leading)
        
        SecureField(placeholder, text: text)
            .textFieldStyle(RoundedBorderTextFieldStyle())
    }
}

#Preview {
    ContentView()
}
