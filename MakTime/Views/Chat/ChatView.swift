import SwiftUI
import Combine

struct ChatView: View {
    let conversation: Conversation
    let onStartCall: (String, String, String) -> Void
    
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var socketService: SocketService
    @StateObject private var vm: ChatViewModel
    @StateObject private var keyboard = KeyboardObserver()
    @FocusState private var inputFocused: Bool
    
    init(conversation: Conversation, onStartCall: @escaping (String, String, String) -> Void) {
        self.conversation = conversation
        self.onStartCall = onStartCall
        _vm = StateObject(wrappedValue: ChatViewModel(conversation: conversation))
    }
    
    var body: some View {
        GeometryReader { geo in
            VStack(spacing: 0) {
                messageList(in: geo)
                
                if vm.isTyping {
                    typingIndicator
                }
                
                ChatInputView(vm: vm, inputFocused: $inputFocused)
            }
        }
        .background(Theme.bgPrimary)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                chatToolbarTitle
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
    
    private static let bottomAnchorId = "chatBottom"

    private func messageList(in geo: GeometryProxy) -> some View {
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
                    Color.clear.frame(height: 1).id(Self.bottomAnchorId)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)
            .onTapGesture {
                inputFocused = false
            }
            .onChange(of: vm.messages.count) { _ in
                scrollToBottom(proxy, animated: true)
            }
            .onChange(of: keyboard.isVisible) { visible in
                if visible {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                        scrollToBottom(proxy, animated: true)
                    }
                }
            }
            .onChange(of: vm.isLoading) { loading in
                if !loading && !vm.messages.isEmpty {
                    for delay in [0.05, 0.2, 0.5] as [Double] {
                        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                            scrollToBottom(proxy, animated: false)
                        }
                    }
                }
            }
            .onAppear {
                if !vm.isLoading && !vm.messages.isEmpty {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        scrollToBottom(proxy, animated: false)
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        scrollToBottom(proxy, animated: false)
                    }
                }
            }
        }
    }

    private func scrollToBottom(_ proxy: ScrollViewProxy, animated: Bool) {
        if animated {
            withAnimation(.easeOut(duration: 0.2)) {
                proxy.scrollTo(Self.bottomAnchorId, anchor: .bottom)
            }
        } else {
            proxy.scrollTo(Self.bottomAnchorId, anchor: .bottom)
        }
    }
    
    private var typingIndicator: some View {
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
    
    private var chatToolbarTitle: some View {
        HStack(spacing: 8) {
            AvatarView(
                name: conversation.participant?.displayName ?? "?",
                color: conversation.participant?.avatarColor ?? "#6C63FF",
                avatarUrl: conversation.participant?.avatarUrl,
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
}

final class KeyboardObserver: ObservableObject {
    @Published var isVisible = false
    @Published var height: CGFloat = 0
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)
            .compactMap { $0.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] frame in
                self?.height = frame.height
                self?.isVisible = true
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.height = 0
                self?.isVisible = false
            }
            .store(in: &cancellables)
    }
}
