import SwiftUI
import PhotosUI

struct StoryUploadView: View {
    let onClose: () -> Void
    let onPublished: () -> Void

    @State private var selectedItem: PhotosPickerItem?
    @State private var imageData: Data?
    @State private var textOverlay = ""
    @State private var isUploading = false
    @State private var showPicker = true
    @State private var errorMessage: String?

    private let bgColors = ["", "#FF6B6B", "#4ECDC4", "#45B7D1", "#96CEB4", "#FFEAA7", "#DDA0DD", "#FF8C42"]
    @State private var selectedBgColor = ""

    var body: some View {
        ZStack {
            Theme.bgPrimary.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                HStack {
                    Button(action: onClose) {
                        Image(systemName: "xmark")
                            .font(.title3)
                            .foregroundColor(Theme.textPrimary)
                    }
                    Spacer()
                    Text("Новая история")
                        .font(.system(.headline, design: .rounded))
                        .foregroundColor(Theme.textPrimary)
                    Spacer()
                    if imageData != nil {
                        Button("Опубликовать") { publish() }
                            .font(.system(.subheadline, design: .rounded).weight(.semibold))
                            .foregroundStyle(Theme.gradientAccent)
                            .disabled(isUploading)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)

                if let data = imageData, let uiImage = UIImage(data: data) {
                    ZStack {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 400)
                            .cornerRadius(16)

                        if !textOverlay.isEmpty {
                            Text(textOverlay)
                                .font(.system(.title2, design: .rounded).weight(.bold))
                                .foregroundColor(.white)
                                .shadow(radius: 4)
                        }
                    }
                    .padding()

                    TextField("Добавить текст...", text: $textOverlay)
                        .foregroundColor(Theme.textPrimary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color.white.opacity(0.05))
                        .cornerRadius(Theme.radiusSm)
                        .overlay(RoundedRectangle(cornerRadius: Theme.radiusSm).stroke(Theme.border, lineWidth: 1))
                        .padding(.horizontal, 16)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(bgColors, id: \.self) { color in
                                Circle()
                                    .fill(color.isEmpty ? Color.white.opacity(0.06) : Color(hex: color))
                                    .frame(width: 32, height: 32)
                                    .overlay(
                                        Circle().stroke(selectedBgColor == color ? Theme.accent : Color.clear, lineWidth: 2)
                                    )
                                    .onTapGesture { selectedBgColor = color }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }

                    if isUploading {
                        ProgressView("Загрузка...")
                            .tint(Theme.accent)
                            .foregroundColor(Theme.textSecondary)
                            .padding()
                    }

                    if let error = errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(Theme.danger)
                            .padding(.horizontal, 16)
                    }

                    Spacer()
                } else {
                    Spacer()

                    PhotosPicker(selection: $selectedItem, matching: .any(of: [.images, .videos])) {
                        VStack(spacing: 16) {
                            Image(systemName: "photo.on.rectangle.angled")
                                .font(.system(size: 48))
                                .foregroundStyle(Theme.gradientAccent)
                            Text("Выберите фото или видео")
                                .font(.system(.subheadline, design: .rounded))
                                .foregroundColor(Theme.textSecondary)
                        }
                    }
                    .onChange(of: selectedItem) { newItem in
                        Task {
                            if let data = try? await newItem?.loadTransferable(type: Data.self) {
                                imageData = data
                            }
                        }
                    }

                    Spacer()
                }
            }
        }
    }

    private func publish() {
        guard let data = imageData else { return }
        isUploading = true
        errorMessage = nil
        Task {
            do {
                let fileUrl = try await MediaService.uploadData(data, filename: "story_\(UUID().uuidString).jpg", mimeType: "image/jpeg")
                _ = try await APIService.shared.createStory(
                    type: "image",
                    fileUrl: fileUrl,
                    textOverlay: textOverlay,
                    bgColor: selectedBgColor
                )
                onPublished()
                onClose()
            } catch {
                errorMessage = "Не удалось загрузить историю"
            }
            isUploading = false
        }
    }
}
