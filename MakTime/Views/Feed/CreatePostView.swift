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
    @State private var errorMessage: String?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 16) {
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
                                        .font(.system(.subheadline, design: .rounded))
                                        .foregroundColor(Theme.textSecondary)
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 200)
                                .background(.ultraThinMaterial)
                                .cornerRadius(12)
                                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.border, lineWidth: 1))
                            }
                            .padding(.horizontal, 16)
                        }

                        TextField("Описание...", text: $caption, axis: .vertical)
                            .foregroundColor(Theme.textPrimary)
                            .lineLimit(1...8)
                            .padding(12)
                            .background(.ultraThinMaterial)
                            .cornerRadius(12)
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.border, lineWidth: 1))
                            .padding(.horizontal, 16)

                        if let error = errorMessage {
                            Text(error)
                                .font(.caption)
                                .foregroundColor(Theme.danger)
                                .padding(.horizontal, 16)
                        }
                    }
                    .padding(.top, 16)
                }

                Button {
                    publish()
                } label: {
                    if isPublishing {
                        ProgressView().tint(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    } else {
                        Text("Опубликовать")
                            .font(.system(.headline, design: .rounded))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                }
                .background(
                    selectedImageData != nil
                    ? LinearGradient(colors: [Theme.accent, Theme.accentSecondary], startPoint: .leading, endPoint: .trailing)
                    : LinearGradient(colors: [Theme.textMuted, Theme.textMuted], startPoint: .leading, endPoint: .trailing)
                )
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
        errorMessage = nil
        Task {
            let error = await vm.publishPost(photoData: data, caption: caption)
            isPublishing = false
            if let error = error {
                errorMessage = error
            } else {
                onClose()
            }
        }
    }
}
