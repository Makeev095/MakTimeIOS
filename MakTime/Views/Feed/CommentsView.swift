import SwiftUI

struct CommentsView: View {
    let post: Post
    @State private var comments: [PostComment] = []
    @State private var newComment = ""
    @State private var isLoading = true
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if isLoading {
                    Spacer()
                    ProgressView().tint(Theme.accent)
                    Spacer()
                } else if comments.isEmpty {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "bubble.left.and.bubble.right")
                            .font(.system(size: 40))
                            .foregroundStyle(Theme.gradientAccent)
                            .opacity(0.4)
                        Text("Пока нет комментариев")
                            .font(.system(.subheadline, design: .rounded))
                            .foregroundColor(Theme.textSecondary)
                    }
                    Spacer()
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 16) {
                            ForEach(comments) { comment in
                                commentRow(comment)
                            }
                        }
                        .padding(16)
                    }
                }

                Divider().background(Theme.border)

                HStack(spacing: 8) {
                    TextField("Комментарий...", text: $newComment)
                        .foregroundColor(Theme.textPrimary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.white.opacity(0.05))
                        .cornerRadius(20)
                        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Theme.border, lineWidth: 1))

                    if !newComment.trimmingCharacters(in: .whitespaces).isEmpty {
                        Button {
                            sendComment()
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
            .background(Theme.bgPrimary)
            .navigationTitle("Комментарии")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Закрыть") { dismiss() }
                        .foregroundColor(Theme.accent)
                }
            }
        }
        .task {
            await loadComments()
        }
    }

    private func commentRow(_ comment: PostComment) -> some View {
        HStack(alignment: .top, spacing: 10) {
            AvatarView(name: comment.authorName, color: comment.authorAvatarColor, size: 32)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(comment.authorName)
                        .font(.system(.caption, design: .rounded).weight(.semibold))
                        .foregroundColor(Theme.textPrimary)
                    Text(comment.timeAgo)
                        .font(.caption2)
                        .foregroundColor(Theme.textMuted)
                }
                Text(comment.text)
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundColor(Theme.textPrimary)
            }
        }
    }

    private func loadComments() async {
        isLoading = true
        comments = (try? await APIService.shared.getComments(postId: post.id)) ?? []
        isLoading = false
    }

    private func sendComment() {
        let text = newComment.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        newComment = ""
        Task {
            if let comment = try? await APIService.shared.addComment(postId: post.id, text: text) {
                comments.append(comment)
            }
        }
    }
}
