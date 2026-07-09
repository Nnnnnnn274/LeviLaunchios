import SwiftUI

struct CurseForgeView: View {
    @State private var searchText = ""
    @State private var results: [CurseForgeClient.SearchResult] = []
    @State private var isLoading = false
    @State private var selectedSort = 0

    private let client = CurseForgeClient.shared

    var body: some View {
        Group {
            if results.isEmpty && !isLoading {
                ContentUnavailableView("Search CurseForge",
                    systemImage: "magnifyingglass",
                    description: Text("Search for mods, resource packs, and more"))
            } else {
                List(results, id: \.id) { item in
                    NavigationLink(destination: CurseForgeDetailView(modId: item.id)) {
                        HStack(spacing: 12) {
                            AsyncImage(url: item.logo?.thumbnailUrl.flatMap { URL(string: $0) }) { image in
                                image.resizable().aspectRatio(contentMode: .fill)
                            } placeholder: {
                                Rectangle().fill(.ultraThinMaterial)
                            }
                            .frame(width: 44, height: 44)
                            .clipShape(RoundedRectangle(cornerRadius: 8))

                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.name)
                                    .font(.headline)
                                if let summary = item.summary {
                                    Text(summary)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                }
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("CurseForge")
        .searchable(text: $searchText, prompt: "Search mods...")
        .onSubmit(of: .search) {
            Task { await search() }
        }
        .overlay {
            if isLoading {
                ProgressView()
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Picker("Sort", selection: $selectedSort) {
                    Text("Relevance").tag(0)
                    Text("Popularity").tag(1)
                    Text("Updated").tag(2)
                }
            }
        }
    }

    private func search() async {
        guard !searchText.isEmpty else { return }
        isLoading = true
        do {
            results = try await client.searchMods(query: searchText, sort: selectedSort)
        } catch {
            Logger.error("CurseForge", "Search failed: \(error)")
        }
        isLoading = false
    }
}

struct CurseForgeDetailView: View {
    let modId: Int
    @State private var detail: CurseForgeClient.SearchResult?
    @State private var files: [CurseForgeClient.CurseForgeFile] = []
    @State private var isLoading = true

    private let client = CurseForgeClient.shared

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
            } else if let detail = detail {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        if let logo = detail.logo, let url = logo.url ?? logo.thumbnailUrl {
                            AsyncImage(url: URL(string: url)) { image in
                                image.resizable().aspectRatio(contentMode: .fit)
                            } placeholder: {
                                Rectangle().fill(.ultraThinMaterial).frame(height: 200)
                            }
                            .frame(maxHeight: 200)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }

                        Text(detail.name)
                            .font(.title.bold())

                        if let summary = detail.summary {
                            Text(summary)
                                .foregroundStyle(.secondary)
                        }

                        if !files.isEmpty {
                            Text("Files")
                                .font(.headline)

                            ForEach(files) { file in
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(file.displayName ?? file.fileName ?? "Unknown")
                                            .font(.subheadline)
                                        if let date = file.fileDate {
                                            Text(date)
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                    Spacer()
                                    if let version = file.gameVersion?.first {
                                        Text(version)
                                            .font(.caption2)
                                            .padding(4)
                                            .background(Capsule().fill(.ultraThinMaterial))
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                    .padding()
                }
            }
        }
        .navigationTitle(detail?.name ?? "Details")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadDetail()
        }
    }

    private func loadDetail() async {
        do {
            detail = try await client.getMod(modId: modId)
            files = try await client.getFiles(modId: modId)
        } catch {
            Logger.error("CurseForge", "Failed to load detail: \(error)")
        }
        isLoading = false
    }
}
