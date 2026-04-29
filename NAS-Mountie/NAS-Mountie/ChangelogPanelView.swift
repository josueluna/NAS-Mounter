import SwiftUI

struct ChangelogPanelView: View {
    @Binding var show: Bool

    private var changelogText: String {
        guard let url = Bundle.main.url(forResource: "CHANGELOG", withExtension: "md"),
              let content = try? String(contentsOf: url, encoding: .utf8)
        else {
            return "Changelog could not be loaded."
        }

        return content
            .replacingOccurrences(of: "# Changelog\n\n", with: "")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            HStack {
                Text("Changelog")
                    .font(Brand.headline(16))
                    .foregroundColor(.primary)

                Spacer()

                Text(appVersion)
                    .font(Brand.caption(11))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 12)

            Divider()

            ScrollView(.vertical, showsIndicators: true) {
                Text(changelogText)
                    .font(Brand.caption(11))
                    .foregroundColor(.primary.opacity(0.9))
                    .lineSpacing(4)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
            }

            Divider()

            HStack {
                Spacer()

                Button {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        show = false
                    }
                } label: {
                    Text("Close")
                        .font(Brand.headline())
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 7)
                        .background(
                            RoundedRectangle(cornerRadius: Brand.radiusMedium)
                                .fill(Brand.primary)
                        )
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.windowBackgroundColor))
    }

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
        return "v\(version)"
    }
}
