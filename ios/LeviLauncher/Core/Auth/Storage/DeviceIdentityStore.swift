import Foundation

struct DeviceIdentityStore: Codable {
    let deviceId: String
    let deviceKey: String

    static var filename: String { "DeviceIdentity.json" }

    init(key: XboxDeviceKey) {
        self.deviceId = key.id
        self.deviceKey = key.key.base64EncodedString()
    }

    func save(to url: URL) {
        try? JSONEncoder().encode(self).write(to: url, options: .atomic)
    }
}
