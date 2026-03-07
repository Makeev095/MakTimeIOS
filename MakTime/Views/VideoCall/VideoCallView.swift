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

    @State private var localVideoCorner: Corner = .topTrailing
    @State private var localVideoDragOffset: CGSize = .zero

    @State private var pipPosition: CGPoint = .zero
    @State private var pipInitialized = false

    private let localVideoSize = CGSize(width: 110, height: 150)
    private let pipSize = CGSize(width: 150, height: 200)

    enum Corner {
        case topLeading, topTrailing, bottomLeading, bottomTrailing

        var alignment: Alignment {
            switch self {
            case .topLeading: return .topLeading
            case .topTrailing: return .topTrailing
            case .bottomLeading: return .bottomLeading
            case .bottomTrailing: return .bottomTrailing
            }
        }
    }

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

            if vm.status == .connected {
                if let localTrack = vm.webRTCService.localStream {
                    localVideoView(track: localTrack)
                }
            }

            if vm.status == .connected {
                VStack {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(target.name)
                                .font(.system(.headline, design: .rounded))
                                .foregroundColor(.white)
                            Text(vm.statusText)
                                .font(.system(.subheadline, design: .rounded))
                                .foregroundColor(.white.opacity(0.7))
                        }
                        Spacer()
                        Button(action: onToggleMinimize) {
                            Image(systemName: "arrow.down.right.and.arrow.up.left")
                                .font(.title3)
                                .foregroundColor(.white)
                                .padding(8)
                                .glassCard(cornerRadius: 20)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 60)
                    Spacer()
                }
            }

            VStack {
                Spacer()

                if vm.status == .rejected || vm.status == .unavailable || vm.status == .error {
                    Text(vm.statusText)
                        .font(.system(.headline, design: .rounded))
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
                                .glassCard(cornerRadius: 25)
                        }
                    }

                    Button(action: { vm.endCall() }) {
                        Image(systemName: "phone.down.fill")
                            .font(.title2)
                            .foregroundColor(.white)
                            .frame(width: 64, height: 64)
                            .background(Theme.danger)
                            .clipShape(Circle())
                            .neonGlow(Theme.danger, radius: 10)
                    }
                }
                .padding(.bottom, 50)
            }
        }
        .animation(.easeInOut(duration: 0.5), value: vm.status == .connected)
    }

    private func localVideoView(track: RTCVideoTrack) -> some View {
        GeometryReader { geo in
            WebRTCVideoView(track: track, mirror: true)
                .frame(width: localVideoSize.width, height: localVideoSize.height)
                .cornerRadius(14)
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.glassBorder, lineWidth: 1))
                .shadow(color: .black.opacity(0.4), radius: 8)
                .position(positionForCorner(localVideoCorner, in: geo.size))
                .offset(localVideoDragOffset)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            localVideoDragOffset = value.translation
                        }
                        .onEnded { value in
                            let currentPos = positionForCorner(localVideoCorner, in: geo.size)
                            let finalPoint = CGPoint(
                                x: currentPos.x + value.translation.width,
                                y: currentPos.y + value.translation.height
                            )
                            let newCorner = closestCorner(to: finalPoint, in: geo.size)
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                                localVideoCorner = newCorner
                                localVideoDragOffset = .zero
                            }
                        }
                )
        }
    }

    private func positionForCorner(_ corner: Corner, in size: CGSize) -> CGPoint {
        let halfW = localVideoSize.width / 2
        let halfH = localVideoSize.height / 2
        let padX: CGFloat = 16
        let topY: CGFloat = 70

        switch corner {
        case .topLeading:
            return CGPoint(x: halfW + padX, y: halfH + topY)
        case .topTrailing:
            return CGPoint(x: size.width - halfW - padX, y: halfH + topY)
        case .bottomLeading:
            return CGPoint(x: halfW + padX, y: size.height - halfH - 70)
        case .bottomTrailing:
            return CGPoint(x: size.width - halfW - padX, y: size.height - halfH - 70)
        }
    }

    private func closestCorner(to point: CGPoint, in size: CGSize) -> Corner {
        let corners: [Corner] = [.topLeading, .topTrailing, .bottomLeading, .bottomTrailing]
        return corners.min(by: { a, b in
            let posA = positionForCorner(a, in: size)
            let posB = positionForCorner(b, in: size)
            let distA = hypot(point.x - posA.x, point.y - posA.y)
            let distB = hypot(point.x - posB.x, point.y - posB.y)
            return distA < distB
        }) ?? .topTrailing
    }

    private var callingBackground: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(hex: "08080F"),
                    Color(hex: "0E0E1A"),
                    Color(hex: "141428")
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
                .fill(Theme.accentSecondary.opacity(0.05))
                .frame(width: pulse2 ? 450 : 280)
                .animation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true).delay(0.3), value: pulse2)

            Circle()
                .fill(Color(hex: "EC4899").opacity(0.03))
                .frame(width: pulse3 ? 550 : 350)
                .animation(.easeInOut(duration: 3.0).repeatForever(autoreverses: true).delay(0.6), value: pulse3)
        }
        .onAppear {
            pulse1 = true
            pulse2 = true
            pulse3 = true
        }
    }

    private var waitingOverlay: some View {
        VStack(spacing: 20) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Theme.accent.opacity(0.15))
                    .frame(width: pulse1 ? 160 : 130)
                    .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: pulse1)

                Circle()
                    .fill(Theme.accentSecondary.opacity(0.08))
                    .frame(width: pulse2 ? 190 : 150)
                    .animation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true).delay(0.2), value: pulse2)

                AvatarView(name: target.name, color: "#8B5CF6", size: 110)
                    .neonGlow(Theme.accent, radius: 20)
            }

            VStack(spacing: 8) {
                Text(target.name)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                Text(vm.statusText)
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundColor(.white.opacity(0.6))
            }

            Spacer()
            Spacer()
        }
    }

    private var pipView: some View {
        GeometryReader { geo in
            ZStack {
                if let remoteTrack = vm.remoteVideoTrack, vm.status == .connected {
                    WebRTCVideoView(track: remoteTrack)
                } else {
                    LinearGradient(
                        colors: [Color(hex: "0E0E1A"), Color(hex: "141428")],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    AvatarView(name: target.name, color: "#8B5CF6", size: 50)
                }

                VStack {
                    Spacer()
                    HStack(spacing: 6) {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(target.name)
                                .font(.system(size: 11, weight: .semibold, design: .rounded))
                                .foregroundColor(.white)
                                .lineLimit(1)
                            Text(vm.statusText)
                                .font(.system(size: 9, design: .rounded))
                                .foregroundColor(.white.opacity(0.7))
                        }
                        Spacer()
                        Button {
                            vm.endCall()
                        } label: {
                            Image(systemName: "phone.down.fill")
                                .font(.system(size: 14))
                                .foregroundColor(.white)
                                .padding(10)
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
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.glassBorder, lineWidth: 1))
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
                .background(isActive ? Theme.danger.opacity(0.7) : Color.white.opacity(0.12))
                .clipShape(Circle())
                .overlay(Circle().stroke(Theme.glassBorder, lineWidth: 1))
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
