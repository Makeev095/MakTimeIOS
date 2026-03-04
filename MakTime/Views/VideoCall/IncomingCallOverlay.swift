import SwiftUI

struct IncomingCallOverlay: View {
    let call: IncomingCall
    let onAccept: () -> Void
    let onReject: () -> Void
    
    @State private var pulse = false
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.7)
                .ignoresSafeArea()
            
            VStack(spacing: 32) {
                Spacer()
                
                ZStack {
                    Circle()
                        .fill(Theme.accent.opacity(0.2))
                        .frame(width: pulse ? 160 : 120, height: pulse ? 160 : 120)
                        .animation(.easeInOut(duration: 1).repeatForever(autoreverses: true), value: pulse)
                    
                    AvatarView(name: call.callerName, color: "#6C63FF", size: 100)
                }
                .onAppear { pulse = true }
                
                VStack(spacing: 8) {
                    Text("Входящий видеозвонок")
                        .font(.headline)
                        .foregroundColor(.white)
                    Text(call.callerName)
                        .font(.title2.weight(.bold))
                        .foregroundColor(.white)
                }
                
                Spacer()
                
                HStack(spacing: 60) {
                    Button(action: onReject) {
                        VStack(spacing: 8) {
                            Image(systemName: "phone.down.fill")
                                .font(.title)
                                .foregroundColor(.white)
                                .frame(width: 70, height: 70)
                                .background(Theme.danger)
                                .clipShape(Circle())
                            Text("Отклонить")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.7))
                        }
                    }
                    
                    Button(action: onAccept) {
                        VStack(spacing: 8) {
                            Image(systemName: "phone.fill")
                                .font(.title)
                                .foregroundColor(.white)
                                .frame(width: 70, height: 70)
                                .background(Theme.success)
                                .clipShape(Circle())
                            Text("Принять")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.7))
                        }
                    }
                }
                .padding(.bottom, 60)
            }
        }
    }
}
