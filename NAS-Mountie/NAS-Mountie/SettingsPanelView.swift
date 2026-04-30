import SwiftUI
import ServiceManagement

struct SettingsPanelView: View {
    
    @Binding var show: Bool
    
    @AppStorage("runOnStartup") private var storedRunOnStartup = false
    @AppStorage("allowedWiFiNetworks") private var storedAllowedWiFiNetworks = "[]"
    @AppStorage("showDockIcon") private var storedShowDockIcon = true
    
    @State private var draftShowDockIcon = false
    @State private var draftRunOnStartup = false
    @State private var allowedNetworks: [String] = []
    @State private var currentNetwork: String? = nil
    @State private var statusMessage = ""
    @State private var isError = false
    
    private let iconSize: CGFloat = 28
    private let iconSpacing: CGFloat = 12
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            
            // ── Header ──────────────────────────────
            HStack(alignment: .center) {
                Text("Settings")
                    .font(Brand.headline(16))
                    .foregroundColor(.primary)
                Spacer()
                
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 14)
            
            // ── Content ──────────────────────────────
            ScrollView {
                VStack {
                    
                    // Card: Launch at Login
                    SettingsCard {
                        HStack(alignment: .center, spacing: iconSpacing) {
                            iconBadge("power")
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Launch at Login")
                                    .font(Brand.headline())
                                    .foregroundColor(.primary)
                                Text("Open NAS-Mountie automatically when you log in.")
                                    .font(Brand.caption())
                                    .foregroundColor(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            Spacer()
                            Toggle("", isOn: $draftRunOnStartup)
                                .labelsHidden()
                                .scaleEffect(0.8)
                                .padding(.trailing, 2)
                        }
                    }
                    
                    // Card: Wi-Fi Networks
                    SettingsCard {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(alignment: .center, spacing: iconSpacing) {
                                iconBadge("wifi")
                                VStack(alignment: .leading, spacing: 3) {
                                    Text("Network Profiles")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundColor(.primary)

                                    Text("Save NAS connection profiles per Wi-Fi network. NAS-Mountie will auto-mount saved shares when it recognizes this network.")
                                        .font(.system(size: 11))
                                        .foregroundColor(.secondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                            
                            Divider().padding(.leading, iconSize + iconSpacing)
                            
                            HStack(alignment: .center, spacing: iconSpacing) {
                                ZStack {
                                    Image(systemName: currentNetwork != nil ? "wifi.circle.fill" : "wifi.slash")
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundColor(currentNetwork != nil ? Brand.primary : .secondary)
                                }
                                .frame(width: iconSize, height: iconSize)
                                
                                VStack(alignment: .leading, spacing: 1) {
                                    Text("Current network")
                                        .font(Brand.caption(10))
                                        .foregroundColor(.secondary)
                                    Text(currentNetwork ?? "Not detected")
                                        .font(Brand.headline(12))
                                        .foregroundColor(currentNetwork != nil ? .primary : .secondary)
                                }
                                Spacer()
                                Button { addCurrentNetwork() } label: {
                                    HStack(spacing: 4) {
                                        Image(systemName: "plus")
                                            .font(.system(size: 10, weight: .semibold))
                                        Text("Save Profile")
                                            .font(.system(size: 11, weight: .medium))
                                    }
                                    .foregroundColor(currentNetwork == nil ? .secondary : Brand.primary)
                                    .padding(.horizontal, 9)
                                    .padding(.vertical, 5)
                                    .background(
                                        RoundedRectangle(cornerRadius: Brand.radiusSmall)
                                            .fill(currentNetwork == nil
                                                  ? Color(NSColor.controlBackgroundColor)
                                                  : Brand.primaryLight)
                                    )
                                }
                                .buttonStyle(.plain)
                                .disabled(currentNetwork == nil)
                            }
                            
                            if !statusMessage.isEmpty {
                                HStack(spacing: 6) {
                                    Image(systemName: isError ? "exclamationmark.circle.fill" : "checkmark.circle.fill")
                                        .font(.system(size: 11))
                                        .foregroundColor(isError ? .red : Brand.primary)
                                    Text(statusMessage)
                                        .font(Brand.caption())
                                        .foregroundColor(isError ? .red : .secondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                .padding(.horizontal, 4)
                                .transition(.opacity.combined(with: .move(edge: .top)))
                            }
                            
                            VStack(alignment: .leading, spacing: 0) {
                                if allowedNetworks.isEmpty {
                                    HStack {
                                        Spacer()
                                        VStack(spacing: 4) {
                                            Image(systemName: "wifi.exclamationmark")
                                                .font(.system(size: 18))
                                                .foregroundColor(.secondary.opacity(0.4))
                                            Text("No networks added yet")
                                                .font(Brand.caption())
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
                                                    .foregroundColor(Brand.primary)
                                                    .frame(width: 16)
                                                Text(network)
                                                    .font(Brand.body(12))
                                                    .foregroundColor(.primary)
                                                Spacer()
                                                Button { removeNetwork(network) } label: {
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
                                        RoundedRectangle(cornerRadius: Brand.radiusMedium)
                                            .fill(Color(NSColor.windowBackgroundColor))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: Brand.radiusMedium)
                                                    .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
                                            )
                                    )
                                }
                            }
                            .padding(.leading, iconSize + iconSpacing)
                        }
                    }
                    
                    // Card: Show Dock Icon
                    SettingsCard {
                        HStack(alignment: .center, spacing: iconSpacing) {
                            iconBadge("dock.rectangle")
                            
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Show Dock Icon")
                                    .font(Brand.headline())
                                    .foregroundColor(.primary)
                                
                                Text("Show NAS-Mountie in the macOS Dock.")
                                    .font(Brand.caption())
                                    .foregroundColor(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            
                            Spacer()
                            
                            Toggle("", isOn: $draftShowDockIcon)
                                .labelsHidden()
                                .scaleEffect(0.8)
                                .padding(.trailing, 2)
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
            }
            
            Divider()
            
            HStack(spacing: 8) {
                Button("Cancel") {
                    withAnimation(.easeInOut(duration: 0.25)) { show = false }
                }
                .buttonStyle(.plain)
                .font(Brand.body())
                .foregroundColor(.secondary)
                Spacer()
                Button { saveSettings() } label: {
                    Text("Save")
                        .font(Brand.headline())
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 7)
                        .background(RoundedRectangle(cornerRadius: Brand.radiusMedium).fill(Brand.primary))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
        .background(Color(NSColor.windowBackgroundColor))
        .onAppear { loadCurrentSettings() }
        .animation(.easeInOut(duration: 0.2), value: allowedNetworks)
        .animation(.easeInOut(duration: 0.2), value: statusMessage)
    }
    
    @ViewBuilder
    private func iconBadge(_ systemName: String) -> some View {
        Image(systemName: systemName)
            .font(.system(size: 13, weight: .medium))
            .foregroundColor(Brand.primary)
            .frame(width: iconSize, height: iconSize)
            .background(RoundedRectangle(cornerRadius: 7).fill(Brand.primaryLight))
    }
    
    private func showStatus(_ message: String, error: Bool = false) {
        statusMessage = message; isError = error
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            withAnimation(.easeOut(duration: 0.3)) { statusMessage = "" }
        }
    }
    
    private func loadCurrentSettings() {
        currentNetwork = NetworkHelper.currentSSID()
        allowedNetworks = NetworkHelper.decodeNetworks(from: storedAllowedWiFiNetworks)

        if UserDefaults.standard.object(forKey: "showDockIcon") == nil {
            storedShowDockIcon = true
        }

        if UserDefaults.standard.object(forKey: "runOnStartup") == nil {
            storedRunOnStartup = false
        }

        draftShowDockIcon = storedShowDockIcon

        if #available(macOS 13.0, *) {
            let startupStatus = SMAppService.mainApp.status

            if storedRunOnStartup && startupStatus != .enabled {
                draftRunOnStartup = true
            } else {
                draftRunOnStartup = startupStatus == .enabled
                storedRunOnStartup = draftRunOnStartup
            }

            if startupStatus == .requiresApproval {
                showStatus("Startup permission requires approval in System Settings.")
            }
        } else {
            draftRunOnStartup = storedRunOnStartup
            showStatus("Launch at Login requires macOS 13 or later.", error: true)
        }
    }
    
    private func addCurrentNetwork() {
        guard let currentNetwork else {
            showStatus("Network could not be detected.", error: true)
            return
        }

        guard !allowedNetworks.contains(currentNetwork) else {
            showStatus("A profile for \(currentNetwork) already exists.")
            return
        }

        withAnimation {
            allowedNetworks.append(currentNetwork)
            allowedNetworks.sort()
        }

        showStatus("Profile saved for \(currentNetwork).")
    }
    
    private func removeNetwork(_ network: String) {
        withAnimation { allowedNetworks.removeAll { $0 == network } }
        showStatus("\(network) removed.")
    }
    
    private func saveSettings() {
        saveStartupSetting()
        
        storedShowDockIcon = draftShowDockIcon
        NSApp.setActivationPolicy(draftShowDockIcon ? .regular : .accessory)
        
        storedAllowedWiFiNetworks = NetworkHelper.encodeNetworks(allowedNetworks)
        
        withAnimation(.easeInOut(duration: 0.25)) {
            show = false
        }
    }
    
    private func saveStartupSetting() {
        if #available(macOS 13.0, *) {
            do {
                if draftRunOnStartup {
                    if SMAppService.mainApp.status != .enabled { try SMAppService.mainApp.register() }
                    storedRunOnStartup = true
                } else {
                    if SMAppService.mainApp.status == .enabled || SMAppService.mainApp.status == .requiresApproval {
                        try SMAppService.mainApp.unregister()
                    }
                    storedRunOnStartup = false
                }
            } catch { showStatus("Could not update startup: \(error.localizedDescription)", error: true) }
        } else { showStatus("Launch at Login requires macOS 13+.", error: true) }
    }
}

struct SettingsCard<Content: View>: View {
    let content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }
    var body: some View {
        content
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: Brand.radiusLarge).fill(Color(NSColor.controlBackgroundColor)))
    }
}
