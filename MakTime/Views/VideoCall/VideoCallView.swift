import SwiftUI
import WebRTC
import AVFoundation

struct VideoCallView: View {
    let target: CallTarget
    let minimized: Bool
    let onToggleMinimize: () -> Void
    let onEnd: () -> Void
    let pipManager: CallPiPManager

    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var socketService: SocketService
    @StateObject private var vm: VideoCallViewModel

    @State private var pulse1 = false
    @State private var pulse2 = false
    @State private var pulse3 = false

    // Draggable PiP window position
    @State private var pipOffset: CGSize = .zero
    @GestureState private var dragOffset: CGSize = .zero

    init(target: CallTarget,
         minimized: Bool,
         onToggleMinimize: @escaping () -> Void,
         onEnd: @escaping () -> Void,
         pipManager: CallPiPManager) {
        self.target = target
        self.minimized = minimized
        self.onToggleMinimize = onToggleMinimize
        self.onEnd = onEnd
        self.pipManager = pipManager
        _vm = StateObject(wrappedValue: VideoCallViewModel(target: target))
    }

    var body: some View {
        Group {
            if minimized {
                pipOverlay
            } else {
                fullscreenView
            }
        }
        .onAppear {
            vm.onEnd = onEnd
            vm.setup(socketService: socketService, callerName: authService.user?.displayName ?? "")
        }
        .onChange(of: vm.status) { status in
            // Initialize PiP (with placeholder) as soon as call starts
            if status == .calling || status == .connecting {
                initPiPEarly()
            }
            // Update with real remote track when connected
            if status == .connected, let remoteTrack = vm.remoteVideoTrack {
                pipManager.updateRemoteTrack(remoteTrack)
            }
        }
        .onChange(of: vm.remoteVideoTrack != nil) { hasTrack in
            if hasTrack, let remoteTrack = vm.remoteVideoTrack {
                pipManager.updateRemoteTrack(remoteTrack)
            }
        }
    }

    private func initPiPEarly() {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = scene.windows.first else { return }
        // Setup with nil track (placeholder) so PiP controller is ready before we go background
        pipManager.setup(sourceView: window, remoteTrack: nil)
    }

    private var isWaiting: Bool {
        vm.status == .calling || vm.status == .connecting
    }

    // MARK: - Minimized floating PiP overlay

    private var pipOverlay: some View {
        ZStack {
            // Transparent hit-test passthrough background so TabBar is usable
            Color.clear
                .ignoresSafeArea()
                .allowsHitTesting(false)

            pipWindow
                .offset(x: pipOffset.width + dragOffset.width,
                        y: pipOffset.height + dragOffset.height)
                .gesture(
                    DragGesture()
                        .updating($dragOffset) { value, state, _ in
                            state = value.translation
                        }
                        .onEnded { value in
                            pipOffset = CGSize(
                                width: pipOffset.width + value.translation.width,
                                height: pipOffset.height + value.translation.height
                            )
                        }
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                .padding(.trailing, 16)
                .padding(.bottom, 120)
        }
    }

    private var pipWindow: some View {
        ZStack(alignment: .topLeading) {
            // Remote video or avatar background
            Group {
                if let remoteTrack = vm.remoteVideoTrack {
                    WebRTCVideoView(track: remoteTrack)
                        .frame(width: 160, height: 220)
                } else {
                    ZStack {
                        LinearGradient(
                            colors: [Color(hex: "1A1145"), Color(hex: "0D0D26")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        AvatarView(name: target.name, color: "#6C63FF", size: 60)
                    }
                    .frame(width: 160, height: 220)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 20))

            // Local camera (small overlay, top-right)
            if let localTrack = vm.webRTCService.localStream, vm.status == .connected {
                WebRTCVideoView(track: localTrack, mirror: true)
                    .frame(width: 48, height: 64)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.4), lineWidth: 1))
                    .shadow(color: .black.opacity(0.4), radius: 4)
                    .padding(6)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }

            // Status label (top-left when not connected)
            if vm.status != .connected {
                Text(vm.statusText)
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.8))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.black.opacity(0.5))
                    .clipShape(Capsule())
                    .padding(8)
            }

            // Controls overlay at bottom
            VStack {
                Spacer()
                HStack(spacing: 0) {
                    // Mute
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        vm.toggleMute()
                    } label: {
                        Image(systemName: vm.isMuted ? "mic.slash.fill" : "mic.fill")
                            .font(.system(size: 13))
                            .foregroundColor(.white)
                            .frame(width: 34, height: 34)
                            .background(.black.opacity(0.55))
                            .clipShape(Circle())
                    }

                    Spacer()

                    // Expand
                    Button(action: onToggleMinimize) {
                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                            .font(.system(size: 13))
                            .foregroundColor(.white)
                            .frame(width: 34, height: 34)
                            .background(.black.opacity(0.55))
                            .clipShape(Circle())
                    }

                    Spacer()

                    // End call
                    Button {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        vm.endCall()
                    } label: {
                        Image(systemName: "phone.down.fill")
                            .font(.system(size: 13))
                            .foregroundColor(.white)
                            .frame(width: 34, height: 34)
                            .background(Theme.danger)
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal, 10)
                .padding(.bottom, 10)
            }
            .frame(width: 160, height: 220)
        }
        .frame(width: 160, height: 220)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.5), radius: 16, x: 0, y: 8)
    }

    // MARK: - Fullscreen view

    private var fullscreenView: some View {
        ZStack {
            if vm.status == .connected, vm.remoteVideoTrack != nil {
                Color.black.ignoresSafeArea()
            } else {
                callingBackground
            }

            if let remoteTrack = vm.remoteVideoTrack, vm.status == .connected {
                WebRTCVideoView(track: remoteTrack)
                    .ignoresSafeArea()
                    .transition(.opacity)
            }

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

    // MARK: - Calling background

    private var callingBackground: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: "0F0F2D"), Color(hex: "1A1145"), Color(hex: "0D0D26")],
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
        .onAppear { pulse1 = true; pulse2 = true; pulse3 = true }
    }

    // MARK: - Waiting overlay

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

// MARK: - WebRTC Video View

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
