import SwiftUI
import AVKit
import AVFoundation

struct ReelsView: View {
    let posts: [Post]
    let startIndex: Int
    let onClose: () -> Void
    let onLike: (Post) -> Void
    let onComment: (Post) -> Void
    let onRepost: (Post) -> Void

    @State private var currentIndex: Int
    @EnvironmentObject var authService: AuthService

    init(posts: [Post],
         startIndex: Int,
         onClose: @escaping () -> Void,
         onLike: @escaping (Post) -> Void,
         onComment: @escaping (Post) -> Void,
         onRepost: @escaping (Post) -> Void) {
        self.posts = posts
        self.startIndex = startIndex
        self.onClose = onClose
        self.onLike = onLike
        self.onComment = onComment
        self.onRepost = onRepost
        _currentIndex = State(initialValue: startIndex)
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.black.ignoresSafeArea()

            if posts.isEmpty {
                VStack {
                    Spacer()
                    Text("Нет видео")
                        .foregroundColor(.white.opacity(0.5))
                        .font(.headline)
                    Spacer()
                }
            } else {
                TabView(selection: $currentIndex) {
                    ForEach(Array(posts.enumerated()), id: \.element.id) { idx, post in
                        ReelPlayerView(
                            post: post,
                            isActive: idx == currentIndex,
                            onLike: { onLike(post) },
                            onComment: { onComment(post) },
                            onRepost: { onRepost(post) }
                        )
                        .tag(idx)
                        .rotationEffect(.degrees(-90))
                        .frame(
                            width: UIScreen.main.bounds.height,
                            height: UIScreen.main.bounds.width
                        )
                    }
                }
                .frame(
                    width: UIScreen.main.bounds.width,
                    height: UIScreen.main.bounds.height
                )
                .tabViewStyle(.page(indexDisplayMode: .never))
                .rotationEffect(.degrees(90))
                .ignoresSafeArea()
            }

            // Close button
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 36, height: 36)
                    .background(.black.opacity(0.45))
                    .clipShape(Circle())
            }
            .padding(.top, 56)
            .padding(.leading, 16)
        }
        .statusBarHidden(true)
        .ignoresSafeArea()
    }
}

// MARK: - Single reel player

private struct ReelPlayerView: View {
    let post: Post
    let isActive: Bool
    let onLike: () -> Void
    let onComment: () -> Void
    let onRepost: () -> Void

    @StateObject private var playerVM = ReelPlayerViewModel()
    @State private var showDoubleTapHeart = false
    @State private var heartScale: CGFloat = 0

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            // Video player
            if let player = playerVM.player {
                ReelAVPlayerView(player: player)
                    .ignoresSafeArea()
            } else {
                ProgressView()
                    .tint(.white)
                    .scaleEffect(1.4)
            }

            // Double-tap heart
            if showDoubleTapHeart {
                Image(systemName: "heart.fill")
                    .font(.system(size: 90))
                    .foregroundColor(.white)
                    .shadow(color: Theme.accent.opacity(0.8), radius: 20)
                    .scaleEffect(heartScale)
                    .transition(.opacity)
            }

            // Gradient overlay (bottom)
            LinearGradient(
                colors: [.clear, .clear, .black.opacity(0.7)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            // Side action buttons (right)
            HStack {
                Spacer()
                VStack(spacing: 24) {
                    Spacer()

                    // Like
                    reelButton(
                        icon: post.isLiked ? "heart.fill" : "heart",
                        label: post.likesCount > 0 ? "\(post.likesCount)" : "",
                        color: post.isLiked ? Theme.danger : .white,
                        action: onLike
                    )

                    // Comment
                    reelButton(
                        icon: "bubble.right.fill",
                        label: post.commentsCount > 0 ? "\(post.commentsCount)" : "",
                        color: .white,
                        action: onComment
                    )

                    // Repost
                    reelButton(
                        icon: "arrow.2.squarepath",
                        label: post.repostsCount > 0 ? "\(post.repostsCount)" : "",
                        color: .white,
                        action: onRepost
                    )

                    // Mute toggle
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        playerVM.toggleMute()
                    } label: {
                        Image(systemName: playerVM.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                            .font(.system(size: 22))
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                    }

                    Spacer().frame(height: 20)
                }
                .padding(.trailing, 16)
            }

            // Bottom info overlay
            VStack(alignment: .leading, spacing: 6) {
                Spacer()
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 8) {
                            AvatarView(name: post.authorName, color: post.authorAvatarColor, size: 32)
                            Text(post.authorName)
                                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                                .foregroundColor(.white)
                        }
                        if !post.caption.isEmpty {
                            Text(post.caption)
                                .font(.system(.subheadline, design: .rounded))
                                .foregroundColor(.white.opacity(0.9))
                                .lineLimit(3)
                        }
                    }
                    .padding(.leading, 16)
                    .padding(.bottom, 40)
                    Spacer().frame(width: 80)
                }
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
        .onTapGesture(count: 1) {
            playerVM.togglePlayPause()
        }
        .onAppear {
            if let url = URL(string: post.fullFileUrl) {
                playerVM.load(url: url)
            }
            if isActive { playerVM.play() }
        }
        .onDisappear {
            playerVM.pause()
        }
        .onChange(of: isActive) { active in
            if active { playerVM.play() } else { playerVM.pause() }
        }
    }

    private func reelButton(icon: String, label: String, color: Color, action: @escaping () -> Void) -> some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            action()
        } label: {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 28))
                    .foregroundColor(color)
                    .shadow(color: .black.opacity(0.4), radius: 4)
                if !label.isEmpty {
                    Text(label)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.4), radius: 4)
                }
            }
            .frame(width: 44)
        }
    }
}

// MARK: - Player ViewModel

@MainActor
private final class ReelPlayerViewModel: ObservableObject {
    @Published var player: AVPlayer?
    @Published var isMuted = false
    @Published var isPlaying = false

    private var loopObserver: Any?
    private var currentURL: URL?

    func load(url: URL) {
        guard url != currentURL else { return }
        currentURL = url
        let item = AVPlayerItem(url: url)
        let p = AVPlayer(playerItem: item)
        p.isMuted = isMuted
        p.actionAtItemEnd = .none

        loopObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak p] _ in
            p?.seek(to: .zero)
            p?.play()
        }

        player = p

        // Configure audio session to allow background audio
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
    }

    func play() {
        player?.play()
        isPlaying = true
    }

    func pause() {
        player?.pause()
        isPlaying = false
    }

    func togglePlayPause() {
        if isPlaying { pause() } else { play() }
    }

    func toggleMute() {
        isMuted.toggle()
        player?.isMuted = isMuted
    }

    deinit {
        if let obs = loopObserver {
            NotificationCenter.default.removeObserver(obs)
        }
    }
}

// MARK: - AVPlayer UIViewRepresentable

private struct ReelAVPlayerView: UIViewRepresentable {
    let player: AVPlayer

    func makeUIView(context: Context) -> PlayerUIView {
        let view = PlayerUIView()
        view.playerLayer.player = player
        view.playerLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: PlayerUIView, context: Context) {
        uiView.playerLayer.player = player
    }

    final class PlayerUIView: UIView {
        override class var layerClass: AnyClass { AVPlayerLayer.self }
        var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }

        override func layoutSubviews() {
            super.layoutSubviews()
            playerLayer.frame = bounds
        }
    }
}
