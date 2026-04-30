import SwiftUI

// ── NAS-Mountie Brand Tokens ─────────────────────
// Single source of truth — change here, updates everywhere.

enum Brand {

    // MARK: Colors
    /// Forest Green #2E6A4F — primary action color
    static let primary      = Color(hex: "#2E6A4F")
    static let primaryLight = Color(hex: "#E6EDEA")
    static let primaryBorder = Color(hex: "#2E6A4F").opacity(0.35)

    /// Charcoal #1D2023 — used for dark backgrounds if needed
    static let charcoal     = Color(hex: "#1D2023")

    /// Off-White #F5F2EB — warm background tint
    static let offWhite     = Color(hex: "#F5F2EB")

    /// Slate Blue #5B6E85 — secondary accent (future use)
    static let slateBlue    = Color(hex: "#5B6E85")

    /// Soft Sand #E6D8B6 — warm neutral (future use)
    static let softSand     = Color(hex: "#E6D8B6")

    // MARK: Typography
    static func title(_ size: CGFloat = 20) -> Font {
        .system(size: size, weight: .bold, design: .default)
    }

    static func headline(_ size: CGFloat = 13) -> Font {
        .system(size: size, weight: .semibold, design: .default)
    }

    static func body(_ size: CGFloat = 13) -> Font {
        .system(size: size, weight: .regular, design: .default)
    }

    static func caption(_ size: CGFloat = 11) -> Font {
        .system(size: size, weight: .regular, design: .default)
    }

    // MARK: Corner radii
    static let radiusSmall:  CGFloat = 6
    static let radiusMedium: CGFloat = 8
    static let radiusLarge:  CGFloat = 10
}

// MARK: - Color hex initializer
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255
        let g = Double((int >> 08) & 0xFF) / 255
        let b = Double((int >> 00) & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}
