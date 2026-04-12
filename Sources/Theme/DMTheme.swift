import SwiftUI

/// DMTheme — Single source of truth for all DM Forge styling.
/// Premium dark DM-screen aesthetic with configurable accent color.
enum DMTheme {
    // MARK: - Core Palette
    static let background = Color(hex: "0d0d14")
    static let card = Color(hex: "171722")
    static let cardHover = Color(hex: "22222f")
    static let detail = Color(hex: "111118")
    static let border = Color(hex: "2c2836")

    // MARK: - Text
    static let textPrimary = Color(hex: "e8dcc8")
    static let textSecondary = Color(hex: "8a8698")
    static let textDim = Color(hex: "55516a")

    // MARK: - Accent (configurable)
    static var accent: Color { Color(hex: "d4a847") }

    static let accentBlue = Color(hex: "6b8ccc")
    static let accentRed = Color(hex: "c45050")
    static let accentGreen = Color(hex: "7aaa68")

    // MARK: - HP (amber torchlight gradient)
    static let hpFull = Color(hex: "c8a84e")
    static let hpHigh = Color(hex: "b89040")
    static let hpLow = Color(hex: "c47030")
    static let hpCritical = Color(hex: "a83030")

    // MARK: - Mana (arcane blue)
    static let manaFull = Color(hex: "6b7ecc")
    static let manaEmpty = Color(hex: "252030")
    static let manaBorder = Color(hex: "4a4470")

    // MARK: - HP Color for ratio
    static func hpColor(ratio: Double) -> Color {
        switch ratio {
        case 0.75...: return hpFull
        case 0.50...: return hpHigh
        case 0.25...: return hpLow
        default: return hpCritical
        }
    }

    // MARK: - Accent Presets
    static let presets: [(name: String, hex: String)] = [
        ("Gold", "d4a847"),
        ("Bronze", "c87033"),
        ("Crimson", "b84040"),
        ("Emerald", "2d8a4e"),
        ("Sapphire", "4a7acc"),
        ("Amethyst", "8a4acc"),
        ("Silver", "8899aa"),
        ("Copper", "cc7744"),
        ("Rose", "cc5577"),
        ("Teal", "44aa99"),
    ]
}

// MARK: - Color hex extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255
        let g = Double((int >> 8) & 0xFF) / 255
        let b = Double(int & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}

// MARK: - Button Styles

struct DMButtonStyle: ButtonStyle {
    var color: Color = DMTheme.card

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(DMTheme.textPrimary)
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
            .background(configuration.isPressed ? color.opacity(0.7) : color)
            .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

struct DMSmallButtonStyle: ButtonStyle {
    var color: Color = DMTheme.card

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline)
            .foregroundStyle(DMTheme.textPrimary)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(configuration.isPressed ? color.opacity(0.7) : color)
            .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

// MARK: - Environment key for active campaign

struct CampaignKey: EnvironmentKey {
    nonisolated(unsafe) static let defaultValue: Campaign? = nil
}

extension EnvironmentValues {
    var campaign: Campaign? {
        get { self[CampaignKey.self] }
        set { self[CampaignKey.self] = newValue }
    }
}
