import Foundation

struct MsaTokenStore: Codable {
    let accessToken: String
    let refreshToken: String
    let expiresIn: Int
    let scope: String
    let tokenType: String
    let userId: String

    static var filename: String { "MsaToken.json" }

    static func url(msUserId: String) -> URL {
        XalStorageManager.userDir(msUserId: msUserId).appendingPathComponent(filename)
    }

    static func save(token: OAuth20Token) {
        let store = MsaTokenStore(
            accessToken: token.accessToken,
            refreshToken: token.refreshToken ?? "",
            expiresIn: token.expiresIn,
            scope: token.scope,
            tokenType: token.tokenType,
            userId: token.userId ?? ""
        )
        let url = Self.url(msUserId: token.userId ?? "")
        XalStorageManager.ensureDir(url.deletingLastPathComponent())
        try? JSONEncoder().encode(store).write(to: url, options: .atomic)
    }

    static func findRefreshToken(msUserId: String) -> String? {
        let url = Self.url(msUserId: msUserId)
        guard let data = try? Data(contentsOf: url),
              let store = try? JSONDecoder().decode(MsaTokenStore.self, from: data) else {
            return nil
        }
        return store.refreshToken.isEmpty ? nil : store.refreshToken
    }
}
