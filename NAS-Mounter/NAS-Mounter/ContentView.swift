import SwiftUI
import Security

// MARK: - Keychain Helper

struct KeychainHelper {
    static let service = "com.nasmounter.credentials"

    static func save(host: String, username: String, password: String) {
        let data: [String: String] = ["host": host, "username": username, "password": password]
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

// MARK: - Main View

struct ContentView: View {

    @State private var showSettingsPanel = false
    @State private var showAppMenu = false
    @AppStorage("allowedWiFiNetworks") private var storedAllowedWiFiNetworks = "[]"

    @State private var smbURL    = ""
    @State private var username  = ""
    @State private var password  = ""
    @State private var remember  = false

    @State private var status        = ""
    @State private var isConnecting  = false
    @State private var isSuccess     = false

    @State private var availableShares: [String] = []
    @State private var selectedShares: Set<String> = []
    @State private var showSharePicker  = false
    @State private var isFetchingShares = false

    private var extractedHost: String {
        let raw = smbURL.trimmingCharacters(in: .whitespaces)
        let withScheme = raw.lowercased().hasPrefix("smb://") ? raw : "smb://\(raw)"
        return URL(string: withScheme)?.host ?? ""
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            mainContent
            appMenuButton

            if showSettingsPanel {
                settingsOverlay
                    .transition(.opacity)
                    .zIndex(10)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .animation(.easeInOut(duration: 0.2), value: showSharePicker)
        .animation(.easeInOut(duration: 0.2), value: status)
        .animation(.easeInOut(duration: 0.25), value: showSettingsPanel)
        .onAppear {
            if let saved = KeychainHelper.load() {
                smbURL   = saved.host
                username = saved.username
                password = saved.password
                remember = true
            }
        }
    }

    // MARK: Main content

    private var mainContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerView
            fieldsView
            sharePickerView
            rememberPasswordView
            connectButton
            statusView
        }
        .padding(.top, 24)
        .padding(.horizontal, 24)
        .padding(.bottom, 40)
        .frame(width: 380)
    }

    // MARK: Header
    // Brand change: logo asset + "NAS Mountie" name + default (not rounded) font

    private var headerView: some View {
        HStack(spacing: 10) {
            // Uses LogoInApp asset from Assets.xcassets
            // Falls back to SF Symbol if asset not found
            if let _ = NSImage(named: "LogoInApp") {
                Image("LogoInApp")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 122, height: 38)
            } else {
                Image(systemName: "LogoInApp")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(Brand.primary)
            }
        }
        .padding(.bottom, 20)
    }

    // MARK: Fields
    // Brand change: blue → Brand.primary on borders and browse button

    private var fieldsView: some View {
        VStack(spacing: 12) {
            FieldRow(label: "SMB") {
                HStack(spacing: 6) {
                    TextField("192.168.X.X or 192.168.X.X/Share", text: $smbURL)
                        .textFieldStyle(.plain)
                        .styledField()

                    Button { fetchShares() } label: {
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
                            RoundedRectangle(cornerRadius: Brand.radiusSmall)
                                .fill(Color(NSColor.controlBackgroundColor))
                                .overlay(
                                    RoundedRectangle(cornerRadius: Brand.radiusSmall)
                                        .strokeBorder(Brand.primaryBorder, lineWidth: 1)
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
                SecureField("Password — press Enter to connect", text: $password)
                    .textFieldStyle(.plain)
                    .styledField()
                    .onSubmit { handleConnect() }
            }
        }
    }

    // MARK: Share picker
    // Brand change: blue checkmarks and borders → Brand.primary

    @ViewBuilder
    private var sharePickerView: some View {
        if showSharePicker {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Available shares — select one or more:")
                        .font(Brand.caption())
                        .foregroundColor(.secondary)
                    Spacer()
                    if !availableShares.isEmpty {
                        Text("\(availableShares.count) shares")
                            .font(Brand.caption())
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.top, 12)

                if isFetchingShares {
                    HStack {
                        Spacer()
                        ProgressView("Looking for shares…")
                            .font(Brand.caption())
                        Spacer()
                    }
                    .frame(height: 60)
                } else if availableShares.isEmpty {
                    HStack {
                        Spacer()
                        Text("No shares found")
                            .font(Brand.caption())
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
                                        Image(systemName: selectedShares.contains(share)
                                              ? "checkmark.circle.fill" : "circle")
                                            .foregroundColor(Brand.primary)
                                            .font(.system(size: 13))

                                        Image("TBIcon")
                                            .renderingMode(.template)
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: 14, height: 14)
                                            .foregroundColor(Brand.primary)

                                        Text(share)
                                            .font(Brand.body())
                                            .foregroundColor(.primary)

                                        Spacer()
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 8)
                                    .background(
                                        selectedShares.contains(share)
                                            ? Brand.primaryLight
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
                        RoundedRectangle(cornerRadius: Brand.radiusMedium)
                            .fill(Color(NSColor.controlBackgroundColor))
                            .overlay(
                                RoundedRectangle(cornerRadius: Brand.radiusMedium)
                                    .strokeBorder(Brand.primaryBorder, lineWidth: 1)
                            )
                    )
                }
            }
            .transition(.opacity.combined(with: .move(edge: .top)))
        }
    }

    // MARK: Remember password
    // Brand change: checkbox uses Brand.primary

    private var rememberPasswordView: some View {
        Toggle(isOn: $remember) {
            Text("Remember Password")
                .font(Brand.body())
                .foregroundColor(.secondary)
        }
        .toggleStyle(MountieCheckboxStyle())
        .padding(.top, 14)
        .onChange(of: remember) { newValue in
            if !newValue { KeychainHelper.delete() }
        }
    }

    // MARK: Connect button
    // Brand change: blue fill → Brand.primary (Forest Green)

    private var connectButton: some View {
        Button(action: handleConnect) {
            HStack(spacing: 8) {
                if isConnecting {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.75)
                }
                Text(isConnecting ? "Connecting…" : "Connect")
                    .font(Brand.headline(15))
            }
            .frame(maxWidth: .infinity, minHeight: 40)
            .background(
                RoundedRectangle(cornerRadius: Brand.radiusLarge)
                    .fill(isConnecting ? Brand.primary.opacity(0.7) : Brand.primary)
            )
            .foregroundColor(.white)
        }
        .buttonStyle(.plain)
        .disabled(isConnecting)
        .padding(.top, 16)
    }

    // MARK: Status view

    @ViewBuilder
    private var statusView: some View {
        if !status.isEmpty {
            if isSuccess {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(Brand.primary)
                            .font(.system(size: 13))
                        Text("Drive mounted successfully")
                            .font(Brand.headline())
                    }
                    Text("This window will close shortly...")
                        .font(Brand.caption())
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
                        .font(Brand.caption(12))
                        .foregroundColor(.red)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.top, 10)
            }
        }
    }

    // MARK: App menu button
    // Brand change: popover items use Brand.primary tint on hover

    private var appMenuButton: some View {
        Button {
            showAppMenu.toggle()
        } label: {
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.secondary)
                .padding(6)
        }
        .buttonStyle(.plain)
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.gray.opacity(0.15)))
        .padding(.trailing, 20)
        .padding(.bottom, 10)
        .popover(isPresented: $showAppMenu, arrowEdge: .bottom) {
            VStack(alignment: .leading, spacing: 0) {
                Button {
                    showAppMenu = false
                    withAnimation(.easeInOut(duration: 0.25)) {
                        showSettingsPanel = true
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "gearshape")
                            .font(.system(size: 12))
                            .foregroundColor(Brand.primary)
                        Text("Settings")
                            .font(Brand.body())
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Divider().padding(.horizontal, 8)

                Button {
                    NSApp.terminate(nil)
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "power")
                            .font(.system(size: 12))
                            .foregroundColor(.red)
                        Text("Quit NAS Mountie")
                            .font(Brand.body())
                            .foregroundColor(.red)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .padding(.vertical, 4)
            .frame(width: 180)
        }
    }

    // MARK: Settings overlay

    private var settingsOverlay: some View {
        SettingsPanelView(show: $showSettingsPanel)
            .frame(width: 380)
            .transition(.move(edge: .trailing))
    }

    // MARK: - Actions

    private func canMountOnCurrentNetwork() -> Bool {
        let allowedNetworks = NetworkHelper.decodeNetworks(from: storedAllowedWiFiNetworks)
        guard !allowedNetworks.isEmpty else { return true }
        guard let currentSSID = NetworkHelper.currentSSID() else {
            status = "Could not detect current Wi-Fi network."
            isSuccess = false
            return false
        }
        guard allowedNetworks.contains(currentSSID) else {
            status = "Mounting blocked on this network: \(currentSSID)"
            isSuccess = false
            return false
        }
        return true
    }

    func handleConnect() {
        guard !username.isEmpty, !password.isEmpty else {
            status = "Enter username and password."
            isSuccess = false
            return
        }
        guard canMountOnCurrentNetwork() else { return }
        let host = extractedHost
        guard !host.isEmpty else {
            status = "Invalid IP or URL."
            isSuccess = false
            return
        }
        let hasShareInURL: Bool = {
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
            status = "Enter username and password first."
            isSuccess = false
            return
        }
        guard canMountOnCurrentNetwork() else { return }
        let host = extractedHost
        guard !host.isEmpty else {
            status = "Enter the NAS IP first."
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
            task.arguments  = ["view", "//\(encodedUser):\(encodedPass)@\(host)"]
            let outPipe = Pipe(); let errPipe = Pipe()
            task.standardOutput = outPipe; task.standardError = errPipe
            task.launch(); task.waitUntilExit()
            let output = String(data: outPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            let errOut = String(data: errPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""

            if task.terminationStatus != 0 || output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                let msg = errOut.trimmingCharacters(in: .whitespacesAndNewlines)
                DispatchQueue.main.async {
                    self.isFetchingShares = false
                    self.showSharePicker  = false
                    self.status    = msg.isEmpty ? "Connection failed. Check IP and credentials." : "Error: \(msg)"
                    self.isSuccess = false
                }
                return
            }
            let shares = output.components(separatedBy: "\n").compactMap { line -> String? in
                let parts = line.trimmingCharacters(in: .whitespaces).components(separatedBy: .whitespaces).filter { !$0.isEmpty }
                guard parts.count >= 2, parts[1] == "Disk" else { return nil }
                let name = parts[0]
                guard !name.hasSuffix("$"), !name.isEmpty else { return nil }
                return name
            }
            DispatchQueue.main.async {
                self.isFetchingShares = false
                if shares.isEmpty {
                    self.status = "No shares found."; self.isSuccess = false; self.showSharePicker = false
                } else {
                    self.availableShares = shares; self.showSharePicker = true
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
            if let url = URL(string: withScheme), let share = url.pathComponents.dropFirst().first {
                sharesToMount = [share]
            }
        }
        guard !sharesToMount.isEmpty else {
            status = "Select at least one share."; isSuccess = false; return
        }
        isConnecting = true; status = ""; isSuccess = false
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
                    mountErrors.append("\(share): \(err[NSAppleScript.errorMessage] as? String ?? "Unknown error")")
                } else if let output = result?.stringValue, output != "ok" {
                    mountErrors.append("\(share): \(output)")
                }
            }
            DispatchQueue.main.async {
                self.isConnecting = false
                if mountErrors.isEmpty {
                    self.isSuccess = true; self.status = "ok"; self.showSharePicker = false
                    if self.remember {
                        KeychainHelper.save(host: self.smbURL, username: self.username, password: self.password)
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                        if let delegate = NSApplication.shared.delegate as? AppDelegate {
                            delegate.statusBar?.closePopover()
                        } else { NSApp.hide(nil) }
                    }
                } else {
                    self.isSuccess = false; self.status = mountErrors.joined(separator: "\n")
                }
            }
        }
    }
}

// MARK: - UI Helpers

struct FieldRow<Content: View>: View {
    let label: String
    let content: Content
    init(label: String, @ViewBuilder content: () -> Content) {
        self.label = label; self.content = content()
    }
    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Text(label)
                .font(Brand.body(13))
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
                RoundedRectangle(cornerRadius: Brand.radiusMedium)
                    .fill(Color(NSColor.controlBackgroundColor))
                    .overlay(
                        RoundedRectangle(cornerRadius: Brand.radiusMedium)
                            .strokeBorder(Brand.primaryBorder, lineWidth: 1)
                    )
            )
            .font(Brand.body())
    }
}

extension View {
    func styledField() -> some View { modifier(StyledFieldModifier()) }
}

// Brand change: checkbox color → Brand.primary (Forest Green)
struct MountieCheckboxStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button(action: { configuration.isOn.toggle() }) {
            HStack(spacing: 7) {
                ZStack {
                    RoundedRectangle(cornerRadius: 5)
                        .fill(configuration.isOn ? Brand.primary : Color(NSColor.controlBackgroundColor))
                        .frame(width: 18, height: 18)
                        .overlay(
                            RoundedRectangle(cornerRadius: 5)
                                .strokeBorder(
                                    configuration.isOn ? Brand.primary : Color.secondary.opacity(0.4),
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
