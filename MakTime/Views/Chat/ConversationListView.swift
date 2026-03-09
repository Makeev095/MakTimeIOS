import SwiftUI

struct ConversationListView: View {
    @EnvironmentObject var socketService: SocketService
    @StateObject private var vm = ConversationsViewModel()
    @Binding var selectedConversation: Conversation?
    let onStartCall: (String, String, String) -> Void

    var body: some View {
        VStack(spacing: 0) {
            SearchBarView(text: $vm.searchQuery)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)

            if !vm.searchResults.isEmpty && !vm.searchQuery.isEmpty {
                searchResultsList
            }

            if vm.filteredConversations.isEmpty && !vm.isLoading {
                emptyState
            } else {
                conversationList
            }
        }
        .background(Theme.bgPrimary)
        .task {
            vm.setup(socketService: socketService)
            await vm.loadConversations()
        }
    }

    // MARK: - Conversation list
    private var conversationList: some View {
        List {
            ForEach(vm.filteredConversations) { conv in
                conversationRow(conv)
                    .listRowInsets(EdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 12))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            withAnimation {
                                vm.conversations.removeAll { $0.id == conv.id }
                            }
                        } label: {
                            Label("Удалить", systemImage: "trash")
                        }
                    }
                    .swipeActions(edge: .leading) {
                        Button {
                            socketService.markRead(conversationId: conv.id)
                            if let idx = vm.conversations.firstIndex(where: { $0.id == conv.id }) {
                                vm.conversations[idx].unreadCount = 0
                            }
                        } label: {
                            Label("Прочитано", systemImage: "envelope.open")
                        }
                        .tint(Theme.accent)
                    }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .scrollDismissesKeyboard(.interactively)
        .refreshable { await vm.loadConversations() }
    }

    // MARK: - Conversation row
    private func conversationRow(_ conv: Conversation) -> some View {
        Button {
            selectedConversation = conv
        } label: {
            HStack(spacing: 12) {
                AvatarView(
                    name: conv.participant?.displayName ?? "?",
                    color: conv.participant?.avatarColor ?? "#6C63FF",
                    avatarUrl: conv.participant?.avatarUrl,
                    size: 52,
                    showOnline: vm.isUserOnline(conv.participant?.id ?? "")
                )

                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(conv.participant?.displayName ?? "Чат")
                            .font(.system(.subheadline, design: .rounded).weight(.semibold))
                            .foregroundColor(Theme.textPrimary)
                            .lineLimit(1)
                        Spacer()
                        Text(conv.lastMessageTimeFormatted)
                            .font(.system(size: 11))
                            .foregroundColor(Theme.textMuted)
                    }

                    HStack(alignment: .center) {
                        Text(conv.lastMessagePreview)
                            .font(.system(.caption, design: .rounded))
                            .foregroundColor(Theme.textSecondary)
                            .lineLimit(1)
                        Spacer()
                        if conv.unreadCount > 0 {
                            Text("\(conv.unreadCount)")
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(Theme.gradientAccent)
                                .clipShape(Capsule())
                        }
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: Theme.radiusLg)
                    .fill(selectedConversation?.id == conv.id ? Theme.bgHover : Theme.bgSecondary)
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.radiusLg)
                            .stroke(Theme.glassBorder, lineWidth: 1)
                    )
            )
        }
    }

    // MARK: - Search results
    private var searchResultsList: some View {
        VStack(spacing: 0) {
            ForEach(vm.searchResults) { user in
                Button {
                    Task {
                        if let conv = await vm.createConversation(with: user.id) {
                            selectedConversation = conv
                            vm.searchQuery = ""
                            vm.searchResults = []
                        }
                    }
                } label: {
                    HStack(spacing: 12) {
                        AvatarView(name: user.displayName, color: user.avatarColor, size: 40)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(user.displayName)
                                .font(.system(.subheadline, design: .rounded).weight(.medium))
                                .foregroundColor(Theme.textPrimary)
                            Text("@\(user.username)")
                                .font(.caption)
                                .foregroundColor(Theme.textSecondary)
                        }
                        Spacer()
                        Image(systemName: "message.fill")
                            .font(.caption)
                            .foregroundStyle(Theme.gradientAccent)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                }
            }
            Divider().background(Theme.border)
        }
        .background(.ultraThinMaterial)
    }

    // MARK: - Empty state
    private var emptyState: some View {
        VStack(spacing: 14) {
            Spacer()
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 56))
                .foregroundStyle(Theme.gradientAccent)
                .opacity(0.4)
            Text("Нет чатов")
                .font(.system(.headline, design: .rounded))
                .foregroundColor(Theme.textSecondary)
            Text("Найдите пользователя через поиск выше")
                .font(.system(.subheadline, design: .rounded))
                .foregroundColor(Theme.textMuted)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 32)
    }
}
