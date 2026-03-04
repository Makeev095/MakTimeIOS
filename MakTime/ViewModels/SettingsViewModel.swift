import Foundation

@MainActor
class SettingsViewModel: ObservableObject {
    @Published var displayName = ""
    @Published var bio = ""
    @Published var isSaving = false
    @Published var saved = false
    
    func load(from user: User?) {
        displayName = user?.displayName ?? ""
        bio = user?.bio ?? ""
    }
    
    func save(authService: AuthService) async {
        isSaving = true
        await authService.updateProfile(displayName: displayName, bio: bio)
        isSaving = false
        saved = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            self?.saved = false
        }
    }
}
