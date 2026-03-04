import SwiftUI

struct AvatarView: View {
    let name: String
    let color: String
    var size: CGFloat = 44
    var showOnline: Bool = false
    
    var body: some View {
        ZStack {
            Circle()
                .fill(Color(hex: color))
                .frame(width: size, height: size)
            
            Text(initials)
                .font(.system(size: size * 0.38, weight: .semibold))
                .foregroundColor(.white)
        }
        .overlay(alignment: .bottomTrailing) {
            if showOnline {
                Circle()
                    .fill(Theme.success)
                    .frame(width: size * 0.3, height: size * 0.3)
                    .overlay(Circle().stroke(Theme.bgPrimary, lineWidth: 2))
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
