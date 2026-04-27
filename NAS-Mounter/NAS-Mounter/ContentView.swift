import SwiftUI
import Security

// ── Keychain Helper ─────────────────────────────
struct KeychainHelper {
    static let service = "com.nasmounter.credentials"

    static func save(host: String, username: String, password: String) {
        let data: [String: String] = [
            "host": host,
            "username": username,
            "password": password
        ]
        guard let encoded = try? JSONEncoder().encode(data) else { return }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: "nas-credentials"
        ]

        let updateFields: [String: Any] = [kSecValueData as String: encoded]
        let status = SecItemUpdate(query as CFDictionary, updateFields as CFDictionary)

        if status == errSecItemNotFound {
            var newItem = query
            newItem[kSecValueData as String] = encoded
            SecItemAdd(newItem as CFDictionary, nil)
        }
    }

    static func load() -> (host: String, username: String, password: String)? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: "nas-credentials",
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data,
              let decoded = try? JSONDecoder().decode([String: String].self, from: data),
              let host = decoded["host"],
              let username = decoded["username"],
              let password = decoded["password"]
        else { return nil }

        return (host, username, password)
    }

    static func delete() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: "nas-credentials"
        ]
        SecItemDelete(query as CFDictionary)
    }
}

// ── MAIN VIEW ───────────────────────────────────
struct ContentView: View {

    @State private var showAppMenu = false
    @State private var smbURL    = ""
    @State private var username  = ""
    @State private var password  = ""
    @State private var remember  = false

    @State private var status      = ""
    @State private var isConnecting  = false
    @State private var isSuccess     = false

    @State private var availableShares: [String] = []
    @State private var selectedShares: Set<String> = []
    @State private var showSharePicker  = false
    @State private var isFetchingShares = false

    // FIX #1: host se extrae una sola vez y se reutiliza en toda la vista
    private var extractedHost: String {
        let raw = smbURL.trimmingCharacters(in: .whitespaces)
        let withScheme = raw.lowercased().hasPrefix("smb://") ? raw : "smb://\(raw)"
        return URL(string: withScheme)?.host ?? ""
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // ── Header ──────────────────────────────
            HStack(spacing: 10) {
                Image(systemName: "externaldrive.fill.badge.wifi")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(.blue)
                Text("NAS Mounter")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
            }
            .padding(.bottom, 20)

            // ── Fields ──────────────────────────────
            VStack(spacing: 12) {

                FieldRow(label: "SMB") {
                    HStack(spacing: 6) {
                        TextField("192.168.X.X  o  192.168.X.X/Share", text: $smbURL)
                            .textFieldStyle(.plain)
                            .styledField()
                        
                        Button {
                            fetchShares()
                        } label: {
                            Group {
                                if isFetchingShares {
                                    ProgressView()
                                        .scaleEffect(0.6)
                                        .frame(width: 28, height: 28)
                                } else {
                                    Image(systemName: "list.bullet.rectangle")
                                        .font(.system(size: 13))
                                        .frame(width: 28, height: 28)
                                }
                            }
                            .background(
                                RoundedRectangle(cornerRadius: 7)
                                    .fill(Color(NSColor.controlBackgroundColor))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 7)
                                            .strokeBorder(Color.blue.opacity(0.35), lineWidth: 1)
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                        .disabled(username.isEmpty || password.isEmpty || isFetchingShares)
                        .opacity((username.isEmpty || password.isEmpty) ? 0.4 : 1)
                        .help("Browse available shares")
                    }
                }

                FieldRow(label: "User") {
                    TextField("Username", text: $username)
                        .textFieldStyle(.plain)
                        .styledField()
                }

                FieldRow(label: "Password") {
                    SecureField("Password", text: $password)
                        .textFieldStyle(.plain)
                        .styledField()
                        .onSubmit { handleConnect() }
                }
            }

            if showSharePicker {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Available shares — choose at least one:")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                        Spacer()
                        if !availableShares.isEmpty {
                            Text("\(availableShares.count) shares")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.top, 12)

                    if isFetchingShares {
                        HStack {
                            Spacer()
                            ProgressView("Searching…")
                                .font(.system(size: 12))
                            Spacer()
                        }
                        .frame(height: 60)
                    } else if availableShares.isEmpty {
                        HStack {
                            Spacer()
                            Text("No shares found")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                        .frame(height: 60)
                    } else {
                        ScrollView(.vertical, showsIndicators: true) {
                            VStack(spacing: 0) {
                                ForEach(availableShares, id: \.self) { share in
                                    Button {
                                        if selectedShares.contains(share) {
                                            selectedShares.remove(share)
                                        } else {
                                            selectedShares.insert(share)
                                        }
                                    } label: {
                                        HStack(spacing: 8) {
                                            Image(systemName:
                                                selectedShares.contains(share)
                                                    ? "checkmark.circle.fill"
                                                    : "circle"
                                            )
                                            .foregroundColor(.blue)
                                            .font(.system(size: 13))

                                            Image(systemName: "externaldrive")
                                                .font(.system(size: 11))
                                                .foregroundColor(.secondary)

                                            Text(share)
                                                .font(.system(size: 13))
                                                .foregroundColor(.primary)
                                            Spacer()
                                        }
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 8)
                                        .background(
                                            selectedShares.contains(share)
                                                ? Color.blue.opacity(0.08)
                                                : Color.clear
                                        )
                                        .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)

                                    if share != availableShares.last {
                                        Divider().padding(.leading, 10)
                                    }
                                }
                            }
                        }
                        .frame(maxHeight: CGFloat(min(availableShares.count, 4)) * 36)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(NSColor.controlBackgroundColor))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .strokeBorder(Color.blue.opacity(0.35), lineWidth: 1)
                                )
                        )
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            Toggle(isOn: $remember) {
                Text("Remember Password")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
            .toggleStyle(ModernCheckboxStyle())
            .padding(.top, 14)

            Button(action: handleConnect) {
                HStack(spacing: 8) {
                    if isConnecting {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.75)
                    }
                    Text(isConnecting ? "Connecting…" : "Connect")
                        .font(.system(size: 15, weight: .semibold))
                }
                .frame(maxWidth: .infinity, minHeight: 40)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(isConnecting ? Color.blue.opacity(0.7) : Color.blue)
                )
                .foregroundColor(.white)
            }
            .buttonStyle(.plain)
            .disabled(isConnecting)
            .padding(.top, 16)

            if !status.isEmpty {
                if isSuccess {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .font(.system(size: 13))
                            Text("Drive mounted successfully")
                                .font(.system(size: 13, weight: .semibold))
                        }
                        Text("This window will close shortly...")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .padding(.leading, 19)
                    }
                    .padding(.top, 12)
                } else {
                    HStack(spacing: 5) {
                        Image(systemName: "exclamationmark.circle.fill")
                            .foregroundColor(.red)
                            .font(.system(size: 12))
                        Text(status)
                            .font(.system(size: 12))
                            .foregroundColor(.red)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.top, 10)
                }
            }
        }
        
        .padding(.top, 24)
        .padding(.horizontal, 24)
        .padding(.bottom, 40)
        .frame(width: 380)
        
        .overlay(alignment: .bottomTrailing) {
            Button {
                showAppMenu.toggle()
            } label: {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.primary)
                    .padding(8)
            }
            .buttonStyle(.plain)

            .background(Color.clear)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.gray.opacity(0.15))
            )
            .offset(y: -8) // mueve hacia abajo SIN afectar layout
            .padding(.trailing, 12)
            .popover(isPresented: $showAppMenu, arrowEdge: .bottom) {
                VStack(alignment: .leading, spacing: 12) {
                    Button("Close NAS-Mounter") {
                        NSApp.terminate(nil)
                    }
                    .buttonStyle(.plain)
                }
                .padding(16)
                .frame(width: 180)
            }
        }
        
        .fixedSize(horizontal: false, vertical: true)
        .animation(.easeInOut(duration: 0.2), value: showSharePicker)
        .animation(.easeInOut(duration: 0.2), value: status)
        .onAppear {
            // FIX #8: cargar credenciales del Keychain al abrir
            if let saved = KeychainHelper.load() {
                smbURL   = saved.host
                username = saved.username
                password = saved.password
                remember = true
            }
        }
    }

    func handleConnect() {
        guard !username.isEmpty, !password.isEmpty else {
            status = "Type user and password."
            isSuccess = false
            return
        }

        let host = extractedHost
        guard !host.isEmpty else {
            status = "Invalid IP/URL"
            isSuccess = false
            return
        }

        let hasShareInURL = {
            let raw = smbURL.trimmingCharacters(in: .whitespaces)
            let withScheme = raw.lowercased().hasPrefix("smb://") ? raw : "smb://\(raw)"
            guard let url = URL(string: withScheme) else { return false }
            return url.pathComponents.dropFirst().first != nil
        }()

        if selectedShares.isEmpty && !hasShareInURL {
            fetchShares()
            return
        }

        mountShares()
    }

    func fetchShares() {
        guard !username.isEmpty, !password.isEmpty else {
            status = "Ingresa usuario y contraseña primero."
            isSuccess = false
            return
        }

        let host = extractedHost
        guard !host.isEmpty else {
            status = "Ingresa la IP del NAS primero."
            isSuccess = false
            return
        }

        isFetchingShares = true
        showSharePicker  = true
        availableShares  = []
        selectedShares   = []
        status           = ""

        let encodedUser = username.addingPercentEncoding(withAllowedCharacters: .urlUserAllowed) ?? username
        let encodedPass = password.addingPercentEncoding(withAllowedCharacters: .urlPasswordAllowed) ?? password

        DispatchQueue.global(qos: .userInitiated).async {

            let task = Process()
            task.launchPath = "/usr/bin/smbutil"
            task.arguments = ["view", "//\(encodedUser):\(encodedPass)@\(host)"]

            let outPipe = Pipe()
            let errPipe = Pipe()
            task.standardOutput = outPipe
            task.standardError  = errPipe

            task.launch()
            task.waitUntilExit()

            let outData = outPipe.fileHandleForReading.readDataToEndOfFile()
            let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
            let output  = String(data: outData, encoding: .utf8) ?? ""
            let errOut  = String(data: errData, encoding: .utf8) ?? ""

            if task.terminationStatus != 0 || output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                let errMsg = errOut.trimmingCharacters(in: .whitespacesAndNewlines)
                DispatchQueue.main.async {
                    self.isFetchingShares = false
                    self.showSharePicker  = false
                    self.status = errMsg.isEmpty
                        ? "No se pudo conectar. Verifica IP y credenciales."
                        : "Error: \(errMsg)"
                    self.isSuccess = false
                }
                return
            }

            let shares = output
                .components(separatedBy: "\n")
                .compactMap { line -> String? in
                    let parts = line
                        .trimmingCharacters(in: .whitespaces)
                        .components(separatedBy: .whitespaces)
                        .filter { !$0.isEmpty }
                    guard parts.count >= 2, parts[1] == "Disk" else { return nil }
                    let name = parts[0]
                    // filtrar shares admin ($) y vacíos
                    guard !name.hasSuffix("$"), !name.isEmpty else { return nil }
                    return name
                }

            DispatchQueue.main.async {
                self.isFetchingShares = false
                if shares.isEmpty {
                    self.status = "No se encontraron shares disponibles."
                    self.isSuccess = false
                    self.showSharePicker = false
                } else {
                    self.availableShares = shares
                    self.showSharePicker = true
                }
            }
        }
    }

    func mountShares() {
        let host = extractedHost

        var sharesToMount: [String] = []

        if !selectedShares.isEmpty {
            sharesToMount = Array(selectedShares).sorted()
        } else {
            let raw = smbURL.trimmingCharacters(in: .whitespaces)
            let withScheme = raw.lowercased().hasPrefix("smb://") ? raw : "smb://\(raw)"
            if let url = URL(string: withScheme),
               let share = url.pathComponents.dropFirst().first {
                sharesToMount = [share]
            }
        }

        guard !sharesToMount.isEmpty else {
            status = "Select a share"
            isSuccess = false
            return
        }

        isConnecting = true
        status       = ""
        isSuccess    = false

        let encodedUser = username.addingPercentEncoding(withAllowedCharacters: .urlUserAllowed) ?? username
        let encodedPass = password.addingPercentEncoding(withAllowedCharacters: .urlPasswordAllowed) ?? password

        DispatchQueue.global(qos: .userInitiated).async {

            var mountErrors: [String] = []

            for share in sharesToMount {
                let fullURL = "smb://\(encodedUser):\(encodedPass)@\(host)/\(share)"
                let script = """
                tell application "Finder"
                    try
                        mount volume "\(fullURL)"
                        return "ok"
                    on error errMsg
                        return errMsg
                    end try
                end tell
                """

                var errorDict: NSDictionary?
                let result = NSAppleScript(source: script)?.executeAndReturnError(&errorDict)

                if let err = errorDict {
                    let msg = err[NSAppleScript.errorMessage] as? String ?? "Unknown error"
                    mountErrors.append("\(share): \(msg)")
                } else if let output = result?.stringValue, output != "ok" {
                    mountErrors.append("\(share): \(output)")
                }
            }

            DispatchQueue.main.async {
                self.isConnecting = false

                if mountErrors.isEmpty {
                    self.isSuccess = true
                    self.status    = "ok"
                    self.showSharePicker = false

                    if self.remember {
                        KeychainHelper.save(
                            host:     self.smbURL,
                            username: self.username,
                            password: self.password
                        )
                    }

                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        NSApp.hide(nil)
                    }
                } else {
                    self.isSuccess = false
                    self.status    = mountErrors.joined(separator: "\n")
                }
            }
        }
    }
}

struct FieldRow<Content: View>: View {
    let label: String
    let content: Content

    init(label: String, @ViewBuilder content: () -> Content) {
        self.label = label
        self.content = content()
    }

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Text(label)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.secondary)
                .frame(width: 64, alignment: .trailing)
            content
        }
    }
}

struct StyledFieldModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(NSColor.controlBackgroundColor))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(Color.blue.opacity(0.35), lineWidth: 1)
                    )
            )
            .font(.system(size: 13))
    }
}

extension View {
    func styledField() -> some View {
        modifier(StyledFieldModifier())
    }
}

struct ModernCheckboxStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button(action: { configuration.isOn.toggle() }) {
            HStack(spacing: 7) {
                ZStack {
                    RoundedRectangle(cornerRadius: 5)
                        .fill(configuration.isOn ? Color.blue : Color(NSColor.controlBackgroundColor))
                        .frame(width: 18, height: 18)
                        .overlay(
                            RoundedRectangle(cornerRadius: 5)
                                .strokeBorder(
                                    configuration.isOn ? Color.blue : Color.secondary.opacity(0.4),
                                    lineWidth: 1.2
                                )
                        )
                    if configuration.isOn {
                        Image(systemName: "checkmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
                configuration.label
            }
        }
        .buttonStyle(.plain)
    }
}
