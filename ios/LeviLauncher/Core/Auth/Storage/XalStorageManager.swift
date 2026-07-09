import Foundation

actor XalStorageManager {
    static let xalDir: URL = {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return paths[0].appendingPathComponent("Xal")
    }()

    static func userDir(msUserId: String) -> URL {
        xalDir.appendingPathComponent(msUserId)
    }

    static func ensureDir(_ url: URL) {
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }

    static func saveDeviceIdentity(msUserId: String, deviceKey: XboxDeviceKey) {
        let dir = userDir(msUserId: msUserId)
        ensureDir(dir)
        let url = dir.appendingPathComponent(DeviceIdentityStore.filename)
        DeviceIdentityStore(key: deviceKey).save(to: url)
    }

    static func saveDeviceToken(msUserId: String, deviceKey: XboxDeviceKey, deviceToken: XboxDeviceToken, cfg: AuthConfig) {
        let dir = userDir(msUserId: msUserId)
        ensureDir(dir)
        DTokenStore(deviceKey: deviceKey, deviceToken: deviceToken, cfg: cfg).save(to: dir)
    }

    static func saveTitleToken(msUserId: String, deviceKey: XboxDeviceKey, titleToken: XboxTitleToken, cfg: AuthConfig) {
        let dir = userDir(msUserId: msUserId)
        ensureDir(dir)
        TTokenStore(deviceKey: deviceKey, titleToken: titleToken, cfg: cfg).save(to: dir)
    }

    static func saveDefaultTitleUser(msUserId: String) {
        TitleDefaultStore(defaultUser: msUserId).save(to: xalDir)
    }

    static func deleteUserDir(msUserId: String) {
        try? FileManager.default.removeItem(at: userDir(msUserId: msUserId))
    }
}
