import SwiftUI

struct ContentView: View {
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var socketService: SocketService
    @State private var logoScale: CGFloat = 0.5
    @State private var logoOpacity: CGFloat = 0
    @State private var glowPulse = false

    var body: some View {
        Group {
            if authService.isLoading && authService.token != nil {
                ZStack {
                    Theme.bgPrimary.ignoresSafeArea()
                    VStack(spacing: 20) {
                        Text("Makke")
                            .font(.system(size: 42, weight: .bold, design: .rounded))
                            .foregroundStyle(Theme.gradientAccent)
                            .shadow(color: Theme.accent.opacity(glowPulse ? 0.6 : 0.2), radius: glowPulse ? 20 : 8)
                            .scaleEffect(logoScale)
                            .opacity(logoOpacity)
                        ProgressView()
                            .scaleEffect(1.2)
                            .tint(Theme.accent)
                            .opacity(logoOpacity)
                    }
                    .onAppear {
                        withAnimation(.spring(response: 0.8, dampingFraction: 0.6)) {
                            logoScale = 1.0
                            logoOpacity = 1.0
                        }
                        withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                            glowPulse = true
                        }
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
