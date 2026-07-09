import SwiftUI

struct ModsListView: View {
    @StateObject private var modManager = ModManager.shared
    @EnvironmentObject private var versionManager: VersionManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if modManager.mods.isEmpty {
                    ContentUnavailableView("No Mods",
                        systemImage: "wrench.and.screwdriver",
                        description: Text("Add mods to customize your game"))
                } else {
                    List {
                        ForEach(modManager.mods) { mod in
                            ModRow(mod: mod)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    modManager.toggleMod(mod)
                                }
                        }
                        .onMove { src, dst in
                            modManager.reorder(from: src, to: dst)
                        }
                        .onDelete { indexSet in
                            for idx in indexSet {
                                modManager.removeMod(modManager.mods[idx])
                            }
                        }
                    }
                }
            }
            .navigationTitle("Mods")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    EditButton()
                }
            }
        }
        .onAppear {
            if let version = versionManager.selectedVersion {
                modManager.loadMods(for: version)
            }
        }
    }
}

struct ModRow: View {
    let mod: Mod

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: mod.isEnabled ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(mod.isEnabled ? .green : .secondary)
                .font(.title3)

            VStack(alignment: .leading, spacing: 2) {
                Text(mod.displayName)
                    .font(.headline)
                if let desc = mod.description {
                    Text(desc)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                HStack {
                    if let author = mod.author {
                        Text(author)
                            .font(.caption2)
                    }
                    if let version = mod.version {
                        Text("v\(version)")
                            .font(.caption2)
                    }
                }
                .foregroundStyle(.tertiary)
            }

            Spacer()

            if mod.hasEditableConfig {
                Image(systemName: "gearshape.fill")
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}
