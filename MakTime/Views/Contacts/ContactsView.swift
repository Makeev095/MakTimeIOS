import SwiftUI

struct ContactsView: View {
    @StateObject private var vm = ContactsViewModel()
    @EnvironmentObject var socketService: SocketService
    @State private var searchQuery = ""
    @State private var searchResults: [User] = []
    var onSelectUser: ((User) -> Void)?
    
    var filteredContacts: [User] {
        if searchQuery.isEmpty { return vm.contacts }
        return vm.contacts.filter {
            $0.displayName.localizedCaseInsensitiveContains(searchQuery) ||
            $0.username.localizedCaseInsensitiveContains(searchQuery)
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            SearchBarView(text: $searchQuery, placeholder: "Найти пользователя...")
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .onChange(of: searchQuery) { q in
                    if q.count >= 2 {
                        Task {
                            do { searchResults = try await APIService.shared.searchUsers(query: q) }
                            catch { searchResults = [] }
                        }
                    } else { searchResults = [] }
                }
            
            if !searchResults.isEmpty && searchQuery.count >= 2 {
                VStack(spacing: 0) {
                    Text("Результаты поиска")
                        .font(.caption.weight(.medium))
                        .foregroundColor(Theme.textMuted)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 6)
                    
                    ForEach(searchResults) { user in
                        userRow(user, showAdd: !vm.contacts.contains(where: { $0.id == user.id }))
                    }
                    
                    Divider().background(Theme.border).padding(.vertical, 4)
                }
            }
            
            ScrollView {
                if filteredContacts.isEmpty && !vm.isLoading {
                    VStack(spacing: 12) {
                        Image(systemName: "person.2")
                            .font(.system(size: 48))
                            .foregroundColor(Theme.textMuted)
                        Text("Нет контактов")
                            .foregroundColor(Theme.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 80)
                } else {
                    LazyVStack(spacing: 0) {
                        ForEach(filteredContacts) { user in
                            userRow(user, showAdd: false)
                        }
                    }
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .refreshable { await vm.loadContacts() }
        }
        .background(Theme.bgPrimary)
        .task { await vm.loadContacts() }
    }
    
    private func userRow(_ user: User, showAdd: Bool) -> some View {
        Button {
            if showAdd {
                Task { await vm.addContact(userId: user.id) }
            }
            onSelectUser?(user)
        } label: {
            HStack(spacing: 12) {
                AvatarView(name: user.displayName, color: user.avatarColor, size: 44,
                          showOnline: user.isOnline)
                VStack(alignment: .leading, spacing: 2) {
                    Text(user.displayName)
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(Theme.textPrimary)
                    Text("@\(user.username)")
                        .font(.caption)
                        .foregroundColor(Theme.textSecondary)
                }
                Spacer()
                if showAdd {
                    Image(systemName: "person.badge.plus")
                        .foregroundColor(Theme.accent)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
    }
}
