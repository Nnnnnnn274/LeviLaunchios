import Foundation

class ResourcePackItem: ContentItem {
    enum PackType: String {
        case resource = "resources"
        case behavior = "behaviors"
        case skin = "skins"
    }

    var packType: PackType = .resource
    var formatVersion: Int?
    var packUUID: String?
    var packVersion: [Int]?
    var itemDescription: String?

    override var type: String {
        switch packType {
        case .resource: return "Resource Pack"
        case .behavior: return "Behavior Pack"
        case .skin: return "Skin Pack"
        }
    }

    override var description: String {
        itemDescription ?? formattedSize
    }

    override var isValid: Bool {
        file != nil && FileManager.default.fileExists(atPath: file!.path)
    }
}
