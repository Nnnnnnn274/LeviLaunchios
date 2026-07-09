import Foundation

struct VersionProfileMetadata: Codable {
    var schemaVersion: Int
    var profileId: String
    var directoryName: String
    var versionName: String
    var displayName: String
    var versionIsolation: Bool
    var launchVertically: Bool

    init(schemaVersion: Int = 2, profileId: String, directoryName: String,
         versionName: String, displayName: String, versionIsolation: Bool = true,
         launchVertically: Bool = false) {
        self.schemaVersion = schemaVersion
        self.profileId = profileId
        self.directoryName = directoryName
        self.versionName = versionName
        self.displayName = displayName
        self.versionIsolation = versionIsolation
        self.launchVertically = launchVertically
    }
}

final class VersionProfileMetadataStore {
    static let filename = "profile.json"

    static func read(from dir: URL) -> VersionProfileMetadata? {
        let url = dir.appendingPathComponent(filename)
        guard let data = try? Data(contentsOf: url),
              let meta = try? JSONDecoder().decode(VersionProfileMetadata.self, from: data) else {
            return nil
        }
        return meta
    }

    static func write(_ meta: VersionProfileMetadata, to dir: URL) {
        let url = dir.appendingPathComponent(filename)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        if let data = try? JSONEncoder().encode(meta) {
            try? data.write(to: url, options: .atomic)
        }
    }
}
