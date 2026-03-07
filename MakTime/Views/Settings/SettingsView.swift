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
                        VStack(spacing: 14) {
                            AvatarView(name: user.displayName, color: user.avatarColor, size: 88)
                                .neonGlow(Theme.accent, radius: 16)

                            Text(user.displayName)
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                                .foregroundColor(Theme.textPrimary)

                            Text("@\(user.username)")
                                .font(.system(.subheadline, design: .rounded))
                                .foregroundColor(Theme.textSecondary)
                        }
                        .padding(.top, 20)
                    }

                    // Edit section
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Редактирование профиля")
                            .font(.system(.subheadline, design: .rounded).weight(.medium))
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
                            .font(.system(.subheadline, design: .rounded).weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .frame(height: 46)
                            .background(vm.saved ? AnyShapeStyle(Theme.success) : AnyShapeStyle(Theme.gradientAccent))
                            .foregroundColor(.white)
                            .cornerRadius(Theme.radiusSm)
                            .neonGlow(vm.saved ? Theme.success : Theme.accent, radius: 6)
                        }
                        .disabled(vm.isSaving || vm.displayName.isEmpty)
                    }
                    .padding(18)
                    .glassCard()

                    // App info
                    VStack(spacing: 14) {
                        settingsRow(icon: "info.circle", title: "Версия", value: "1.0.0")
                        settingsRow(icon: "shield.checkered", title: "Шифрование", value: "E2E")
                    }
                    .padding(18)
                    .glassCard()

                    // Logout
                    Button { showLogoutConfirm = true } label: {
                        HStack {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                            Text("Выйти из аккаунта")
                        }
                        .font(.system(.subheadline, design: .rounded).weight(.medium))
                        .frame(maxWidth: .infinity)
                        .frame(height: 46)
                        .background(Theme.danger.opacity(0.15))
                        .foregroundColor(Theme.danger)
                        .cornerRadius(Theme.radiusSm)
                        .overlay(RoundedRectangle(cornerRadius: Theme.radiusSm).stroke(Theme.danger.opacity(0.3), lineWidth: 1))
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
                .foregroundStyle(Theme.gradientAccent)
                .frame(width: 20)
            TextField(placeholder, text: text)
                .foregroundColor(Theme.textPrimary)
        }
        .padding(.horizontal, 14)
        .frame(height: 46)
        .background(Color.white.opacity(0.04))
        .cornerRadius(Theme.radiusSm)
        .overlay(RoundedRectangle(cornerRadius: Theme.radiusSm).stroke(Theme.border, lineWidth: 1))
    }

    private func settingsRow(icon: String, title: String, value: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(Theme.gradientAccent)
                .frame(width: 20)
            Text(title)
                .font(.system(.subheadline, design: .rounded))
                .foregroundColor(Theme.textPrimary)
            Spacer()
            Text(value)
                .font(.system(.subheadline, design: .rounded))
                .foregroundColor(Theme.textSecondary)
        }
    }
}
