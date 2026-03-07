import SwiftUI
import AVKit

struct StoryViewerView: View {
    let storyUsers: [StoryUser]
    let startUserIdx: Int
    let onClose: () -> Void

    @State private var currentUserIdx: Int
    @State private var currentStoryIdx = 0
    @State private var progress: CGFloat = 0
    @State private var timer: Timer?
    @State private var replyText = ""
    @State private var viewers: [StoryViewer] = []
    @State private var showViewers = false
    @State private var storyImage: UIImage?
    @State private var imageLoading = false
    @State private var imageError = false
    @State private var currentLoadingId: String?
    @State private var imageReady = false
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var socketService: SocketService

    init(storyUsers: [StoryUser], startUserIdx: Int, onClose: @escaping () -> Void) {
        self.storyUsers = storyUsers
        self.startUserIdx = startUserIdx
        self.onClose = onClose
        _currentUserIdx = State(initialValue: startUserIdx)
    }

    private var currentUser: StoryUser? {
        guard currentUserIdx < storyUsers.count else { return nil }
        return storyUsers[currentUserIdx]
    }

    private var currentStory: Story? {
        guard let user = currentUser, currentStoryIdx < user.stories.count else { return nil }
        return user.stories[currentStoryIdx]
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let story = currentStory {
                storyContent(story)
            }

            VStack {
                if let user = currentUser {
                    HStack(spacing: 3) {
                        ForEach(0..<user.stories.count, id: \.self) { idx in
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    Rectangle().fill(Color.white.opacity(0.3))
                                    Rectangle()
                                        .fill(
                                            idx < currentStoryIdx ? AnyShapeStyle(Theme.gradientAccent) :
                                            idx == currentStoryIdx ? AnyShapeStyle(Theme.gradientAccent) :
                                            AnyShapeStyle(Color.clear)
                                        )
                                        .frame(width: idx < currentStoryIdx ? geo.size.width :
                                                       idx == currentStoryIdx ? geo.size.width * progress : 0)
                                }
                            }
                            .frame(height: 3)
                            .cornerRadius(1.5)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.top, 50)

                    HStack(spacing: 10) {
                        AvatarView(name: user.displayName, color: user.avatarColor, size: 36)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(user.displayName)
                                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                                .foregroundColor(.white)
                            Text(currentStory?.createdAt.prefix(16) ?? "")
                                .font(.caption2)
                                .foregroundColor(.white.opacity(0.6))
                        }
                        Spacer()

                        if user.isOwn {
                            Button {
                                Task { await deleteCurrentStory() }
                            } label: {
                                Image(systemName: "trash")
                                    .foregroundColor(.white)
                            }
                            Button { showViewers = true } label: {
                                HStack(spacing: 3) {
                                    Image(systemName: "eye")
                                    if let s = currentStory { Text("\(s.viewCount)") }
                                }
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.8))
                            }
                        }

                        Button(action: onClose) {
                            Image(systemName: "xmark")
                                .font(.title3)
                                .foregroundColor(.white)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                }

                Spacer()

                if !(currentUser?.isOwn ?? true) {
                    HStack(spacing: 8) {
                        TextField("Ответить...", text: $replyText)
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .glassCard(cornerRadius: 20)
                            .onSubmit { sendReply() }

                        ForEach(["❤️", "🔥", "😂", "😮", "👏"], id: \.self) { emoji in
                            Button {
                                Task {
                                    if let s = currentStory {
                                        try? await APIService.shared.reactToStory(storyId: s.id, emoji: emoji)
                                    }
                                }
                            } label: {
                                Text(emoji).font(.title3)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 30)
                }
            }

            HStack(spacing: 0) {
                Color.clear.contentShape(Rectangle()).onTapGesture { previousStory() }
                Color.clear.contentShape(Rectangle()).onTapGesture { nextStory() }
            }
        }
        .onAppear { loadAndStart() }
        .onDisappear { timer?.invalidate() }
        .sheet(isPresented: $showViewers) { viewersList }
    }

    @ViewBuilder
    private func storyContent(_ story: Story) -> some View {
        ZStack {
            if story.type == .video, let url = URL(string: story.fullFileUrl) {
                VideoPlayer(player: AVPlayer(url: url))
                    .ignoresSafeArea()
            } else if let image = storyImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()
            } else if imageLoading {
                ProgressView()
                    .tint(.white)
                    .scaleEffect(1.5)
            } else if imageError {
                VStack(spacing: 16) {
                    Image(systemName: "photo.badge.exclamationmark")
                        .font(.system(size: 48))
                        .foregroundColor(.white.opacity(0.5))
                    Text("Не удалось загрузить")
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundColor(.white.opacity(0.6))
                    Button("Повторить") { loadAndStart() }
                        .foregroundStyle(Theme.gradientAccent)
                        .padding(.top, 4)
                }
            }

            if !story.textOverlay.isEmpty {
                Text(story.textOverlay)
                    .font(.system(.title2, design: .rounded).weight(.bold))
                    .foregroundColor(.white)
                    .shadow(radius: 4)
                    .padding()
            }
        }
    }

    private func loadAndStart() {
        guard let story = currentStory else { return }
        if story.type == .video {
            startTimer()
            return
        }
        loadStoryImage(story: story)
    }

    private func loadStoryImage(story: Story) {
        let storyId = story.id
        currentLoadingId = storyId
        storyImage = nil
        imageLoading = true
        imageError = false
        imageReady = false

        let urlString = story.fullFileUrl
        guard let url = URL(string: urlString) else {
            imageLoading = false
            imageError = true
            return
        }

        Task {
            do {
                let (data, response) = try await URLSession.shared.data(from: url)
                await MainActor.run {
                    guard currentLoadingId == storyId else { return }
                    if let httpResponse = response as? HTTPURLResponse,
                       (200...299).contains(httpResponse.statusCode),
                       let image = UIImage(data: data) {
                        storyImage = image
                        imageLoading = false
                        imageReady = true
                        startTimer()
                    } else {
                        imageLoading = false
                        imageError = true
                    }
                }
            } catch {
                await MainActor.run {
                    guard currentLoadingId == storyId else { return }
                    imageLoading = false
                    imageError = true
                }
            }
        }
    }

    private var viewersList: some View {
        NavigationStack {
            List(viewers) { viewer in
                HStack {
                    Text(viewer.displayName).foregroundColor(Theme.textPrimary)
                    Spacer()
                    Text(viewer.viewedAt.prefix(16)).font(.caption).foregroundColor(Theme.textSecondary)
                }
                .listRowBackground(Color.white.opacity(0.04))
            }
            .scrollContentBackground(.hidden)
            .background(Theme.bgPrimary)
            .navigationTitle("Просмотры")
            .navigationBarTitleDisplayMode(.inline)
        }
        .task {
            if let s = currentStory {
                viewers = (try? await APIService.shared.getStoryViewers(storyId: s.id)) ?? []
            }
        }
    }

    private func startTimer() {
        markViewed()
        timer?.invalidate()
        progress = 0
        timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
            Task { @MainActor in
                progress += 0.05 / 5.0
                if progress >= 1 { nextStory() }
            }
        }
    }

    private func nextStory() {
        timer?.invalidate()
        guard let user = currentUser else { onClose(); return }
        if currentStoryIdx < user.stories.count - 1 {
            currentStoryIdx += 1
            loadAndStart()
        } else if currentUserIdx < storyUsers.count - 1 {
            currentUserIdx += 1
            currentStoryIdx = 0
            loadAndStart()
        } else {
            onClose()
        }
    }

    private func previousStory() {
        timer?.invalidate()
        if currentStoryIdx > 0 {
            currentStoryIdx -= 1
            loadAndStart()
        } else if currentUserIdx > 0 {
            currentUserIdx -= 1
            currentStoryIdx = max(0, (storyUsers[currentUserIdx].stories.count) - 1)
            loadAndStart()
        }
    }

    private func markViewed() {
        if let s = currentStory, !(currentUser?.isOwn ?? true) {
            Task { try? await APIService.shared.viewStory(storyId: s.id) }
        }
    }

    private func sendReply() {
        guard !replyText.isEmpty else { return }
        if let user = currentUser {
            Task {
                if let conv = try? await APIService.shared.createConversation(participantId: user.userId) {
                    socketService.sendMessage(conversationId: conv.id, text: "Re: история — \(replyText)")
                }
            }
        }
        replyText = ""
    }

    private func deleteCurrentStory() async {
        guard let s = currentStory else { return }
        try? await APIService.shared.deleteStory(storyId: s.id)
        nextStory()
    }
}
