import SwiftUI

struct AvatarView: View {
    let name: String
    let color: String
    var size: CGFloat = 44
    var showOnline: Bool = false

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color(hex: color), Color(hex: color).opacity(0.7)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: size, height: size)

            Text(initials)
                .font(.system(size: size * 0.38, weight: .bold, design: .rounded))
                .foregroundColor(.white)
        }
        .overlay(
            Circle()
                .stroke(Theme.glassBorder, lineWidth: 1)
        )
        .overlay(alignment: .bottomTrailing) {
            if showOnline {
                Circle()
                    .fill(Theme.success)
                    .frame(width: size * 0.28, height: size * 0.28)
                    .overlay(Circle().stroke(Theme.bgPrimary, lineWidth: 2))
                    .shadow(color: Theme.success.opacity(0.6), radius: 4)
                    .offset(x: 2, y: 2)
            }
        }
    }

    private var initials: String {
        let parts = name.split(separator: " ")
        if parts.count >= 2 {
            return String(parts[0].prefix(1) + parts[1].prefix(1)).uppercased()
        }
        return String(name.prefix(2)).uppercased()
    }
}
