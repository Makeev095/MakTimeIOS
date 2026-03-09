import SwiftUI

struct FeedView: View {
    @StateObject private var vm = FeedViewModel()
    @EnvironmentObject var authService: AuthService
    @State private var showCreatePost = false
    @State private var selectedPostForComments: Post?
    @State private var showReels = false
    @State private var reelsStartIndex = 0

    /// Only video posts, used for Reels
    private var videoPosts: [Post] { vm.posts.filter { $0.type == .video } }

    var body: some View {
        ZStack(alignment: .top) {
            Theme.bgPrimary.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Лента")
                            .font(.system(size: 26, weight: .bold, design: .rounded))
                            .foregroundColor(Theme.textPrimary)
                    }
                    Spacer()

                    // Reels button
                    if !videoPosts.isEmpty {
                        Button {
                            reelsStartIndex = 0
                            showReels = true
                        } label: {
                            Image(systemName: "play.rectangle.fill")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(width: 36, height: 36)
                                .background(Theme.bgTertiary)
                                .clipShape(Circle())
                        }
                        .padding(.trailing, 8)
                    }

                    // New post button
                    Button {
                        showCreatePost = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 36, height: 36)
                            .background(Theme.gradientAccent)
                            .clipShape(Circle())
                            .neonGlow(Theme.accent, radius: 6)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 10)

                Divider().background(Theme.glassBorder)

                content
            }
        }
        .task { await vm.loadPosts() }
        .sheet(isPresented: $showCreatePost) {
            CreatePostView(vm: vm, onClose: { showCreatePost = false })
        }
        .sheet(item: $selectedPostForComments) { post in
            CommentsView(post: post)
        }
        .fullScreenCover(isPresented: $showReels) {
            ReelsView(
                posts: videoPosts,
                startIndex: reelsStartIndex,
                onClose: { showReels = false },
                onLike: { post in vm.toggleLike(post: post) },
                onComment: { post in selectedPostForComments = post; showReels = false },
                onRepost: { post in vm.repost(post: post) }
            )
            .environmentObject(authService)
        }
    }

    @ViewBuilder
    private var content: some View {
        if vm.isLoading && vm.posts.isEmpty {
            loadingState
        } else if let error = vm.loadError, vm.posts.isEmpty {
            errorState(error)
        } else if vm.posts.isEmpty {
            emptyState
        } else {
            postsList
        }
    }

    private var loadingState: some View {
        VStack(spacing: 16) {
            Spacer()
            ProgressView().scaleEffect(1.2).tint(Theme.accent)
            Text("Загрузка ленты...")
                .font(.system(.subheadline, design: .rounded))
                .foregroundColor(Theme.textSecondary)
            Spacer()
        }
    }

    private func errorState(_ error: String) -> some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 50))
                .foregroundColor(Theme.textMuted)
            Text(error)
                .font(.system(.subheadline, design: .rounded))
                .foregroundColor(Theme.textSecondary)
                .multilineTextAlignment(.center)
            Button { Task { await vm.loadPosts() } } label: {
                Label("Повторить", systemImage: "arrow.clockwise")
                    .font(.system(.subheadline, design: .rounded).weight(.medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 24).padding(.vertical, 10)
                    .background(Theme.gradientAccent)
                    .cornerRadius(Theme.radiusLg)
            }
            Spacer()
        }
        .padding(.horizontal, 24)
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 56))
                .foregroundStyle(Theme.gradientAccent)
                .opacity(0.5)
            Text("Пока нет публикаций")
                .font(.system(.headline, design: .rounded))
                .foregroundColor(Theme.textSecondary)
            Text("Будьте первым — поделитесь фото!")
                .font(.system(.subheadline, design: .rounded))
                .foregroundColor(Theme.textMuted)
                .multilineTextAlignment(.center)
            Button { showCreatePost = true } label: {
                Text("Создать пост")
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 28).padding(.vertical, 12)
                    .background(Theme.gradientAccent)
                    .cornerRadius(Theme.radiusLg)
                    .neonGlow(Theme.accent, radius: 6)
            }
            Spacer()
        }
        .padding(.horizontal, 32)
    }

    private var postsList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(vm.posts) { post in
                    PostCardView(
                        post: post,
                        isMine: post.authorId == authService.user?.id,
                        onLike: { vm.toggleLike(post: post) },
                        onComment: { selectedPostForComments = post },
                        onRepost: { vm.repost(post: post) },
                        onDelete: { vm.deletePost(post) },
                        onVideoTap: post.type == .video ? {
                            // Find index of this post in video-only list
                            reelsStartIndex = videoPosts.firstIndex(where: { $0.id == post.id }) ?? 0
                            showReels = true
                        } : nil
                    )
                    .padding(.horizontal, 12)
                }
            }
            .padding(.vertical, 12)
        }
        .refreshable { await vm.refreshPosts() }
    }
}
