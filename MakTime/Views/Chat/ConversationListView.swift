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
                List {
                    ForEach(vm.filteredConversations) { conv in
                        conversationRow(conv)
                            .listRowInsets(EdgeInsets())
                            .listRowBackground(selectedConversation?.id == conv.id ? Theme.bgHover : Theme.bgPrimary)
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
                                    // Mark as read
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
        }
        .background(Theme.bgPrimary)
        .task {
            vm.setup(socketService: socketService)
            await vm.loadConversations()
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 56))
                .foregroundColor(Theme.textMuted.opacity(0.5))
            Text("Нет чатов")
                .font(.headline)
                .foregroundColor(Theme.textSecondary)
            Text("Найдите пользователя через поиск")
                .font(.subheadline)
                .foregroundColor(Theme.textMuted)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
    
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
                                .font(.subheadline.weight(.medium))
                                .foregroundColor(Theme.textPrimary)
                            Text("@\(user.username)")
                                .font(.caption)
                                .foregroundColor(Theme.textSecondary)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                }
            }
            Divider().background(Theme.border)
        }
        .background(Theme.bgSecondary)
    }
    
    private func conversationRow(_ conv: Conversation) -> some View {
        Button {
            selectedConversation = conv
        } label: {
            HStack(spacing: 12) {
                AvatarView(
                    name: conv.participant?.displayName ?? "?",
                    color: conv.participant?.avatarColor ?? "#6C63FF",
                    size: 50,
                    showOnline: vm.isUserOnline(conv.participant?.id ?? "")
                )
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(conv.participant?.displayName ?? "Чат")
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(Theme.textPrimary)
                            .lineLimit(1)
                        Spacer()
                        Text(conv.lastMessageTimeFormatted)
                            .font(.caption2)
                            .foregroundColor(Theme.textMuted)
                    }
                    
                    HStack {
                        Text(conv.lastMessagePreview)
                            .font(.caption)
                            .foregroundColor(Theme.textSecondary)
                            .lineLimit(1)
                        Spacer()
                        if conv.unreadCount > 0 {
                            Text("\(conv.unreadCount)")
                                .font(.caption2.weight(.bold))
                                .foregroundColor(.white)
                                .frame(minWidth: 20, minHeight: 20)
                                .background(Theme.accent)
                                .clipShape(Capsule())
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
    }
}
