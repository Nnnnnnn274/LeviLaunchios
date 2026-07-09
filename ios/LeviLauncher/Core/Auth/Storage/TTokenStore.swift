import Foundation

struct TTokenStore: Codable {
    let deviceKeyId: String
    let titleToken: String
    let issueInstant: String
    let notAfter: String
    let relyingParty: String

    static var filename: String { "TToken.json" }

    init(deviceKey: XboxDeviceKey, titleToken: XboxTitleToken, cfg: AuthConfig) {
        self.deviceKeyId = deviceKey.id
        self.titleToken = titleToken.token
        self.issueInstant = titleToken.issueInstant
        self.notAfter = titleToken.notAfter
        self.relyingParty = cfg.userAuthRP
    }

    func save(to dir: URL) {
        let url = dir.appendingPathComponent(Self.filename)
        try? JSONEncoder().encode(self).write(to: url, options: .atomic)
    }
}
