import SwiftUI

struct SearchBarView: View {
    @Binding var text: String
    var placeholder: String = "Поиск..."

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(Theme.textMuted)

            TextField(placeholder, text: $text)
                .foregroundColor(Theme.textPrimary)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)

            if !text.isEmpty {
                Button { text = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(Theme.textMuted)
                }
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 42)
        .glassCard(cornerRadius: Theme.radiusSm)
    }
}
