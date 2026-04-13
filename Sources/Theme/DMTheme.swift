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
    static let sidebarBackground = Color(hex: "0a0a10")

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

    // MARK: - Card shadow
    static let cardShadow: Color = .black.opacity(0.2)
    static let cardCornerRadius: CGFloat = 16
    static let cardPadding: CGFloat = 16

    // MARK: - Spacing constants
    static let sectionSpacing: CGFloat = 24
    static let cardSpacing: CGFloat = 12
    static let contentPadding: CGFloat = 16
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
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

/// Primary action button (gold bg, dark text)
struct DMPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(DMTheme.background)
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
            .frame(minHeight: 44)
            .background(configuration.isPressed ? DMTheme.accent.opacity(0.7) : DMTheme.accent)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

/// Destructive action button (red tint)
struct DMDestructiveButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline)
            .foregroundStyle(DMTheme.accentRed)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .frame(minHeight: 44)
            .background(configuration.isPressed ? DMTheme.accentRed.opacity(0.15) : DMTheme.accentRed.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - Card Modifier

struct DMCardModifier: ViewModifier {
    var cornerRadius: CGFloat = DMTheme.cardCornerRadius
    var showBorder: Bool = true

    func body(content: Content) -> some View {
        content
            .padding(DMTheme.cardPadding)
            .background(DMTheme.card)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(DMTheme.border, lineWidth: showBorder ? 1 : 0)
            )
            .shadow(color: DMTheme.cardShadow, radius: 4, y: 2)
    }
}

extension View {
    func dmCard(cornerRadius: CGFloat = DMTheme.cardCornerRadius, showBorder: Bool = true) -> some View {
        modifier(DMCardModifier(cornerRadius: cornerRadius, showBorder: showBorder))
    }
}

// MARK: - Empty State View

struct DMEmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    var buttonTitle: String?
    var buttonAction: (() -> Void)?

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 56, weight: .light))
                .foregroundStyle(DMTheme.accent.opacity(0.3))

            Text(title)
                .font(.title3.bold())
                .foregroundStyle(DMTheme.textPrimary)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(DMTheme.textSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 320)

            if let buttonTitle, let buttonAction {
                Button(action: buttonAction) {
                    Label(buttonTitle, systemImage: "plus")
                }
                .buttonStyle(DMPrimaryButtonStyle())
                .padding(.top, 8)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
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
