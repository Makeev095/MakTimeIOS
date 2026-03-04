import SwiftUI

struct AuthView: View {
    @EnvironmentObject var authService: AuthService
    @StateObject private var vm = AuthViewModel()
    
    var body: some View {
        ZStack {
            Theme.bgPrimary.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 24) {
                    Spacer().frame(height: 60)
                    
                    Text("MakTime")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundColor(Theme.accent)
                    
                    Text("Мессенджер с видеозвонками")
                        .font(.subheadline)
                        .foregroundColor(Theme.textSecondary)
                    
                    Spacer().frame(height: 20)
                    
                    HStack(spacing: 0) {
                        tabButton("Вход", isSelected: vm.isLogin) { vm.isLogin = true; vm.clear() }
                        tabButton("Регистрация", isSelected: !vm.isLogin) { vm.isLogin = false; vm.clear() }
                    }
                    .background(Theme.bgTertiary)
                    .cornerRadius(Theme.radiusSm)
                    
                    VStack(spacing: 16) {
                        inputField("Имя пользователя", text: $vm.username, icon: "person")
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                        
                        if !vm.isLogin {
                            inputField("Отображаемое имя", text: $vm.displayName, icon: "person.text.rectangle")
                        }
                        
                        inputField("Пароль", text: $vm.password, icon: "lock", isSecure: true)
                        
                        if !vm.isLogin {
                            inputField("Повторите пароль", text: $vm.confirmPassword, icon: "lock.rotation", isSecure: true)
                        }
                    }
                    
                    if let error = vm.validationError {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(Theme.danger)
                    }
                    
                    if let error = authService.error {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(Theme.danger)
                            .multilineTextAlignment(.center)
                    }
                    
                    Button(action: submit) {
                        Group {
                            if authService.isLoading {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Text(vm.isLogin ? "Войти" : "Зарегистрироваться")
                                    .fontWeight(.semibold)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(vm.canSubmit ? Theme.accent : Theme.accent.opacity(0.4))
                        .foregroundColor(.white)
                        .cornerRadius(Theme.radius)
                    }
                    .disabled(!vm.canSubmit || authService.isLoading)
                    
                    Spacer()
                }
                .padding(.horizontal, 24)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .onTapGesture {
            UIApplication.shared.dismissKeyboard()
        }
    }
    
    private func submit() {
        Task {
            if vm.isLogin {
                await authService.login(username: vm.username, password: vm.password)
            } else {
                await authService.register(username: vm.username, displayName: vm.displayName, password: vm.password)
            }
        }
    }
    
    private func tabButton(_ title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.medium))
                .foregroundColor(isSelected ? .white : Theme.textSecondary)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(isSelected ? Theme.accent : Color.clear)
                .cornerRadius(Theme.radiusSm)
        }
    }
    
    private func inputField(_ placeholder: String, text: Binding<String>, icon: String, isSecure: Bool = false) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(Theme.textMuted)
                .frame(width: 20)
            
            if isSecure {
                SecureField(placeholder, text: text)
                    .foregroundColor(Theme.textPrimary)
            } else {
                TextField(placeholder, text: text)
                    .foregroundColor(Theme.textPrimary)
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 50)
        .background(Theme.bgTertiary)
        .cornerRadius(Theme.radius)
    }
}
