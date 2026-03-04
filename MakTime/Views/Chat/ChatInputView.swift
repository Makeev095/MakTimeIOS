import SwiftUI
import PhotosUI

struct ChatInputView: View {
    @ObservedObject var vm: ChatViewModel
    @State private var showPhotoPicker = false
    
    var body: some View {
        VStack(spacing: 0) {
            if let reply = vm.replyTo {
                HStack {
                    Rectangle().fill(Theme.accent).frame(width: 3)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Ответ")
                            .font(.caption2.weight(.medium))
                            .foregroundColor(Theme.accent)
                        Text(reply.text.isEmpty ? "Медиа" : reply.text)
                            .font(.caption)
                            .foregroundColor(Theme.textSecondary)
                            .lineLimit(1)
                    }
                    Spacer()
                    Button { vm.replyTo = nil } label: {
                        Image(systemName: "xmark")
                            .font(.caption)
                            .foregroundColor(Theme.textMuted)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Theme.bgTertiary)
            }
            
            Divider().background(Theme.border)
            
            HStack(spacing: 8) {
                Button { showPhotoPicker = true } label: {
                    Image(systemName: "paperclip")
                        .font(.title3)
                        .foregroundColor(Theme.textSecondary)
                }
                
                TextField("Сообщение...", text: $vm.messageText, axis: .vertical)
                    .foregroundColor(Theme.textPrimary)
                    .lineLimit(1...5)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Theme.bgTertiary)
                    .cornerRadius(20)
                    .onChange(of: vm.messageText) { _ in
                        vm.handleTyping()
                    }
                
                if vm.messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Button {
                        if vm.isRecording {
                            vm.stopVoiceRecording()
                        } else {
                            Task {
                                let granted = await MediaService.requestMicrophonePermission()
                                if granted { vm.startVoiceRecording() }
                            }
                        }
                    } label: {
                        Image(systemName: vm.isRecording ? "stop.circle.fill" : "mic.fill")
                            .font(.title3)
                            .foregroundColor(vm.isRecording ? Theme.danger : Theme.accent)
                    }
                } else {
                    Button { vm.sendTextMessage() } label: {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.title2)
                            .foregroundColor(Theme.accent)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Theme.bgSecondary)
        }
        .photosPicker(isPresented: $showPhotoPicker, selection: $vm.selectedPhotoItem, matching: .any(of: [.images, .videos]))
        .onChange(of: vm.selectedPhotoItem) { _ in
            Task { await vm.handleSelectedPhoto() }
        }
    }
}
