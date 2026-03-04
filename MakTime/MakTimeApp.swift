import SwiftUI

@main
struct MakTimeApp: App {
    @StateObject private var authService = AuthService()
    @StateObject private var socketService = SocketService()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authService)
                .environmentObject(socketService)
                .preferredColorScheme(.dark)
                .onAppear {
                    authService.tryAutoLogin()
                }
                .onChange(of: authService.token) { newToken in
                    if let token = newToken {
                        socketService.connect(token: token)
                    } else {
                        socketService.disconnect()
                    }
                }
        }
    }
}
