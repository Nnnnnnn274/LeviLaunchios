import Foundation

final class ResourcePackManager {
    static let shared = ResourcePackManager()
    private let fileManager = FileManager.default
    private let disabledPacksKey = "LeviLauncher.disabledResourcePacks"
    private let imageExtensions: Set<String> = ["png", "tga", "jpg", "jpeg"]

    /// The real Bedrock content directory inside the injected Minecraft app.
    var packsDirectory: URL {
        LauncherStorage.appRoot
            .appendingPathComponent("games/com.mojang/resource_packs", isDirectory: true)
    }

    func listPacks(in packsDir: URL) -> [ResourcePackItem] {
        var packs: [ResourcePackItem] = []
        guard let enumerator = fileManager.enumerator(
            at: packsDir,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }
        for case let manifestURL as URL in enumerator where manifestURL.lastPathComponent.lowercased() == "manifest.json" {
            let item = manifestURL.deletingLastPathComponent()
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

            pack.isEnabled = isEnabled(pack)
            packs.append(pack)
            enumerator.skipDescendants()
        }
        return packs.sorted { $0.name < $1.name }
    }

    func setEnabled(_ enabled: Bool, for pack: ResourcePackItem) {
        var disabled = Set(UserDefaults.standard.stringArray(forKey: disabledPacksKey) ?? [])
        let key = persistenceKey(for: pack)
        if enabled {
            disabled.remove(key)
        } else {
            disabled.insert(key)
        }
        UserDefaults.standard.set(Array(disabled).sorted(), forKey: disabledPacksKey)
        pack.isEnabled = enabled
    }

    func isEnabled(_ pack: ResourcePackItem) -> Bool {
        let disabled = Set(UserDefaults.standard.stringArray(forKey: disabledPacksKey) ?? [])
        return !disabled.contains(persistenceKey(for: pack))
    }

    /// Builds a flat lookup table once, instead of touching the filesystem on
    /// Minecraft's render/loading threads for every image request.
    func textureOverrides(in packsDir: URL? = nil) -> [String: String] {
        let directory = packsDir ?? packsDirectory
        var overrides: [String: String] = [:]
        let packs = listPacks(in: directory).filter { $0.packType == .resource && $0.isEnabled }

        for pack in packs {
            guard let root = pack.file,
                  let enumerator = fileManager.enumerator(
                    at: root,
                    includingPropertiesForKeys: [.isRegularFileKey],
                    options: [.skipsHiddenFiles]
                  ) else { continue }

            for case let fileURL as URL in enumerator {
                guard imageExtensions.contains(fileURL.pathExtension.lowercased()) else { continue }
                let prefix = root.path.hasSuffix("/") ? root.path : root.path + "/"
                guard fileURL.path.hasPrefix(prefix) else { continue }
                let relative = String(fileURL.path.dropFirst(prefix.count))
                    .replacingOccurrences(of: "\\", with: "/")
                    .lowercased()
                overrides[relative] = fileURL.path

                // Bedrock callers are not consistent about including the file
                // extension, so index both forms.
                let withoutExtension = (relative as NSString).deletingPathExtension
                overrides[withoutExtension] = fileURL.path
            }
        }
        return overrides
    }

    @discardableResult
    func applyTextureOverrides() -> Bool {
        syncGlobalResourcePacks()
        let overrides = textureOverrides()
        let installed = LauncherBridge.setTextureOverrides(overrides)
        NSLog("[LeviLauncher] Texture hook \(installed ? "ready" : "unavailable") " +
              "with \(overrides.count) override path(s)")
        return installed
    }

    /// Mirrors launcher enablement into Bedrock's native global pack stack so
    /// non-image resources (UI, sounds, atlases, materials and text) load too.
    private func syncGlobalResourcePacks() {
        let packs = listPacks(in: packsDirectory).filter { $0.packType == .resource }
        let installedIDs = Set(packs.compactMap { $0.packUUID?.lowercased() })
        let configURL = packsDirectory.deletingLastPathComponent()
            .appendingPathComponent("global_resource_packs.json")

        var entries: [[String: Any]] = []
        if let data = try? Data(contentsOf: configURL),
           let existing = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
            // Preserve entries owned by Minecraft or other tools. Installed
            // launcher packs are re-added below according to their toggle.
            entries = existing.filter { entry in
                guard let id = (entry["pack_id"] as? String)?.lowercased() else { return true }
                return !installedIDs.contains(id)
            }
        }

        for pack in packs where pack.isEnabled {
            guard let id = pack.packUUID, !id.isEmpty else { continue }
            entries.append([
                "pack_id": id,
                "version": pack.packVersion ?? [1, 0, 0],
            ])
        }

        do {
            let data = try JSONSerialization.data(withJSONObject: entries, options: [.prettyPrinted])
            try fileManager.createDirectory(
                at: configURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try data.write(to: configURL, options: .atomic)
        } catch {
            NSLog("[LeviLauncher] Could not update global resource packs: \(error)")
        }
    }

    func importPack(from sourceURL: URL, to destDir: URL) throws -> ResourcePackItem? {
        let fileName = sourceURL.lastPathComponent
        let fileExtension = sourceURL.pathExtension.lowercased()
        if ["mcpack", "zip", "mcaddon"].contains(fileExtension) {
            try fileManager.createDirectory(at: destDir, withIntermediateDirectories: true)
            let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            try fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true)
            defer { try? fileManager.removeItem(at: tempDir) }

            try fileManager.unzipItem(at: sourceURL, to: tempDir)

            let packName = sourceURL.deletingPathExtension().lastPathComponent
            let packDir = destDir.appendingPathComponent(packName)

            let contents = try fileManager.contentsOfDirectory(at: tempDir, includingPropertiesForKeys: nil)
            let extractedRoot = contents.count == 1 && contents[0].hasDirectoryPath ? contents[0] : tempDir
            guard !listPacks(in: extractedRoot).isEmpty else { return nil }

            if fileManager.fileExists(atPath: packDir.path) {
                try fileManager.removeItem(at: packDir)
            }

            if contents.count == 1 && contents[0].hasDirectoryPath {
                try fileManager.moveItem(at: contents[0], to: packDir)
            } else {
                try fileManager.moveItem(at: tempDir, to: packDir)
            }

            guard let imported = listPacks(in: packDir).first else {
                try? fileManager.removeItem(at: packDir)
                return nil
            }
            setEnabled(true, for: imported)
            return imported
        }

        return nil
    }

    private func persistenceKey(for pack: ResourcePackItem) -> String {
        if let uuid = pack.packUUID, !uuid.isEmpty { return uuid.lowercased() }
        return pack.file?.standardizedFileURL.path.lowercased() ?? pack.name.lowercased()
    }
}
