import Foundation

struct UserTokenStore: Codable {
    let userToken: XboxToken
    let xstsXboxLive: XboxToken
    let xstsPlayfab: XboxToken
    let xstsRealms: XboxToken

    static var filename: String { "UserToken.json" }

    static func url(msUserId: String) -> URL {
        XalStorageManager.userDir(msUserId: msUserId).appendingPathComponent(filename)
    }

    static func save(deviceKey: XboxDeviceKey, msUserId: String, cfg: AuthConfig,
                     userToken: XboxToken, xstsXboxLive: XboxToken,
                     xstsPlayfab: XboxToken, xstsRealms: XboxToken) {
        let store = UserTokenStore(
            userToken: userToken,
            xstsXboxLive: xstsXboxLive,
            xstsPlayfab: xstsPlayfab,
            xstsRealms: xstsRealms
        )
        let url = Self.url(msUserId: msUserId)
        XalStorageManager.ensureDir(url.deletingLastPathComponent())
        try? JSONEncoder().encode(store).write(to: url, options: .atomic)
    }
}
