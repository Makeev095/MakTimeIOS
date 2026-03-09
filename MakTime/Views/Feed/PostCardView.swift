import SwiftUI
import AVFoundation

struct PostCardView: View {
    let post: Post
    let isMine: Bool
    @ObservedObject var feedSound: FeedVideoSoundState
    let onLike: () -> Void
    let onComment: () -> Void
    let onRepost: () -> Void
    let onDelete: () -> Void
    var onVideoTap: (() -> Void)? = nil
    var onSave: (() -> Void)? = nil

    @State private var showDoubleTapHeart = false
    @State private var heartScale: CGFloat = 0

    var body: some View {
        ZStack(alignment: .top) {
            // Media fills entire card
            mediaBackground

            // Top overlay: header (always visible)
            VStack {
                headerOverlay
                Spacer(minLength: 0)
                // Bottom overlay: actions + caption
                bottomOverlay
            }
            .padding(.horizontal, 12)
            .padding(.top, 12)
            .padding(.bottom, 16)

            if showDoubleTapHeart {
                Image(systemName: "heart.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(Theme.gradientAccent)
                    .shadow(color: Theme.accent.opacity(0.7), radius: 14)
                    .scaleEffect(heartScale)
                    .transition(.opacity)
            }
        }
        .background(Theme.bgCard)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusLg))
        .overlay(RoundedRectangle(cornerRadius: Theme.radiusLg).stroke(Theme.glassBorder, lineWidth: 1))
        .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
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

    // MARK: - Media background (fills card)
    private var mediaBackground: some View {
        Group {
            if post.type == .video {
                InlineFeedVideoPlayer(url: URL(string: post.fullFileUrl), feedSound: feedSound)
            } else if let url = URL(string: post.fullFileUrl) {
                CachedImage(url: url) { img in
                    img.resizable()
                        .scaledToFill()
                } placeholder: {
                    ShimmerBox()
                }
            } else {
                Theme.bgCard
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusLg))
    }

    // MARK: - Header overlay (top)
    private var headerOverlay: some View {
        HStack(spacing: 10) {
            AvatarView(name: post.authorName, color: post.authorAvatarColor, size: 38)
                .overlay(Circle().stroke(Color.white.opacity(0.3), lineWidth: 1))
            VStack(alignment: .leading, spacing: 1) {
                Text(post.authorName)
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.5), radius: 2)
                Text(post.timeAgo)
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.85))
                    .shadow(color: .black.opacity(0.4), radius: 1)
            }
            Spacer()
            Menu {
                if let onSave = onSave {
                    Button { onSave() } label: {
                        Label("Сохранить", systemImage: "square.and.arrow.down")
                    }
                }
                if isMine {
                    Button(role: .destructive, action: onDelete) {
                        Label("Удалить", systemImage: "trash")
                    }
                }
            } label: {
                Image(systemName: "ellipsis")
                    .foregroundColor(.white)
                    .font(.system(size: 16, weight: .semibold))
                    .shadow(color: .black.opacity(0.4), radius: 2)
                    .frame(width: 36, height: 36)
                    .background(.black.opacity(0.35))
                    .clipShape(Circle())
            }
        }
    }

    // MARK: - Bottom overlay (actions + caption)
    private var bottomOverlay: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 0) {
                actionButton(
                    icon: post.isLiked ? "heart.fill" : "heart",
                    label: post.likesCount > 0 ? "\(post.likesCount)" : "",
                    color: post.isLiked ? Theme.danger : .white,
                    scale: post.isLiked ? 1.1 : 1.0,
                    action: onLike
                )
                actionButton(
                    icon: "bubble.right",
                    label: post.commentsCount > 0 ? "\(post.commentsCount)" : "",
                    color: .white,
                    scale: 1,
                    action: onComment
                )
                actionButton(
                    icon: "arrow.2.squarepath",
                    label: post.repostsCount > 0 ? "\(post.repostsCount)" : "",
                    color: .white,
                    scale: 1,
                    action: onRepost
                )
                Spacer()
            }

            if !post.caption.isEmpty || post.commentsCount > 0 {
                VStack(alignment: .leading, spacing: 4) {
                    if !post.caption.isEmpty {
                        (
                            Text(post.authorName)
                                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                            + Text(" ")
                            + Text(post.caption)
                                .font(.system(.subheadline, design: .rounded))
                        )
                        .foregroundColor(.white)
                        .lineLimit(2)
                        .shadow(color: .black.opacity(0.5), radius: 2)
                    }
                    if post.commentsCount > 0 {
                        Button(action: onComment) {
                            Text("Посмотреть все комментарии (\(post.commentsCount))")
                                .font(.system(.caption, design: .rounded))
                                .foregroundColor(.white.opacity(0.9))
                        }
                    }
                }
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 4)
        .background(
            LinearGradient(
                colors: [.clear, .black.opacity(0.6)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    private func actionButton(icon: String, label: String, color: Color, scale: CGFloat, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 22))
                    .foregroundColor(color)
                    .scaleEffect(scale)
                    .animation(.spring(response: 0.3), value: scale)
                    .shadow(color: .black.opacity(0.4), radius: 2)
                if !label.isEmpty {
                    Text(label)
                        .font(.system(.caption, design: .rounded).weight(.medium))
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.4), radius: 1)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
    }
}

// MARK: - Inline feed video player (autoplay, loop 3x, mute toggle)

struct InlineFeedVideoPlayer: View {
    let url: URL?
    @ObservedObject var feedSound: FeedVideoSoundState
    @StateObject private var vm = InlineFeedVideoVM()

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            if let player = vm.player {
                FeedAVPlayerView(player: player)
            } else {
                ShimmerBox()
            }

            // Mute button
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                vm.toggleMute(feedSound: feedSound)
            } label: {
                Image(systemName: vm.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 30, height: 30)
                    .background(.black.opacity(0.5))
                    .clipShape(Circle())
            }
            .padding(10)

            // Play/pause overlay when paused manually
            if vm.isPausedByUser {
                ZStack {
                    Color.black.opacity(0.25)
                    Image(systemName: "play.fill")
                        .font(.system(size: 36))
                        .foregroundColor(.white.opacity(0.85))
                }
                .onTapGesture { vm.togglePlayPause() }
            }
        }
        .onTapGesture {
            vm.togglePlayPause()
        }
        .onAppear {
            if let url = url { vm.load(url: url) }
            vm.applyMuteFrom(feedSound: feedSound)
            vm.play()
        }
        .onDisappear {
            vm.pause()
        }
    }
}

@MainActor
private final class InlineFeedVideoVM: ObservableObject {
    @Published var player: AVPlayer?
    @Published var isMuted = true
    @Published var isPausedByUser = false

    private var loopCount = 0
    private let maxLoops = 3
    private var loopObserver: Any?
    private var currentURL: URL?

    func load(url: URL) {
        guard url != currentURL else { return }
        currentURL = url

        if let obs = loopObserver { NotificationCenter.default.removeObserver(obs) }

        let item = AVPlayerItem(url: url)
        let p = AVPlayer(playerItem: item)
        p.isMuted = true
        p.actionAtItemEnd = .none

        loopCount = 0
        loopObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self, weak p] _ in
            guard let p else { return }
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.loopCount += 1
                if self.loopCount < self.maxLoops {
                    p.seek(to: .zero)
                    p.play()
                } else {
                    p.pause()
                    p.seek(to: .zero)
                }
            }
        }

        player = p

        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers])
    }

    func play() {
        isPausedByUser = false
        loopCount = 0
        player?.seek(to: .zero)
        player?.play()
    }

    func pause() {
        player?.pause()
    }

    func togglePlayPause() {
        if isPausedByUser {
            isPausedByUser = false
            loopCount = 0
            player?.play()
        } else {
            isPausedByUser = true
            player?.pause()
        }
    }

    func toggleMute(feedSound: FeedVideoSoundState) {
        isMuted.toggle()
        feedSound.soundOn = !isMuted
        player?.isMuted = isMuted
    }

    func applyMuteFrom(feedSound: FeedVideoSoundState) {
        isMuted = !feedSound.soundOn
        player?.isMuted = isMuted
    }

    deinit {
        if let obs = loopObserver { NotificationCenter.default.removeObserver(obs) }
    }
}

private struct FeedAVPlayerView: UIViewRepresentable {
    let player: AVPlayer

    func makeUIView(context: Context) -> FeedPlayerUIView {
        let v = FeedPlayerUIView()
        v.playerLayer.player = player
        v.playerLayer.videoGravity = .resizeAspectFill
        return v
    }
    func updateUIView(_ uiView: FeedPlayerUIView, context: Context) {
        uiView.playerLayer.player = player
    }

    final class FeedPlayerUIView: UIView {
        override class var layerClass: AnyClass { AVPlayerLayer.self }
        var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
        override func layoutSubviews() { super.layoutSubviews(); playerLayer.frame = bounds }
    }
}
