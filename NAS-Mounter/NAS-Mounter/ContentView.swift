import SwiftUI
import Security

// ── Keychain Helper ───────────────────────────────────────────────
struct KeychainHelper {
    static let service = "com.nasmounter.credentials"

    // Save all credentials
    static func save(host: String, username: String, password: String) {
        let data: [String: String] = [
            "host": host,
            "username": username,
            "password": password
        ]
        guard let encoded = try? JSONEncoder().encode(data) else { return }

        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: "nas-credentials"
        ]

        // Try update first, then add
        let updateFields: [String: Any] = [kSecValueData as String: encoded]
        let status = SecItemUpdate(query as CFDictionary, updateFields as CFDictionary)

        if status == errSecItemNotFound {
            var newItem = query
            newItem[kSecValueData as String] = encoded
            SecItemAdd(newItem as CFDictionary, nil)
        }
    }

    // Load all credentials
    static func load() -> (host: String, username: String, password: String)? {
        let query: [String: Any] = [
            kSecClass as String:            kSecClassGenericPassword,
            kSecAttrService as String:      service,
            kSecAttrAccount as String:      "nas-credentials",
            kSecReturnData as String:       true,
            kSecMatchLimit as String:       kSecMatchLimitOne
        ]

        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data,
              let decoded = try? JSONDecoder().decode([String: String].self, from: data),
              let host     = decoded["host"],
              let username = decoded["username"],
              let password = decoded["password"]
        else { return nil }

        return (host, username, password)
    }

    // Delete credentials
    static func delete() {
        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: "nas-credentials"
        ]
        SecItemDelete(query as CFDictionary)
    }
}

// ── Main View ─────────────────────────────────────────────────────
struct ContentView: View {

    @State private var smbURL    = ""
    @State private var username  = ""
    @State private var password  = ""
    @State private var remember  = false
    @State private var status    = ""
    @State private var isConnecting  = false
    @State private var isSuccess     = false

    // Share browser
    @State private var availableShares: [String] = []
    @State private var selectedShare:   String?  = nil
    @State private var isFetchingShares = false
    @State private var showSharePicker  = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // ── Header ──────────────────────────────────────────
            HStack(spacing: 10) {
                Image(systemName: "externaldrive.fill.badge.wifi")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(.blue)
                Text("NAS Mounter")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
            }
            .padding(.bottom, 20)

            // ── Fields ──────────────────────────────────────────
            VStack(spacing: 12) {

                FieldRow(label: "SMB") {
                    HStack(spacing: 6) {
                        TextField("192.XXX.XX.XX  or  192.XXX.XX.XX/Share", text: $smbURL)
                            .textFieldStyle(PlainTextFieldStyle())
                            .styledField()
                            .onSubmit { normalizeSMBURL() }

                        if !username.isEmpty && !password.isEmpty {
                            Button(action: fetchShares) {
                                Group {
                                    if isFetchingShares {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle())
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
                            .buttonStyle(PlainButtonStyle())
                            .help("Browse available shares")
                            .disabled(isFetchingShares)
                        }
                    }
                }

                FieldRow(label: "User") {
                    TextField("Username", text: $username)
                        .textFieldStyle(PlainTextFieldStyle())
                        .styledField()
                }

                FieldRow(label: "Password") {
                    SecureField("Password — press Enter to connect", text: $password)
                        .textFieldStyle(PlainTextFieldStyle())
                        .styledField()
                        .onSubmit { mountNAS() }
                }
            }

            // ── Share Picker ─────────────────────────────────────
            if showSharePicker && !availableShares.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Available shares — select one:")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(availableShares.count) shares")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 12)

                    ScrollView(.vertical, showsIndicators: true) {
                        VStack(spacing: 0) {
                            ForEach(availableShares, id: \.self) { share in
                                Button(action: {
                                    selectedShare = share
                                    let host = hostFromURL(smbURL)
                                    smbURL = "smb://\(host)/\(share)"
                                    showSharePicker = false
                                    availableShares = []
                                }) {
                                    HStack(spacing: 8) {
                                        Image(systemName: "externaldrive")
                                            .font(.system(size: 11))
                                            .foregroundColor(.blue)
                                        Text(share)
                                            .font(.system(size: 13))
                                            .foregroundColor(.primary)
                                        Spacer()
                                        if selectedShare == share {
                                            Image(systemName: "checkmark")
                                                .font(.system(size: 11, weight: .semibold))
                                                .foregroundColor(.blue)
                                        }
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 8)
                                    .background(
                                        selectedShare == share
                                            ? Color.blue.opacity(0.08)
                                            : Color.clear
                                    )
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(PlainButtonStyle())

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
                    .shadow(
                        color: availableShares.count > 4 ? Color.black.opacity(0.06) : .clear,
                        radius: 4, x: 0, y: 4
                    )
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            // ── Remember Password ────────────────────────────────
            HStack {
                Toggle(isOn: $remember) {
                    Text("Remember Password")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
                .toggleStyle(ModernCheckboxStyle())
                .onChange(of: remember) { newValue in
                    // If user unchecks, delete saved credentials immediately
                    if !newValue { KeychainHelper.delete() }
                }

                Spacer()

                // Show "Saved" badge when credentials are stored
                if remember && !username.isEmpty {
                    HStack(spacing: 3) {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 9))
                        Text("Saved in Keychain")
                            .font(.system(size: 10))
                    }
                    .foregroundColor(.green)
                    .transition(.opacity)
                }
            }
            .padding(.top, 14)

            // ── Connect Button ───────────────────────────────────
            Button(action: mountNAS) {
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
            .buttonStyle(PlainButtonStyle())
            .padding(.top, 16)
            .disabled(isConnecting)

            // ── Status ──────────────────────────────────────────
            if !status.isEmpty {
                if isSuccess {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .font(.system(size: 13))
                            Text("Drive mounted successfully.")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.primary)
                        }
                        Text("This window will close in a moment…")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .padding(.leading, 19)
                    }
                    .padding(.top, 12)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
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
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
            }
        }
        .padding(24)
        .frame(width: 380)
        .fixedSize(horizontal: false, vertical: true)
        .animation(.easeInOut(duration: 0.25), value: status)
        .animation(.easeInOut(duration: 0.25), value: isSuccess)
        .animation(.easeInOut(duration: 0.2), value: showSharePicker)
        .animation(.easeInOut(duration: 0.2), value: remember)
        .onAppear {
            if let window = NSApplication.shared.windows.first {
                window.styleMask.remove(.resizable)
                window.center()
            }
            // ── Load saved credentials on launch ─────────────
            if let saved = KeychainHelper.load() {
                smbURL   = saved.host
                username = saved.username
                password = saved.password
                remember = true
            }
        }
    }

    // ── Helpers ──────────────────────────────────────────────────

    func hostFromURL(_ raw: String) -> String {
        let cleaned = raw.replacingOccurrences(of: "smb://", with: "", options: .caseInsensitive)
        return cleaned.components(separatedBy: "/").first ?? cleaned
    }

    func normalizeSMBURL() {
        let trimmed = smbURL.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        if !trimmed.lowercased().hasPrefix("smb://") {
            smbURL = "smb://" + trimmed
        }
    }

    // ── Fetch shares via smbutil ──────────────────────────────────
    func fetchShares() {
        guard !username.isEmpty, !password.isEmpty else {
            status = "Enter User and Password first to browse shares."
            isSuccess = false
            return
        }

        let host = hostFromURL(smbURL.trimmingCharacters(in: .whitespaces))
        guard !host.isEmpty else {
            status = "Enter the NAS IP address first."
            isSuccess = false
            return
        }

        isFetchingShares = true
        showSharePicker  = false
        availableShares  = []
        status = ""

        DispatchQueue.global(qos: .userInitiated).async {
            let encodedUser = username.addingPercentEncoding(withAllowedCharacters: .urlUserAllowed) ?? username
            let encodedPass = password.addingPercentEncoding(withAllowedCharacters: .urlPasswordAllowed) ?? password

            let task = Process()
            task.launchPath = "/usr/bin/smbutil"
            task.arguments  = ["view", "-g", "//\(encodedUser):\(encodedPass)@\(host)"]

            let pipe = Pipe()
            task.standardOutput = pipe
            task.standardError  = pipe
            task.launch()
            task.waitUntilExit()

            let output = String(
                data: pipe.fileHandleForReading.readDataToEndOfFile(),
                encoding: .utf8
            ) ?? ""

            let shares = output
                .components(separatedBy: "\n")
                .compactMap { line -> String? in
                    let parts = line.split(separator: " ", omittingEmptySubsequences: true)
                    guard parts.count >= 2, parts[1] == "Disk" else { return nil }
                    let name = String(parts[0])
                    guard !name.hasSuffix("$") else { return nil }
                    return name
                }

            DispatchQueue.main.async {
                isFetchingShares = false
                if shares.isEmpty {
                    status = "No shares found — check your credentials or IP."
                    isSuccess = false
                } else {
                    availableShares = shares
                    showSharePicker = true
                    smbURL = host
                }
            }
        }
    }

    // ── Mount ────────────────────────────────────────────────────
    func mountNAS() {
        normalizeSMBURL()

        guard !smbURL.isEmpty, !username.isEmpty, !password.isEmpty else {
            status = "Please fill in all fields."
            isSuccess = false
            return
        }

        guard let url = URL(string: smbURL), let host = url.host else {
            status = "Invalid URL — use 192.168.X.X/ShareName"
            isSuccess = false
            return
        }

        let shareName = url.pathComponents.dropFirst().first ?? ""
        if shareName.isEmpty {
            fetchShares()
            return
        }

        isConnecting = true
        status = ""
        isSuccess = false
        showSharePicker = false

        DispatchQueue.global(qos: .userInitiated).async {
            let encodedUser = username.addingPercentEncoding(withAllowedCharacters: .urlUserAllowed) ?? username
            let encodedPass = password.addingPercentEncoding(withAllowedCharacters: .urlPasswordAllowed) ?? password
            let fullURLString = "smb://\(encodedUser):\(encodedPass)@\(host)/\(shareName)"

            let script = """
            tell application "Finder"
                try
                    mount volume "\(fullURLString)"
                    return "ok"
                on error errMsg
                    return errMsg
                end try
            end tell
            """

            var error: NSDictionary?
            let appleScript = NSAppleScript(source: script)
            let result = appleScript?.executeAndReturnError(&error)

            DispatchQueue.main.async {
                self.isConnecting = false

                if let err = error {
                    let msg = err[NSAppleScript.errorMessage] as? String ?? "Unknown error"
                    self.status = "Connection failed: \(msg)"
                    self.isSuccess = false
                } else if let output = result?.stringValue, output != "ok" {
                    self.status = "Connection failed: \(output)"
                    self.isSuccess = false
                } else {
                    self.status = "ok"
                    self.isSuccess = true

                    // Save to Keychain if Remember is checked
                    if self.remember {
                        KeychainHelper.save(
                            host:     self.smbURL,
                            username: self.username,
                            password: self.password
                        )
                    }

                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        NSApplication.shared.terminate(nil)
                    }
                }
            }
        }
    }
}

// ── UI Helpers ────────────────────────────────────────────────────

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

struct StyledField: ViewModifier {
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
    func styledField() -> some View { modifier(StyledField()) }
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
        .buttonStyle(PlainButtonStyle())
    }
}
