import Foundation

final class WorldManager {
    static let shared = WorldManager()
    private let fileManager = FileManager.default

    func listWorlds(in worldsDir: URL) -> [WorldItem] {
        var worlds: [WorldItem] = []
        guard let contents = try? fileManager.contentsOfDirectory(at: worldsDir, includingPropertiesForKeys: nil) else {
            return []
        }
        for item in contents where item.hasDirectoryPath {
            let world = WorldItem(name: item.lastPathComponent, file: item)
            if let levelDat = try? BedrockNbtReader.read(from: item.appendingPathComponent("level.dat")) {
                world.gameMode = worldGameMode(from: levelDat)
                world.lastPlayed = worldLastPlayed(from: levelDat)
            }
            worlds.append(world)
        }
        return worlds.sorted { $0.lastModified > $1.lastModified }
    }

    func exportWorld(_ world: WorldItem, to url: URL) throws {
        guard let worldDir = world.file else { throw ContentError.invalidWorld }
        let coordinator = NSFileCoordinator()
        var error: NSError?
        coordinator.coordinate(readingItemAt: worldDir, options: .forUploading,
                                error: &error) { zipURL in
            try? fileManager.copyItem(at: zipURL, to: url)
        }
        if let error = error { throw error }
    }

    func deleteWorld(_ world: WorldItem) throws {
        guard let worldDir = world.file else { throw ContentError.invalidWorld }
        try fileManager.removeItem(at: worldDir)
    }

    func duplicateWorld(_ world: WorldItem) throws -> WorldItem? {
        guard let worldDir = world.file else { throw ContentError.invalidWorld }
        let parent = worldDir.deletingLastPathComponent()
        let newName = world.name + " Copy"
        let newDir = parent.appendingPathComponent(newName)
        try fileManager.copyItem(at: worldDir, to: newDir)
        return WorldItem(name: newName, file: newDir)
    }

    // MARK: - level.dat parsing

    private func worldGameMode(from tag: NbtTag) -> String? {
        guard let data = tag.tag("Data"),
              let gmTag = data.tag("GameType") else { return nil }
        switch gmTag.intValue {
        case 0: return "Survival"
        case 1: return "Creative"
        case 2: return "Adventure"
        case 3: return "Spectator"
        default: return "Unknown"
        }
    }

    private func worldLastPlayed(from tag: NbtTag) -> Date? {
        guard let data = tag.tag("Data"),
              let lpTag = data.tag("LastPlayed") else { return nil }
        return Date(timeIntervalSince1970: TimeInterval(lpTag.longValue) / 1000)
    }
}

enum ContentError: LocalizedError {
    case invalidWorld
    case invalidPack
    case importFailed

    var errorDescription: String? {
        switch self {
        case .invalidWorld: return "Invalid world"
        case .invalidPack: return "Invalid resource pack"
        case .importFailed: return "Failed to import content"
        }
    }
}
