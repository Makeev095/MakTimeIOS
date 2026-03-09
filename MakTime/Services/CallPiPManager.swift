import AVKit
import WebRTC
import UIKit

@MainActor
final class CallPiPManager: NSObject, ObservableObject {
    @Published var isPiPActive = false
    @Published var isRestoring = false

    private var pipController: AVPictureInPictureController?
    private var pipContentVC: AVPictureInPictureVideoCallViewController?
    private var remoteVideoView: RTCMTLVideoView?
    private var currentRemoteTrack: RTCVideoTrack?
    private var startPiPRetryCount = 0
    private let maxRetries = 5

    var onRestoreFullScreen: (() -> Void)?

    // MARK: - Setup

    /// Call as soon as a remote track is available (or earlier with nil track for placeholder).
    func setup(sourceView: UIView, remoteTrack: RTCVideoTrack?) {
        guard AVPictureInPictureController.isPictureInPictureSupported() else { return }

        // Detach old track if re-setting up
        if let old = currentRemoteTrack, let view = remoteVideoView {
            old.remove(view)
        }

        let vc = AVPictureInPictureVideoCallViewController()
        vc.preferredContentSize = CGSize(width: 180, height: 240)

        let videoView = RTCMTLVideoView(frame: vc.view.bounds)
        videoView.videoContentMode = .scaleAspectFill
        videoView.clipsToBounds = true
        videoView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        vc.view.addSubview(videoView)

        if let track = remoteTrack {
            track.add(videoView)
        }

        let source = AVPictureInPictureController.ContentSource(
            activeVideoCallSourceView: sourceView,
            contentViewController: vc
        )

        let ctrl = AVPictureInPictureController(contentSource: source)
        ctrl.delegate = self
        ctrl.canStartPictureInPictureAutomaticallyFromInline = true

        self.pipContentVC = vc
        self.remoteVideoView = videoView
        self.pipController = ctrl
        self.currentRemoteTrack = remoteTrack
    }

    /// Update remote track after initial setup (e.g. when track arrives after app was backgrounded).
    func updateRemoteTrack(_ track: RTCVideoTrack) {
        if let old = currentRemoteTrack, let view = remoteVideoView {
            old.remove(view)
        }
        currentRemoteTrack = track
        if let view = remoteVideoView {
            track.add(view)
        }
    }

    // MARK: - Control

    func startPiP() {
        guard AVPictureInPictureController.isPictureInPictureSupported() else { return }
        startPiPRetryCount = 0
        attemptStartPiP()
    }

    private func attemptStartPiP() {
        guard let ctrl = pipController else { return }

        if ctrl.isPictureInPicturePossible {
            ctrl.startPictureInPicture()
            startPiPRetryCount = 0
        } else if startPiPRetryCount < maxRetries {
            startPiPRetryCount += 1
            let delay = Double(startPiPRetryCount) * 0.4
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                self?.attemptStartPiP()
            }
        } else {
            print("PiP: failed to start after \(maxRetries) retries")
            startPiPRetryCount = 0
        }
    }

    func stopPiP() {
        pipController?.stopPictureInPicture()
    }

    func cleanup() {
        stopPiP()
        startPiPRetryCount = 0
        if let track = currentRemoteTrack, let view = remoteVideoView {
            track.remove(view)
        }
        pipController = nil
        pipContentVC = nil
        remoteVideoView = nil
        currentRemoteTrack = nil
        isPiPActive = false
    }
}

// MARK: - AVPictureInPictureControllerDelegate

extension CallPiPManager: AVPictureInPictureControllerDelegate {

    nonisolated func pictureInPictureControllerWillStartPictureInPicture(
        _ controller: AVPictureInPictureController
    ) {
        Task { @MainActor in self.isPiPActive = true }
    }

    nonisolated func pictureInPictureControllerDidStartPictureInPicture(
        _ controller: AVPictureInPictureController
    ) {
        Task { @MainActor in self.isPiPActive = true }
    }

    nonisolated func pictureInPictureControllerWillStopPictureInPicture(
        _ controller: AVPictureInPictureController
    ) {
        Task { @MainActor in self.isPiPActive = false }
    }

    nonisolated func pictureInPictureControllerDidStopPictureInPicture(
        _ controller: AVPictureInPictureController
    ) {
        Task { @MainActor in self.isPiPActive = false }
    }

    nonisolated func pictureInPictureController(
        _ controller: AVPictureInPictureController,
        restoreUserInterfaceForPictureInPictureStopWithCompletionHandler completionHandler: @escaping (Bool) -> Void
    ) {
        Task { @MainActor in
            self.isRestoring = true
            self.onRestoreFullScreen?()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self.isRestoring = false
                completionHandler(true)
            }
        }
    }

    nonisolated func pictureInPictureController(
        _ controller: AVPictureInPictureController,
        failedToStartPictureInPictureWithError error: Error
    ) {
        print("PiP failed: \(error.localizedDescription)")
        Task { @MainActor in
            // Retry once after a short delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                self?.attemptStartPiP()
            }
        }
    }
}
