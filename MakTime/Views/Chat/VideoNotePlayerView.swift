import SwiftUI
import AVFoundation
import AVKit

struct VideoNotePlayerView: View {
    let url: URL
    let duration: TimeInterval?

    @State private var player: AVPlayer?
    @State private var isPlaying = false
    @State private var playProgress: CGFloat = 0
    @State private var progressTimer: Timer?
    @State private var playerLooped = false

    private let size: CGFloat = 124

    var body: some View {
        ZStack {
            // Video layer
            if let player = player {
                VideoPlayerCircle(player: player)
                    .frame(width: size, height: size)
                    .clipShape(Circle())
            } else {
                Circle()
                    .fill(Theme.bgTertiary)
                    .frame(width: size, height: size)
            }

            // Play/pause overlay
            if !isPlaying {
                Circle()
                    .fill(.black.opacity(0.35))
                    .frame(width: size, height: size)
                Image(systemName: "play.fill")
                    .font(.system(size: 28))
                    .foregroundColor(.white)
                    .shadow(radius: 4)
            }

            // Progress arc
            if isPlaying {
                Circle()
                    .trim(from: 0, to: playProgress)
                    .stroke(
                        LinearGradient(
                            colors: [Theme.accent, Theme.accentSecondary],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 3, lineCap: .round)
                    )
                    .frame(width: size + 6, height: size + 6)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 0.1), value: playProgress)
            }

            // Duration label (bottom)
            if let dur = duration, !isPlaying {
                VStack {
                    Spacer()
                    Text(formatDuration(dur))
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.black.opacity(0.55))
                        .clipShape(Capsule())
                        .padding(.bottom, 10)
                }
                .frame(width: size, height: size)
            }
        }
        .frame(width: size + 8, height: size + 8)
        .onAppear { setupPlayer() }
        .onDisappear { teardown() }
        .onTapGesture { togglePlay() }
    }

    private func setupPlayer() {
        let p = AVPlayer(url: url)
        p.actionAtItemEnd = .none
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: p.currentItem,
            queue: .main
        ) { _ in
            p.seek(to: .zero)
            isPlaying = false
            playProgress = 0
            progressTimer?.invalidate()
        }
        player = p
    }

    private func togglePlay() {
        guard let player else { return }
        if isPlaying {
            player.pause()
            progressTimer?.invalidate()
            isPlaying = false
        } else {
            player.play()
            isPlaying = true
            startProgressTimer()
        }
    }

    private func startProgressTimer() {
        progressTimer?.invalidate()
        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            Task { @MainActor in
                guard let player, let item = player.currentItem else { return }
                let total = item.duration.seconds
                let current = player.currentTime().seconds
                guard total > 0, !total.isNaN else { return }
                playProgress = CGFloat(current / total)
            }
        }
    }

    private func teardown() {
        player?.pause()
        progressTimer?.invalidate()
        NotificationCenter.default.removeObserver(self)
    }

    private func formatDuration(_ t: TimeInterval) -> String {
        let s = Int(t)
        return String(format: "%d:%02d", s / 60, s % 60)
    }
}

// MARK: - UIKit AVPlayer in circle (no controls)
struct VideoPlayerCircle: UIViewRepresentable {
    let player: AVPlayer

    func makeUIView(context: Context) -> UIView {
        let view = PlayerView()
        view.playerLayer.player = player
        view.playerLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {}

    final class PlayerView: UIView {
        override class var layerClass: AnyClass { AVPlayerLayer.self }
        var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
    }
}
