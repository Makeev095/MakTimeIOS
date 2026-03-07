import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var authService: AuthService
    @StateObject private var vm = SettingsViewModel()
    @State private var showLogoutConfirm = false

    var body: some View {
        ZStack {
            Theme.bgPrimary.ignoresSafeArea()

            List {
                // MARK: — Profile header (non-interactive)
                Section {
                    HStack(spacing: 16) {
                        if let user = authService.user {
                            AvatarView(name: user.displayName, color: user.avatarColor, size: 56)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(user.displayName)
                                    .font(.headline)
                                    .foregroundColor(Theme.textPrimary)
                                Text("@\(user.username)")
                                    .font(.subheadline)
                                    .foregroundColor(Theme.textSecondary)
                            }
                        }
                    }
                    .padding(.vertical, 6)
                    .listRowBackground(Theme.bgSecondary)
                }

                // MARK: — Edit profile
                Section(header: sectionHeader("Профиль")) {
                    settingsField("Имя", text: $vm.displayName, icon: "person")
                    settingsField("О себе", text: $vm.bio, icon: "text.quote")

                    Button {
                        Task { await vm.save(authService: authService) }
                    } label: {
                        HStack {
                            Spacer()
                            if vm.isSaving {
                                ProgressView().tint(.white)
                            } else if vm.saved {
                                Label("Сохранено", systemImage: "checkmark")
                            } else {
                                Text("Сохранить")
                            }
                            Spacer()
                        }
                        .font(.subheadline.weight(.semibold))
                        .frame(height: 40)
                        .foregroundColor(.white)
                        .background(vm.saved ? Theme.success : Theme.accent)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusSm))
                    }
                    .disabled(vm.isSaving || vm.displayName.isEmpty)
                    .listRowBackground(Theme.bgSecondary)
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                }

                // MARK: — About
                Section(header: sectionHeader("О приложении")) {
                    settingsRow(icon: "info.circle", title: "Версия", value: "1.0.0")
                }

                // MARK: — Account
                Section(header: sectionHeader("Аккаунт")) {
                    Button(role: .destructive) {
                        showLogoutConfirm = true
                    } label: {
                        HStack {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                            Text("Выйти из аккаунта")
                        }
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(Theme.danger)
                    }
                    .listRowBackground(Theme.bgSecondary)
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("Настройки")
        .confirmationDialog("Выйти из аккаунта?", isPresented: $showLogoutConfirm) {
            Button("Выйти", role: .destructive) { authService.logout() }
            Button("Отмена", role: .cancel) {}
        }
        .onAppear { vm.load(from: authService.user) }
    }

    // MARK: - Helpers

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundColor(Theme.textMuted)
            .textCase(nil)
    }

    private func settingsField(_ placeholder: String, text: Binding<String>, icon: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(Theme.accent)
                .frame(width: 20)
            TextField(placeholder, text: text)
                .foregroundColor(Theme.textPrimary)
                .tint(Theme.accent)
        }
        .listRowBackground(Theme.bgSecondary)
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
        .listRowBackground(Theme.bgSecondary)
    }
}
