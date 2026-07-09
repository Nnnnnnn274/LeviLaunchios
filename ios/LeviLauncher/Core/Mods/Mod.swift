import Foundation

struct Mod: Identifiable, Codable {
    let id: String
    let fileName: String
    let entryPath: String
    let displayName: String
    let minecraftVersions: [String]
    let author: String?
    let version: String?
    let iconPath: String?
    let manifestPath: String?
    let description: String?
    let modRootPath: String?
    let configDirPath: String?
    let hasEditableConfig: Bool
    let configFileCount: Int
    var isEnabled: Bool
    var order: Int

    enum CodingKeys: String, CodingKey {
        case id, fileName, entryPath, displayName, minecraftVersions
        case author, version, iconPath, manifestPath, description
        case modRootPath, configDirPath, hasEditableConfig, configFileCount
        case isEnabled = "enabled", order
    }

    init(id: String, fileName: String, entryPath: String, displayName: String,
         minecraftVersions: [String] = [], author: String? = nil, version: String? = nil,
         iconPath: String? = nil, manifestPath: String? = nil, description: String? = nil,
         modRootPath: String? = nil, configDirPath: String? = nil,
         hasEditableConfig: Bool = false, configFileCount: Int = 0,
         isEnabled: Bool = false, order: Int = 0) {
        self.id = id
        self.fileName = fileName
        self.entryPath = entryPath
        self.displayName = displayName
        self.minecraftVersions = minecraftVersions
        self.author = author
        self.version = version
        self.iconPath = iconPath
        self.manifestPath = manifestPath
        self.description = description
        self.modRootPath = modRootPath
        self.configDirPath = configDirPath
        self.hasEditableConfig = hasEditableConfig
        self.configFileCount = configFileCount
        self.isEnabled = isEnabled
        self.order = order
    }
}
