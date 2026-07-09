import Foundation

final class FeatureSettings: ObservableObject {
    static let shared = FeatureSettings()

    enum StorageType: String, Codable {
        case `internal` = "INTERNAL"
        case external = "EXTERNAL"
        case versionIsolation = "VERSION_ISOLATION"
        case versionIsolationInternal = "VERSION_ISOLATION_INTERNAL"
        case versionIsolationExternal = "VERSION_ISOLATION_EXTERNAL"
    }

    @Published var versionIsolation: Bool {
        didSet { save() }
    }
    @Published var launcherManagedLogin: Bool {
        didSet { save() }
    }
    @Published var logcatOverlayEnabled: Bool {
        didSet { save() }
    }
    @Published var crashUploadEnabled: Bool {
        didSet { save() }
    }
    @Published var selectedTheme: ThemeMode {
        didSet { save() }
    }
    @Published var accentColor: AccentColor {
        didSet { save() }
    }
    @Published var selectedLanguage: String {
        didSet { save() }
    }
    @Published var storageType: StorageType {
        didSet { save() }
    }

    enum ThemeMode: String, Codable {
        case system, light, dark
    }

    enum AccentColor: String, Codable, CaseIterable {
        case green, blue, purple, orange, red, teal, pink, indigo

        var displayName: String { rawValue.capitalized }
    }

    private let defaults = UserDefaults.standard
    private let suiteName = "com.levimc.launcher.settings"

    static let settingsURL: URL = {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return paths[0].appendingPathComponent("settings.json")
    }()

    init() {
        let saved = Self.load()
        self.versionIsolation = saved?.versionIsolation ?? true
        self.launcherManagedLogin = saved?.launcherManagedLogin ?? true
        self.logcatOverlayEnabled = saved?.logcatOverlayEnabled ?? false
        self.crashUploadEnabled = saved?.crashUploadEnabled ?? true
        self.selectedTheme = saved?.selectedTheme ?? .system
        self.accentColor = saved?.accentColor ?? .green
        self.selectedLanguage = saved?.selectedLanguage ?? "en"
        self.storageType = saved?.storageType ?? .internal
    }

    private struct SettingsData: Codable {
        var versionIsolation: Bool
        var launcherManagedLogin: Bool
        var logcatOverlayEnabled: Bool
        var crashUploadEnabled: Bool
        var selectedTheme: ThemeMode
        var accentColor: AccentColor
        var selectedLanguage: String
        var storageType: StorageType
    }

    private static func load() -> SettingsData? {
        guard let data = try? Data(contentsOf: settingsURL),
              let settings = try? JSONDecoder().decode(SettingsData.self, from: data) else {
            return nil
        }
        return settings
    }

    private func save() {
        let data = SettingsData(
            versionIsolation: versionIsolation,
            launcherManagedLogin: launcherManagedLogin,
            logcatOverlayEnabled: logcatOverlayEnabled,
            crashUploadEnabled: crashUploadEnabled,
            selectedTheme: selectedTheme,
            accentColor: accentColor,
            selectedLanguage: selectedLanguage,
            storageType: storageType
        )
        if let encoded = try? JSONEncoder().encode(data) {
            try? encoded.write(to: Self.settingsURL, options: .atomic)
        }
    }
}
