import SwiftUI

struct ChatView: View {
    let conversation: Conversation
    let onStartCall: (String, String, String) -> Void
    
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var socketService: SocketService
    @StateObject private var vm: ChatViewModel
    
    init(conversation: Conversation, onStartCall: @escaping (String, String, String) -> Void) {
        self.conversation = conversation
        self.onStartCall = onStartCall
        _vm = StateObject(wrappedValue: ChatViewModel(conversation: conversation))
    }
    
    var body: some View {
        VStack(spacing: 0) {
            messageList
            
            if vm.isTyping {
                HStack(spacing: 6) {
                    Text("\(conversation.participant?.displayName ?? "") печатает")
                        .font(.caption)
                        .foregroundColor(Theme.textSecondary)
                    ProgressView().scaleEffect(0.6)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.vertical, 4)
                .background(Theme.bgPrimary)
            }
            
            ChatInputView(vm: vm)
        }
        .background(Theme.bgPrimary)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                HStack(spacing: 8) {
                    AvatarView(
                        name: conversation.participant?.displayName ?? "?",
                        color: conversation.participant?.avatarColor ?? "#6C63FF",
                        size: 32,
                        showOnline: conversation.participant?.isOnline ?? false
                    )
                    VStack(alignment: .leading, spacing: 1) {
                        Text(conversation.participant?.displayName ?? "Чат")
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(Theme.textPrimary)
                        Text(conversation.participant?.isOnline == true ? "в сети" : "не в сети")
                            .font(.caption2)
                            .foregroundColor(conversation.participant?.isOnline == true ? Theme.success : Theme.textMuted)
                    }
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    if let p = conversation.participant {
                        onStartCall(p.id, p.displayName, conversation.id)
                    }
                } label: {
                    Image(systemName: "video.fill")
                        .foregroundColor(Theme.accent)
                }
            }
        }
        .task {
            vm.setup(socketService: socketService, userId: authService.user?.id ?? "")
            await vm.loadMessages()
        }
    }
    
    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(vm.messages) { message in
                        MessageBubbleView(
                            message: message,
                            isMine: vm.isMine(message),
                            replyMessage: vm.replyToMessage(for: message),
                            onReply: { vm.replyTo = message },
                            onDelete: { Task { await vm.deleteMessage(message) } }
                        )
                        .id(message.id)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
            .onChange(of: vm.messages.count) { _ in
                if let last = vm.messages.last {
                    withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                }
            }
            .onAppear {
                if let last = vm.messages.last {
                    proxy.scrollTo(last.id, anchor: .bottom)
                }
            }
        }
    }
}
