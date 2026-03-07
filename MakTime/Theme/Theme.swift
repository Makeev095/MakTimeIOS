import SwiftUI

struct Theme {
    static let bgPrimary = Color(hex: "0F0F1A")
    static let bgSecondary = Color(hex: "1A1A2E")
    static let bgTertiary = Color(hex: "16213E")
    static let bgHover = Color(hex: "1F2544")
    static let bgActive = Color(hex: "2A2D5E")
    
    static let accent = Color(hex: "6C63FF")
    static let accentHover = Color(hex: "5A52E0")
    static let accentLight = Color(hex: "6C63FF").opacity(0.15)
    static let accentSecondary = Color(hex: "FF6584")
    
    static let gradientAccent = LinearGradient(
        colors: [Color(hex: "6C63FF"), Color(hex: "FF6584")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let gradientNeon = AngularGradient(
        gradient: Gradient(colors: [
            Color(hex: "F58529"),
            Color(hex: "DD2A7B"),
            Color(hex: "8134AF"),
            Color(hex: "515BD4"),
            Color(hex: "F58529"),
        ]),
        center: .center
    )
    
    static let textPrimary = Color(hex: "EAEAEA")
    static let textSecondary = Color(hex: "8B8CA0")
    static let textMuted = Color(hex: "555670")
    
    static let msgSent = Color(hex: "6C63FF")
    static let msgReceived = Color(hex: "1F2544")
    
    static let success = Color(hex: "43AA8B")
    static let danger = Color(hex: "F94144")
    
    static let border = Color.white.opacity(0.06)
    static let glassBorder = Color.white.opacity(0.12)
    
    static let radius: CGFloat = 12
    static let radiusSm: CGFloat = 8
}

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

extension View {
    func neonGlow(_ color: Color, radius: CGFloat = 8) -> some View {
        self
            .shadow(color: color.opacity(0.5), radius: radius / 2)
            .shadow(color: color.opacity(0.25), radius: radius)
    }
    
    func glassCard(cornerRadius: CGFloat = Theme.radius) -> some View {
        self
            .background(.ultraThinMaterial)
            .background(Color.white.opacity(0.03))
            .cornerRadius(cornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
    }
}
