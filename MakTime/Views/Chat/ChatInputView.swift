import SwiftUI
import PhotosUI

struct ChatInputView: View {
    @ObservedObject var vm: ChatViewModel
    var inputFocused: FocusState<Bool>.Binding
    @State private var showPhotoPicker = false
    @State private var showVideoNote = false

    var body: some View {
        VStack(spacing: 0) {
            // Reply preview
            if let reply = vm.replyTo {
                HStack(spacing: 10) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Theme.gradientAccent)
                        .frame(width: 3)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Ответ")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(Theme.gradientAccent)
                        Text(reply.text.isEmpty ? "Медиа" : reply.text)
                            .font(.caption)
                            .foregroundColor(Theme.textSecondary)
                            .lineLimit(1)
                    }
                    Spacer()
                    Button { vm.replyTo = nil } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundColor(Theme.textMuted)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial)
            }

            // Input row
            HStack(spacing: 10) {
                // Attachment
                Button { showPhotoPicker = true } label: {
                    Image(systemName: "photo.on.rectangle")
                        .font(.system(size: 20))
                        .foregroundStyle(Theme.gradientAccent)
                        .frame(width: 38, height: 38)
                        .background(Theme.bgTertiary)
                        .clipShape(Circle())
                }

                // Text field
                TextField("Сообщение...", text: $vm.messageText, axis: .vertical)
                    .foregroundColor(Theme.textPrimary)
                    .tint(Theme.accent)
                    .focused(inputFocused)
                    .lineLimit(1...5)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .background(Theme.bgTertiary)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.radiusLg))
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.radiusLg)
                            .stroke(Theme.glassBorder, lineWidth: 1)
                    )
                    .submitLabel(.send)
                    .onSubmit {
                        let trimmed = vm.messageText.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !trimmed.isEmpty {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            vm.messageText = ""
                            vm.sendTextMessageWith(trimmed)
                        }
                    }
                    .onChange(of: vm.messageText) { newValue in
                        if newValue.hasSuffix("\n") {
                            let trimmed = String(newValue.dropLast()).trimmingCharacters(in: .whitespacesAndNewlines)
                            if !trimmed.isEmpty {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                vm.messageText = ""
                                vm.sendTextMessageWith(trimmed)
                            } else {
                                vm.messageText = ""
                            }
                        } else {
                            vm.handleTyping()
                        }
                    }

                // Right button: send / mic / video note
                trailingButton
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial)
            .background(Theme.bgSecondary.opacity(0.8))
        }
        .photosPicker(
            isPresented: $showPhotoPicker,
            selection: $vm.selectedPhotoItem,
            matching: .any(of: [.images, .videos])
        )
        .onChange(of: vm.selectedPhotoItem) { _ in
            Task { await vm.handleSelectedPhoto() }
        }
        .fullScreenCover(isPresented: $showVideoNote) {
            VideoNoteRecorderView { url, duration in
                showVideoNote = false
                Task { await vm.sendVideoNote(url: url, duration: duration) }
            } onCancel: {
                showVideoNote = false
            }
        }
    }

    @ViewBuilder
    private var trailingButton: some View {
        let hasText = !vm.messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

        if hasText {
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                vm.sendTextMessage()
            } label: {
                Image(systemName: "arrow.up")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 38, height: 38)
                    .background(Theme.gradientAccent)
                    .clipShape(Circle())
                    .neonGlow(Theme.accent, radius: 6)
            }
        } else if vm.isRecording {
            Button {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                vm.stopVoiceRecording()
            } label: {
                Image(systemName: "stop.circle.fill")
                    .font(.system(size: 30))
                    .foregroundColor(Theme.danger)
            }
            .transition(.scale.combined(with: .opacity))
        } else {
            HStack(spacing: 6) {
                // Mic button — long press for voice, quick tap = start/stop
                Button {
                    Task {
                        let granted = await MediaService.requestMicrophonePermission()
                        if granted {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            vm.startVoiceRecording()
                        }
                    }
                } label: {
                    Image(systemName: "mic.fill")
                        .font(.system(size: 18))
                        .foregroundColor(Theme.textSecondary)
                        .frame(width: 38, height: 38)
                        .background(Theme.bgTertiary)
                        .clipShape(Circle())
                }

                // Video note button
                Button {
                    Task {
                        let mic = await MediaService.requestMicrophonePermission()
                        let cam = await MediaService.requestCameraPermission()
                        if mic && cam {
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            showVideoNote = true
                        }
                    }
                } label: {
                    Image(systemName: "video.circle.fill")
                        .font(.system(size: 30))
                        .foregroundStyle(Theme.gradientAccent)
                }
            }
        }
    }
}
