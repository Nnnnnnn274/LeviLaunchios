import SwiftUI

@main
struct LeviLauncherApp: App {
    @StateObject private var settings = FeatureSettings.shared
    @StateObject private var versionManager = VersionManager.shared
    @StateObject private var viewModel = MainViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(settings)
                .environmentObject(versionManager)
                .environmentObject(viewModel)
                .preferredColorScheme(settings.selectedTheme == .dark ? .dark :
                                        settings.selectedTheme == .light ? .light : nil)
                .accentColor(accentColor(for: settings.accentColor))
                .onAppear {
                    versionManager.loadVersions()
                    LauncherStorage.ensureNoMedia()
                }
        }
    }

    private func accentColor(for color: FeatureSettings.AccentColor) -> Color {
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
