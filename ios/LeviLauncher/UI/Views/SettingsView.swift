import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var settings: FeatureSettings

    var body: some View {
        NavigationStack {
            Form {
                Section("Appearance") {
                    Picker("Theme", selection: $settings.selectedTheme) {
                        Text("System").tag(FeatureSettings.ThemeMode.system)
                        Text("Light").tag(FeatureSettings.ThemeMode.light)
                        Text("Dark").tag(FeatureSettings.ThemeMode.dark)
                    }

                    Picker("Accent Color", selection: $settings.accentColor) {
                        ForEach(FeatureSettings.AccentColor.allCases, id: \.self) { color in
                            HStack {
                                Circle()
                                    .fill(accentSwiftUIColor(color))
                                    .frame(width: 16, height: 16)
                                Text(color.displayName)
                            }
                            .tag(color)
                        }
                    }

                    Picker("Language", selection: $settings.selectedLanguage) {
                        Text("English").tag("en")
                        Text("中文").tag("zh")
                        // More locales can be added
                    }
                }

                Section("Game") {
                    Toggle("Version Isolation", isOn: $settings.versionIsolation)
                    Toggle("Launcher-Managed Login", isOn: $settings.launcherManagedLogin)

                    Picker("Storage Type", selection: $settings.storageType) {
                        Text("Internal").tag(FeatureSettings.StorageType.internal)
                        Text("External").tag(FeatureSettings.StorageType.external)
                        Text("Version Isolated").tag(FeatureSettings.StorageType.versionIsolation)
                    }
                }

                Section("Advanced") {
                    Toggle("Crash Upload", isOn: $settings.crashUploadEnabled)
                    Toggle("Logcat Overlay", isOn: $settings.logcatOverlayEnabled)
                }

                Section("Storage") {
                    HStack {
                        Text("App Root")
                        Spacer()
                        Text(LauncherStorage.appRoot.path)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    HStack {
                        Text("Crash Logs")
                        Spacer()
                        Text(LauncherStorage.crashLogsDir.path)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.0")
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("Build")
                        Spacer()
                        Text(Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
        }
    }

    private func accentSwiftUIColor(_ color: FeatureSettings.AccentColor) -> Color {
        switch color {
        case .green: return .green
        case .blue: return .blue
        case .purple: return .purple
        case .orange: return .orange
        case .red: return .red
        case .teal: return .teal
        case .pink: return .pink
        case .indigo: return .indigo
        }
    }
}
