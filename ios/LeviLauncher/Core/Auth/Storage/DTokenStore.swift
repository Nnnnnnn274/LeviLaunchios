import Foundation

struct DTokenStore: Codable {
    let deviceKeyId: String
    let deviceToken: String
    let issueInstant: String
    let notAfter: String
    let relyingParty: String

    static var filename: String { "DToken.json" }

    init(deviceKey: XboxDeviceKey, deviceToken: XboxDeviceToken, cfg: AuthConfig) {
        self.deviceKeyId = deviceKey.id
        self.deviceToken = deviceToken.token
        self.issueInstant = deviceToken.issueInstant
        self.notAfter = deviceToken.notAfter
        self.relyingParty = cfg.deviceAuthRP
    }

    func save(to dir: URL) {
        let url = dir.appendingPathComponent(Self.filename)
        try? JSONEncoder().encode(self).write(to: url, options: .atomic)
    }
}
