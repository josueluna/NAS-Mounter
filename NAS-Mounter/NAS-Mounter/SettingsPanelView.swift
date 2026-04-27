import SwiftUI

struct SettingsPanelView: View {

    @Binding var show: Bool
    @AppStorage("runOnStartup") private var runOnStartup = false

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {

            // TITLE
            Text("Settings")
                .font(.title2)
                .bold()

            Divider()

            // OPTION
            Toggle("Run on startup", isOn: $runOnStartup)

            Spacer()

            // ACTIONS
            HStack {
                Button("Cancel") {
                    withAnimation {
                        show = false
                    }
                }

                Spacer()

                Button("Save Settings") {
                    withAnimation {
                        show = false
                    }
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(20)
        .frame(maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(NSColor.windowBackgroundColor))
                .shadow(radius: 10)
        )
    }
}
