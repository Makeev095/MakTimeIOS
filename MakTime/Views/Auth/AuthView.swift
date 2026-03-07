import SwiftUI

struct AuthView: View {
    @EnvironmentObject var authService: AuthService
    @StateObject private var vm = AuthViewModel()
    @State private var float1 = false
    @State private var float2 = false
    @State private var float3 = false
    @State private var logoGlow = false

    var body: some View {
        ZStack {
            Theme.bgPrimary.ignoresSafeArea()

            // Floating background circles
            Circle()
                .fill(Theme.accent.opacity(0.08))
                .frame(width: 300)
                .offset(x: float1 ? 60 : -60, y: float1 ? -80 : 80)
                .blur(radius: 60)
                .animation(.easeInOut(duration: 6).repeatForever(autoreverses: true), value: float1)

            Circle()
                .fill(Theme.accentSecondary.opacity(0.06))
                .frame(width: 250)
                .offset(x: float2 ? -50 : 50, y: float2 ? 120 : -40)
                .blur(radius: 50)
                .animation(.easeInOut(duration: 7).repeatForever(autoreverses: true).delay(1), value: float2)

            Circle()
                .fill(Color(hex: "EC4899").opacity(0.05))
                .frame(width: 200)
                .offset(x: float3 ? 80 : -30, y: float3 ? 60 : -100)
                .blur(radius: 40)
                .animation(.easeInOut(duration: 5).repeatForever(autoreverses: true).delay(2), value: float3)

            ScrollView {
                VStack(spacing: 24) {
                    Spacer().frame(height: 60)

                    Text("Makke")
                        .font(.system(size: 44, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.gradientAccent)
                        .shadow(color: Theme.accent.opacity(logoGlow ? 0.6 : 0.2), radius: logoGlow ? 24 : 10)

                    Text("Мессенджер нового поколения")
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundColor(Theme.textSecondary)

                    Spacer().frame(height: 20)

                    // Tab selector
                    HStack(spacing: 0) {
                        tabButton("Вход", isSelected: vm.isLogin) { vm.isLogin = true; vm.clear() }
                        tabButton("Регистрация", isSelected: !vm.isLogin) { vm.isLogin = false; vm.clear() }
                    }
                    .glassCard(cornerRadius: Theme.radiusSm)

                    // Form
                    VStack(spacing: 14) {
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
                    .padding(20)
                    .glassCard()

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
                                ProgressView().tint(.white)
                            } else {
                                Text(vm.isLogin ? "Войти" : "Зарегистрироваться")
                                    .font(.system(.headline, design: .rounded))
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(
                            vm.canSubmit
                            ? AnyShapeStyle(Theme.gradientAccent)
                            : AnyShapeStyle(Theme.accent.opacity(0.3))
                        )
                        .foregroundColor(.white)
                        .cornerRadius(Theme.radius)
                        .neonGlow(Theme.accent, radius: vm.canSubmit ? 10 : 0)
                    }
                    .disabled(!vm.canSubmit || authService.isLoading)

                    Spacer()
                }
                .padding(.horizontal, 24)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .onAppear {
            float1 = true; float2 = true; float3 = true
            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) { logoGlow = true }
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
                .font(.system(.subheadline, design: .rounded).weight(.medium))
                .foregroundColor(isSelected ? .white : Theme.textSecondary)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(isSelected ? AnyShapeStyle(Theme.gradientAccent) : AnyShapeStyle(Color.clear))
                .cornerRadius(Theme.radiusSm)
        }
    }

    private func inputField(_ placeholder: String, text: Binding<String>, icon: String, isSecure: Bool = false) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(Theme.gradientAccent)
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
        .background(Color.white.opacity(0.04))
        .cornerRadius(Theme.radiusSm)
        .overlay(RoundedRectangle(cornerRadius: Theme.radiusSm).stroke(Theme.border, lineWidth: 1))
    }
}
