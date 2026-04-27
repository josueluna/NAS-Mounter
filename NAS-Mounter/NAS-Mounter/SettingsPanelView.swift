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

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            Text("Settings")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(.primary)

            Divider()
                .padding(.vertical, 16)

            VStack(alignment: .leading, spacing: 18) {

                Toggle(isOn: $draftRunOnStartup) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Run on startup")
                            .font(.system(size: 13, weight: .semibold))

                        Text("Open NAS Mounter automatically when you log in.")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }

                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    Text("Allowed Wi-Fi networks")
                        .font(.system(size: 13, weight: .semibold))

                    Text("NAS Mounter will only mount shares when connected to one of these networks. If the list is empty, mounting is allowed on any network.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack {
                        Text("Current network:")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)

                        Text(currentNetwork ?? "Not detected")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(currentNetwork == nil ? .secondary : .primary)

                        Spacer()
                    }

                    Button("Add current network") {
                        addCurrentNetwork()
                    }
                    .buttonStyle(.plain)
                    .disabled(currentNetwork == nil)

                    if allowedNetworks.isEmpty {
                        Text("No networks added yet.")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .padding(.top, 4)
                    } else {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(allowedNetworks, id: \.self) { network in
                                HStack {
                                    Image(systemName: "wifi")
                                        .foregroundColor(.blue)

                                    Text(network)
                                        .font(.system(size: 12))

                                    Spacer()

                                    Button {
                                        removeNetwork(network)
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundColor(.secondary)
                                    }
                                    .buttonStyle(.plain)
                                }
                                .padding(.vertical, 4)
                            }
                        }
                        .padding(.top, 4)
                    }
                }

                if !statusMessage.isEmpty {
                    Text(statusMessage)
                        .font(.system(size: 11))
                        .foregroundColor(isError ? .red : .secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer()

            HStack {
                Button("Cancel") {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        show = false
                    }
                }
                .buttonStyle(.plain)

                Spacer()

                Button("Save Settings") {
                    saveSettings()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(20)
        .frame(maxHeight: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(NSColor.windowBackgroundColor))
                .shadow(radius: 10)
        )
        .onAppear {
            loadCurrentSettings()
        }
    }

    private func loadCurrentSettings() {
        currentNetwork = NetworkHelper.currentSSID()
        allowedNetworks = NetworkHelper.decodeNetworks(from: storedAllowedWiFiNetworks)

        if #available(macOS 13.0, *) {
            draftRunOnStartup = SMAppService.mainApp.status == .enabled
            storedRunOnStartup = draftRunOnStartup

            if SMAppService.mainApp.status == .requiresApproval {
                statusMessage = "Startup permission requires approval in System Settings."
                isError = false
            }
        } else {
            draftRunOnStartup = storedRunOnStartup
            statusMessage = "Run on startup requires macOS 13 or later."
            isError = true
        }
    }

    private func addCurrentNetwork() {
        guard let currentNetwork else {
            statusMessage = "Current Wi-Fi network could not be detected."
            isError = true
            return
        }

        guard !allowedNetworks.contains(currentNetwork) else {
            statusMessage = "\(currentNetwork) is already in the allowed list."
            isError = false
            return
        }

        allowedNetworks.append(currentNetwork)
        allowedNetworks.sort()

        statusMessage = "\(currentNetwork) added."
        isError = false
    }

    private func removeNetwork(_ network: String) {
        allowedNetworks.removeAll { $0 == network }

        statusMessage = "\(network) removed."
        isError = false
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
                isError = true
                statusMessage = "Could not update startup setting: \(error.localizedDescription)"
            }
        } else {
            isError = true
            statusMessage = "Run on startup requires macOS 13 or later."
        }
    }
}
