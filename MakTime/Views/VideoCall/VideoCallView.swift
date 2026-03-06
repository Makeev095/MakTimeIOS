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

    // Draggable local video position
    @State private var localVideoPosition: CGPoint = .zero
    @State private var localVideoInitialized = false

    // Draggable PiP position
    @State private var pipPosition: CGPoint = .zero
    @State private var pipInitialized = false

    private let localVideoSize = CGSize(width: 110, height: 150)
    private let pipSize = CGSize(width: 150, height: 200)

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
        GeometryReader { geo in
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

                // Local video (draggable)
                if vm.status == .connected {
                    if let localTrack = vm.webRTCService.localStream {
                        WebRTCVideoView(track: localTrack, mirror: true)
                            .frame(width: localVideoSize.width, height: localVideoSize.height)
                            .cornerRadius(14)
                            .shadow(color: .black.opacity(0.4), radius: 8)
                            .position(localVideoInitialized ? localVideoPosition : defaultLocalVideoPosition(in: geo))
                            .gesture(
                                DragGesture()
                                    .onChanged { value in
                                        localVideoPosition = value.location
                                    }
                                    .onEnded { value in
                                        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                                            localVideoPosition = snapToCorner(
                                                point: value.location,
                                                in: geo.size,
                                                itemSize: localVideoSize,
                                                padding: 16,
                                                topInset: 70
                                            )
                                        }
                                    }
                            )
                            .onAppear {
                                if !localVideoInitialized {
                                    localVideoPosition = defaultLocalVideoPosition(in: geo)
                                    localVideoInitialized = true
                                }
                            }
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
    }

    // MARK: - Snap to Corner

    private func defaultLocalVideoPosition(in geo: GeometryProxy) -> CGPoint {
        CGPoint(
            x: geo.size.width - localVideoSize.width / 2 - 16,
            y: localVideoSize.height / 2 + 70
        )
    }

    private func snapToCorner(point: CGPoint, in size: CGSize, itemSize: CGSize, padding: CGFloat, topInset: CGFloat) -> CGPoint {
        let halfW = itemSize.width / 2
        let halfH = itemSize.height / 2
        let left = halfW + padding
        let right = size.width - halfW - padding
        let top = halfH + topInset
        let bottom = size.height - halfH - padding - 60

        let x = point.x < size.width / 2 ? left : right
        let y = point.y < size.height / 2 ? top : bottom

        return CGPoint(x: x, y: y)
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

    // MARK: - PiP View (Telegram-style floating window)

    private var pipView: some View {
        GeometryReader { geo in
            ZStack {
                // Video or avatar content
                if let remoteTrack = vm.remoteVideoTrack, vm.status == .connected {
                    WebRTCVideoView(track: remoteTrack)
                } else {
                    LinearGradient(
                        colors: [Color(hex: "1A1145"), Color(hex: "0D0D26")],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    AvatarView(name: target.name, color: "#6C63FF", size: 50)
                }

                // Overlay info
                VStack {
                    Spacer()
                    HStack(spacing: 6) {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(target.name)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.white)
                                .lineLimit(1)
                            Text(vm.statusText)
                                .font(.system(size: 9))
                                .foregroundColor(.white.opacity(0.7))
                        }
                        Spacer()
                        Button {
                            vm.endCall()
                        } label: {
                            Image(systemName: "phone.down.fill")
                                .font(.system(size: 10))
                                .foregroundColor(.white)
                                .padding(6)
                                .background(Theme.danger)
                                .clipShape(Circle())
                        }
                    }
                    .padding(8)
                    .background(
                        LinearGradient(
                            colors: [.clear, .black.opacity(0.7)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                }
            }
            .frame(width: pipSize.width, height: pipSize.height)
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.5), radius: 12, x: 0, y: 4)
            .position(pipInitialized ? pipPosition : defaultPipPosition(in: geo))
            .gesture(
                DragGesture()
                    .onChanged { value in
                        pipPosition = value.location
                    }
                    .onEnded { value in
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                            pipPosition = snapToEdge(
                                point: value.location,
                                in: geo.size,
                                itemSize: pipSize
                            )
                        }
                    }
            )
            .onTapGesture(perform: onToggleMinimize)
            .onAppear {
                if !pipInitialized {
                    pipPosition = defaultPipPosition(in: geo)
                    pipInitialized = true
                }
            }
        }
    }

    private func defaultPipPosition(in geo: GeometryProxy) -> CGPoint {
        CGPoint(
            x: geo.size.width - pipSize.width / 2 - 16,
            y: geo.size.height - pipSize.height / 2 - 120
        )
    }

    private func snapToEdge(point: CGPoint, in size: CGSize, itemSize: CGSize) -> CGPoint {
        let halfW = itemSize.width / 2
        let halfH = itemSize.height / 2
        let padding: CGFloat = 12

        let x: CGFloat
        if point.x < size.width / 2 {
            x = halfW + padding
        } else {
            x = size.width - halfW - padding
        }

        let y = min(max(point.y, halfH + 60), size.height - halfH - 100)

        return CGPoint(x: x, y: y)
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
