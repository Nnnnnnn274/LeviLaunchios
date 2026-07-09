import Foundation
import CryptoKit
import AuthenticationServices

actor MsftAuthManager: NSObject {
    static let shared = MsftAuthManager()

    static let defaultClientId = "0000000048183522"
    static let defaultScope = "service::user.auth.xboxlive.com::mbi_ssl"
    static let defaultXstsRelyingParty = "https://multiplayer.minecraft.net/"

    private let session = URLSession.shared
    private var currentAuthSession: ASWebAuthenticationSession?

    struct XboxAuthResult {
        let xstsToken: XboxToken
        let gamertag: String
        let avatarUrl: String?
        let device: XboxDevice
    }

    // MARK: - OAuth URL Building

    static func buildAuthorizeURL(clientId: String, scope: String, codeChallenge: String, state: String) -> URL {
        var components = URLComponents(string: "https://login.live.com/oauth20_authorize.srf")!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: clientId),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: scope),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "code_challenge", value: codeChallenge),
            URLQueryItem(name: "state", value: state),
            URLQueryItem(name: "redirect_uri", value: "msauth.\(Bundle.main.bundleIdentifier ?? "com.levimc.launcher")://auth")
        ]
        return components.url!
    }

    // MARK: - PKCE

    static func generateCodeVerifier() -> String {
        var bytes = Data(count: 32)
        _ = bytes.withUnsafeMutableBytes { SecRandomCopyBytes(kSecRandomDefault, 32, $0.baseAddress!) }
        return bytes.base64URLEncodedString()
    }

    static func generateCodeChallenge(verifier: String) -> String {
        let data = Data(verifier.utf8)
        let hash = SHA256.hash(data: data)
        return Data(hash).base64URLEncodedString()
    }

    static func generateState() -> String {
        var bytes = Data(count: 16)
        _ = bytes.withUnsafeMutableBytes { SecRandomCopyBytes(kSecRandomDefault, 16, $0.baseAddress!) }
        return bytes.base64URLEncodedString()
    }

    // MARK: - Token Exchange

    func exchangeCodeForToken(clientId: String, code: String, codeVerifier: String, scope: String) async throws -> OAuth20Token {
        var components = URLComponents(string: "https://login.live.com/oauth20_token.srf")!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: clientId),
            URLQueryItem(name: "code", value: code),
            URLQueryItem(name: "code_verifier", value: codeVerifier),
            URLQueryItem(name: "grant_type", value: "authorization_code"),
            URLQueryItem(name: "scope", value: scope),
            URLQueryItem(name: "redirect_uri", value: "msauth.\(Bundle.main.bundleIdentifier ?? "com.levimc.launcher")://auth")
        ]
        var request = URLRequest(url: components.url!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let (data, _) = try await session.data(for: request)
        return try JSONDecoder().decode(OAuth20Token.self, from: data)
    }

    func exchangeRefreshToken(clientId: String, refreshToken: String, scope: String) async throws -> OAuth20Token {
        var components = URLComponents(string: "https://login.live.com/oauth20_token.srf")!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: clientId),
            URLQueryItem(name: "refresh_token", value: refreshToken),
            URLQueryItem(name: "grant_type", value: "refresh_token"),
            URLQueryItem(name: "scope", value: scope),
            URLQueryItem(name: "redirect_uri", value: "msauth.\(Bundle.main.bundleIdentifier ?? "com.levimc.launcher")://auth")
        ]
        var request = URLRequest(url: components.url!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let (data, _) = try await session.data(for: request)
        return try JSONDecoder().decode(OAuth20Token.self, from: data)
    }

    // MARK: - Xbox Auth

    func refreshAndAuth(account: MsftAccount) async throws -> XboxAuthResult {
        guard !account.msUserId.isEmpty else {
            throw AuthError.invalidAccount
        }
        guard let refreshToken = MsaTokenStore.findRefreshToken(msUserId: account.msUserId) else {
            throw AuthError.noRefreshToken
        }
        let token = try await exchangeRefreshToken(clientId: Self.defaultClientId,
                                                    refreshToken: refreshToken,
                                                    scope: Self.defaultScope)
        return try await performXboxAuth(token: token)
    }

    func performXboxAuth(token: OAuth20Token) async throws -> XboxAuthResult {
        let cfg = AuthConfig.productionRetailJwtDefault()
        let deviceKey = XboxDeviceKey()
        let deviceAuthReq = XboxDeviceAuthRequest(
            relyingParty: cfg.deviceAuthRP,
            tokenType: cfg.tokenType,
            deviceType: "iOS",
            deviceVersion: ProcessInfo.processInfo.operatingSystemVersionString,
            deviceKey: deviceKey
        )

        await XalStorageManager.saveDeviceIdentity(msUserId: token.userId ?? "", deviceKey: deviceKey)

        let deviceToken = try await deviceAuthReq.request(session: session)
        await XalStorageManager.saveDeviceToken(msUserId: token.userId ?? "", deviceKey: deviceKey, deviceToken: deviceToken, cfg: cfg)
        let device = XboxDevice(key: deviceKey, token: deviceToken)

        let userToken = try await XboxUserAuthRequest(
            relyingParty: cfg.userAuthRP,
            tokenType: cfg.tokenType,
            authMethod: cfg.authMethodRps,
            siteName: cfg.siteNameRps,
            rpsTicket: "t=\(token.accessToken)"
        ).request(session: session)

        let xstsTokenMain: XboxToken
        do {
            xstsTokenMain = try await XboxXSTSAuthRequest(
                relyingParty: Self.defaultXstsRelyingParty,
                tokenType: cfg.tokenType,
                sandbox: cfg.sandbox,
                userTokens: [userToken]
            ).request(session: session)
            await XalStorageManager.saveDefaultTitleUser(msUserId: token.userId ?? "")
        } catch {
            let titleToken = try await XboxTitleAuthRequest(
                relyingParty: cfg.userAuthRP,
                tokenType: cfg.tokenType,
                authMethod: cfg.authMethodRps,
                siteName: cfg.siteNameRps,
                rpsTicket: "t=\(token.accessToken)",
                deviceToken: deviceToken,
                deviceKey: deviceKey
            ).request(session: session)
            await XalStorageManager.saveTitleToken(msUserId: token.userId ?? "", deviceKey: deviceKey, titleToken: titleToken, cfg: cfg)
            xstsTokenMain = try await XboxXSTSAuthRequest(
                relyingParty: Self.defaultXstsRelyingParty,
                tokenType: cfg.tokenType,
                sandbox: cfg.sandbox,
                userTokens: [userToken]
            ).request(session: session)
            await XalStorageManager.saveDefaultTitleUser(msUserId: token.userId ?? "")
        }

        let xstsXboxLive = try await XboxXSTSAuthRequest(
            relyingParty: "http://xboxlive.com",
            tokenType: cfg.tokenType,
            sandbox: cfg.sandbox,
            userTokens: [userToken]
        ).request(session: session)

        let xstsPlayfab = try await XboxXSTSAuthRequest(
            relyingParty: "https://b980a380.minecraft.playfabapi.com/",
            tokenType: cfg.tokenType,
            sandbox: cfg.sandbox,
            userTokens: [userToken]
        ).request(session: session)

        let xstsRealms = try await XboxXSTSAuthRequest(
            relyingParty: "https://pocket.realms.minecraft.net/",
            tokenType: cfg.tokenType,
            sandbox: cfg.sandbox,
            userTokens: [userToken]
        ).request(session: session)

        await UserTokenStore.save(deviceKey: deviceKey, msUserId: token.userId ?? "", cfg: cfg,
                                   userToken: userToken, xstsXboxLive: xstsXboxLive,
                                   xstsPlayfab: xstsPlayfab, xstsRealms: xstsRealms)
        await MsaTokenStore.save(token: token)

        let xuid = extractXuid(userToken: userToken)
        let profile = try? await fetchXboxProfile(xstsXboxLive: xstsXboxLive, xuid: xuid)
        let gamertag = profile?.gamertag ?? "Unknown"
        let avatarUrl = profile?.avatarUrl

        return XboxAuthResult(xstsToken: xstsTokenMain, gamertag: gamertag, avatarUrl: avatarUrl, device: device)
    }

    // MARK: - Minecraft Identity

    func fetchMinecraftIdentity(xstsToken: XboxToken) async throws -> (username: String, xuid: String) {
        let identityToken = xstsToken.toIdentityToken()
        let publicKey = try createMinecraftIdentityPublicKey()

        var request = URLRequest(url: URL(string: "https://multiplayer.minecraft.net/authentication")!)
        request.httpMethod = "POST"
        request.setValue("1.21.110", forHTTPHeaderField: "Client-Version")
        request.setValue(identityToken, forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: String] = ["identityPublicKey": publicKey]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, _) = try await session.data(for: request)
        guard let result = Self.parseUsernameAndXuidFromChain(data) else {
            throw AuthError.minecraftIdentityFailed
        }
        return result
    }

    private func createMinecraftIdentityPublicKey() throws -> String {
        let keyPair = try EncryptionUtils.createKeyPair()
        var error: Unmanaged<CFError>?
        guard let data = SecKeyCopyExternalRepresentation(keyPair.publicKey, &error) as Data? else {
            throw error?.takeRetainedValue() ?? CryptoError.keyGenerationFailed
        }
        return data.base64URLEncodedString()
    }

    static func parseUsernameAndXuidFromChain(_ data: Data) -> (username: String, xuid: String)? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let chain = json["chain"] as? [String] else {
            return nil
        }
        for entry in chain {
            let parts = entry.split(separator: ".")
            guard parts.count >= 2 else { continue }
            let payload = String(parts[1])
            guard let decoded = Data(base64URLEncoded: payload),
                  let body = try? JSONSerialization.jsonObject(with: decoded) as? [String: Any],
                  let extraData = body["extraData"] as? [String: Any] else {
                continue
            }
            let username = extraData["displayName"] as? String
            let xuid = extraData["XUID"] as? String
            if let username = username, let xuid = xuid {
                return (username, xuid)
            }
        }
        return nil
    }

    // MARK: - Profile

    private func fetchXboxProfile(xstsXboxLive: XboxToken, xuid: String?) async throws -> (gamertag: String, avatarUrl: String?) {
        let identity = xstsXboxLive.toIdentityToken()
        let urlStr: String
        if let xuid = xuid, !xuid.isEmpty {
            urlStr = "https://profile.xboxlive.com/users/xuid(\(xuid))/profile/settings?settings=Gamertag,PublicGamerpic"
        } else {
            urlStr = "https://profile.xboxlive.com/users/me/profile/settings?settings=Gamertag,PublicGamerpic"
        }

        var request = URLRequest(url: URL(string: urlStr)!)
        request.setValue("3", forHTTPHeaderField: "x-xbl-contract-version")
        request.setValue(identity, forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "content-type")

        let (data, _) = try await session.data(for: request)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let users = json["profileUsers"] as? [[String: Any]],
              let user = users.first,
              let settings = user["settings"] as? [[String: Any]] else {
            return ("Unknown", nil)
        }

        var gamertag: String?
        var picUrl: String?
        for setting in settings {
            guard let id = setting["id"] as? String, let value = setting["value"] as? String else { continue }
            if id == "Gamertag" { gamertag = value }
            else if id == "PublicGamerpic" { picUrl = sanitizeURL(value) }
        }
        return (gamertag ?? "Unknown", picUrl)
    }

    // MARK: - Helpers

    private func extractXuid(userToken: XboxToken) -> String? {
        guard let xui = userToken.displayClaims["xui"] as? [[String: Any]],
              let xid = xui.first?["xid"] as? String, !xid.isEmpty else {
            return nil
        }
        return xid
    }

    private func sanitizeURL(_ url: String) -> String? {
        let u = url.replacingOccurrences(of: "`", with: "").trimmingCharacters(in: .whitespaces)
        guard u.hasPrefix("http://") || u.hasPrefix("https://") else { return nil }
        return u
    }

    static func saveAccount(token: OAuth20Token, gamertag: String, minecraftUsername: String, xuid: String, avatarUrl: String?) {
        MsftAccountStore.addOrUpdate(
            msUserId: token.userId ?? "",
            refreshToken: token.refreshToken,
            gamertag: gamertag,
            minecraftUsername: minecraftUsername,
            xuid: xuid,
            avatarUrl: avatarUrl
        )
    }
}

enum AuthError: LocalizedError {
    case invalidAccount
    case noRefreshToken
    case minecraftIdentityFailed

    var errorDescription: String? {
        switch self {
        case .invalidAccount: return "No user id available for the selected account"
        case .noRefreshToken: return "No refresh token found in MSA store for the selected account"
        case .minecraftIdentityFailed: return "Minecraft identity request failed"
        }
    }
}
