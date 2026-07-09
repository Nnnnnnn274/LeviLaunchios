import SwiftUI
import AuthenticationServices

struct LoginView: View {
    @EnvironmentObject private var viewModel: MainViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var isLoggingIn = false

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "person.circle.fill")
                .font(.system(size: 60))
                .foregroundStyle(.blue)

            Text("Sign in with Microsoft")
                .font(.title2.bold())

            Text("Sign in with your Microsoft account to play Minecraft: Bedrock Edition")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal)

            Button(action: login) {
                HStack {
                    Image(systemName: "xbox.logo")
                    Text("Sign in with Microsoft")
                }
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.green)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled(isLoggingIn)
            .padding(.horizontal)

            if isLoggingIn {
                ProgressView("Signing in...")
            }
        }
        .padding()
    }

    private func login() {
        isLoggingIn = true
        Task {
            await viewModel.login()
            isLoggingIn = false
            if viewModel.errorMessage == nil {
                dismiss()
            }
        }
    }
}
