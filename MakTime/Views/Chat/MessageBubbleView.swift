import SwiftUI
import AVKit

struct MessageBubbleView: View {
    let message: Message
    let isMine: Bool
    let replyMessage: Message?
    let onReply: () -> Void
    let onDelete: () -> Void

    @State private var showActions = false

    var body: some View {
        HStack(alignment: .bottom, spacing: 6) {
            if isMine { Spacer(minLength: 52) }

            VStack(alignment: isMine ? .trailing : .leading, spacing: 4) {
                // Reply preview
                if let reply = replyMessage {
                    replyPreview(reply)
                }

                // Message content
                messageContent

                // Time + read receipt
                HStack(spacing: 4) {
                    Text(message.dateFormatted)
                        .font(.system(size: 10, design: .rounded))
                        .foregroundColor(isMine ? .white.opacity(0.55) : Theme.textMuted)
                    if isMine {
                        Image(systemName: message.read ? "checkmark.circle.fill" : "checkmark.circle")
                            .font(.system(size: 10))
                            .foregroundColor(message.read ? Theme.success : .white.opacity(0.4))
                    }
                }
                .padding(message.type == .videoNote ? 0 : 0)
            }
            .onTapGesture(count: 2) {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                onReply()
            }
            .onLongPressGesture {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                showActions = true
            }
            .confirmationDialog("Действия", isPresented: $showActions) {
                Button("Ответить") { onReply() }
                if isMine {
                    Button("Удалить", role: .destructive) { onDelete() }
                }
                Button("Отмена", role: .cancel) {}
            }

            if !isMine { Spacer(minLength: 52) }
        }
    }

    // MARK: - Reply preview
    private func replyPreview(_ reply: Message) -> some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 2)
                .fill(Theme.gradientAccent)
                .frame(width: 3)
            Text(reply.text.isEmpty ? "Медиа" : reply.text)
                .font(.caption2)
                .foregroundColor(Theme.textSecondary)
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Theme.bgTertiary.opacity(0.8))
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusSm))
        .overlay(RoundedRectangle(cornerRadius: Theme.radiusSm).stroke(Theme.glassBorder))
    }

    // MARK: - Content switcher
    @ViewBuilder
    private var messageContent: some View {
        switch message.type {
        case .text:    textContent
        case .image:   imageContent
        case .video:   videoContent
        case .voice:   voiceContent
        case .videoNote: videoNoteContent
        case .file:    fileContent
        }
    }

    // MARK: - Text bubble
    private var textContent: some View {
        Text(message.text)
            .font(.system(.subheadline, design: .rounded))
            .foregroundColor(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                Group {
                    if isMine {
                        AnyShapeStyle(Theme.gradientSent)
                    } else {
                        AnyShapeStyle(Theme.bgHover)
                    }
                }
            )
            .clipShape(
                RoundedRectangle(cornerRadius: Theme.radiusLg)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.radiusLg)
                    .stroke(isMine ? Color.clear : Theme.glassBorder, lineWidth: 1)
            )
            .shadow(
                color: isMine ? Theme.accent.opacity(0.25) : Color.clear,
                radius: 6, x: 0, y: 3
            )
    }

    // MARK: - Image
    private var imageContent: some View {
        Group {
            if let url = URL(string: message.fullFileUrl ?? "") {
                CachedImage(url: url) { img in
                    img.resizable()
                        .scaledToFill()
                        .frame(maxWidth: 240, maxHeight: 300)
                        .clipped()
                } placeholder: {
                    ShimmerBox(cornerRadius: Theme.radiusLg)
                        .frame(width: 200, height: 180)
                }
            } else {
                imagePlaceholder("photo")
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusLg))
        .overlay(RoundedRectangle(cornerRadius: Theme.radiusLg).stroke(Theme.glassBorder))
    }

    // MARK: - Video
    private var videoContent: some View {
        Group {
            if let url = URL(string: message.fullFileUrl ?? "") {
                VideoPlayer(player: AVPlayer(url: url))
                    .frame(width: 240, height: 180)
            } else {
                imagePlaceholder("video")
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusLg))
    }

    // MARK: - Voice
    private var voiceContent: some View {
        HStack(spacing: 10) {
            Image(systemName: "waveform")
                .font(.title3)
                .foregroundStyle(isMine ? AnyShapeStyle(Color.white) : AnyShapeStyle(Theme.gradientAccent))
            VStack(alignment: .leading, spacing: 2) {
                if let dur = message.duration {
                    Text(formatDuration(dur))
                        .font(.system(.caption, design: .rounded).weight(.medium))
                        .foregroundColor(isMine ? .white : Theme.textPrimary)
                }
                Text("Голосовое сообщение")
                    .font(.system(size: 10, design: .rounded))
                    .foregroundColor(isMine ? .white.opacity(0.65) : Theme.textMuted)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(isMine ? AnyShapeStyle(Theme.gradientSent) : AnyShapeStyle(Theme.bgHover))
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusLg))
        .overlay(RoundedRectangle(cornerRadius: Theme.radiusLg).stroke(Theme.glassBorder))
    }

    // MARK: - Video Note (circle)
    private var videoNoteContent: some View {
        Group {
            if let url = URL(string: message.fullFileUrl ?? "") {
                VideoNotePlayerView(url: url, duration: message.duration)
            } else {
                Circle()
                    .fill(Theme.bgTertiary)
                    .frame(width: 120, height: 120)
                    .overlay(
                        Image(systemName: "video.circle").font(.largeTitle).foregroundColor(Theme.textMuted)
                    )
            }
        }
        .shadow(color: isMine ? Theme.accent.opacity(0.3) : .clear, radius: 8)
    }

    // MARK: - File
    private var fileContent: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(isMine ? Color.white.opacity(0.2) : Theme.accentLight)
                    .frame(width: 38, height: 38)
                Image(systemName: "doc.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(isMine ? AnyShapeStyle(Color.white) : AnyShapeStyle(Theme.gradientAccent))
            }
            Text(message.fileName ?? "Файл")
                .font(.system(.caption, design: .rounded))
                .foregroundColor(isMine ? .white : Theme.textPrimary)
                .lineLimit(1)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(isMine ? AnyShapeStyle(Theme.gradientSent) : AnyShapeStyle(Theme.bgHover))
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusLg))
        .overlay(RoundedRectangle(cornerRadius: Theme.radiusLg).stroke(Theme.glassBorder))
    }

    // MARK: - Helpers
    private func imagePlaceholder(_ icon: String) -> some View {
        ZStack {
            ShimmerBox(cornerRadius: Theme.radiusLg)
            Image(systemName: icon)
                .font(.largeTitle).foregroundColor(Theme.textMuted)
        }
        .frame(width: 200, height: 150)
    }

    private func formatDuration(_ dur: TimeInterval) -> String {
        String(format: "%d:%02d", Int(dur) / 60, Int(dur) % 60)
    }
}
