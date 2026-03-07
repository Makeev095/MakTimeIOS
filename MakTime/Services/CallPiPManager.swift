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

    var onRestoreFullScreen: (() -> Void)?

    // MARK: - Setup

    func setup(sourceView: UIView, remoteTrack: RTCVideoTrack) {
        guard AVPictureInPictureController.isPictureInPictureSupported() else { return }

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
        remoteTrack.add(videoView)

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

    // MARK: - Control

    func startPiP() {
        guard let ctrl = pipController,
              AVPictureInPictureController.isPictureInPictureSupported() else { return }
        if ctrl.isPictureInPicturePossible {
            ctrl.startPictureInPicture()
        }
    }

    func stopPiP() {
        pipController?.stopPictureInPicture()
    }

    func cleanup() {
        stopPiP()
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
        print("PiP failed to start: \(error)")
    }
}
