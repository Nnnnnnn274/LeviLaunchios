import Foundation

@MainActor
final class VersionManager: ObservableObject {
    static let shared = VersionManager()

    @Published var versions: [GameVersion] = []
    @Published var selectedVersion: GameVersion?

    private let fileManager = FileManager.default

    func loadVersions() {
        var loaded: [GameVersion] = []

        let mcRoot = LauncherStorage.minecraftRoot
        guard let contents = try? fileManager.contentsOfDirectory(at: mcRoot,
                                                                    includingPropertiesForKeys: nil) else {
            versions = []
            return
        }

        for item in contents where item.hasDirectoryPath {
            let dirName = item.lastPathComponent
            guard !LauncherStorage.isReservedProfileId(dirName) else { continue }

            let meta = VersionProfileMetadataStore.read(from: item)
            let versionCode = meta?.versionName ?? dirName
            let displayName = meta?.displayName ?? dirName
            let versionIsolation = meta?.versionIsolation ?? true
            let launchVertically = meta?.launchVertically ?? false

            let gv = GameVersion(
                directoryName: dirName,
                displayName: displayName,
                versionCode: versionCode,
                versionDir: item,
                isOfficial: dirName == LauncherStorage.installedMinecraftProfileId,
                packageName: "com.mojang.minecraftpe",
                abiList: ""
            )
            loaded.append(gv)
        }

        versions = loaded.sorted { $0.displayName < $1.displayName }

        if selectedVersion == nil, let first = versions.first {
            selectedVersion = first
        }
    }

    func selectVersion(_ version: GameVersion) {
        selectedVersion = version
    }
}
