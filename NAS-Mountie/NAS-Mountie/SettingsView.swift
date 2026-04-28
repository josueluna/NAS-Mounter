import SwiftUI

struct SettingsView: View {
    
    @AppStorage("runOnStartup") private var runOnStartup = false

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            
            Text("Settings")
                .font(.title2)
                .bold()
            
            Toggle("Run on startup", isOn: $runOnStartup)
            
            Spacer()
        }
        .padding(24)
        .frame(width: 320, height: 180)
    }
}
