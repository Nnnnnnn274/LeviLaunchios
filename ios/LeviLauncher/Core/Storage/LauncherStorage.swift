import Foundation

struct LauncherStorage {
    static let minecraftDir = "minecraft"
    static let sharedProfileId = "_shared"
    static let legacyUnclassifiedDir = "_legacy_unclassified"
    static let installedMinecraftProfileId = "com.mojang.minecraftpe"
    static let internalStorageDir = "internal"
    static let externalStorageDir = "external"
    static let profileDataDir = "data"
    static let profileCacheDir = "cache"
    static let profileModsDir = "mods"
    static let profileMetadataDir = "metadata"
    static let gamesDir = "games"
    static let mojangDir = "com.mojang"
    static let crashLogsDir = "crash_logs"
    static let backupsDir = "backups"
    static let worldsDir = "worlds"

    static var appRoot: URL = {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return paths[0]
    }()

    static var minecraftRoot: URL {
        let dir = appRoot.appendingPathComponent(minecraftDir)
        ensureDir(dir)
        return dir
    }

    static var sharedRoot: URL {
        let dir = minecraftRoot.appendingPathComponent(sharedProfileId)
        ensureDir(dir)
        return dir
    }

    static var sharedDataRoot: URL {
        let dir = sharedRoot.appendingPathComponent(profileDataDir)
        ensureDir(dir)
        return dir
    }

    static var sharedCacheRoot: URL {
        let dir = sharedRoot.appendingPathComponent(profileCacheDir)
        ensureDir(dir)
        return dir
    }

    static func versionRoot(_ profileId: String) -> URL {
        let dir = minecraftRoot.appendingPathComponent(sanitizeProfileId(profileId))
        ensureDir(dir)
        return dir
    }

    static func versionDir(_ directoryName: String) -> URL {
        versionRoot(directoryName)
    }

    static func profileFilesRoot(_ profileId: String, external: Bool = false) -> URL {
        let dir = versionRoot(profileId).appendingPathComponent(external ? externalStorageDir : internalStorageDir)
        ensureDir(dir)
        let gameData = dir.appendingPathComponent("\(gamesDir)/\(mojangDir)")
        ensureDir(gameData)
        return dir
    }

    static func profileGameDataDir(_ profileId: String, external: Bool = true) -> URL {
        profileFilesRoot(profileId, external: external)
            .appendingPathComponent("\(gamesDir)/\(mojangDir)")
    }

    static func profileDataRoot(_ profileId: String) -> URL {
        let dir = versionRoot(profileId).appendingPathComponent(profileDataDir)
        ensureDir(dir)
        return dir
    }

    static func profileCacheRoot(_ profileId: String) -> URL {
        let dir = versionRoot(profileId).appendingPathComponent(profileCacheDir)
        ensureDir(dir)
        return dir
    }

    static func profileModsDir(_ profileId: String) -> URL {
        let dir = versionRoot(profileId).appendingPathComponent(profileModsDir)
        ensureDir(dir)
        return dir
    }

    static var crashLogsDir: URL {
        let dir = appRoot.appendingPathComponent(crashLogsDir)
        ensureDir(dir)
        return dir
    }

    static var backupsRoot: URL {
        let dir = appRoot.appendingPathComponent(backupsDir)
        ensureDir(dir)
        return dir
    }

    static var worldBackupsDir: URL {
        backupsRoot.appendingPathComponent(worldsDir)
    }

    static func storageFilesRoot(_ profileId: String, versionIsolation: Bool, external: Bool) -> URL {
        versionIsolation
            ? profileFilesRoot(profileId, external: external)
            : (external ? sharedRoot : sharedDataRoot)
    }

    static func storageGameDataDir(_ profileId: String, versionIsolation: Bool, external: Bool) -> URL {
        versionIsolation
            ? profileGameDataDir(profileId, external: external)
            : sharedDataRoot.appendingPathComponent("\(gamesDir)/\(mojangDir)")
    }

    static func storageDataRoot(_ profileId: String, versionIsolation: Bool) -> URL {
        versionIsolation
            ? profileDataRoot(profileId)
            : sharedDataRoot
    }

    static func storageCacheRoot(_ profileId: String, versionIsolation: Bool) -> URL {
        versionIsolation
            ? profileCacheRoot(profileId)
            : sharedCacheRoot
    }

    static func sanitizeProfileId(_ value: String) -> String {
        guard !value.isEmpty else { return "default" }
        var sanitized = value.reduce(into: "") { result, char in
            if char.isLetter || char.isNumber || char == "." || char == "_" || char == "-" {
                result.append(char)
            } else {
                result.append("_")
            }
        }
        while sanitized.hasSuffix(".") { sanitized = String(sanitized.dropLast()) }
        if sanitized.isEmpty { return "default" }
        let lower = sanitized.lowercased()
        if lower == sharedProfileId || lower == legacyUnclassifiedDir {
            return sanitized + "_profile"
        }
        return sanitized
    }

    static func isReservedProfileId(_ value: String) -> Bool {
        let profileId = value.trimmingCharacters(in: .whitespaces).lowercased()
        return profileId == sharedProfileId || profileId == legacyUnclassifiedDir
    }

    static func contentGameDataDir(_ profileId: String, storageType: FeatureSettings.StorageType) -> URL {
        switch storageType {
        case .versionIsolation, .versionIsolationExternal:
            return profileGameDataDir(profileId, external: true)
        case .versionIsolationInternal:
            return profileGameDataDir(profileId, external: false)
        case .external:
            return sharedDataRoot.appendingPathComponent("\(gamesDir)/\(mojangDir)")
        case .internal:
            return sharedDataRoot.appendingPathComponent("\(gamesDir)/\(mojangDir)")
        }
    }

    static func normalizeContentStorageType(_ storageType: FeatureSettings.StorageType?,
                                             versionIsolation: Bool) -> FeatureSettings.StorageType {
        let safeType = storageType ?? .internal
        if versionIsolation {
            switch safeType {
            case .external, .versionIsolation, .versionIsolationExternal:
                return .versionIsolationExternal
            case .internal, .versionIsolationInternal:
                return .versionIsolationInternal
            }
        }
        switch safeType {
        case .external, .versionIsolation, .versionIsolationExternal:
            return .external
        case .internal, .versionIsolationInternal:
            return .internal
        }
    }

    static func ensureNoMedia() {
        let noMedia = appRoot.appendingPathComponent(".nomedia")
        guard !FileManager.default.fileExists(atPath: noMedia.path) else { return }
        try? FileManager.default.createDirectory(at: appRoot, withIntermediateDirectories: true)
        FileManager.default.createFile(atPath: noMedia.path, contents: nil)
    }

    @discardableResult
    static func ensureDir(_ url: URL) -> Bool {
        guard !FileManager.default.fileExists(atPath: url.path) else {
            var isDir: ObjCBool = false
            FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir)
            return isDir.boolValue
        }
        do {
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
            return true
        } catch {
            return false
        }
    }
}
