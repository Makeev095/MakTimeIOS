import SwiftUI

struct Theme {
    // Backgrounds
    static let bgPrimary = Color(hex: "08080F")
    static let bgSecondary = Color(hex: "0E0E1A")
    static let bgTertiary = Color(hex: "141428")
    static let bgHover = Color(hex: "1A1A35")
    static let bgActive = Color(hex: "222244")

    // Accents
    static let accent = Color(hex: "8B5CF6")
    static let accentHover = Color(hex: "7C3AED")
    static let accentLight = Color(hex: "8B5CF6").opacity(0.15)
    static let accentSecondary = Color(hex: "06B6D4")

    // Text
    static let textPrimary = Color(hex: "F8FAFC")
    static let textSecondary = Color(hex: "94A3B8")
    static let textMuted = Color(hex: "475569")

    // Messages
    static let msgSent = LinearGradient(colors: [Color(hex: "8B5CF6"), Color(hex: "06B6D4")], startPoint: .topLeading, endPoint: .bottomTrailing)
    static let msgSentColor = Color(hex: "8B5CF6")
    static let msgReceived = Color.white.opacity(0.06)

    // Status
    static let success = Color(hex: "10B981")
    static let danger = Color(hex: "F43F5E")
    static let warning = Color(hex: "F59E0B")

    // Border & Glass
    static let border = Color.white.opacity(0.08)
    static let glassBorder = Color.white.opacity(0.12)

    // Radius
    static let radius: CGFloat = 16
    static let radiusSm: CGFloat = 10

    // Gradients
    static let gradientAccent = LinearGradient(
        colors: [Color(hex: "8B5CF6"), Color(hex: "06B6D4")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let gradientBg = LinearGradient(
        colors: [Color(hex: "08080F"), Color(hex: "0E0E1A"), Color(hex: "141428")],
        startPoint: .top,
        endPoint: .bottom
    )

    static let gradientNeon = LinearGradient(
        colors: [Color(hex: "8B5CF6"), Color(hex: "EC4899"), Color(hex: "06B6D4")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

// MARK: - View Modifiers

extension View {
    func glassCard(cornerRadius: CGFloat = 16) -> some View {
        self
            .background(.ultraThinMaterial)
            .cornerRadius(cornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(Theme.glassBorder, lineWidth: 1)
            )
    }

    func neonGlow(_ color: Color = Theme.accent, radius: CGFloat = 12) -> some View {
        self.shadow(color: color.opacity(0.5), radius: radius)
    }

    func glassBackground() -> some View {
        self.background(
            ZStack {
                Theme.bgPrimary
                Color.white.opacity(0.03)
            }
        )
    }
}

// MARK: - Color Hex Init

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
