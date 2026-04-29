import SwiftUI

struct ChangelogSection: Identifiable {
    let id = UUID()
    let title: String
    let items: [String]
}

struct ChangelogEntry: Identifiable {
    let id = UUID()
    let version: String
    let date: String
    let sections: [ChangelogSection]
}

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
    
    private var changelogEntries: [ChangelogEntry] {
        parseChangelog(changelogText)
    }

    private func parseChangelog(_ rawText: String) -> [ChangelogEntry] {
        let lines = rawText.components(separatedBy: .newlines)

        var entries: [ChangelogEntry] = []

        var currentVersion = ""
        var currentDate = ""
        var currentSections: [ChangelogSection] = []

        var currentSectionTitle = ""
        var currentItems: [String] = []

        func saveCurrentSection() {
            guard !currentSectionTitle.isEmpty else { return }

            currentSections.append(
                ChangelogSection(
                    title: currentSectionTitle,
                    items: currentItems
                )
            )

            currentSectionTitle = ""
            currentItems = []
        }

        func saveCurrentEntry() {
            guard !currentVersion.isEmpty else { return }

            saveCurrentSection()

            entries.append(
                ChangelogEntry(
                    version: currentVersion,
                    date: currentDate,
                    sections: currentSections
                )
            )

            currentVersion = ""
            currentDate = ""
            currentSections = []
        }

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)

            if trimmed.hasPrefix("## ") {
                saveCurrentEntry()

                let heading = trimmed
                    .replacingOccurrences(of: "## ", with: "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)

                let parts = heading.components(separatedBy: " - ")

                currentVersion = parts.first?
                    .replacingOccurrences(of: "[", with: "")
                    .replacingOccurrences(of: "]", with: "")
                    ?? heading

                currentDate = parts.count > 1 ? parts[1] : ""
            } else if trimmed.hasPrefix("### ") {
                saveCurrentSection()

                currentSectionTitle = trimmed
                    .replacingOccurrences(of: "### ", with: "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            } else if trimmed.hasPrefix("- ") {
                let item = trimmed
                    .replacingOccurrences(of: "- ", with: "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)

                if !item.isEmpty {
                    currentItems.append(item)
                }
            }
        }

        saveCurrentEntry()

        return entries
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
                VStack(alignment: .leading, spacing: 18) {
                    ForEach(changelogEntries) { entry in
                        VStack(alignment: .leading, spacing: 14) {
                            HStack(alignment: .firstTextBaseline) {
                                Text(entry.version)
                                    .font(Brand.headline(15))
                                    .foregroundColor(.primary)

                                Spacer()

                                if !entry.date.isEmpty {
                                    Text(entry.date)
                                        .font(Brand.caption(11))
                                        .foregroundColor(.secondary)
                                }
                            }

                            ForEach(entry.sections) { section in
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(section.title)
                                        .font(Brand.headline(13))
                                        .foregroundColor(Brand.primary)

                                    VStack(alignment: .leading, spacing: 6) {
                                        ForEach(section.items, id: \.self) { item in
                                            HStack(alignment: .top, spacing: 8) {
                                                Text("•")
                                                    .font(Brand.caption(11))
                                                    .foregroundColor(Brand.primary)

                                                Text(.init(item))
                                                    .font(Brand.caption(11))
                                                    .foregroundColor(.primary.opacity(0.9))
                                                    .fixedSize(horizontal: false, vertical: true)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: Brand.radiusLarge)
                                .fill(Color(NSColor.controlBackgroundColor))
                        )
                    }
                }
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
