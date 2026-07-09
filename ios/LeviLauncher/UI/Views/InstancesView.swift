import SwiftUI

struct InstancesView: View {
    @EnvironmentObject private var versionManager: VersionManager
    @State private var searchText = ""
    @State private var filter: Filter = .all

    enum Filter: String, CaseIterable {
        case all = "All"
        case custom = "Custom"
    }

    var body: some View {
        NavigationStack {
            VStack {
                Picker("Filter", selection: $filter) {
                    ForEach(Filter.allCases, id: \.self) { f in
                        Text(f.rawValue).tag(f)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

                if filteredVersions.isEmpty {
                    ContentUnavailableView("No Versions",
                        systemImage: "square.grid.2x2",
                        description: Text("Import a Minecraft version to create an instance"))
                } else {
                    ScrollView {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 160))], spacing: 12) {
                            ForEach(filteredVersions) { version in
                                InstanceCard(version: version)
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Instances")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Import", systemImage: "plus") { }
                }
            }
        }
    }

    private var filteredVersions: [GameVersion] {
        var result = versionManager.versions
        if filter == .custom {
            result = result.filter { !$0.isInstalled }
        }
        if !searchText.isEmpty {
            result = result.filter { $0.displayName.localizedCaseInsensitiveContains(searchText) }
        }
        return result
    }
}

struct InstanceCard: View {
    let version: GameVersion

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: version.isInstalled ? "checkmark.seal.fill" : "square.dashed")
                    .foregroundStyle(version.isInstalled ? .green : .orange)
                Spacer()
                Text(version.versionCode)
                    .font(.caption2)
                    .padding(4)
                    .background(Capsule().fill(.ultraThinMaterial))
            }

            Text(version.displayName)
                .font(.headline)
                .lineLimit(2)

            HStack {
                Label("\(version.versionIsolation ? "Isolated" : "Shared")", systemImage: "square.split.diagonal.fill")
                    .font(.caption2)
                Spacer()
            }
            .foregroundStyle(.secondary)
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(.ultraThinMaterial))
    }
}
