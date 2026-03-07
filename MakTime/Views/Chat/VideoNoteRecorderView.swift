import SwiftUI
import AVFoundation

struct VideoNoteRecorderView: View {
    let onFinish: (URL, TimeInterval) -> Void
    let onCancel: () -> Void

    @StateObject private var recorder = VideoNoteRecorder()
    @State private var showPermissionAlert = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 28) {
                Spacer()

                // Circular camera preview
                ZStack {
                    // Outer ring — animated gradient while recording
                    if recorder.isRecording {
                        Circle()
                            .strokeBorder(Theme.gradientNeon, lineWidth: 3)
                            .frame(width: 274, height: 274)
                            .rotationEffect(.degrees(recorder.isRecording ? 360 : 0))
                            .animation(
                                .linear(duration: 4).repeatForever(autoreverses: false),
                                value: recorder.isRecording
                            )
                    } else {
                        Circle()
                            .stroke(Theme.glassBorder, lineWidth: 2)
                            .frame(width: 274, height: 274)
                    }

                    // Camera preview clipped to circle
                    CameraPreviewView(session: recorder.session)
                        .frame(width: 268, height: 268)
                        .clipShape(Circle())

                    // Duration overlay (top of circle)
                    if recorder.isRecording {
                        VStack {
                            HStack(spacing: 5) {
                                Circle()
                                    .fill(Theme.danger)
                                    .frame(width: 8, height: 8)
                                    .opacity(recorder.blinkState ? 1 : 0.2)
                                    .animation(.easeInOut(duration: 0.5).repeatForever(), value: recorder.blinkState)
                                Text(formatDuration(recorder.duration))
                                    .font(.system(.subheadline, design: .monospaced).weight(.semibold))
                                    .foregroundColor(.white)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 5)
                            .background(.black.opacity(0.55))
                            .clipShape(Capsule())
                            .padding(.top, 10)
                            Spacer()
                        }
                        .frame(width: 268, height: 268)
                    }

                    // Progress arc
                    if recorder.isRecording {
                        Circle()
                            .trim(from: 0, to: min(recorder.duration / 60, 1))
                            .stroke(
                                Theme.gradientAccent,
                                style: StrokeStyle(lineWidth: 4, lineCap: .round)
                            )
                            .frame(width: 278, height: 278)
                            .rotationEffect(.degrees(-90))
                            .animation(.linear(duration: 0.1), value: recorder.duration)
                    }
                }

                // Hint text
                Text(recorder.isRecording ? "Нажмите стоп, чтобы отправить" : "Нажмите кнопку для записи")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundColor(.white.opacity(0.7))

                // Control buttons
                HStack(spacing: 52) {
                    // Cancel
                    Button {
                        recorder.stop()
                        onCancel()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 60, height: 60)
                            .background(.white.opacity(0.12))
                            .clipShape(Circle())
                    }

                    // Record / Stop
                    Button {
                        if recorder.isRecording {
                            recorder.stop()
                        } else {
                            recorder.startRecording()
                        }
                    } label: {
                        ZStack {
                            Circle()
                                .fill(recorder.isRecording ? Theme.danger : Color.white)
                                .frame(width: 72, height: 72)

                            if recorder.isRecording {
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color.white)
                                    .frame(width: 24, height: 24)
                            } else {
                                Circle()
                                    .fill(Theme.danger)
                                    .frame(width: 54, height: 54)
                            }
                        }
                        .animation(.spring(response: 0.3), value: recorder.isRecording)
                    }
                    .scaleEffect(recorder.isRecording ? 1.05 : 1)
                    .animation(.spring(response: 0.3), value: recorder.isRecording)

                    // Flip camera
                    Button {
                        recorder.flipCamera()
                    } label: {
                        Image(systemName: "arrow.triangle.2.circlepath.camera")
                            .font(.system(size: 22))
                            .foregroundColor(.white)
                            .frame(width: 60, height: 60)
                            .background(.white.opacity(0.12))
                            .clipShape(Circle())
                    }
                }

                Spacer().frame(height: 20)
            }
        }
        .onAppear { recorder.setup(onFinish: onFinish) }
        .onDisappear { recorder.stop() }
    }

    private func formatDuration(_ t: TimeInterval) -> String {
        let s = Int(t)
        return String(format: "%d:%02d", s / 60, s % 60)
    }
}

// MARK: - Recorder ViewModel
@MainActor
final class VideoNoteRecorder: ObservableObject {
    @Published var isRecording = false
    @Published var duration: TimeInterval = 0
    @Published var blinkState = false

    private let mediaService = MediaService()
    private var blinkTimer: Timer?
    private var onFinish: ((URL, TimeInterval) -> Void)?

    var session: AVCaptureSession { mediaService.captureSession ?? AVCaptureSession() }

    func setup(onFinish: @escaping (URL, TimeInterval) -> Void) {
        self.onFinish = onFinish
        mediaService.onVideoNoteReady = { [weak self] url, duration in
            Task { @MainActor [weak self] in
                self?.isRecording = false
                onFinish(url, duration)
            }
        }
        Task.detached(priority: .userInitiated) { [weak self] in
            guard let self else { return }
            if let session = try? await self.mediaService.setupCaptureSession() {
                session.startRunning()
            }
        }
    }

    func startRecording() {
        isRecording = true
        duration = 0
        mediaService.startVideoNoteRecording()
        blinkState = true
        blinkTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.blinkState.toggle() }
        }
        // Update duration display
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] t in
            Task { @MainActor [weak self] in
                guard let self, self.isRecording else { t.invalidate(); return }
                self.duration = self.mediaService.videoDuration
            }
        }
    }

    func stop() {
        blinkTimer?.invalidate()
        blinkTimer = nil
        if isRecording {
            mediaService.stopVideoNoteRecording()
        } else {
            mediaService.teardownCaptureSession()
        }
        isRecording = false
    }

    func flipCamera() {
        guard let session = mediaService.captureSession else { return }
        Task.detached(priority: .userInitiated) {
            session.beginConfiguration()
            let currentInputs = session.inputs.compactMap { $0 as? AVCaptureDeviceInput }
            let videoInputs = currentInputs.filter { $0.device.hasMediaType(.video) }
            guard let current = videoInputs.first else { session.commitConfiguration(); return }

            let newPosition: AVCaptureDevice.Position = current.device.position == .front ? .back : .front
            if let newDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: newPosition),
               let newInput = try? AVCaptureDeviceInput(device: newDevice) {
                session.removeInput(current)
                if session.canAddInput(newInput) {
                    session.addInput(newInput)
                }
            }
            session.commitConfiguration()
        }
    }
}

// MARK: - Camera preview UIViewRepresentable
struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewUIView {
        let view = PreviewUIView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        view.previewLayer.connection?.automaticallyAdjustsVideoMirroring = false
        return view
    }

    func updateUIView(_ uiView: PreviewUIView, context: Context) {
        uiView.previewLayer.session = session
    }

    final class PreviewUIView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    }
}
