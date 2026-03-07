import SwiftUI

struct FeedView: View {
    @StateObject private var vm = FeedViewModel()
    @EnvironmentObject var authService: AuthService
    @State private var showCreatePost = false
    @State private var selectedPostForComments: Post?

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Лента")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(Theme.textPrimary)
                Spacer()
                Button {
                    showCreatePost = true
                } label: {
                    Image(systemName: "plus.square.fill")
                        .font(.title2)
                        .foregroundStyle(Theme.gradientAccent)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            Divider().background(Theme.border)

            if vm.isLoading && vm.posts.isEmpty {
                Spacer()
                ProgressView().tint(Theme.accent)
                Spacer()
            } else if let error = vm.loadError, vm.posts.isEmpty {
                Spacer()
                VStack(spacing: 12) {
                    Image(systemName: "wifi.exclamationmark")
                        .font(.system(size: 50))
                        .foregroundStyle(Theme.gradientAccent)
                        .opacity(0.4)
                    Text(error)
                        .font(.system(.headline, design: .rounded))
                        .foregroundColor(Theme.textSecondary)
                    Button {
                        Task { await vm.loadPosts() }
                    } label: {
                        Text("Повторить")
                            .font(.system(.subheadline, design: .rounded).weight(.medium))
                            .foregroundColor(.white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 10)
                            .background(Theme.gradientAccent)
                            .cornerRadius(20)
                    }
                }
                Spacer()
            } else if vm.posts.isEmpty {
                Spacer()
                VStack(spacing: 12) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 50))
                        .foregroundStyle(Theme.gradientAccent)
                        .opacity(0.4)
                    Text("Пока нет публикаций")
                        .font(.system(.headline, design: .rounded))
                        .foregroundColor(Theme.textSecondary)
                    Text("Будьте первым — поделитесь фото!")
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundColor(Theme.textMuted)
                    Button {
                        showCreatePost = true
                    } label: {
                        Text("Создать пост")
                            .font(.system(.subheadline, design: .rounded).weight(.medium))
                            .foregroundColor(.white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 10)
                            .background(Theme.gradientAccent)
                            .cornerRadius(20)
                            .neonGlow(Theme.accent, radius: 6)
                    }
                    .padding(.top, 4)
                }
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 1) {
                        ForEach(vm.posts) { post in
                            PostCardView(
                                post: post,
                                isMine: post.authorId == authService.user?.id,
                                onLike: { vm.toggleLike(post: post) },
                                onComment: { selectedPostForComments = post },
                                onRepost: { vm.repost(post: post) },
                                onDelete: { vm.deletePost(post) }
                            )
                            Divider().background(Theme.border)
                        }
                    }
                }
                .refreshable {
                    await vm.refreshPosts()
                }
            }
        }
        .background(Theme.bgPrimary)
        .task {
            await vm.loadPosts()
        }
        .sheet(isPresented: $showCreatePost) {
            CreatePostView(vm: vm, onClose: { showCreatePost = false })
        }
        .sheet(item: $selectedPostForComments) { post in
            CommentsView(post: post)
        }
    }
}
