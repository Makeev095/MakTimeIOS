import SwiftUI
import WebRTC

struct VideoCallView: View {
    let target: CallTarget
    let minimized: Bool
    let onToggleMinimize: () -> Void
    let onEnd: () -> Void
    
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var socketService: SocketService
    @StateObject private var vm: VideoCallViewModel
    
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
    
    private var fullscreenView: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            // Remote video
            if let remoteTrack = vm.remoteVideoTrack {
                WebRTCVideoView(track: remoteTrack)
                    .ignoresSafeArea()
            } else {
                VStack(spacing: 16) {
                    AvatarView(name: target.name, color: "#6C63FF", size: 100)
                    Text(target.name)
                        .font(.title2.weight(.semibold))
                        .foregroundColor(.white)
                }
            }
            
            // Local video (small)
            VStack {
                HStack {
                    Spacer()
                    if let localTrack = vm.webRTCService.localStream {
                        WebRTCVideoView(track: localTrack, mirror: true)
                            .frame(width: 120, height: 160)
                            .cornerRadius(12)
                            .shadow(radius: 4)
                            .padding(.trailing, 16)
                            .padding(.top, 60)
                    }
                }
                Spacer()
            }
            
            // Top bar
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
            
            // Controls
            VStack {
                Spacer()
                HStack(spacing: 24) {
                    callButton(icon: vm.isMuted ? "mic.slash.fill" : "mic.fill",
                              isActive: vm.isMuted) { vm.toggleMute() }
                    callButton(icon: vm.isVideoOff ? "video.slash.fill" : "video.fill",
                              isActive: vm.isVideoOff) { vm.toggleVideo() }
                    callButton(icon: "arrow.triangle.2.circlepath.camera", isActive: false) { vm.switchCamera() }
                    
                    Button(action: { vm.endCall() }) {
                        Image(systemName: "phone.down.fill")
                            .font(.title2)
                            .foregroundColor(.white)
                            .frame(width: 60, height: 60)
                            .background(Theme.danger)
                            .clipShape(Circle())
                    }
                }
                .padding(.bottom, 50)
            }
        }
    }
    
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
    
    static func dismantleUIView(_ uiView: RTCMTLVideoView, coordinator: ()) {
        // track removal handled by WebRTCService cleanup
    }
}
