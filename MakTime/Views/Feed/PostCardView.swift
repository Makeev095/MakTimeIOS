import SwiftUI
import AVKit

struct PostCardView: View {
    let post: Post
    let isMine: Bool
    let onLike: () -> Void
    let onComment: () -> Void
    let onRepost: () -> Void
    let onDelete: () -> Void

    @State private var showDoubleTapHeart = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(spacing: 10) {
                AvatarView(name: post.authorName, color: post.authorAvatarColor, size: 36)
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
                        Button(role: .destructive) {
                            onDelete()
                        } label: {
                            Label("Удалить", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .foregroundColor(Theme.textSecondary)
                            .padding(8)
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            // Media
            ZStack {
                if post.type == .video, let url = URL(string: post.fullFileUrl) {
                    VideoPlayer(player: AVPlayer(url: url))
                        .aspectRatio(1, contentMode: .fill)
                        .clipped()
                } else {
                    AsyncImage(url: URL(string: post.fullFileUrl)) { phase in
                        switch phase {
                        case .success(let img):
                            img
                                .resizable()
                                .scaledToFill()
                                .frame(maxWidth: .infinity)
                                .frame(minHeight: 300)
                                .clipped()
                        case .failure:
                            Rectangle()
                                .fill(Color.white.opacity(0.04))
                                .frame(height: 300)
                                .overlay(
                                    Image(systemName: "photo")
                                        .font(.largeTitle)
                                        .foregroundColor(Theme.textMuted)
                                )
                        default:
                            Rectangle()
                                .fill(Color.white.opacity(0.04))
                                .frame(height: 300)
                                .overlay(ProgressView().tint(Theme.accent))
                        }
                    }
                }

                if showDoubleTapHeart {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 80))
                        .foregroundStyle(Theme.gradientAccent)
                        .shadow(color: Theme.accent.opacity(0.6), radius: 12)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .onTapGesture(count: 2) {
                if !post.isLiked {
                    onLike()
                }
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                    showDoubleTapHeart = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    withAnimation { showDoubleTapHeart = false }
                }
            }

            // Action buttons
            HStack(spacing: 18) {
                Button(action: onLike) {
                    Image(systemName: post.isLiked ? "heart.fill" : "heart")
                        .font(.title3)
                        .foregroundColor(post.isLiked ? Theme.danger : Theme.textPrimary)
                        .scaleEffect(post.isLiked ? 1.1 : 1.0)
                        .animation(.spring(response: 0.3), value: post.isLiked)
                }

                Button(action: onComment) {
                    Image(systemName: "bubble.right")
                        .font(.title3)
                        .foregroundColor(Theme.textPrimary)
                }

                Button(action: onRepost) {
                    Image(systemName: "arrow.2.squarepath")
                        .font(.title3)
                        .foregroundColor(Theme.textPrimary)
                }

                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.top, 10)
            .padding(.bottom, 6)

            if post.likesCount > 0 {
                Text(likesText)
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                    .foregroundColor(Theme.textPrimary)
                    .padding(.horizontal, 14)
                    .padding(.bottom, 4)
            }

            if !post.caption.isEmpty {
                HStack(alignment: .top, spacing: 4) {
                    Text(post.authorName).font(.system(.subheadline, design: .rounded).weight(.semibold))
                    + Text(" ")
                    + Text(post.caption).font(.system(.subheadline, design: .rounded))
                }
                .foregroundColor(Theme.textPrimary)
                .lineLimit(3)
                .padding(.horizontal, 14)
                .padding(.bottom, 4)
            }

            if post.commentsCount > 0 {
                Button(action: onComment) {
                    Text("Показать комментарии (\(post.commentsCount))")
                        .font(.system(.caption, design: .rounded))
                        .foregroundColor(Theme.textMuted)
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 8)
            } else {
                Spacer().frame(height: 8)
            }
        }
        .background(Theme.bgPrimary)
    }

    private var likesText: String {
        let count = post.likesCount
        let lastDigit = count % 10
        let lastTwoDigits = count % 100
        if lastTwoDigits >= 11 && lastTwoDigits <= 19 {
            return "\(count) отметок «Нравится»"
        }
        switch lastDigit {
        case 1: return "\(count) отметка «Нравится»"
        case 2, 3, 4: return "\(count) отметки «Нравится»"
        default: return "\(count) отметок «Нравится»"
        }
    }
}
