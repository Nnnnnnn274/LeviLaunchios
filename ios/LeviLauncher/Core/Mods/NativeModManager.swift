import Foundation

/// iOS counterpart of LeviLaunchroid's native mod package manager.
///
/// Users install a ZIP package. After extraction it must contain
/// `manifest.json` plus one ARM64 `.dylib` native entry:
/// `{ "type": "preload-native", "entry": "Example.dylib", ... }`.
final class NativeModManager {
    static let shared = NativeModManager()

    private struct Manifest: Decodable {
        let type: String
        let name: String?
        let entry: String
        let author: String?
        let version: String?
        let icon: String?
        let description: String?
        let minecraftVersions: [String]?

        enum CodingKeys: String, CodingKey {
            case type, name, entry, author, version, icon, description
            case minecraftVersions = "minecraft_versions"
        }
    }

    private struct State: Codable {
        let name: String
        var enabled: Bool
        var order: Int
    }

    private let fileManager = FileManager.default
    private var configURL: URL { modsDirectory.appendingPathComponent("mods_config.json") }

    var modsDirectory: URL {
        let directory = LauncherStorage.minecraftRoot.appendingPathComponent("mods", isDirectory: true)
        LauncherStorage.ensureDir(directory)
        return directory
    }

    func discoverMods() -> [Mod] {
        migrateLooseDylibs()
        let saved = loadState()
        let entries = (try? fileManager.contentsOfDirectory(
            at: modsDirectory, includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles])) ?? []
        var mods = entries.compactMap { parseModDirectory($0) }

        mods.sort {
            let left = saved[$0.id]?.order ?? Int.max
            let right = saved[$1.id]?.order ?? Int.max
            return left == right ? $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
                : left < right
        }
        for index in mods.indices {
            mods[index].isEnabled = saved[mods[index].id]?.enabled ?? true
            mods[index].order = index
        }
        saveState(mods)
        return mods
    }

    func setEnabled(_ enabled: Bool, for mod: Mod) {
        var mods = discoverMods()
        guard let index = mods.firstIndex(where: { $0.id == mod.id }) else { return }
        mods[index].isEnabled = enabled
        saveState(mods)
    }

    @discardableResult
    func loadEnabledMods() -> [String] {
        let gameVersion = LauncherBridge.minecraftVersion()
        var failures: [String] = []
        for mod in discoverMods() where mod.isEnabled {
            guard isCompatible(mod.minecraftVersions, with: gameVersion) else {
                NSLog("[LeviLauncher] Skipping incompatible mod \(mod.displayName) for \(gameVersion)")
                continue
            }
            if !LauncherBridge.injectMod(mod.entryPath) {
                failures.append(mod.displayName)
                NSLog("[LeviLauncher] Failed to load native mod \(mod.displayName)")
            }
        }
        return failures
    }

    @discardableResult
    func importMod(from source: URL) throws -> Mod {
        let ext = source.pathExtension.lowercased()
        guard ext == "zip" || ext == "levipack" else { throw ContentError.importFailed }

        let temporary = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try fileManager.createDirectory(at: temporary, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: temporary) }
        try fileManager.unzipItem(at: source, to: temporary)

        let candidates = manifestDirectories(under: temporary).compactMap { parseModDirectory($0) }
        guard candidates.count == 1, let sourceRootPath = candidates[0].modRootPath else {
            throw ContentError.importFailed
        }
        let sourceRoot = URL(fileURLWithPath: sourceRootPath, isDirectory: true)
        guard dylibEntries(under: sourceRoot).count == 1 else { throw ContentError.importFailed }
        let packageName = candidates[0].displayName.nilIfEmpty
            ?? source.deletingPathExtension().lastPathComponent
        let destination = uniqueDirectory(named: packageName)
        do {
            try fileManager.copyItem(at: sourceRoot, to: destination)
        } catch {
            try? fileManager.removeItem(at: destination)
            throw error
        }
        guard let installed = parseModDirectory(destination) else {
            try? fileManager.removeItem(at: destination)
            throw ContentError.importFailed
        }
        var mods = discoverMods()
        if let index = mods.firstIndex(where: { $0.id == installed.id }) {
            mods[index].isEnabled = true
        }
        saveState(mods)
        return installed
    }

    private func parseModDirectory(_ directory: URL) -> Mod? {
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: directory.path, isDirectory: &isDirectory),
              isDirectory.boolValue else { return nil }
        let manifestURL = directory.appendingPathComponent("manifest.json")
        guard let data = try? Data(contentsOf: manifestURL),
              let manifest = try? JSONDecoder().decode(Manifest.self, from: data),
              manifest.type == "preload-native",
              let entryURL = safeChild(manifest.entry, of: directory),
              entryURL.pathExtension.lowercased() == "dylib",
              isArm64Dylib(entryURL) else { return nil }

        let iconURL = manifest.icon.flatMap { safeChild($0, of: directory) }
        let configDirectory = directory.appendingPathComponent("config", isDirectory: true)
        let configCount = ((try? fileManager.contentsOfDirectory(
            at: configDirectory, includingPropertiesForKeys: nil)) ?? [])
            .filter { $0.pathExtension.lowercased() == "json" }.count
        return Mod(
            id: directory.lastPathComponent,
            fileName: entryURL.lastPathComponent,
            entryPath: entryURL.path,
            displayName: manifest.name?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
                ?? directory.lastPathComponent,
            minecraftVersions: manifest.minecraftVersions ?? [],
            author: manifest.author,
            version: manifest.version,
            iconPath: iconURL.flatMap { fileManager.fileExists(atPath: $0.path) ? $0.path : nil },
            manifestPath: manifestURL.path,
            description: manifest.description,
            modRootPath: directory.path,
            configDirPath: configDirectory.path,
            hasEditableConfig: configCount > 0,
            configFileCount: configCount,
            isEnabled: true
        )
    }

    private func installLooseDylib(_ source: URL) throws -> Mod {
        let baseName = source.deletingPathExtension().lastPathComponent
        let destination = uniqueDirectory(named: sanitizeID(baseName))
        try fileManager.createDirectory(at: destination, withIntermediateDirectories: true)
        let library = destination.appendingPathComponent(source.lastPathComponent)
        do {
            try fileManager.copyItem(at: source, to: library)
            let manifest: [String: Any] = [
                "type": "preload-native", "name": baseName,
                "entry": library.lastPathComponent, "author": "Unknown", "version": "1.0.0",
            ]
            let data = try JSONSerialization.data(withJSONObject: manifest, options: [.prettyPrinted])
            try data.write(to: destination.appendingPathComponent("manifest.json"), options: .atomic)
        } catch {
            try? fileManager.removeItem(at: destination)
            throw error
        }
        guard let mod = parseModDirectory(destination) else { throw ContentError.importFailed }
        return mod
    }

    private func migrateLooseDylibs() {
        let loose = ((try? fileManager.contentsOfDirectory(
            at: modsDirectory, includingPropertiesForKeys: [.isRegularFileKey])) ?? [])
            .filter { $0.pathExtension.lowercased() == "dylib" }
        for library in loose {
            do {
                let mod = try installLooseDylib(library)
                try fileManager.removeItem(at: library)
                NSLog("[LeviLauncher] Migrated loose dylib to mod package \(mod.id)")
            } catch {
                NSLog("[LeviLauncher] Could not migrate \(library.lastPathComponent): \(error)")
            }
        }
    }

    private func manifestDirectories(under root: URL) -> [URL] {
        var result: [URL] = []
        if fileManager.fileExists(atPath: root.appendingPathComponent("manifest.json").path) {
            result.append(root)
        }
        guard let enumerator = fileManager.enumerator(
            at: root, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles]) else {
            return result
        }
        for case let file as URL in enumerator where file.lastPathComponent.lowercased() == "manifest.json" {
            let directory = file.deletingLastPathComponent()
            if directory != root { result.append(directory) }
        }
        return result
    }

    private func dylibEntries(under root: URL) -> [URL] {
        guard let enumerator = fileManager.enumerator(
            at: root, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles]) else {
            return []
        }
        var entries: [URL] = []
        for case let file as URL in enumerator where file.pathExtension.lowercased() == "dylib" {
            entries.append(file)
        }
        return entries
    }

    private func safeChild(_ relativePath: String, of root: URL) -> URL? {
        let normalized = relativePath.replacingOccurrences(of: "\\", with: "/")
        guard !normalized.hasPrefix("/"),
              !normalized.split(separator: "/").contains("..") else { return nil }
        let rootPath = root.standardizedFileURL.path + "/"
        let child = root.appendingPathComponent(normalized).standardizedFileURL
        return child.path.hasPrefix(rootPath) ? child : nil
    }

    private func isCompatible(_ patterns: [String], with version: String) -> Bool {
        let valid = patterns.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        guard !valid.isEmpty else { return true }
        return valid.contains { pattern in
            guard let wildcard = pattern.firstIndex(of: "*") else { return pattern == version }
            return version.hasPrefix(String(pattern[..<wildcard]))
        }
    }

    private func isArm64Dylib(_ url: URL) -> Bool {
        guard let bytes = try? Data(contentsOf: url, options: [.mappedIfSafe]), bytes.count >= 16 else {
            return false
        }
        func uint32(_ offset: Int) -> UInt32 {
            UInt32(bytes[offset])
                | (UInt32(bytes[offset + 1]) << 8)
                | (UInt32(bytes[offset + 2]) << 16)
                | (UInt32(bytes[offset + 3]) << 24)
        }
        return uint32(0) == 0xfeedfacf       // MH_MAGIC_64
            && uint32(4) == 0x0100000c       // CPU_TYPE_ARM64
            && uint32(12) == 0x6             // MH_DYLIB
    }

    private func loadState() -> [String: State] {
        guard let data = try? Data(contentsOf: configURL),
              let states = try? JSONDecoder().decode([State].self, from: data) else { return [:] }
        var result: [String: State] = [:]
        for state in states { result[state.name] = state }
        return result
    }

    private func saveState(_ mods: [Mod]) {
        let states = mods.enumerated().map { State(name: $0.element.id, enabled: $0.element.isEnabled, order: $0.offset) }
        guard let data = try? JSONEncoder().encode(states) else { return }
        try? data.write(to: configURL, options: .atomic)
    }

    private func uniqueDirectory(named rawName: String) -> URL {
        let name = sanitizeID(rawName)
        var candidate = modsDirectory.appendingPathComponent(name, isDirectory: true)
        var suffix = 1
        while fileManager.fileExists(atPath: candidate.path) {
            candidate = modsDirectory.appendingPathComponent("\(name)_\(suffix)", isDirectory: true)
            suffix += 1
        }
        return candidate
    }

    private func sanitizeID(_ value: String) -> String {
        let cleaned = value.map { $0.isLetter || $0.isNumber || "._-".contains($0) ? $0 : "_" }
        return String(cleaned).nilIfEmpty ?? "mod"
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
