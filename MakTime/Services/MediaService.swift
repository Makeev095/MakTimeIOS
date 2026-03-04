import Foundation
import AVFoundation
import PhotosUI
import SwiftUI

class MediaService: NSObject, ObservableObject {
    @Published var isRecording = false
    @Published var recordingDuration: TimeInterval = 0
    
    private var audioRecorder: AVAudioRecorder?
    private var recordingTimer: Timer?
    private var recordingURL: URL?
    
    func startVoiceRecording() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
        try session.setActive(true)
        
        let tempDir = FileManager.default.temporaryDirectory
        let fileName = "voice_\(UUID().uuidString).m4a"
        let url = tempDir.appendingPathComponent(fileName)
        recordingURL = url
        
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100.0,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        
        audioRecorder = try AVAudioRecorder(url: url, settings: settings)
        audioRecorder?.record()
        isRecording = true
        recordingDuration = 0
        
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.recordingDuration += 0.1
        }
    }
    
    func stopVoiceRecording() -> (url: URL, duration: TimeInterval)? {
        recordingTimer?.invalidate()
        recordingTimer = nil
        audioRecorder?.stop()
        isRecording = false
        
        guard let url = recordingURL else { return nil }
        let duration = recordingDuration
        recordingDuration = 0
        return (url: url, duration: duration)
    }
    
    func cancelVoiceRecording() {
        recordingTimer?.invalidate()
        recordingTimer = nil
        audioRecorder?.stop()
        audioRecorder?.deleteRecording()
        isRecording = false
        recordingDuration = 0
    }
    
    static func requestMicrophonePermission() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }
    
    static func requestCameraPermission() async -> Bool {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        if status == .authorized { return true }
        return await AVCaptureDevice.requestAccess(for: .video)
    }
    
    static func uploadData(_ data: Data, filename: String, mimeType: String) async throws -> String {
        let response = try await APIService.shared.uploadFile(data: data, filename: filename, mimeType: mimeType)
        return response.fileUrl
    }
    
    static func mimeType(for url: URL) -> String {
        let ext = url.pathExtension.lowercased()
        switch ext {
        case "jpg", "jpeg": return "image/jpeg"
        case "png": return "image/png"
        case "gif": return "image/gif"
        case "mp4", "mov": return "video/mp4"
        case "m4a", "aac": return "audio/m4a"
        case "mp3": return "audio/mpeg"
        case "pdf": return "application/pdf"
        default: return "application/octet-stream"
        }
    }
}
