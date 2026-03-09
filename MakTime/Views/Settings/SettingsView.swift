import SwiftUI
import PhotosUI

struct SettingsView: View {
    @EnvironmentObject var authService: AuthService
    @StateObject private var vm = SettingsViewModel()
    @State private var showLogoutConfirm = false
    @State private var selectedAvatarItem: PhotosPickerItem?
    @State private var isUploadingAvatar = false

    private var effectiveAvatarUrl: String? {
        vm.avatarUrl ?? authService.user?.avatarUrl
    }

    var body: some View {
        ZStack {
            Theme.bgPrimary.ignoresSafeArea()

            List {
                // MARK: — Profile header with avatar picker
                Section {
                    HStack(spacing: 16) {
                        if let user = authService.user {
                            PhotosPicker(selection: $selectedAvatarItem, matching: .images) {
                                ZStack(alignment: .bottomTrailing) {
                                    AvatarView(name: user.displayName, color: user.avatarColor, avatarUrl: effectiveAvatarUrl, size: 56)
                                    if isUploadingAvatar {
                                        ProgressView().tint(.white)
                                            .frame(width: 24, height: 24)
                                            .background(Circle().fill(.black.opacity(0.5)))
                                    } else {
                                        Image(systemName: "camera.fill")
                                            .font(.system(size: 12))
                                            .foregroundColor(.white)
                                            .frame(width: 24, height: 24)
                                            .background(Circle().fill(Theme.accent))
                                    }
                                }
                            }
                            .disabled(isUploadingAvatar)
                            .onChange(of: selectedAvatarItem) { _ in
                                Task { await uploadSelectedAvatar() }
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text(user.displayName)
                                    .font(.headline)
                                    .foregroundColor(Theme.textPrimary)
                                Text("@\(user.username)")
                                    .font(.subheadline)
                                    .foregroundColor(Theme.textSecondary)
                                Text("Нажмите на аватар, чтобы изменить")
                                    .font(.caption2)
                                    .foregroundColor(Theme.textMuted)
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

    private func uploadSelectedAvatar() async {
        guard let item = selectedAvatarItem else { return }
        selectedAvatarItem = nil
        isUploadingAvatar = true
        defer { isUploadingAvatar = false }
        guard let data = try? await item.loadTransferable(type: Data.self) else { return }
        do {
            let resp = try await APIService.shared.uploadFile(
                data: data,
                filename: "avatar_\(UUID().uuidString).jpg",
                mimeType: "image/jpeg"
            )
            vm.setAvatarUrl(resp.fileUrl)
            await authService.updateProfile(displayName: vm.displayName, bio: vm.bio, avatarUrl: resp.fileUrl)
        } catch {
            print("Avatar upload error: \(error)")
        }
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
