import SwiftUI

struct StoryBarView: View {
    @StateObject private var vm = StoriesViewModel()
    @EnvironmentObject var socketService: SocketService
    @EnvironmentObject var authService: AuthService
    var onViewStories: ([StoryUser], Int) -> Void
    var onAddStory: () -> Void
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 14) {
                addStoryButton
                
                ForEach(Array(vm.storyUsers.enumerated()), id: \.element.id) { idx, user in
                    storyItem(user, index: idx)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .background(Theme.bgSecondary)
        .task {
            vm.setup(socketService: socketService)
            await vm.loadStories()
        }
    }
    
    private var addStoryButton: some View {
        Button(action: onAddStory) {
            VStack(spacing: 4) {
                ZStack {
                    Circle()
                        .fill(Theme.bgTertiary)
                        .frame(width: 56, height: 56)
                    Image(systemName: "plus")
                        .font(.title3)
                        .foregroundColor(Theme.accent)
                }
                Text("История")
                    .font(.system(size: 10))
                    .foregroundColor(Theme.textSecondary)
                    .lineLimit(1)
            }
            .frame(width: 64)
        }
    }
    
    private func storyItem(_ user: StoryUser, index: Int) -> some View {
        Button {
            onViewStories(vm.storyUsers, index)
        } label: {
            VStack(spacing: 4) {
                ZStack {
                    Circle()
                        .stroke(
                            user.hasUnviewed ? Theme.accent : Theme.textMuted.opacity(0.3),
                            lineWidth: 2.5
                        )
                        .frame(width: 58, height: 58)
                    
                    AvatarView(name: user.displayName, color: user.avatarColor, size: 52)
                }
                Text(user.isOwn ? "Вы" : user.displayName)
                    .font(.system(size: 10))
                    .foregroundColor(Theme.textSecondary)
                    .lineLimit(1)
            }
            .frame(width: 64)
        }
    }
}
