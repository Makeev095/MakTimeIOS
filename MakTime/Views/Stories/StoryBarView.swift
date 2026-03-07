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
        .background(.ultraThinMaterial)
        .task {
            vm.setup(socketService: socketService)
            await vm.loadStories()
        }
    }

    private var addStoryButton: some View {
        Button(action: onAddStory) {
            VStack(spacing: 6) {
                ZStack(alignment: .bottomTrailing) {
                    Circle()
                        .fill(Color.white.opacity(0.05))
                        .frame(width: 62, height: 62)

                    if let user = authService.user {
                        AvatarView(name: user.displayName, color: user.avatarColor, size: 58)
                    } else {
                        Image(systemName: "camera.fill")
                            .font(.title3)
                            .foregroundColor(Theme.textSecondary)
                    }

                    ZStack {
                        Circle()
                            .fill(Theme.accent)
                            .frame(width: 22, height: 22)
                            .neonGlow(Theme.accent, radius: 4)
                        Image(systemName: "plus")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .offset(x: 3, y: 3)
                }
                Text("История")
                    .font(.system(size: 11, design: .rounded))
                    .foregroundColor(Theme.textSecondary)
                    .lineLimit(1)
            }
            .frame(width: 72)
        }
    }

    private func storyItem(_ user: StoryUser, index: Int) -> some View {
        Button {
            onViewStories(vm.storyUsers, index)
        } label: {
            VStack(spacing: 6) {
                ZStack {
                    if user.hasUnviewed {
                        Circle()
                            .strokeBorder(
                                Theme.gradientNeon,
                                lineWidth: 2.5
                            )
                            .frame(width: 64, height: 64)
                            .neonGlow(Theme.accent, radius: 6)
                    } else {
                        Circle()
                            .stroke(Theme.textMuted.opacity(0.3), lineWidth: 1.5)
                            .frame(width: 64, height: 64)
                    }

                    AvatarView(name: user.displayName, color: user.avatarColor, size: 56)
                }
                Text(user.isOwn ? "Вы" : user.displayName.components(separatedBy: " ").first ?? user.displayName)
                    .font(.system(size: 11, design: .rounded))
                    .foregroundColor(Theme.textSecondary)
                    .lineLimit(1)
            }
            .frame(width: 72)
        }
    }
}
