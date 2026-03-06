import SwiftUI
import PhotosUI

struct CreatePostView: View {
    @ObservedObject var vm: FeedViewModel
    let onClose: () -> Void

    @State private var selectedItem: PhotosPickerItem?
    @State private var selectedImageData: Data?
    @State private var previewImage: UIImage?
    @State private var caption = ""
    @State private var isPublishing = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 16) {
                        // Media picker
                        if let image = previewImage {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                                .frame(maxWidth: .infinity)
                                .frame(height: 300)
                                .clipped()
                                .cornerRadius(12)
                                .padding(.horizontal, 16)
                                .overlay(alignment: .topTrailing) {
                                    Button {
                                        previewImage = nil
                                        selectedImageData = nil
                                        selectedItem = nil
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.title2)
                                            .foregroundColor(.white)
                                            .shadow(radius: 4)
                                    }
                                    .padding(24)
                                }
                        } else {
                            PhotosPicker(selection: $selectedItem, matching: .images) {
                                VStack(spacing: 12) {
                                    Image(systemName: "photo.badge.plus")
                                        .font(.system(size: 44))
                                        .foregroundColor(Theme.accent)
                                    Text("Выбрать фото")
                                        .font(.subheadline)
                                        .foregroundColor(Theme.textSecondary)
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 200)
                                .background(Theme.bgTertiary)
                                .cornerRadius(12)
                            }
                            .padding(.horizontal, 16)
                        }

                        // Caption
                        TextField("Описание...", text: $caption, axis: .vertical)
                            .foregroundColor(Theme.textPrimary)
                            .lineLimit(1...8)
                            .padding(12)
                            .background(Theme.bgTertiary)
                            .cornerRadius(12)
                            .padding(.horizontal, 16)
                    }
                    .padding(.top, 16)
                }

                // Publish button
                Button {
                    publish()
                } label: {
                    if isPublishing {
                        ProgressView().tint(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    } else {
                        Text("Опубликовать")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                }
                .background(selectedImageData != nil ? Theme.accent : Theme.textMuted)
                .cornerRadius(14)
                .padding(16)
                .disabled(selectedImageData == nil || isPublishing)
            }
            .background(Theme.bgPrimary)
            .navigationTitle("Новый пост")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Отмена") { onClose() }
                        .foregroundColor(Theme.accent)
                }
            }
            .onChange(of: selectedItem) { _ in
                Task {
                    if let data = try? await selectedItem?.loadTransferable(type: Data.self) {
                        selectedImageData = data
                        previewImage = UIImage(data: data)
                    }
                }
            }
        }
    }

    private func publish() {
        guard let data = selectedImageData else { return }
        isPublishing = true
        Task {
            let success = await vm.publishPost(photoData: data, caption: caption)
            isPublishing = false
            if success {
                onClose()
            }
        }
    }
}
