import Foundation

@MainActor
final class ModManager: ObservableObject {
    static let shared = ModManager()

    @Published var mods: [Mod] = []

    private let fileManager = FileManager.default

    func loadMods(for version: GameVersion) {
        guard let modsDir = version.modsDir else {
            mods = []
            return
        }
        var loaded: [Mod] = []
        do {
            let contents = try fileManager.contentsOfDirectory(at: modsDir, includingPropertiesForKeys: nil)
            for item in contents {
                if item.pathExtension == "so" || item.pathExtension == "dylib" {
                    let mod = Mod(
                        id: item.lastPathComponent,
                        fileName: item.lastPathComponent,
                        entryPath: item.path,
                        displayName: item.deletingPathExtension().lastPathComponent,
                        minecraftVersions: [version.versionCode],
                        isEnabled: true,
                        order: loaded.count
                    )
                    loaded.append(mod)
                } else if item.lastPathComponent == "manifest.json" {
                    if let data = try? Data(contentsOf: item),
                       let manifestMod = try? JSONDecoder().decode(Mod.self, from: data) {
                        loaded.append(manifestMod)
                    }
                }
            }
        } catch {
            Logger.warn("ModManager", "Failed to load mods: \(error)")
        }
        mods = loaded.sorted { $0.order < $1.order }
    }

    func toggleMod(_ mod: Mod) {
        guard let idx = mods.firstIndex(where: { $0.id == mod.id }) else { return }
        mods[idx].isEnabled.toggle()
    }

    func reorder(from source: IndexSet, to destination: Int) {
        mods.move(fromOffsets: source, toOffset: destination)
        for i in mods.indices {
            mods[i].order = i
        }
    }

    func removeMod(_ mod: Mod) {
        mods.removeAll { $0.id == mod.id }
        if let path = mod.modRootPath {
            try? fileManager.removeItem(atPath: path)
        }
    }
}
