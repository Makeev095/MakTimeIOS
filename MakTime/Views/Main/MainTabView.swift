import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var socketService: SocketService
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
                    ConversationListView(
                        selectedConversation: $selectedConversation,
                        onStartCall: { userId, name, convId in
                            callTarget = CallTarget(userId: userId, name: name, conversationId: convId, isInitiator: true)
                        }
                    )
                    .tabItem {
                        Label("Чаты", systemImage: "message.fill")
                    }
                    .tag(0)
                    
                    ContactsView { user in
                        Task {
                            let conv = try? await APIService.shared.createConversation(participantId: user.id)
                            if let conv = conv {
                                selectedConversation = conv
                                selectedTab = 0
                            }
                        }
                    }
                    .tabItem {
                        Label("Контакты", systemImage: "person.2.fill")
                    }
                    .tag(1)
                    
                    SettingsView()
                        .tabItem {
                            Label("Настройки", systemImage: "gearshape.fill")
                        }
                        .tag(2)
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
            }
            
            // Incoming call overlay
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
            
            // Active call
            if let target = callTarget {
                VideoCallView(
                    target: target,
                    minimized: callMinimized,
                    onToggleMinimize: { callMinimized.toggle() },
                    onEnd: {
                        callTarget = nil
                        callMinimized = false
                    }
                )
            }
        }
    }
}

struct CallTarget: Equatable {
    let userId: String
    let name: String
    let conversationId: String
    let isInitiator: Bool
}
