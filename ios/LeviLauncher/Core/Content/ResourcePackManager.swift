import Foundation

final class ResourcePackManager {
    static let shared = ResourcePackManager()
    private let fileManager = FileManager.default

    func listPacks(in packsDir: URL) -> [ResourcePackItem] {
        var packs: [ResourcePackItem] = []
        guard let contents = try? fileManager.contentsOfDirectory(at: packsDir, includingPropertiesForKeys: nil) else {
            return []
        }
        for item in contents {
            let manifestURL = item.appendingPathComponent("manifest.json")
            guard let manifestData = try? Data(contentsOf: manifestURL),
                  let manifest = try? JSONSerialization.jsonObject(with: manifestData) as? [String: Any] else {
                continue
            }
            let pack = ResourcePackItem(name: item.lastPathComponent, file: item)

            if let header = manifest["header"] as? [String: Any] {
                pack.itemDescription = header["description"] as? String
                pack.packUUID = header["uuid"] as? String
                if let version = header["version"] as? [Int] {
                    pack.packVersion = version
                }
                pack.formatVersion = manifest["format_version"] as? Int
            }

            if let modules = manifest["modules"] as? [[String: Any]] {
                for module in modules {
                    if let type = module["type"] as? String {
                        switch type {
                        case "resources": pack.packType = .resource
                        case "data": pack.packType = .behavior
                        case "skin_pack": pack.packType = .skin
                        default: break
                        }
                        break
                    }
                }
            }

            packs.append(pack)
        }
        return packs.sorted { $0.name < $1.name }
    }

    func importPack(from sourceURL: URL, to destDir: URL) throws -> ResourcePackItem? {
        let fileName = sourceURL.lastPathComponent
        let destURL = destDir.appendingPathComponent(fileName)

        if fileName.hasSuffix(".mcpack") || fileName.hasSuffix(".zip") || fileName.hasSuffix(".mcaddon") {
            try fileManager.createDirectory(at: destDir, withIntermediateDirectories: true)
            let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            try fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true)
            defer { try? fileManager.removeItem(at: tempDir) }

            try fileManager.unzipItem(at: sourceURL, to: tempDir)

            let packName = fileName.replacingOccurrences(of: ".mcpack", with: "")
                .replacingOccurrences(of: ".mcaddon", with: "")
                .replacingOccurrences(of: ".zip", with: "")
            let packDir = destDir.appendingPathComponent(packName)
            if fileManager.fileExists(atPath: packDir.path) {
                try fileManager.removeItem(at: packDir)
            }

            let contents = try fileManager.contentsOfDirectory(at: tempDir, includingPropertiesForKeys: nil)
            if contents.count == 1 && contents[0].hasDirectoryPath {
                try fileManager.moveItem(at: contents[0], to: packDir)
            } else {
                try fileManager.moveItem(at: tempDir, to: packDir)
            }

            return ResourcePackItem(name: packName, file: packDir)
        }

        return nil
    }
}
