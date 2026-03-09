import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var socketService: SocketService
    @StateObject private var pipManager = CallPiPManager()
    @State private var selectedTab = 0
    @State private var selectedConversation: Conversation?
    @State private var navigateToChat = false
    @State private var callTarget: CallTarget?
    @State private var callMinimized = false
    @State private var showStoryViewer = false
    @State private var storyViewData: (users: [StoryUser], startIdx: Int)?
    @State private var showStoryUpload = false

    var body: some View {
        ZStack {
            NavigationStack {
                TabView(selection: $selectedTab) {
                    chatsTab
                        .tabItem {
                            Label("Чаты", systemImage: "message.fill")
                        }
                        .tag(0)

                    FeedView()
                        .tabItem {
                            Label("Лента", systemImage: "square.grid.2x2.fill")
                        }
                        .tag(1)

                    ContactsView { user in
                        Task {
                            if let conv = try? await APIService.shared.createConversation(participantId: user.id) {
                                selectedConversation = conv
                                selectedTab = 0
                            }
                        }
                    }
                    .tabItem {
                        Label("Контакты", systemImage: "person.2.fill")
                    }
                    .tag(2)

                    SettingsView()
                        .tabItem {
                            Label("Настройки", systemImage: "gearshape.fill")
                        }
                        .tag(3)
                }
                .tint(Theme.accent)
                .navigationDestination(isPresented: $navigateToChat) {
                    if let conv = selectedConversation {
                        ChatView(
                            conversation: conv,
                            onStartCall: { userId, name, convId in
                                callTarget = CallTarget(userId: userId, name: name, conversationId: convId, isInitiator: true)
                            }
                        )
                    }
                }
                .onChange(of: selectedConversation) { newValue in
                    navigateToChat = newValue != nil
                }
                .onChange(of: navigateToChat) { isPresented in
                    if !isPresented {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            selectedConversation = nil
                        }
                    }
                }
            }

            if let incoming = socketService.incomingCall, callTarget == nil {
                IncomingCallOverlay(
                    call: incoming,
                    onAccept: {
                        callTarget = CallTarget(
                            userId: incoming.from,
                            name: incoming.callerName,
                            conversationId: incoming.conversationId,
                            isInitiator: false
                        )
                        socketService.incomingCall = nil
                    },
                    onReject: {
                        socketService.rejectCall(to: incoming.from)
                        socketService.incomingCall = nil
                    }
                )
            }

            if let target = callTarget {
                VideoCallView(
                    target: target,
                    minimized: callMinimized,
                    onToggleMinimize: { callMinimized.toggle() },
                    onEnd: {
                        pipManager.cleanup()
                        callTarget = nil
                        callMinimized = false
                    },
                    pipManager: pipManager
                )
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
            if callTarget != nil {
                // Small delay so the PiP controller finishes setup before activation
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    pipManager.startPiP()
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            if pipManager.isPiPActive {
                pipManager.stopPiP()
            }
        }
        .onAppear {
            pipManager.onRestoreFullScreen = {
                callMinimized = false
            }
        }
        .fullScreenCover(isPresented: $showStoryViewer) {
            if let data = storyViewData {
                StoryViewerView(
                    storyUsers: data.users,
                    startUserIdx: data.startIdx,
                    onClose: { showStoryViewer = false }
                )
            }
        }
        .sheet(isPresented: $showStoryUpload) {
            StoryUploadView(
                onClose: { showStoryUpload = false },
                onPublished: { showStoryUpload = false }
            )
        }
    }
    
    private var chatsTab: some View {
        VStack(spacing: 0) {
            StoryBarView(
                onViewStories: { users, idx in
                    storyViewData = (users, idx)
                    showStoryViewer = true
                },
                onAddStory: { showStoryUpload = true }
            )
            
            Divider().background(Theme.border)
            
            ConversationListView(
                selectedConversation: $selectedConversation,
                onStartCall: { userId, name, convId in
                    callTarget = CallTarget(userId: userId, name: name, conversationId: convId, isInitiator: true)
                }
            )
        }
    }
}

struct CallTarget: Equatable {
    let userId: String
    let name: String
    let conversationId: String
    let isInitiator: Bool
}
