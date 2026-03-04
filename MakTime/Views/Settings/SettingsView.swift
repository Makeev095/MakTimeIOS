import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var authService: AuthService
    @StateObject private var vm = SettingsViewModel()
    @State private var showLogoutConfirm = false
    
    var body: some View {
        ZStack {
            Theme.bgPrimary.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 24) {
                    // Profile header
                    if let user = authService.user {
                        VStack(spacing: 12) {
                            AvatarView(name: user.displayName, color: user.avatarColor, size: 80)
                            
                            Text(user.displayName)
                                .font(.title2.weight(.bold))
                                .foregroundColor(Theme.textPrimary)
                            
                            Text("@\(user.username)")
                                .font(.subheadline)
                                .foregroundColor(Theme.textSecondary)
                        }
                        .padding(.top, 20)
                    }
                    
                    // Edit section
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Редактирование профиля")
                            .font(.subheadline.weight(.medium))
                            .foregroundColor(Theme.textMuted)
                        
                        VStack(spacing: 12) {
                            settingsField("Имя", text: $vm.displayName, icon: "person")
                            settingsField("О себе", text: $vm.bio, icon: "text.quote")
                        }
                        
                        Button {
                            Task { await vm.save(authService: authService) }
                        } label: {
                            HStack {
                                if vm.isSaving {
                                    ProgressView().tint(.white)
                                } else if vm.saved {
                                    Image(systemName: "checkmark")
                                    Text("Сохранено")
                                } else {
                                    Text("Сохранить")
                                }
                            }
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .background(vm.saved ? Theme.success : Theme.accent)
                            .foregroundColor(.white)
                            .cornerRadius(Theme.radiusSm)
                        }
                        .disabled(vm.isSaving || vm.displayName.isEmpty)
                    }
                    .padding(16)
                    .background(Theme.bgSecondary)
                    .cornerRadius(Theme.radius)
                    
                    // App info
                    VStack(spacing: 12) {
                        settingsRow(icon: "info.circle", title: "Версия", value: "1.0.0")
                        settingsRow(icon: "shield.checkered", title: "Шифрование", value: "E2E")
                    }
                    .padding(16)
                    .background(Theme.bgSecondary)
                    .cornerRadius(Theme.radius)
                    
                    // Logout
                    Button { showLogoutConfirm = true } label: {
                        HStack {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                            Text("Выйти из аккаунта")
                        }
                        .font(.subheadline.weight(.medium))
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(Theme.danger.opacity(0.15))
                        .foregroundColor(Theme.danger)
                        .cornerRadius(Theme.radiusSm)
                    }
                    .confirmationDialog("Выйти из аккаунта?", isPresented: $showLogoutConfirm) {
                        Button("Выйти", role: .destructive) { authService.logout() }
                        Button("Отмена", role: .cancel) {}
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 32)
            }
        }
        .onAppear { vm.load(from: authService.user) }
    }
    
    private func settingsField(_ placeholder: String, text: Binding<String>, icon: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(Theme.textMuted)
                .frame(width: 20)
            TextField(placeholder, text: text)
                .foregroundColor(Theme.textPrimary)
        }
        .padding(.horizontal, 14)
        .frame(height: 44)
        .background(Theme.bgTertiary)
        .cornerRadius(Theme.radiusSm)
    }
    
    private func settingsRow(icon: String, title: String, value: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(Theme.accent)
                .frame(width: 20)
            Text(title)
                .foregroundColor(Theme.textPrimary)
            Spacer()
            Text(value)
                .foregroundColor(Theme.textSecondary)
        }
    }
}
