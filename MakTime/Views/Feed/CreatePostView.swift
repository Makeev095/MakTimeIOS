import SwiftUI
import PhotosUI
import AVFoundation
import UniformTypeIdentifiers

struct CreatePostView: View {
    @ObservedObject var vm: FeedViewModel
    let onClose: () -> Void

    @State private var selectedItem: PhotosPickerItem?
    @State private var selectedImageData: Data?
    @State private var selectedVideoData: Data?
    @State private var previewImage: UIImage?
    @State private var isVideo = false
    @State private var caption = ""
    @State private var isPublishing = false
    @State private var errorMessage: String?
    @Environment(\.dismiss) private var dismiss

    private var hasMedia: Bool { selectedImageData != nil || selectedVideoData != nil }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 16) {
                        if let image = previewImage {
                            ZStack(alignment: .topTrailing) {
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 300)
                                    .clipped()
                                    .cornerRadius(12)

                                // Video badge
                                if isVideo {
                                    Label("Видео", systemImage: "video.fill")
                                        .font(.caption2.weight(.semibold))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(.black.opacity(0.6))
                                        .clipShape(Capsule())
                                        .padding(12)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }

                                Button {
                                    clearSelection()
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.title2)
                                        .foregroundColor(.white)
                                        .shadow(radius: 4)
                                }
                                .padding(12)
                            }
                            .padding(.horizontal, 16)
                        } else {
                            PhotosPicker(selection: $selectedItem, matching: .any(of: [.images, .videos])) {
                                VStack(spacing: 12) {
                                    Image(systemName: "photo.badge.plus")
                                        .font(.system(size: 44))
                                        .foregroundColor(Theme.accent)
                                    Text("Выбрать фото или видео")
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
                    hasMedia
                    ? LinearGradient(colors: [Theme.accent, Theme.accentSecondary], startPoint: .leading, endPoint: .trailing)
                    : LinearGradient(colors: [Theme.textMuted, Theme.textMuted], startPoint: .leading, endPoint: .trailing)
                )
                .cornerRadius(14)
                .padding(16)
                .disabled(!hasMedia || isPublishing)
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
                Task { await loadSelectedMedia() }
            }
        }
    }

    private func clearSelection() {
        previewImage = nil
        selectedImageData = nil
        selectedVideoData = nil
        selectedItem = nil
        isVideo = false
    }

    private func loadSelectedMedia() async {
        guard let item = selectedItem else { return }

        // Check if it's a video by supported content types
        let videoTypes: [UTType] = [.movie, .video, .mpeg4Movie, .quickTimeMovie, .avi]
        let isVideoItem = item.supportedContentTypes.contains(where: { type in
            videoTypes.contains(where: { type.conforms(to: $0) })
        })

        if isVideoItem {
            // Load video
            if let movie = try? await item.loadTransferable(type: VideoTransferable.self) {
                let data = try? Data(contentsOf: movie.url)
                selectedVideoData = data
                selectedImageData = nil
                isVideo = true
                // Generate thumbnail from video
                previewImage = generateVideoThumbnail(url: movie.url)
            }
        } else {
            // Load image
            if let data = try? await item.loadTransferable(type: Data.self) {
                selectedImageData = data
                selectedVideoData = nil
                isVideo = false
                previewImage = UIImage(data: data)
            }
        }
    }

    private func generateVideoThumbnail(url: URL) -> UIImage? {
        let asset = AVAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 600, height: 600)
        if let cgImage = try? generator.copyCGImage(at: .zero, actualTime: nil) {
            return UIImage(cgImage: cgImage)
        }
        return nil
    }

    private func publish() {
        isPublishing = true
        errorMessage = nil
        Task {
            var error: String?
            if isVideo, let data = selectedVideoData {
                error = await vm.publishVideoPost(videoData: data, caption: caption)
            } else if let data = selectedImageData {
                error = await vm.publishPost(photoData: data, caption: caption)
            }
            isPublishing = false
            if let error = error {
                errorMessage = error
            } else {
                onClose()
            }
        }
    }
}

struct VideoTransferable: Transferable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .movie) { movie in
            SentTransferredFile(movie.url)
        } importing: { received in
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("video_\(UUID().uuidString).mp4")
            try FileManager.default.copyItem(at: received.file, to: tempURL)
            return Self(url: tempURL)
        }
    }
}
