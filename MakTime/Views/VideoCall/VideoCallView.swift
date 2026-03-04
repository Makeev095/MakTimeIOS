import SwiftUI
import WebRTC
import AVFoundation

struct VideoCallView: View {
    let target: CallTarget
    let minimized: Bool
    let onToggleMinimize: () -> Void
    let onEnd: () -> Void
    
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var socketService: SocketService
    @StateObject private var vm: VideoCallViewModel
    @State private var pulse1 = false
    @State private var pulse2 = false
    @State private var pulse3 = false
    
    init(target: CallTarget, minimized: Bool, onToggleMinimize: @escaping () -> Void, onEnd: @escaping () -> Void) {
        self.target = target
        self.minimized = minimized
        self.onToggleMinimize = onToggleMinimize
        self.onEnd = onEnd
        _vm = StateObject(wrappedValue: VideoCallViewModel(target: target))
    }
    
    var body: some View {
        Group {
            if minimized {
                pipView
            } else {
                fullscreenView
            }
        }
        .onAppear {
            vm.onEnd = onEnd
            vm.setup(socketService: socketService, callerName: authService.user?.displayName ?? "")
        }
    }
    
    private var isWaiting: Bool {
        vm.status == .calling || vm.status == .connecting
    }
    
    private var fullscreenView: some View {
        ZStack {
            // Background
            if vm.status == .connected, vm.remoteVideoTrack != nil {
                Color.black.ignoresSafeArea()
            } else {
                callingBackground
            }
            
            // Remote video (only when connected)
            if let remoteTrack = vm.remoteVideoTrack, vm.status == .connected {
                WebRTCVideoView(track: remoteTrack)
                    .ignoresSafeArea()
                    .transition(.opacity)
            }
            
            // Calling/connecting state - avatar + name
            if isWaiting || vm.remoteVideoTrack == nil {
                waitingOverlay
            }
            
            // Local video (small, top-right)
            if vm.status == .connected {
                VStack {
                    HStack {
                        Spacer()
                        if let localTrack = vm.webRTCService.localStream {
                            WebRTCVideoView(track: localTrack, mirror: true)
                                .frame(width: 110, height: 150)
                                .cornerRadius(14)
                                .shadow(color: .black.opacity(0.4), radius: 8)
                                .padding(.trailing, 16)
                                .padding(.top, 60)
                        }
                    }
                    Spacer()
                }
            }
            
            // Top bar (when connected)
            if vm.status == .connected {
                VStack {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(target.name)
                                .font(.headline)
                                .foregroundColor(.white)
                            Text(vm.statusText)
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.7))
                        }
                        Spacer()
                        Button(action: onToggleMinimize) {
                            Image(systemName: "arrow.down.right.and.arrow.up.left")
                                .font(.title3)
                                .foregroundColor(.white)
                                .padding(8)
                                .background(.ultraThinMaterial)
                                .clipShape(Circle())
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 60)
                    Spacer()
                }
            }
            
            // Controls
            VStack {
                Spacer()
                
                if vm.status == .rejected || vm.status == .unavailable || vm.status == .error {
                    Text(vm.statusText)
                        .font(.headline)
                        .foregroundColor(.white.opacity(0.8))
                        .padding(.bottom, 20)
                }
                
                HStack(spacing: 24) {
                    if vm.status == .connected {
                        callButton(icon: vm.isMuted ? "mic.slash.fill" : "mic.fill",
                                  isActive: vm.isMuted) { vm.toggleMute() }
                        callButton(icon: vm.isVideoOff ? "video.slash.fill" : "video.fill",
                                  isActive: vm.isVideoOff) { vm.toggleVideo() }
                        callButton(icon: "arrow.triangle.2.circlepath.camera", isActive: false) { vm.switchCamera() }
                        
                        Button(action: onToggleMinimize) {
                            Image(systemName: "arrow.down.right.and.arrow.up.left")
                                .font(.title3)
                                .foregroundColor(.white)
                                .frame(width: 50, height: 50)
                                .background(.white.opacity(0.2))
                                .clipShape(Circle())
                        }
                    }
                    
                    Button(action: { vm.endCall() }) {
                        Image(systemName: "phone.down.fill")
                            .font(.title2)
                            .foregroundColor(.white)
                            .frame(width: 64, height: 64)
                            .background(Theme.danger)
                            .clipShape(Circle())
                            .shadow(color: Theme.danger.opacity(0.4), radius: 8)
                    }
                }
                .padding(.bottom, 50)
            }
        }
        .animation(.easeInOut(duration: 0.5), value: vm.status == .connected)
    }
    
    // MARK: - Calling Background with Animations
    
    private var callingBackground: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(hex: "0F0F2D"),
                    Color(hex: "1A1145"),
                    Color(hex: "0D0D26")
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            Circle()
                .fill(Theme.accent.opacity(0.08))
                .frame(width: pulse1 ? 350 : 200)
                .animation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true), value: pulse1)
            
            Circle()
                .fill(Theme.accent.opacity(0.05))
                .frame(width: pulse2 ? 450 : 280)
                .animation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true).delay(0.3), value: pulse2)
            
            Circle()
                .fill(Theme.accent.opacity(0.03))
                .frame(width: pulse3 ? 550 : 350)
                .animation(.easeInOut(duration: 3.0).repeatForever(autoreverses: true).delay(0.6), value: pulse3)
        }
        .onAppear {
            pulse1 = true
            pulse2 = true
            pulse3 = true
        }
    }
    
    // MARK: - Waiting Overlay (calling/connecting state)
    
    private var waitingOverlay: some View {
        VStack(spacing: 20) {
            Spacer()
            
            ZStack {
                Circle()
                    .fill(Theme.accent.opacity(0.15))
                    .frame(width: pulse1 ? 160 : 130)
                    .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: pulse1)
                
                Circle()
                    .fill(Theme.accent.opacity(0.1))
                    .frame(width: pulse2 ? 190 : 150)
                    .animation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true).delay(0.2), value: pulse2)
                
                AvatarView(name: target.name, color: "#6C63FF", size: 110)
                    .shadow(color: Theme.accent.opacity(0.3), radius: 20)
            }
            
            VStack(spacing: 8) {
                Text(target.name)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)
                
                Text(vm.statusText)
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.6))
            }
            
            Spacer()
            Spacer()
        }
    }
    
    // MARK: - PiP View
    
    private var pipView: some View {
        HStack(spacing: 12) {
            AvatarView(name: target.name, color: "#6C63FF", size: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text(target.name)
                    .font(.caption.weight(.medium))
                    .foregroundColor(.white)
                    .lineLimit(1)
                Text(vm.statusText)
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.7))
            }
            Spacer()
            Button { vm.toggleMute() } label: {
                Image(systemName: vm.isMuted ? "mic.slash.fill" : "mic.fill")
                    .foregroundColor(vm.isMuted ? Theme.danger : .white)
                    .font(.caption)
            }
            Button { vm.endCall() } label: {
                Image(systemName: "phone.down.fill")
                    .foregroundColor(.white)
                    .font(.caption)
                    .padding(6)
                    .background(Theme.danger)
                    .clipShape(Circle())
            }
            Button(action: onToggleMinimize) {
                Image(systemName: "arrow.up.left.and.arrow.down.right")
                    .foregroundColor(.white)
                    .font(.caption)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.black.opacity(0.85))
        .cornerRadius(16)
        .shadow(radius: 8)
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .padding(.bottom, 100)
        .onTapGesture(perform: onToggleMinimize)
    }
    
    private func callButton(icon: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.white)
                .frame(width: 50, height: 50)
                .background(isActive ? Theme.danger.opacity(0.7) : .white.opacity(0.2))
                .clipShape(Circle())
        }
    }
}

struct WebRTCVideoView: UIViewRepresentable {
    let track: RTCVideoTrack
    var mirror: Bool = false
    
    func makeUIView(context: Context) -> RTCMTLVideoView {
        let view = RTCMTLVideoView()
        view.videoContentMode = .scaleAspectFill
        view.clipsToBounds = true
        if mirror {
            view.transform = CGAffineTransform(scaleX: -1, y: 1)
        }
        track.add(view)
        return view
    }
    
    func updateUIView(_ uiView: RTCMTLVideoView, context: Context) {}
    
    static func dismantleUIView(_ uiView: RTCMTLVideoView, coordinator: ()) {}
}
