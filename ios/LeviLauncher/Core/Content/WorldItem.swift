import Foundation

class WorldItem: ContentItem {
    var gameMode: String?
    var lastPlayed: Date?

    override var type: String { "World" }

    override var description: String {
        var parts: [String] = []
        if let gm = gameMode { parts.append("Mode: \(gm)") }
        parts.append(formattedSize)
        return parts.joined(separator: " · ")
    }

    override var isValid: Bool {
        file != nil && FileManager.default.fileExists(atPath: file!.path)
    }
}
