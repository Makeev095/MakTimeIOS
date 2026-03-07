import SwiftUI

struct CachedImage<Content: View, Placeholder: View>: View {
    let url: URL?
    let content: (Image) -> Content
    let placeholder: () -> Placeholder

    @State private var uiImage: UIImage?
    @State private var isLoading = false

    init(
        url: URL?,
        @ViewBuilder content: @escaping (Image) -> Content,
        @ViewBuilder placeholder: @escaping () -> Placeholder
    ) {
        self.url = url
        self.content = content
        self.placeholder = placeholder
    }

    var body: some View {
        Group {
            if let img = uiImage {
                content(Image(uiImage: img))
            } else {
                placeholder()
                    .task(id: url?.absoluteString) {
                        await loadImage()
                    }
            }
        }
    }

    private func loadImage() async {
        guard let url else { return }
        isLoading = true
        if let img = await ImageCache.shared.load(url: url) {
            withAnimation(.easeIn(duration: 0.15)) {
                uiImage = img
            }
        }
        isLoading = false
    }
}

// MARK: - Shimmer placeholder helper
struct ShimmerBox: View {
    var cornerRadius: CGFloat = 0
    @State private var phase: CGFloat = 0

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(
                LinearGradient(
                    gradient: Gradient(stops: [
                        .init(color: Color.white.opacity(0.04), location: phase - 0.3),
                        .init(color: Color.white.opacity(0.10), location: phase),
                        .init(color: Color.white.opacity(0.04), location: phase + 0.3),
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .onAppear {
                withAnimation(.linear(duration: 1.4).repeatForever(autoreverses: false)) {
                    phase = 1.3
                }
            }
    }
}
