import SwiftUI
import ServiceManagement

struct SettingsPanelView: View {

    @Binding var show: Bool

    @AppStorage("runOnStartup") private var storedRunOnStartup = false

    @State private var draftRunOnStartup = false
    @State private var statusMessage = ""
    @State private var isError = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            Text("Settings")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(.primary)

            Divider()
                .padding(.vertical, 16)

            VStack(alignment: .leading, spacing: 14) {

                Toggle(isOn: $draftRunOnStartup) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Run on startup")
                            .font(.system(size: 13, weight: .semibold))

                        Text("Open NAS Mounter automatically when you log in.")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
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

    private func saveSettings() {
        if #available(macOS 13.0, *) {
            do {
                if draftRunOnStartup {
                    if SMAppService.mainApp.status != .enabled {
                        try SMAppService.mainApp.register()
                    }

                    storedRunOnStartup = true
                    statusMessage = "Startup setting saved."
                    isError = false
                } else {
                    if SMAppService.mainApp.status == .enabled ||
                        SMAppService.mainApp.status == .requiresApproval {
                        try SMAppService.mainApp.unregister()
                    }

                    storedRunOnStartup = false
                    statusMessage = "Startup setting saved."
                    isError = false
                }

                withAnimation(.easeInOut(duration: 0.25)) {
                    show = false
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
