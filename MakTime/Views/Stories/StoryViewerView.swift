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
    @State private var showReactions = false
    @State private var replyText = ""
    @State private var viewers: [StoryViewer] = []
    @State private var showViewers = false
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
            
            // Progress bars
            VStack {
                if let user = currentUser {
                    HStack(spacing: 3) {
                        ForEach(0..<user.stories.count, id: \.self) { idx in
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    Rectangle().fill(Color.white.opacity(0.3))
                                    Rectangle().fill(Color.white)
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
                    
                    // User info
                    HStack(spacing: 10) {
                        AvatarView(name: user.displayName, color: user.avatarColor, size: 36)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(user.displayName)
                                .font(.subheadline.weight(.semibold))
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
                                    if let s = currentStory {
                                        Text("\(s.viewCount)")
                                    }
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
                
                // Reactions + reply
                if !(currentUser?.isOwn ?? true) {
                    HStack(spacing: 8) {
                        TextField("Ответить...", text: $replyText)
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(.ultraThinMaterial)
                            .cornerRadius(20)
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
            
            // Tap zones
            HStack(spacing: 0) {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture { previousStory() }
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture { nextStory() }
            }
        }
        .onAppear { startTimer() }
        .onDisappear { timer?.invalidate() }
        .sheet(isPresented: $showViewers) {
            viewersList
        }
    }
    
    private func storyContent(_ story: Story) -> some View {
        ZStack {
            if story.type == .video, let url = URL(string: story.fullFileUrl) {
                VideoPlayer(player: AVPlayer(url: url))
                    .ignoresSafeArea()
            } else if let url = URL(string: story.fullFileUrl) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let img):
                        img.resizable().scaledToFill().ignoresSafeArea()
                    case .failure:
                        VStack(spacing: 16) {
                            Image(systemName: "photo.badge.exclamationmark")
                                .font(.system(size: 48))
                                .foregroundColor(.white.opacity(0.5))
                            Text("Не удалось загрузить")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.6))
                        }
                    default:
                        ProgressView()
                            .tint(.white)
                            .scaleEffect(1.5)
                    }
                }
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "photo.badge.exclamationmark")
                        .font(.system(size: 48))
                        .foregroundColor(.white.opacity(0.5))
                    Text("Недоступно")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.6))
                }
            }

            if !story.textOverlay.isEmpty {
                Text(story.textOverlay)
                    .font(.title2.weight(.bold))
                    .foregroundColor(.white)
                    .shadow(radius: 4)
                    .padding()
            }
        }
    }
    
    private var viewersList: some View {
        NavigationStack {
            List(viewers) { viewer in
                HStack {
                    Text(viewer.displayName)
                        .foregroundColor(Theme.textPrimary)
                    Spacer()
                    Text(viewer.viewedAt.prefix(16))
                        .font(.caption)
                        .foregroundColor(Theme.textSecondary)
                }
                .listRowBackground(Theme.bgSecondary)
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
        guard let user = currentUser else { onClose(); return }
        if currentStoryIdx < user.stories.count - 1 {
            currentStoryIdx += 1
            startTimer()
        } else if currentUserIdx < storyUsers.count - 1 {
            currentUserIdx += 1
            currentStoryIdx = 0
            startTimer()
        } else {
            onClose()
        }
    }
    
    private func previousStory() {
        if currentStoryIdx > 0 {
            currentStoryIdx -= 1
            startTimer()
        } else if currentUserIdx > 0 {
            currentUserIdx -= 1
            currentStoryIdx = max(0, (storyUsers[currentUserIdx].stories.count) - 1)
            startTimer()
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
