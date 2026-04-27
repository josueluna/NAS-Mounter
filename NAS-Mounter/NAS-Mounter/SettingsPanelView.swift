import SwiftUI
import ServiceManagement

struct SettingsPanelView: View {

    @Binding var show: Bool

    @AppStorage("runOnStartup") private var storedRunOnStartup = false
    @AppStorage("allowedWiFiNetworks") private var storedAllowedWiFiNetworks = "[]"

    @State private var draftRunOnStartup = false
    @State private var allowedNetworks: [String] = []
    @State private var currentNetwork: String? = nil
    @State private var statusMessage = ""
    @State private var isError = false

    // Ancho del ícono badge — usado para alinear contenido en todas las cards
    private let iconSize: CGFloat = 28
    private let iconSpacing: CGFloat = 12

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // ── Header ──────────────────────────────
            HStack(alignment: .center) {
                Text("Settings")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(.primary)

                Spacer()

            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 14)

            // ── Scrollable content ───────────────────
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 10) {

                    // ── Card: Launch at Login ────────
                    SettingsCard {
                        HStack(alignment: .center, spacing: iconSpacing) {

                            // Ícono badge
                            iconBadge("power")

                            // Texto
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Launch at Login")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.primary)
                                Text("Open NAS Mounter automatically when you log in.")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }

                            Spacer()

                            // FIX: toggle centrado verticalmente, padding derecho
                            Toggle("", isOn: $draftRunOnStartup)
                                .labelsHidden()
                                .scaleEffect(0.8)
                                .padding(.trailing, 2)
                        }
                    }

                    // ── Card: Wi-Fi Networks ─────────
                    SettingsCard {
                        VStack(alignment: .leading, spacing: 12) {

                            // Card header row
                            HStack(alignment: .center, spacing: iconSpacing) {
                                iconBadge("wifi")

                                VStack(alignment: .leading, spacing: 3) {
                                    Text("Allowed Wi-Fi Networks")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundColor(.primary)
                                    Text("Only mount shares on these networks. Empty = any network.")
                                        .font(.system(size: 11))
                                        .foregroundColor(.secondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }

                            Divider()
                                .padding(.leading, iconSize + iconSpacing)

                            HStack(alignment: .center, spacing: iconSpacing) {

                                ZStack {

                                    Image(systemName: currentNetwork != nil ? "wifi.circle.fill" : "wifi.slash")
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundColor(currentNetwork != nil ? .green : .secondary)
                                }
                                .frame(width: iconSize, height: iconSize)

                                VStack(alignment: .leading, spacing: 1) {
                                    Text("Current network")
                                        .font(.system(size: 10))
                                        .foregroundColor(.secondary)

                                    Text(currentNetwork ?? "Not detected")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(currentNetwork != nil ? .primary : .secondary)
                                }

                                Spacer()

                                Button {
                                    addCurrentNetwork()
                                } label: {
                                    HStack(spacing: 4) {
                                        Image(systemName: "plus")
                                            .font(.system(size: 10, weight: .semibold))
                                        Text("Add")
                                            .font(.system(size: 11, weight: .medium))
                                    }
                                    .foregroundColor(currentNetwork == nil ? .secondary : .blue)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(
                                                currentNetwork == nil
                                                ? Color(NSColor.controlBackgroundColor)
                                                : Color.blue.opacity(0.1)
                                            )
                                    )
                                }
                                .buttonStyle(.plain)
                                .disabled(currentNetwork == nil)
                            }

                            // Networks list or empty state
                            // FIX: indentado con el mismo offset que los títulos
                            VStack(alignment: .leading, spacing: 0) {
                                if allowedNetworks.isEmpty {
                                    HStack {
                                        Spacer()
                                        VStack(spacing: 4) {
                                            Image(systemName: "wifi.exclamationmark")
                                                .font(.system(size: 18))
                                                .foregroundColor(.secondary.opacity(0.4))
                                            Text("No networks added yet")
                                                .font(.system(size: 11))
                                                .foregroundColor(.secondary)
                                        }
                                        .padding(.vertical, 10)
                                        Spacer()
                                    }
                                } else {
                                    VStack(spacing: 0) {
                                        ForEach(allowedNetworks, id: \.self) { network in
                                            HStack(spacing: 8) {
                                                Image(systemName: "wifi")
                                                    .font(.system(size: 11))
                                                    .foregroundColor(.blue)
                                                    .frame(width: 16)

                                                Text(network)
                                                    .font(.system(size: 12))
                                                    .foregroundColor(.primary)

                                                Spacer()

                                                Button {
                                                    removeNetwork(network)
                                                } label: {
                                                    Image(systemName: "xmark.circle.fill")
                                                        .font(.system(size: 13))
                                                        .foregroundColor(Color(NSColor.tertiaryLabelColor))
                                                }
                                                .buttonStyle(.plain)
                                                .help("Remove \(network)")
                                            }
                                            .padding(.vertical, 7)
                                            .padding(.horizontal, 10)

                                            if network != allowedNetworks.last {
                                                Divider().padding(.leading, 10)
                                            }
                                        }
                                    }
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(Color(NSColor.windowBackgroundColor))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 8)
                                                    .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
                                            )
                                    )
                                }
                            }
                            .padding(.leading, iconSize + iconSpacing)
                        }
                    }

                    // ── Status message — auto-dismiss ─
                    if !statusMessage.isEmpty {
                        HStack(spacing: 6) {
                            Image(systemName: isError
                                  ? "exclamationmark.circle.fill"
                                  : "checkmark.circle.fill")
                                .font(.system(size: 11))
                                .foregroundColor(isError ? .red : .green)
                            Text(statusMessage)
                                .font(.system(size: 11))
                                .foregroundColor(isError ? .red : .secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(.horizontal, 4)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 8)
            }

            // ── Footer ──────────────────────────────
            
            HStack(spacing: 8) {
                Button("Cancel") {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        show = false
                    }
                }
                .buttonStyle(.plain)
                .font(.system(size: 13))
                .foregroundColor(.secondary)

                Spacer()

                Button {
                    saveSettings()
                } label: {
                    Text("Save")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 7)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Color.blue))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .background(Color(NSColor.windowBackgroundColor))
        .onAppear { loadCurrentSettings() }
        .animation(.easeInOut(duration: 0.2), value: allowedNetworks)
        .animation(.easeInOut(duration: 0.2), value: statusMessage)
    }

    // ── Shared icon badge ────────────────────────
    @ViewBuilder
    private func iconBadge(_ systemName: String) -> some View {
        Image(systemName: systemName)
            .font(.system(size: 13, weight: .medium))
            .foregroundColor(.blue)
            .frame(width: iconSize, height: iconSize)
            .background(RoundedRectangle(cornerRadius: 7).fill(Color.blue.opacity(0.1)))
    }

    // ── FIX: auto-dismiss status after 2.5s ─────
    private func showStatus(_ message: String, error: Bool = false) {
        statusMessage = message
        isError = error

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            withAnimation(.easeOut(duration: 0.3)) {
                statusMessage = ""
            }
        }
    }

    // ── Helpers ─────────────────────────────────

    private func loadCurrentSettings() {
        currentNetwork = NetworkHelper.currentSSID()
        allowedNetworks = NetworkHelper.decodeNetworks(from: storedAllowedWiFiNetworks)

        if #available(macOS 13.0, *) {
            draftRunOnStartup = SMAppService.mainApp.status == .enabled
            storedRunOnStartup = draftRunOnStartup

            if SMAppService.mainApp.status == .requiresApproval {
                showStatus("Startup permission requires approval in System Settings.")
            }
        } else {
            draftRunOnStartup = storedRunOnStartup
            showStatus("Launch at Login requires macOS 13 or later.", error: true)
        }
    }

    private func addCurrentNetwork() {
        guard let currentNetwork else {
            showStatus("Current Wi-Fi network could not be detected.", error: true)
            return
        }

        guard !allowedNetworks.contains(currentNetwork) else {
            showStatus("\(currentNetwork) is already in the list.")
            return
        }

        withAnimation {
            allowedNetworks.append(currentNetwork)
            allowedNetworks.sort()
        }

        showStatus("\(currentNetwork) added.")
    }

    private func removeNetwork(_ network: String) {
        withAnimation {
            allowedNetworks.removeAll { $0 == network }
        }
        showStatus("\(network) removed.")
    }

    private func saveSettings() {
        saveStartupSetting()
        storedAllowedWiFiNetworks = NetworkHelper.encodeNetworks(allowedNetworks)

        withAnimation(.easeInOut(duration: 0.25)) {
            show = false
        }
    }

    private func saveStartupSetting() {
        if #available(macOS 13.0, *) {
            do {
                if draftRunOnStartup {
                    if SMAppService.mainApp.status != .enabled {
                        try SMAppService.mainApp.register()
                    }
                    storedRunOnStartup = true
                } else {
                    if SMAppService.mainApp.status == .enabled ||
                        SMAppService.mainApp.status == .requiresApproval {
                        try SMAppService.mainApp.unregister()
                    }
                    storedRunOnStartup = false
                }
            } catch {
                showStatus("Could not update startup setting: \(error.localizedDescription)", error: true)
            }
        } else {
            showStatus("Launch at Login requires macOS 13 or later.", error: true)
        }
    }
}

// ── Card container ───────────────────────────────
struct SettingsCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(NSColor.controlBackgroundColor))
            )
    }
}
