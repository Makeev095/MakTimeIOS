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
    @State private var isPaused = false
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var socketService: SocketService
    
    init(storyUsers: [StoryUser], startUserIdx: Int, onClose: @escaping () -> Void) {
        self.storyUsers = storyUsers
        self.startUserIdx = startUserIdx
        self.onClose = onClose
        _currentUserIdx = State(initialValue: startUserIdx)
    }
    
    private var currentUser: StoryUser? {
        guard currentUserIdx >= 0, currentUserIdx < storyUsers.count else { return nil }
        return storyUsers[currentUserIdx]
    }
    
    private var currentStory: Story? {
        guard let user = currentUser,
              currentStoryIdx >= 0,
              currentStoryIdx < user.stories.count else { return nil }
        return user.stories[currentStoryIdx]
    }
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.black
                    .ignoresSafeArea()
                
                // Story content
                if let story = currentStory {
                    storyMedia(story, size: geo.size)
                        .ignoresSafeArea()
                }
                
                // Gradient overlays for readability
                VStack(spacing: 0) {
                    LinearGradient(
                        colors: [Color.black.opacity(0.5), Color.clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 140)
                    Spacer()
                    LinearGradient(
                        colors: [Color.clear, Color.black.opacity(0.4)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 120)
                }
                .ignoresSafeArea()
                
                // UI overlay
                VStack(spacing: 0) {
                    // Progress bars
                    if let user = currentUser {
                        HStack(spacing: 3) {
                            ForEach(0..<user.stories.count, id: \.self) { idx in
                                GeometryReader { bar in
                                    ZStack(alignment: .leading) {
                                        RoundedRectangle(cornerRadius: 2)
                                            .fill(Color.white.opacity(0.3))
                                        RoundedRectangle(cornerRadius: 2)
                                            .fill(Color.white)
                                            .frame(width: progressWidth(idx: idx, total: bar.size.width))
                                    }
                                }
                                .frame(height: 3)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.top, geo.safeAreaInsets.top + 8)
                        
                        // Header
                        HStack(spacing: 10) {
                            AvatarView(name: user.displayName, color: user.avatarColor, size: 36)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(user.displayName)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundColor(.white)
                                if let story = currentStory {
                                    Text(formatStoryDate(story.createdAt))
                                        .font(.caption2)
                                        .foregroundColor(.white.opacity(0.6))
                                }
                            }
                            Spacer()
                            
                            if user.isOwn {
                                Button {
                                    Task { await deleteCurrentStory() }
                                } label: {
                                    Image(systemName: "trash")
                                        .foregroundColor(.white)
                                        .padding(8)
                                        .background(.black.opacity(0.3))
                                        .clipShape(Circle())
                                }
                                
                                Button { showViewers = true } label: {
                                    HStack(spacing: 4) {
                                        Image(systemName: "eye.fill")
                                        if let s = currentStory {
                                            Text("\(s.viewCount)")
                                        }
                                    }
                                    .font(.caption)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(.black.opacity(0.3))
                                    .clipShape(Capsule())
                                }
                            }
                            
                            Button(action: onClose) {
                                Image(systemName: "xmark")
                                    .font(.title3.weight(.semibold))
                                    .foregroundColor(.white)
                                    .padding(8)
                                    .background(.black.opacity(0.3))
                                    .clipShape(Circle())
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.top, 8)
                    }
                    
                    Spacer()
                    
                    // Text overlay
                    if let story = currentStory, !story.textOverlay.isEmpty {
                        Text(story.textOverlay)
                            .font(.title2.weight(.bold))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .shadow(color: .black.opacity(0.7), radius: 4)
                            .padding(.horizontal, 20)
                            .padding(.bottom, 16)
                    }
                    
                    // Reply / reactions (for others' stories)
                    if !(currentUser?.isOwn ?? true) {
                        VStack(spacing: 8) {
                            HStack(spacing: 8) {
                                ForEach(["❤️", "🔥", "😂", "😮", "👏"], id: \.self) { emoji in
                                    Button {
                                        Task {
                                            if let s = currentStory {
                                                try? await APIService.shared.reactToStory(storyId: s.id, emoji: emoji)
                                            }
                                        }
                                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    } label: {
                                        Text(emoji).font(.title3)
                                    }
                                }
                            }
                            
                            HStack(spacing: 8) {
                                TextField("Ответить...", text: $replyText)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 10)
                                    .background(.white.opacity(0.15))
                                    .cornerRadius(22)
                                    .overlay(RoundedRectangle(cornerRadius: 22).stroke(.white.opacity(0.2)))
                                    .submitLabel(.send)
                                    .onSubmit { sendReply() }
                                
                                if !replyText.isEmpty {
                                    Button { sendReply() } label: {
                                        Image(systemName: "arrow.up.circle.fill")
                                            .font(.title2)
                                            .foregroundColor(.white)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.bottom, max(geo.safeAreaInsets.bottom, 20))
                    } else {
                        Spacer().frame(height: max(geo.safeAreaInsets.bottom, 16))
                    }
                }
                
                // Tap zones (left / right)
                HStack(spacing: 0) {
                    Color.clear
                        .contentShape(Rectangle())
                        .frame(width: geo.size.width * 0.35)
                        .onTapGesture { previousStory() }
                    
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture { nextStory() }
                }
            }
        }
        .ignoresSafeArea()
        .onAppear { startTimer() }
        .onDisappear { stopTimer() }
        .sheet(isPresented: $showViewers) {
            viewersList
        }
    }
    
    private func progressWidth(idx: Int, total: CGFloat) -> CGFloat {
        if idx < currentStoryIdx { return total }
        if idx == currentStoryIdx { return total * min(progress, 1) }
        return 0
    }
    
    private func formatStoryDate(_ str: String) -> String {
        guard let date = DateParsing.parse(str) else { return str }
        let formatter = DateFormatter()
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            formatter.dateFormat = "HH:mm"
        } else {
            formatter.dateFormat = "d MMM, HH:mm"
            formatter.locale = Locale(identifier: "ru_RU")
        }
        return formatter.string(from: date)
    }
    
    @ViewBuilder
    private func storyMedia(_ story: Story, size: CGSize) -> some View {
        if story.type == .video, let url = URL(string: story.fullFileUrl) {
            VideoPlayer(player: AVPlayer(url: url))
                .frame(width: size.width, height: size.height)
        } else if let url = URL(string: story.fullFileUrl) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let img):
                    img
                        .resizable()
                        .scaledToFill()
                        .frame(width: size.width, height: size.height)
                        .clipped()
                case .failure:
                    ZStack {
                        Color(hex: story.bgColor.isEmpty ? "1A1A2E" : story.bgColor)
                        Image(systemName: "photo")
                            .font(.system(size: 48))
                            .foregroundColor(.white.opacity(0.3))
                    }
                    .frame(width: size.width, height: size.height)
                default:
                    ZStack {
                        Color.black
                        ProgressView().tint(.white)
                    }
                    .frame(width: size.width, height: size.height)
                }
            }
        } else {
            Color(hex: story.bgColor.isEmpty ? "1A1A2E" : story.bgColor)
                .frame(width: size.width, height: size.height)
        }
    }
    
    private var viewersList: some View {
        NavigationStack {
            Group {
                if viewers.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "eye.slash")
                            .font(.system(size: 40))
                            .foregroundColor(Theme.textMuted)
                        Text("Никто ещё не смотрел")
                            .foregroundColor(Theme.textSecondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Theme.bgPrimary)
                } else {
                    List(viewers) { viewer in
                        HStack(spacing: 10) {
                            AvatarView(
                                name: viewer.displayName,
                                color: viewer.avatarColor ?? "#6C63FF",
                                size: 36
                            )
                            VStack(alignment: .leading, spacing: 2) {
                                Text(viewer.displayName)
                                    .foregroundColor(Theme.textPrimary)
                                Text(formatStoryDate(viewer.viewedAt))
                                    .font(.caption)
                                    .foregroundColor(Theme.textSecondary)
                            }
                        }
                        .listRowBackground(Theme.bgSecondary)
                        .listRowSeparator(.hidden)
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .background(Theme.bgPrimary)
                }
            }
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
        stopTimer()
        progress = 0
        timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
            Task { @MainActor in
                guard !self.isPaused else { return }
                self.progress += 0.05 / 5.0
                if self.progress >= 1 { self.nextStory() }
            }
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
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
        } else {
            // Already at first story, restart
            startTimer()
        }
    }
    
    private func markViewed() {
        if let s = currentStory, !(currentUser?.isOwn ?? true) {
            Task { try? await APIService.shared.viewStory(storyId: s.id) }
        }
    }
    
    private func sendReply() {
        let text = replyText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        replyText = ""
        if let user = currentUser {
            Task {
                if let conv = try? await APIService.shared.createConversation(participantId: user.userId) {
                    socketService.sendMessage(conversationId: conv.id, text: "↩ История: \(text)")
                }
            }
        }
    }
    
    private func deleteCurrentStory() async {
        guard let s = currentStory else { return }
        stopTimer()
        try? await APIService.shared.deleteStory(storyId: s.id)
        nextStory()
    }
}
