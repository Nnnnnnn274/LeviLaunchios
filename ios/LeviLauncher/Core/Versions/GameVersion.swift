import Foundation

struct GameVersion: Identifiable, Codable {
    var id: String { directoryName }
    let directoryName: String
    var versionCode: String
    var displayName: String
    var versionDir: URL?
    var isInstalled: Bool
    var packageName: String
    var needsRepair: Bool
    var onlyVersionTxt: Bool
    var onlyAbiList: Bool
    var isExtractFalse: Bool
    var abiList: String
    var versionIsolation: Bool
    var launchVertically: Bool
    var modsDir: URL?

    init(directoryName: String, displayName: String, versionCode: String,
         versionDir: URL?, isOfficial: Bool, packageName: String, abiList: String) {
        self.directoryName = directoryName
        self.displayName = displayName
        self.versionCode = versionCode
        self.versionDir = versionDir
        self.isInstalled = isOfficial
        self.packageName = packageName
        self.needsRepair = false
        self.onlyVersionTxt = false
        self.onlyAbiList = false
        self.isExtractFalse = false
        self.abiList = abiList
        self.versionIsolation = !isOfficial
        self.launchVertically = false
        self.modsDir = versionDir?.appendingPathComponent(LauncherStorage.profileModsDir)
    }

    var storageProfileId: String {
        if isInstalled { return LauncherStorage.installedMinecraftProfileId }
        return LauncherStorage.sanitizeProfileId(directoryName)
    }
}
