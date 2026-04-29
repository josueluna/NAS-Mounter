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
    @State private var showChangelogPanel = false
    @State private var showAppMenu = false
    @State private var isVersionHovered = false
    @AppStorage("allowedWiFiNetworks") private var storedAllowedWiFiNetworks = "[]"
    @AppStorage("lastMountedShares") private var storedLastMountedShares = "[]"

    @State private var smbURL       = ""
    @State private var username     = ""
    @State private var password     = ""
    @State private var showPassword = false
    @State private var remember     = false

    @State private var status        = ""
    @State private var isConnecting  = false
    @State private var isSuccess     = false

    @State private var availableShares: [String] = []
    @State private var selectedShares: Set<String> = []
    @State private var mountedShares: [String] = []
    @State private var showSharePicker  = false
    @State private var isFetchingShares = false

    @FocusState private var focusedField: Field?

    private enum Field {
        case smb, username, password
    }

    private var extractedHost: String {
        let raw = smbURL.trimmingCharacters(in: .whitespaces)
        let withScheme = raw.lowercased().hasPrefix("smb://") ? raw : "smb://\(raw)"
        return URL(string: withScheme)?.host ?? ""
    }

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
        return "v\(version)"
    }

    // MARK: - Body
    // FIX: VStack replaces ZStack so footer occupies a fixed 40pt row
    // anchored below mainContent — version tag and menu button are
    // always centered vertically in that row regardless of content height.

    var body: some View {
        VStack(spacing: 0) {
            mainContent

            // ── Footer ─────────────────────────────────────────
            // Fixed 40pt height guarantees vertical centering of
            // versionLabel and appMenuButton relative to each other
            // and relative to the window bottom edge.
            HStack(alignment: .center) {
                versionLabel
                Spacer()
                appMenuButton
            }
            .frame(height: 40)
        }
        .fixedSize(horizontal: false, vertical: true)
        .overlay(alignment: .center) {
            if showSettingsPanel {
                settingsOverlay
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            }
            if showChangelogPanel {
                changelogOverlay
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: showSharePicker)
        .animation(.easeInOut(duration: 0.2), value: status)
        .animation(.easeInOut(duration: 0.25), value: showSettingsPanel)
        .animation(.easeInOut(duration: 0.25), value: showChangelogPanel)
        .onAppear {
            DispatchQueue.main.async { focusedField = nil }
            status = ""
            isSuccess = false
            isConnecting = false
            loadProfileForCurrentNetwork()
            refreshMountedShares()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("NASMountiePopoverDidOpen"))) { _ in
            DispatchQueue.main.async { focusedField = nil }
            status = ""
            isSuccess = false
            isConnecting = false
            loadProfileForCurrentNetwork()
            refreshMountedShares()
        }
    }

    // MARK: Main content
    // FIX: .padding(.bottom) reduced from 40 → 8 because
    // the footer row now owns the bottom spacing.

    private var mainContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerView
            fieldsView
            mountedSharesView
            sharePickerView
            rememberPasswordView
            connectButton
            statusView
        }
        .padding(.top, 24)
        .padding(.horizontal, 24)
        .padding(.bottom, 8)
        .frame(width: 380)
    }

    // MARK: Header

    private var headerView: some View {
        HStack(spacing: 10) {
            if let _ = NSImage(named: "LogoInApp") {
                Image("LogoInApp")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 122, height: 38)
            } else {
                Image(systemName: "externaldrive.fill.badge.wifi")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(Brand.primary)
            }
        }
        .padding(.bottom, 20)
    }

    // MARK: Fields

    private var fieldsView: some View {
        VStack(spacing: 12) {
            FieldRow(label: "SMB") {
                HStack(spacing: 6) {
                    TextField("192.168.X.X or 192.168.X.X/Share", text: $smbURL)
                        .textFieldStyle(.plain)
                        .focused($focusedField, equals: .smb)
                        .onSubmit { handleConnect() }
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
                    .focused($focusedField, equals: .username)
                    .onSubmit { handleConnect() }
                    .styledField()
            }

            FieldRow(label: "Password") {
                HStack(spacing: 6) {
                    Group {
                        if showPassword {
                            TextField("Password — press Enter to mount", text: $password)
                                .textFieldStyle(.plain)
                                .focused($focusedField, equals: .password)
                                .onSubmit { handleConnect() }
                        } else {
                            SecureField("Password — press Enter to mount", text: $password)
                                .textFieldStyle(.plain)
                                .focused($focusedField, equals: .password)
                                .onSubmit { handleConnect() }
                        }
                    }
                    Button { showPassword.toggle() } label: {
                        Image(systemName: showPassword ? "eye" : "eye.slash")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.secondary)
                            .frame(width: 22, height: 22)
                    }
                    .buttonStyle(.plain)
                    .help(showPassword ? "Hide password" : "Show password")
                }
                .styledField()
            }
        }
    }

    // MARK: Mounted shares

    @ViewBuilder
    private var mountedSharesView: some View {
        if !mountedShares.isEmpty && !showSharePicker {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Mounted shares")
                        .font(Brand.caption())
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(mountedShares.count) mounted")
                        .font(Brand.caption())
                        .foregroundColor(.secondary)
                }
                .padding(.top, 12)

                VStack(spacing: 0) {
                    ForEach(mountedShares, id: \.self) { share in
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
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
                        .background(Brand.primaryLight)

                        if share != mountedShares.last {
                            Divider().padding(.leading, 10)
                        }
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: Brand.radiusMedium)
                        .fill(Color(NSColor.controlBackgroundColor))
                        .overlay(
                            RoundedRectangle(cornerRadius: Brand.radiusMedium)
                                .strokeBorder(Brand.primaryBorder, lineWidth: 1)
                        )
                )
            }
            .transition(.opacity.combined(with: .move(edge: .top)))
        }
    }

    // MARK: Share picker

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
                        ProgressView("Looking for shares…").font(Brand.caption())
                        Spacer()
                    }
                    .frame(height: 60)
                } else if availableShares.isEmpty {
                    HStack {
                        Spacer()
                        Text("No shares found").font(Brand.caption()).foregroundColor(.secondary)
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
                                    .background(selectedShares.contains(share) ? Brand.primaryLight : Color.clear)
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

    private var connectButton: some View {
        Button(action: handleConnect) {
            HStack(spacing: 8) {
                if isConnecting {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.75)
                }
                Text(isConnecting ? "Mounting…" : "Mount")
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

    // MARK: Version label
    // FIX: removed .padding(.bottom, 20) — footer HStack owns vertical centering

    private var versionLabel: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                showChangelogPanel = true
            }
        } label: {
            Text(appVersion)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(isVersionHovered ? .primary : .secondary)
                .opacity(isVersionHovered ? 1.0 : 0.65)
                .underline(isVersionHovered)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isVersionHovered = hovering
            }
        }
        .help("Open changelog")
        .padding(.leading, 20)
    }

    // MARK: App menu button
    // FIX: removed .padding(.bottom, 10) — footer HStack owns vertical centering

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
        .background(RoundedRectangle(cornerRadius: 6).stroke(Color.gray.opacity(0.2), lineWidth: 1))
        .contentShape(Rectangle())
        .padding(.trailing, 20)
        .popover(isPresented: $showAppMenu, arrowEdge: .bottom) {
            VStack(alignment: .leading, spacing: 0) {
                Button {
                    showAppMenu = false
                    withAnimation(.easeInOut(duration: 0.25)) { showSettingsPanel = true }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "gearshape")
                            .font(.system(size: 12))
                            .foregroundColor(Brand.primary)
                        Text("Settings").font(Brand.body())
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
                        Text("Quit NAS-Mountie")
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

    // MARK: Changelog overlay

    private var changelogOverlay: some View {
        ChangelogPanelView(show: $showChangelogPanel)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .transition(.move(edge: .trailing))
    }

    // MARK: Settings overlay

    private var settingsOverlay: some View {
        SettingsPanelView(show: $showSettingsPanel)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .transition(.move(edge: .trailing))
    }

    // MARK: - Actions

    private func lastMountedShares() -> [String] {
        guard let data = storedLastMountedShares.data(using: .utf8),
              let shares = try? JSONDecoder().decode([String].self, from: data)
        else { return [] }
        return shares
    }

    private func restoreLastMountedShares() {
        let shares = lastMountedShares()
        guard !shares.isEmpty else {
            selectedShares = []; availableShares = []; showSharePicker = false; return
        }
        let host = extractedHost
        guard !host.isEmpty else {
            selectedShares = []; availableShares = []; showSharePicker = false; return
        }
        DispatchQueue.global(qos: .userInitiated).async {
            let reachable = isSMBHostReachable(host)
            DispatchQueue.main.async {
                if reachable {
                    selectedShares = Set(shares); availableShares = shares; showSharePicker = true
                } else {
                    selectedShares = []; availableShares = []; showSharePicker = false
                    status = "Saved shares hidden because NAS is not reachable on this network."
                    isSuccess = false
                }
            }
        }
    }

    private func sortedSharesWithSelectedFirst(_ shares: [String], selected: Set<String>) -> [String] {
        shares.sorted { left, right in
            let l = selected.contains(left), r = selected.contains(right)
            if l != r { return l && !r }
            return left.localizedCaseInsensitiveCompare(right) == .orderedAscending
        }
    }

    private func refreshMountedShares() {
        let mountedVolumeNames = (try? FileManager.default.contentsOfDirectory(atPath: "/Volumes")) ?? []
        let knownShares = Set(selectedShares).union(Set(lastMountedShares()))
        mountedShares = knownShares
            .filter { mountedVolumeNames.contains($0) }
            .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    private func clearNetworkProfileFields() {
        smbURL = ""; username = ""; password = ""; remember = false
        selectedShares = []; availableShares = []; showSharePicker = false
        status = ""; isSuccess = false
    }

    private func loadProfileForCurrentNetwork() {
        guard let currentSSID = NetworkHelper.currentSSID() else {
            clearNetworkProfileFields()
            status = "Current Wi-Fi network could not be detected."
            isSuccess = false
            return
        }
        guard let profile = NetworkProfileManager.profile(for: currentSSID) else {
            clearNetworkProfileFields(); status = ""; return
        }
        smbURL = profile.host; username = profile.username
        if let saved = KeychainHelper.load() {
            password = saved.password; remember = true
        } else {
            password = ""; remember = false
        }
        selectedShares = Set(profile.shares); availableShares = []; showSharePicker = false
        status = ""; isSuccess = false
    }

    private func isSMBHostReachable(_ host: String) -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/nc")
        process.arguments = ["-z", "-G", "2", host, "445"]
        do {
            try process.run(); process.waitUntilExit()
            return process.terminationStatus == 0
        } catch { return false }
    }

    private func canMountOnCurrentNetwork() -> Bool { return true }

    func handleConnect() {
        guard !username.isEmpty, !password.isEmpty else {
            status = "Enter username and password."; isSuccess = false; return
        }
        guard canMountOnCurrentNetwork() else { return }
        let host = extractedHost
        guard !host.isEmpty else {
            status = "Invalid IP or URL."; isSuccess = false; return
        }
        guard isSMBHostReachable(host) else {
            status = "NAS is not reachable on this network."; isSuccess = false; return
        }
        let hasShareInURL: Bool = {
            let raw = smbURL.trimmingCharacters(in: .whitespaces)
            let withScheme = raw.lowercased().hasPrefix("smb://") ? raw : "smb://\(raw)"
            guard let url = URL(string: withScheme) else { return false }
            return url.pathComponents.dropFirst().first != nil
        }()
        if selectedShares.isEmpty && !hasShareInURL { fetchShares(); return }
        mountShares()
    }

    func fetchShares() {
        guard !username.isEmpty, !password.isEmpty else {
            status = "Enter username and password first."; isSuccess = false; return
        }
        guard canMountOnCurrentNetwork() else { return }
        let host = extractedHost
        guard !host.isEmpty else {
            status = "Enter the NAS IP first."; isSuccess = false; return
        }
        isFetchingShares = true; showSharePicker = true; availableShares = []; status = ""

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
                    self.isFetchingShares = false; self.showSharePicker = false
                    self.status = msg.isEmpty ? "Connection failed. Check IP and credentials." : "Error: \(msg)"
                    self.isSuccess = false
                }
                return
            }
            let shares = output.components(separatedBy: "\n").compactMap { line -> String? in
                let parts = line.trimmingCharacters(in: .whitespaces)
                    .components(separatedBy: .whitespaces).filter { !$0.isEmpty }
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
                    let savedShares = Set(self.lastMountedShares())
                    let validSaved = savedShares.intersection(Set(shares))
                    self.selectedShares = validSaved
                    self.availableShares = self.sortedSharesWithSelectedFirst(shares, selected: validSaved)
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
                    self.isSuccess = true; self.status = "ok"
                    if let currentSSID = NetworkHelper.currentSSID() {
                        NetworkProfileManager.saveProfile(
                            ssid: currentSSID, host: self.smbURL,
                            username: self.username, shares: sharesToMount
                        )
                    }
                    if self.remember {
                        KeychainHelper.save(host: self.smbURL, username: self.username, password: self.password)
                    }
                    if let encoded = try? JSONEncoder().encode(sharesToMount),
                       let str = String(data: encoded, encoding: .utf8) {
                        self.storedLastMountedShares = str
                        self.selectedShares = Set(sharesToMount)
                        self.availableShares = sharesToMount
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        self.status = ""; self.isSuccess = false
                        NotificationCenter.default.post(
                            name: NSNotification.Name("NASMountieClosePopover"), object: nil
                        )
                    }
                } else {
                    self.isSuccess = false
                    self.status = mountErrors.joined(separator: "\n")
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
