import SwiftUI

struct PostCardView: View {
    let post: Post
    let isMine: Bool
    let onLike: () -> Void
    let onComment: () -> Void
    let onRepost: () -> Void
    let onDelete: () -> Void
    var onVideoTap: (() -> Void)? = nil

    @State private var showDoubleTapHeart = false
    @State private var heartScale: CGFloat = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            mediaSection
            actionBar
            captionSection
        }
        .background(Theme.bgCard)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusLg))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.radiusLg)
                .stroke(Theme.glassBorder, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
    }

    // MARK: - Header
    private var header: some View {
        HStack(spacing: 10) {
            AvatarView(name: post.authorName, color: post.authorAvatarColor, size: 38)
            VStack(alignment: .leading, spacing: 1) {
                Text(post.authorName)
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                    .foregroundColor(Theme.textPrimary)
                Text(post.timeAgo)
                    .font(.caption2)
                    .foregroundColor(Theme.textMuted)
            }
            Spacer()
            if isMine {
                Menu {
                    Button(role: .destructive, action: onDelete) {
                        Label("Удалить", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .foregroundColor(Theme.textSecondary)
                        .padding(10)
                        .background(Theme.bgHover)
                        .clipShape(Circle())
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 14)
        .padding(.bottom, 10)
    }

    // MARK: - Media
    private var mediaSection: some View {
        ZStack {
            Group {
                if post.type == .video {
                    videoPreview
                } else if let url = URL(string: post.fullFileUrl) {
                    CachedImage(url: url) { img in
                        img.resizable()
                            .scaledToFill()
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: 280)
                            .clipped()
                    } placeholder: {
                        ShimmerBox()
                            .frame(maxWidth: .infinity)
                            .frame(height: 280)
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: Theme.radius))
            .padding(.horizontal, 10)

            // Double-tap heart
            if showDoubleTapHeart {
                Image(systemName: "heart.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(Theme.gradientAccent)
                    .shadow(color: Theme.accent.opacity(0.7), radius: 14)
                    .scaleEffect(heartScale)
                    .opacity(showDoubleTapHeart ? 1 : 0)
                    .transition(.opacity)
            }
        }
        .onTapGesture(count: 2) {
            if !post.isLiked { onLike() }
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            withAnimation(.spring(response: 0.25, dampingFraction: 0.55)) {
                showDoubleTapHeart = true
                heartScale = 1
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
                withAnimation(.easeOut(duration: 0.25)) {
                    showDoubleTapHeart = false
                    heartScale = 0
                }
            }
        }
    }

    /// Video thumbnail — static gradient placeholder with play icon; tapping opens Reels
    private var videoPreview: some View {
        Button(action: { onVideoTap?() }) {
            ZStack {
                // Dark gradient placeholder (no live AVPlayer in feed)
                LinearGradient(
                    colors: [Color(hex: "111126"), Color(hex: "1C1C3A")],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .frame(maxWidth: .infinity)
                .frame(height: 280)

                // Play icon
                ZStack {
                    Circle()
                        .fill(.white.opacity(0.15))
                        .frame(width: 72, height: 72)
                    Image(systemName: "play.fill")
                        .font(.system(size: 30))
                        .foregroundColor(.white)
                        .offset(x: 3)
                }
                .shadow(color: .black.opacity(0.4), radius: 12)

                // "Reels" badge
                VStack {
                    HStack {
                        Spacer()
                        Label("Reels", systemImage: "play.rectangle.fill")
                            .font(.caption2.weight(.semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.black.opacity(0.5))
                            .clipShape(Capsule())
                            .padding(8)
                    }
                    Spacer()
                }
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Action bar
    private var actionBar: some View {
        HStack(spacing: 0) {
            actionButton(
                icon: post.isLiked ? "heart.fill" : "heart",
                label: post.likesCount > 0 ? "\(post.likesCount)" : "",
                color: post.isLiked ? Theme.danger : Theme.textSecondary,
                scale: post.isLiked ? 1.1 : 1.0,
                action: onLike
            )
            actionButton(
                icon: "bubble.right",
                label: post.commentsCount > 0 ? "\(post.commentsCount)" : "",
                color: Theme.textSecondary,
                scale: 1,
                action: onComment
            )
            actionButton(
                icon: "arrow.2.squarepath",
                label: post.repostsCount > 0 ? "\(post.repostsCount)" : "",
                color: Theme.textSecondary,
                scale: 1,
                action: onRepost
            )
            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
    }

    private func actionButton(
        icon: String,
        label: String,
        color: Color,
        scale: CGFloat,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(color)
                    .scaleEffect(scale)
                    .animation(.spring(response: 0.3), value: scale)
                if !label.isEmpty {
                    Text(label)
                        .font(.system(.caption, design: .rounded).weight(.medium))
                        .foregroundColor(Theme.textSecondary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
    }

    // MARK: - Caption
    @ViewBuilder
    private var captionSection: some View {
        if !post.caption.isEmpty || post.commentsCount > 0 {
            VStack(alignment: .leading, spacing: 4) {
                if !post.caption.isEmpty {
                    Group {
                        Text(post.authorName)
                            .font(.system(.subheadline, design: .rounded).weight(.semibold))
                        + Text(" ")
                        + Text(post.caption)
                            .font(.system(.subheadline, design: .rounded))
                    }
                    .foregroundColor(Theme.textPrimary)
                    .lineLimit(3)
                }
                if post.commentsCount > 0 {
                    Button(action: onComment) {
                        Text("Посмотреть все комментарии (\(post.commentsCount))")
                            .font(.system(.caption, design: .rounded))
                            .foregroundColor(Theme.textMuted)
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 14)
        } else {
            Spacer().frame(height: 4)
        }
    }
}
