import SwiftUI

struct AccountsView: View {
    @EnvironmentObject private var viewModel: MainViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var isLoggingIn = false

    var body: some View {
        NavigationStack {
            List {
                if viewModel.accounts.isEmpty {
                    Section {
                        ContentUnavailableView("No Accounts",
                            systemImage: "person.slash",
                            description: Text("Add a Microsoft account to play Minecraft"))
                    }
                } else {
                    Section("Accounts") {
                        ForEach(viewModel.accounts) { account in
                            AccountRow(account: account)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    MsftAccountStore.setActive(id: account.id)
                                    viewModel.loadAccounts()
                                }
                        }
                        .onDelete { indexSet in
                            for idx in indexSet {
                                viewModel.logout(account: viewModel.accounts[idx])
                            }
                        }
                    }
                }

                Section {
                    Button(action: login) {
                        HStack {
                            Spacer()
                            if isLoggingIn {
                                ProgressView()
                            } else {
                                Image(systemName: "plus.circle.fill")
                                Text("Add Microsoft Account")
                            }
                            Spacer()
                        }
                    }
                    .disabled(isLoggingIn)
                }
            }
            .navigationTitle("Accounts")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .onAppear {
            viewModel.loadAccounts()
        }
        .alert("Login Error", isPresented: .init(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Text(viewModel.errorMessage ?? "")
        }
    }

    private func login() {
        isLoggingIn = true
        Task {
            await viewModel.login()
            isLoggingIn = false
        }
    }
}

struct AccountRow: View {
    let account: MsftAccount

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(.secondary.opacity(0.2))
                    .frame(width: 44, height: 44)
                Text(account.xboxGamertag?.prefix(1).uppercased() ?? "?")
                    .font(.headline)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(account.xboxGamertag ?? "Unknown")
                    .font(.headline)
                if let username = account.minecraftUsername {
                    Text(username)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if let xuid = account.xuid {
                    Text("XUID: \(xuid)")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()

            if account.isActive {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            }
        }
    }
}
