import SwiftUI

struct ContentView: View {
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var socketService: SocketService
    
    var body: some View {
        Group {
            if authService.isLoading && authService.token != nil {
                ZStack {
                    Theme.bgPrimary.ignoresSafeArea()
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.5)
                            .tint(Theme.accent)
                        Text("MakTime")
                            .font(.title2.weight(.bold))
                            .foregroundColor(Theme.textPrimary)
                    }
                }
            } else if authService.isAuthenticated {
                MainTabView()
            } else {
                AuthView()
            }
        }
        .animation(.easeInOut(duration: 0.3), value: authService.isAuthenticated)
    }
}
