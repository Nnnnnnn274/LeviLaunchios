import SwiftUI

struct MainLaunchView: View {
    @EnvironmentObject private var versionManager: VersionManager
    @EnvironmentObject private var viewModel: MainViewModel
    @State private var showMods = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    headerView
                    versionSelector
                    quickActions
                    modsPreview
                }
                .padding()
            }
            .navigationTitle("LeviLauncher")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Accounts") { }
                }
            }
            .sheet(isPresented: $showMods) {
                ModsListView()
            }
        }
    }

    private var headerView: some View {
        VStack(spacing: 8) {
            Image(systemName: "leaf.fill")
                .font(.system(size: 60))
                .foregroundStyle(.green)
            Text("LeviLauncher")
                .font(.largeTitle.bold())
            Text("Minecraft: Bedrock Edition Launcher")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var versionSelector: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Game Version")
                .font(.headline)

            if versionManager.versions.isEmpty {
                ContentUnavailableView("No Versions",
                    systemImage: "square.dashed",
                    description: Text("Import a Minecraft version to get started"))
            } else {
                Picker("Version", selection: Binding(
                    get: { versionManager.selectedVersion?.id ?? "" },
                    set: { id in
                        versionManager.selectedVersion = versionManager.versions.first { $0.id == id }
                    }
                )) {
                    ForEach(versionManager.versions) { version in
                        HStack {
                            Text(version.displayName)
                            if version.isInstalled {
                                Image(systemName: "checkmark.seal.fill")
                                    .foregroundStyle(.green)
                            }
                        }
                        .tag(version.id)
                    }
                }
                .pickerStyle(.menu)
                .buttonStyle(.bordered)

                HStack {
                    Label("Version: \(versionManager.selectedVersion?.versionCode ?? "N/A")", systemImage: "tag")
                    Spacer()
                    if versionManager.selectedVersion?.versionIsolation ?? false {
                        Label("Isolated", systemImage: "square.split.diagonal.fill")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(.ultraThinMaterial))
    }

    private var quickActions: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            QuickActionButton(icon: "play.fill", title: "Launch", color: .green) {
                launchGame()
            }
            QuickActionButton(icon: "plus.square", title: "Import APK", color: .blue) {
                importAPK()
            }
            QuickActionButton(icon: "square.and.arrow.down", title: "Import Content", color: .orange) {
                importContent()
            }
            QuickActionButton(icon: "wrench.fill", title: "Mods", color: .purple) {
                showMods = true
            }
        }
    }

    private var modsPreview: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Active Mods")
                .font(.headline)
            if let selected = versionManager.selectedVersion {
                ModsPreviewView(version: selected)
            } else {
                Text("Select a version to view mods")
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12).fill(.ultraThinMaterial))
    }

    private func launchGame() {
        guard let version = versionManager.selectedVersion else { return }
        Task {
            await viewModel.login()
        }
    }

    private func importAPK() {
        // iOS: Prompt user to select Minecraft IPA
    }

    private func importContent() {
        // iOS: Document picker for .mcworld, .mcpack, etc.
    }
}

struct QuickActionButton: View {
    let icon: String
    let title: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                Text(title)
                    .font(.caption.bold())
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(RoundedRectangle(cornerRadius: 12).fill(color.opacity(0.15)))
            .foregroundStyle(color)
        }
    }
}

struct ModsPreviewView: View {
    let version: GameVersion
    @StateObject private var modManager = ModManager.shared

    var body: some View {
        if modManager.mods.isEmpty {
            Text("No mods installed")
                .foregroundStyle(.secondary)
                .font(.caption)
        } else {
            ForEach(modManager.mods.prefix(3)) { mod in
                HStack {
                    Image(systemName: mod.isEnabled ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(mod.isEnabled ? .green : .secondary)
                    Text(mod.displayName)
                        .font(.caption)
                    Spacer()
                }
            }
            if modManager.mods.count > 3 {
                Button("Show all (\(modManager.mods.count))") { }
                    .font(.caption)
            }
        }
    }
}
