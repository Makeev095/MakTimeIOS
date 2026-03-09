import SwiftUI
import PhotosUI

struct ChatInputView: View {
    @ObservedObject var vm: ChatViewModel
    var inputFocused: FocusState<Bool>.Binding
    @State private var showPhotoPicker = false
    @State private var showVideoNote = false
    @State private var isHoldingMic = false
    @State private var micPermissionGranted = false

    var body: some View {
        VStack(spacing: 0) {
            // Recording indicator
            if vm.isRecording {
                HStack(spacing: 8) {
                    Circle()
                        .fill(Theme.danger)
                        .frame(width: 8, height: 8)
                    Text("Запись...")
                        .font(.system(.caption, design: .rounded).weight(.medium))
                        .foregroundColor(Theme.danger)
                    Text(formatDuration(vm.recordingDuration))
                        .font(.system(.caption, design: .monospaced).weight(.medium))
                        .foregroundColor(Theme.textSecondary)
                    Spacer()
                    Text("Отпустите для отправки")
                        .font(.system(size: 11, design: .rounded))
                        .foregroundColor(Theme.textMuted)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Theme.bgSecondary)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

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
                    .submitLabel(.return)
                    .onChange(of: vm.messageText) { _ in
                        vm.handleTyping()
                    }

                // Right button: send / recording / mic+video
                trailingButton
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial)
            .background(Theme.bgSecondary.opacity(0.8))
        }
        .animation(.easeInOut(duration: 0.2), value: vm.isRecording)
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
        .task {
            micPermissionGranted = await MediaService.requestMicrophonePermission()
        }
    }

    @ViewBuilder
    private var trailingButton: some View {
        let hasText = !vm.messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

        if hasText {
            // Send text button
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
        } else {
            HStack(spacing: 6) {
                // Hold-to-record voice message
                Image(systemName: "mic.fill")
                    .font(.system(size: 18))
                    .foregroundColor(vm.isRecording ? Theme.danger : Theme.textSecondary)
                    .frame(width: 38, height: 38)
                    .background(vm.isRecording ? Theme.danger.opacity(0.15) : Theme.bgTertiary)
                    .clipShape(Circle())
                    .scaleEffect(vm.isRecording ? 1.15 : 1.0)
                    .animation(.spring(response: 0.3), value: vm.isRecording)
                    .gesture(
                        LongPressGesture(minimumDuration: 0.15)
                            .onEnded { _ in
                                guard micPermissionGranted else {
                                    Task { micPermissionGranted = await MediaService.requestMicrophonePermission() }
                                    return
                                }
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                vm.startVoiceRecording()
                            }
                            .sequenced(before: DragGesture(minimumDistance: 0))
                            .onEnded { _ in
                                if vm.isRecording {
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    vm.stopVoiceRecording()
                                }
                            }
                    )

                // Video note: hold to open recorder
                if !vm.isRecording {
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

    private func formatDuration(_ t: TimeInterval) -> String {
        let s = Int(t)
        return String(format: "%d:%02d", s / 60, s % 60)
    }
}
