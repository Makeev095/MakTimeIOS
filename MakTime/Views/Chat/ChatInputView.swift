import SwiftUI
import PhotosUI

struct CameraPickerView: UIViewControllerRepresentable {
    let onCapture: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraPickerView
        init(_ parent: CameraPickerView) { self.parent = parent }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.onCapture(image)
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

struct ChatInputView: View {
    @ObservedObject var vm: ChatViewModel
    var inputFocused: FocusState<Bool>.Binding
    @State private var showPhotoPicker = false
    @State private var showCamera = false
    @State private var showAttachMenu = false

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
                .background(.ultraThinMaterial)
            }

            Divider().background(Theme.border)

            HStack(spacing: 8) {
                Menu {
                    Button {
                        Task {
                            let granted = await MediaService.requestCameraPermission()
                            if granted { showCamera = true }
                        }
                    } label: {
                        Label("Камера", systemImage: "camera")
                    }
                    Button {
                        showPhotoPicker = true
                    } label: {
                        Label("Галерея", systemImage: "photo.on.rectangle")
                    }
                } label: {
                    Image(systemName: "paperclip")
                        .font(.title3)
                        .foregroundStyle(Theme.gradientAccent)
                }

                TextField("Сообщение...", text: $vm.messageText, axis: .vertical)
                    .foregroundColor(Theme.textPrimary)
                    .focused(inputFocused)
                    .lineLimit(1...5)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(20)
                    .overlay(RoundedRectangle(cornerRadius: 20).stroke(Theme.border, lineWidth: 1))
                    .onChange(of: vm.messageText) { _ in
                        vm.handleTyping()
                    }
                    .submitLabel(.send)
                    .onSubmit {
                        if !vm.messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            vm.sendTextMessage()
                        }
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
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        vm.sendTextMessage()
                    } label: {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.title2)
                            .foregroundStyle(Theme.gradientAccent)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial)
        }
        .photosPicker(isPresented: $showPhotoPicker, selection: $vm.selectedPhotoItem, matching: .any(of: [.images, .videos]))
        .onChange(of: vm.selectedPhotoItem) { _ in
            Task { await vm.handleSelectedPhoto() }
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraPickerView { image in
                Task { await vm.sendCameraPhoto(image: image) }
            }
            .ignoresSafeArea()
        }
    }
}
