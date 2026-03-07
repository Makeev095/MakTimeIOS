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
        HStack {
            if isMine { Spacer(minLength: 60) }

            VStack(alignment: isMine ? .trailing : .leading, spacing: 4) {
                if let reply = replyMessage {
                    HStack(spacing: 4) {
                        Rectangle()
                            .fill(Theme.accent)
                            .frame(width: 3)
                        Text(reply.text.isEmpty ? "Медиа" : reply.text)
                            .font(.caption2)
                            .foregroundColor(Theme.textSecondary)
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(6)
                }

                Group {
                    switch message.type {
                    case .image:
                        imageContent
                    case .video:
                        videoContent
                    case .voice:
                        voiceContent
                    case .file:
                        fileContent
                    case .text:
                        textContent
                    }
                }

                HStack(spacing: 4) {
                    Text(message.dateFormatted)
                        .font(.system(size: 10))
                        .foregroundColor(isMine ? .white.opacity(0.6) : Theme.textMuted)

                    if isMine {
                        Image(systemName: message.read ? "checkmark.circle.fill" : "checkmark.circle")
                            .font(.system(size: 10))
                            .foregroundColor(message.read ? Theme.success : .white.opacity(0.4))
                    }
                }
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

            if !isMine { Spacer(minLength: 60) }
        }
    }

    private var textContent: some View {
        Text(message.text)
            .font(.system(.subheadline, design: .rounded))
            .foregroundColor(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                isMine
                ? AnyShapeStyle(Theme.gradientAccent)
                : AnyShapeStyle(Color.white.opacity(0.08))
            )
            .cornerRadius(Theme.radius)
    }

    private var imageContent: some View {
        AsyncImage(url: URL(string: message.fullFileUrl ?? "")) { phase in
            switch phase {
            case .success(let image):
                image.resizable().scaledToFit()
                    .frame(maxWidth: 240, maxHeight: 300)
                    .cornerRadius(Theme.radius)
            case .failure:
                imagePlaceholder("photo")
            default:
                ProgressView().frame(width: 200, height: 150)
            }
        }
    }

    private var videoContent: some View {
        VStack {
            if let url = URL(string: message.fullFileUrl ?? "") {
                VideoPlayer(player: AVPlayer(url: url))
                    .frame(width: 240, height: 180)
                    .cornerRadius(Theme.radius)
            }
        }
    }

    private var voiceContent: some View {
        HStack(spacing: 10) {
            Image(systemName: "waveform")
                .foregroundStyle(isMine ? AnyShapeStyle(.white) : AnyShapeStyle(Theme.gradientAccent))
            if let dur = message.duration {
                Text(String(format: "%d:%02d", Int(dur) / 60, Int(dur) % 60))
                    .font(.caption)
                    .foregroundColor(isMine ? .white.opacity(0.8) : Theme.textSecondary)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            isMine
            ? AnyShapeStyle(Theme.gradientAccent)
            : AnyShapeStyle(Color.white.opacity(0.08))
        )
        .cornerRadius(Theme.radius)
    }

    private var fileContent: some View {
        HStack(spacing: 10) {
            Image(systemName: "doc.fill")
                .foregroundStyle(isMine ? AnyShapeStyle(.white) : AnyShapeStyle(Theme.gradientAccent))
            Text(message.fileName ?? "Файл")
                .font(.caption)
                .foregroundColor(.white)
                .lineLimit(1)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            isMine
            ? AnyShapeStyle(Theme.gradientAccent)
            : AnyShapeStyle(Color.white.opacity(0.08))
        )
        .cornerRadius(Theme.radius)
    }

    private func imagePlaceholder(_ icon: String) -> some View {
        Image(systemName: icon)
            .font(.largeTitle)
            .foregroundColor(Theme.textMuted)
            .frame(width: 200, height: 150)
            .glassCard()
    }
}
