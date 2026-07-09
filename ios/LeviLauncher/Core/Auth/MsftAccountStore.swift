import Foundation

struct MsftAccount: Codable, Identifiable {
    var id: String
    var msUserId: String
    var refreshToken: String?
    var xboxGamertag: String?
    var minecraftUsername: String?
    var xuid: String?
    var xboxAvatarUrl: String?
    var lastUpdated: Date
    var isActive: Bool

    enum CodingKeys: String, CodingKey {
        case id, msUserId, xboxGamertag, minecraftUsername, xuid, xboxAvatarUrl, lastUpdated
        case isActive = "active"
    }

    init(id: String = UUID().uuidString, msUserId: String, refreshToken: String? = nil,
         xboxGamertag: String? = nil, minecraftUsername: String? = nil, xuid: String? = nil,
         xboxAvatarUrl: String? = nil, lastUpdated: Date = Date(), isActive: Bool = false) {
        self.id = id
        self.msUserId = msUserId
        self.refreshToken = refreshToken
        self.xboxGamertag = xboxGamertag
        self.minecraftUsername = minecraftUsername
        self.xuid = xuid
        self.xboxAvatarUrl = xboxAvatarUrl
        self.lastUpdated = lastUpdated
        self.isActive = isActive
    }
}

final class MsftAccountStore {
    private static let filename = "Xal.Accounts.json"

    static var accountsURL: URL {
        XalStorageManager.xalDir.appendingPathComponent(filename)
    }

    static func list() -> [MsftAccount] {
        guard FileManager.default.fileExists(atPath: accountsURL.path) else { return [] }
        do {
            let data = try Data(contentsOf: accountsURL)
            let accounts = try JSONDecoder().decode([MsftAccount].self, from: data)
            return accounts
        } catch {
            Logger.warn("XALExport", "Failed to read accounts: \(error)")
            return []
        }
    }

    private static func save(_ accounts: [MsftAccount]) {
        do {
            let data = try JSONEncoder().encode(accounts)
            try FileManager.default.createDirectory(at: accountsURL.deletingLastPathComponent(),
                                                    withIntermediateDirectories: true)
            try data.write(to: accountsURL, options: .atomic)
        } catch {
            Logger.warn("XALExport", "Failed to write accounts: \(error)")
        }
    }

    @discardableResult
    static func addOrUpdate(msUserId: String, refreshToken: String?, gamertag: String?,
                            minecraftUsername: String? = nil, xuid: String? = nil,
                            avatarUrl: String? = nil) -> MsftAccount {
        var accounts = list()
        var target: MsftAccount?
        if let idx = accounts.firstIndex(where: { $0.msUserId == msUserId }) {
            target = accounts[idx]
            if let refreshToken = refreshToken { target?.refreshToken = refreshToken }
            if let g = gamertag, !g.isEmpty { target?.xboxGamertag = g }
            if let u = minecraftUsername, !u.isEmpty { target?.minecraftUsername = u }
            if let x = xuid, !x.isEmpty { target?.xuid = x }
            if let a = avatarUrl, !a.isEmpty { target?.xboxAvatarUrl = a }
            target?.lastUpdated = Date()
            if let t = target { accounts[idx] = t }
        } else {
            target = MsftAccount(
                msUserId: msUserId,
                refreshToken: refreshToken,
                xboxGamertag: gamertag,
                minecraftUsername: minecraftUsername,
                xuid: xuid,
                xboxAvatarUrl: avatarUrl,
                isActive: accounts.isEmpty
            )
            if let t = target { accounts.append(t) }
        }
        save(accounts)
        return target ?? accounts.last!
    }

    static func remove(id: String) {
        var accounts = list()
        let removed = accounts.first { $0.id == id }
        accounts.removeAll { $0.id == id }
        if let removed = removed, !removed.msUserId.isEmpty {
            XalStorageManager.deleteUserDir(msUserId: removed.msUserId)
        }
        if !accounts.contains(where: { $0.isActive }), let first = accounts.first {
            accounts[0].isActive = true
        }
        save(accounts)
    }

    static func setActive(id: String) {
        var accounts = list()
        for i in accounts.indices {
            accounts[i].isActive = accounts[i].id == id
        }
        save(accounts)
    }

    static func find(id: String) -> MsftAccount? {
        list().first { $0.id == id }
    }

    static var activeAccount: MsftAccount? {
        list().first { $0.isActive }
    }
}
