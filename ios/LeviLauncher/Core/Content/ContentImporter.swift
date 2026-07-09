import Foundation
import UniformTypeIdentifiers

final class ContentImporter {
    static let shared = ContentImporter()

    enum ImportedContent {
        case world(WorldItem)
        case resourcePack(ResourcePackItem)
        case mod(Mod)
    }

    func importContent(from url: URL, into baseDir: URL) throws -> ImportedContent? {
        let ext = url.pathExtension.lowercased()

        switch ext {
        case "mcworld":
            return try importMCWorld(from: url, into: baseDir.appendingPathComponent("worlds"))

        case "mcpack", "mcaddon":
            guard let pack = try ResourcePackManager.shared.importPack(from: url, to: baseDir.appendingPathComponent("resource_packs")) else {
                throw ContentError.importFailed
            }
            return .resourcePack(pack)

        case "zip":
            if let world = try importZIPAsWorld(from: url, into: baseDir.appendingPathComponent("worlds")) {
                return world
            }
            if let pack = try ResourcePackManager.shared.importPack(from: url, to: baseDir.appendingPathComponent("resource_packs")) {
                return .resourcePack(pack)
            }
            throw ContentError.importFailed

        case "so", "dylib":
            let modsDir = baseDir.appendingPathComponent("mods")
            try FileManager.default.createDirectory(at: modsDir, withIntermediateDirectories: true)
            let dest = modsDir.appendingPathComponent(url.lastPathComponent)
            try FileManager.default.copyItem(at: url, to: dest)
            let mod = Mod(id: url.lastPathComponent, fileName: url.lastPathComponent,
                          entryPath: dest.path, displayName: url.deletingPathExtension().lastPathComponent)
            return .mod(mod)

        case "levibackup":
            return try importBackup(from: url, into: baseDir)

        default:
            throw ContentError.importFailed
        }
    }

    private func importMCWorld(from url: URL, into worldsDir: URL) throws -> ImportedContent {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        try FileManager.default.unzipItem(at: url, to: tempDir)

        let contents = try FileManager.default.contentsOfDirectory(at: tempDir, includingPropertiesForKeys: nil)
        let worldDir: URL
        if let levelDat = contents.first(where: { $0.lastPathComponent == "level.dat" }) {
            worldDir = tempDir
        } else if let subDir = contents.first(where: { $0.hasDirectoryPath }) {
            worldDir = subDir
        } else {
            throw ContentError.importFailed
        }

        let worldName = try worldNameFromLevelDat(worldDir.appendingPathComponent("level.dat"))
            ?? url.deletingPathExtension().lastPathComponent
        let destDir = worldsDir.appendingPathComponent(worldName)

        try FileManager.default.createDirectory(at: worldsDir, withIntermediateDirectories: true)
        if FileManager.default.fileExists(atPath: destDir.path) {
            try FileManager.default.removeItem(at: destDir)
        }
        try FileManager.default.moveItem(at: worldDir, to: destDir)

        return .world(WorldItem(name: worldName, file: destDir))
    }

    private func importZIPAsWorld(from url: URL, into worldsDir: URL) throws -> ImportedContent? {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        try FileManager.default.unzipItem(at: url, to: tempDir)

        let levelDatURL = tempDir.appendingPathComponent("level.dat")
        guard FileManager.default.fileExists(atPath: levelDatURL.path) else { return nil }

        let worldName = try worldNameFromLevelDat(levelDatURL) ?? url.deletingPathExtension().lastPathComponent
        let destDir = worldsDir.appendingPathComponent(worldName)

        try FileManager.default.createDirectory(at: worldsDir, withIntermediateDirectories: true)
        if FileManager.default.fileExists(atPath: destDir.path) {
            try FileManager.default.removeItem(at: destDir)
        }
        try FileManager.default.moveItem(at: tempDir, to: destDir)

        return .world(WorldItem(name: worldName, file: destDir))
    }

    private func importBackup(from url: URL, into baseDir: URL) throws -> ImportedContent {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }
        try FileManager.default.unzipItem(at: url, to: tempDir)
        throw ContentError.importFailed
    }

    private func worldNameFromLevelDat(_ url: URL) -> String? {
        guard let tag = try? BedrockNbtReader.read(from: url),
              let data = tag.tag("Data"),
              let levelName = data.tag("LevelName") else {
            return nil
        }
        return levelName.stringValue
    }
}
