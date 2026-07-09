import Foundation
import Combine
import AuthenticationServices

@MainActor
final class MainViewModel: ObservableObject {
    @Published var accounts: [MsftAccount] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let authManager = MsftAuthManager.shared

    func loadAccounts() {
        accounts = MsftAccountStore.list()
    }

    func login(presenting viewController: UIViewController) async {
        isLoading = true
        errorMessage = nil

        do {
            let verifier = MsftAuthManager.generateCodeVerifier()
            let challenge = MsftAuthManager.generateCodeChallenge(verifier: verifier)
            let state = MsftAuthManager.generateState()

            let url = MsftAuthManager.buildAuthorizeURL(
                clientId: MsftAuthManager.defaultClientId,
                scope: MsftAuthManager.defaultScope,
                codeChallenge: challenge,
                state: state
            )

            let callbackURL = try await performWebAuth(url: url, callbackScheme: "msauth.\(Bundle.main.bundleIdentifier ?? "com.levimc.launcher")", presenting: viewController)

            guard let code = extractCode(from: callbackURL, expectedState: state) else {
                throw AuthError.invalidAccount
            }

            let token = try await authManager.exchangeCodeForToken(
                clientId: MsftAuthManager.defaultClientId,
                code: code,
                codeVerifier: verifier,
                scope: MsftAuthManager.defaultScope
            )

            let xboxResult = try await authManager.performXboxAuth(token: token)
            let identity = try await authManager.fetchMinecraftIdentity(xstsToken: xboxResult.xstsToken)

            MsftAuthManager.saveAccount(
                token: token,
                gamertag: xboxResult.gamertag,
                minecraftUsername: identity.username,
                xuid: identity.xuid,
                avatarUrl: xboxResult.avatarUrl
            )

            loadAccounts()
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func logout(account: MsftAccount) {
        MsftAccountStore.remove(id: account.id)
        loadAccounts()
    }

    private func performWebAuth(url: URL, callbackScheme: String, presenting viewController: UIViewController) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(url: url, callbackURLScheme: callbackScheme) { url, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else if let url = url {
                    continuation.resume(returning: url)
                } else {
                    continuation.resume(throwing: AuthError.invalidAccount)
                }
            }
            session.prefersEphemeralWebBrowserSession = true
            setPresentationProvider(for: session, viewController: viewController)
            if !session.start() {
                continuation.resume(throwing: AuthError.invalidAccount)
            }
        }
    }

    private func extractCode(from url: URL, expectedState: String) -> String? {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let code = components.queryItems?.first(where: { $0.name == "code" })?.value,
              let state = components.queryItems?.first(where: { $0.name == "state" })?.value,
              state == expectedState else {
            return nil
        }
        return code
    }
}

// Runtime-based presentation context provider (avoids compile-time dependency
// on the removed/deprecated ASWebAuthenticationSessionPresentationContextProviding protocol)
private class _AuthProvider: NSObject {
    weak var window: UIWindow?
    init(window: UIWindow?) { self.window = window }
    @objc(presentationAnchorForWebAuthenticationSession:)
    func anchor(for session: Any) -> Any? { return window }
}

private func setPresentationProvider(for session: ASWebAuthenticationSession, viewController: UIViewController) {
    let window = viewController.view.window ?? UIApplication.shared.connectedScenes
        .compactMap { ($0 as? UIWindowScene)?.keyWindow }
        .first
    let provider = _AuthProvider(window: window)
    objc_setAssociatedObject(session, UnsafeRawPointer(bitPattern: 1)!, provider, .OBJC_ASSOCIATION_RETAIN)
    session.perform(NSSelectorFromString("setPresentationContextProvider:"), with: provider)
}
