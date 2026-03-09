import SwiftUI
import AVFoundation

struct VoiceMessagePlayerView: View {
    let url: URL?
    let duration: TimeInterval?
    let isMine: Bool

    @State private var player: AVAudioPlayer?
    @State private var isPlaying = false
    @State private var playProgress: CGFloat = 0
    @State private var progressTimer: Timer?
    @State private var loadError: String?

    var body: some View {
        Button {
            togglePlay()
        } label: {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(isMine ? Color.white.opacity(0.25) : Theme.accentLight.opacity(0.5))
                        .frame(width: 40, height: 40)
                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(isMine ? AnyShapeStyle(Color.white) : AnyShapeStyle(Theme.gradientAccent))
                }

                VStack(alignment: .leading, spacing: 2) {
                    if let dur = duration {
                        Text(formatDuration(isPlaying ? (Double(playProgress) * dur) : dur))
                            .font(.system(.caption, design: .rounded).weight(.medium))
                            .foregroundColor(isMine ? .white : Theme.textPrimary)
                    }
                    Text("Голосовое сообщение")
                        .font(.system(size: 10, design: .rounded))
                        .foregroundColor(isMine ? .white.opacity(0.65) : Theme.textMuted)
                }

                if loadError != nil {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(isMine ? AnyShapeStyle(Theme.gradientSent) : AnyShapeStyle(Theme.bgHover))
            .clipShape(RoundedRectangle(cornerRadius: Theme.radiusLg))
            .overlay(RoundedRectangle(cornerRadius: Theme.radiusLg).stroke(Theme.glassBorder))
        }
        .buttonStyle(.plain)
        .disabled(url == nil || loadError != nil)
        .task(id: url?.absoluteString) { await setupPlayer() }
        .onDisappear { teardown() }
    }

    private func setupPlayer() async {
        guard let url else { return }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let p = try AVAudioPlayer(data: data)
            p.prepareToPlay()
            await MainActor.run { player = p }
        } catch {
            await MainActor.run { loadError = error.localizedDescription }
        }
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
        guard let p = player else { return }
        let total = p.duration
        guard total > 0 else { return }
        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
            Task { @MainActor in
                let current = p.currentTime
                playProgress = CGFloat(current / total)
                if !p.isPlaying {
                    isPlaying = false
                    playProgress = 0
                    progressTimer?.invalidate()
                }
            }
        }
    }

    private func teardown() {
        player?.stop()
        progressTimer?.invalidate()
    }

    private func formatDuration(_ t: TimeInterval) -> String {
        let s = Int(t)
        return String(format: "%d:%02d", s / 60, s % 60)
    }
}
