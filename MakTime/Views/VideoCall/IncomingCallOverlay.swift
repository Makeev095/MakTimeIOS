import SwiftUI
import AudioToolbox
import AVFoundation

struct IncomingCallOverlay: View {
    let call: IncomingCall
    let onAccept: () -> Void
    let onReject: () -> Void
    
    @State private var pulse1 = false
    @State private var pulse2 = false
    @State private var pulse3 = false
    @State private var ringTimer: Timer?
    @State private var shimmerOffset: CGFloat = -200
    
    var body: some View {
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
                .fill(Theme.accent.opacity(0.06))
                .frame(width: pulse3 ? 500 : 300)
                .animation(.easeInOut(duration: 3.0).repeatForever(autoreverses: true).delay(0.5), value: pulse3)
            
            Circle()
                .fill(Theme.accent.opacity(0.04))
                .frame(width: pulse2 ? 400 : 250)
                .animation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true).delay(0.3), value: pulse2)
            
            VStack(spacing: 32) {
                Spacer()
                
                Text("Входящий видеозвонок")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.6))
                    .textCase(.uppercase)
                    .tracking(1.5)
                
                ZStack {
                    Circle()
                        .fill(Theme.accent.opacity(0.15))
                        .frame(width: pulse1 ? 170 : 135)
                        .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: pulse1)
                    
                    Circle()
                        .fill(Theme.accent.opacity(0.08))
                        .frame(width: pulse2 ? 200 : 155)
                        .animation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true).delay(0.2), value: pulse2)
                    
                    AvatarView(name: call.callerName, color: "#6C63FF", size: 120)
                        .shadow(color: Theme.accent.opacity(0.4), radius: 20)
                }
                
                Text(call.callerName)
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.white)
                
                Spacer()
                
                HStack(spacing: 60) {
                    Button(action: {
                        stopRingtone()
                        onReject()
                    }) {
                        VStack(spacing: 10) {
                            ZStack {
                                Circle()
                                    .fill(Theme.danger)
                                    .frame(width: 70, height: 70)
                                    .shadow(color: Theme.danger.opacity(0.4), radius: 10)
                                Image(systemName: "phone.down.fill")
                                    .font(.title2)
                                    .foregroundColor(.white)
                            }
                            Text("Отклонить")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.6))
                        }
                    }
                    
                    Button(action: {
                        stopRingtone()
                        onAccept()
                    }) {
                        VStack(spacing: 10) {
                            ZStack {
                                Circle()
                                    .fill(Theme.success)
                                    .frame(width: 70, height: 70)
                                    .shadow(color: Theme.success.opacity(0.4), radius: 10)
                                Image(systemName: "phone.fill")
                                    .font(.title2)
                                    .foregroundColor(.white)
                                    .rotationEffect(.degrees(-135))
                            }
                            Text("Принять")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.6))
                        }
                    }
                }
                .padding(.bottom, 60)
            }
        }
        .onAppear {
            pulse1 = true
            pulse2 = true
            pulse3 = true
            startRingtone()
        }
        .onDisappear {
            stopRingtone()
        }
    }
    
    private func startRingtone() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.soloAmbient)
        try? session.setActive(true)
        
        AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
        AudioServicesPlaySystemSound(1005)
        
        let timer = Timer.scheduledTimer(withTimeInterval: 2.5, repeats: true) { _ in
            AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
            AudioServicesPlaySystemSound(1005)
        }
        ringTimer = timer
    }
    
    private func stopRingtone() {
        ringTimer?.invalidate()
        ringTimer = nil
    }
}
