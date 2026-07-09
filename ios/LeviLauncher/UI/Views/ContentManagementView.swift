import SwiftUI

struct ContentManagementView: View {
    var body: some View {
        NavigationStack {
            List {
                Section("Content") {
                    NavigationLink(destination: WorldListView()) {
                        Label("Worlds", systemImage: "globe")
                    }
                    NavigationLink(destination: ResourcePackListView()) {
                        Label("Resource Packs", systemImage: "paintbrush.fill")
                    }
                    NavigationLink(destination: ServerListView()) {
                        Label("Servers", systemImage: "server.rack")
                    }
                    NavigationLink(destination: ScreenshotListView()) {
                        Label("Screenshots", systemImage: "photo.on.rectangle")
                    }
                }

                Section("Browse") {
                    NavigationLink(destination: CurseForgeView()) {
                        Label("CurseForge", systemImage: "globe.desk")
                    }
                }

                Section("Tools") {
                    NavigationLink(destination: QuickLaunchView()) {
                        Label("Quick Actions", systemImage: "bolt.fill")
                    }
                }
            }
            .navigationTitle("Content")
        }
    }
}

// MARK: - World List

struct WorldListView: View {
    @State private var worlds: [WorldItem] = []

    var body: some View {
        Group {
            if worlds.isEmpty {
                ContentUnavailableView("No Worlds",
                    systemImage: "globe.desk",
                    description: Text("Import a .mcworld file or create a new world"))
            } else {
                List(worlds, id: \.id) { world in
                    NavigationLink(destination: WorldEditorView(world: world)) {
                        VStack(alignment: .leading) {
                            Text(world.name).font(.headline)
                            Text(world.description).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle("Worlds")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Import", systemImage: "square.and.arrow.down") { }
            }
        }
    }
}

// MARK: - Resource Pack List

struct ResourcePackListView: View {
    @State private var packs: [ResourcePackItem] = []

    var body: some View {
        Group {
            if packs.isEmpty {
                ContentUnavailableView("No Packs",
                    systemImage: "paintbrush",
                    description: Text("Import .mcpack files to customize your game"))
            } else {
                List(packs, id: \.id) { pack in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(pack.name).font(.headline)
                            Text(pack.itemDescription ?? pack.formattedSize)
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(pack.type)
                            .font(.caption2)
                            .padding(4)
                            .background(Capsule().fill(.ultraThinMaterial))
                    }
                }
            }
        }
        .navigationTitle("Resource Packs")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Import", systemImage: "square.and.arrow.down") { }
            }
        }
    }
}

// MARK: - Server List

struct ServerListView: View {
    @State private var servers: [ServerItem] = []

    var body: some View {
        Group {
            if servers.isEmpty {
                ContentUnavailableView("No Servers",
                    systemImage: "server.rack",
                    description: Text("Add servers to connect to multiplayer"))
            } else {
                List(servers) { server in
                    VStack(alignment: .leading) {
                        Text(server.name).font(.headline)
                        Text(server.displayAddress).font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
        }
        .navigationTitle("Servers")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Add", systemImage: "plus") { }
            }
        }
    }
}

// MARK: - Screenshot List

struct ScreenshotListView: View {
    @State private var screenshots: [ScreenshotItem] = []

    var body: some View {
        Group {
            if screenshots.isEmpty {
                ContentUnavailableView("No Screenshots",
                    systemImage: "photo.on.rectangle",
                    description: Text("Take screenshots in-game to see them here"))
            } else {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 120))], spacing: 8) {
                        ForEach(screenshots) { screenshot in
                            AsyncImage(url: screenshot.file) { image in
                                image.resizable().aspectRatio(contentMode: .fill)
                            } placeholder: {
                                Rectangle().fill(.ultraThinMaterial)
                            }
                            .frame(height: 120)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                    .padding()
                }
            }
        }
        .navigationTitle("Screenshots")
    }
}

// MARK: - World Editor

struct WorldEditorView: View {
    let world: WorldItem
    @State private var worldName: String = ""
    @State private var gameMode: Int32 = 0
    @State private var difficulty: Int32 = 1
    @State private var cheats: Bool = false

    var body: some View {
        Form {
            Section("Properties") {
                TextField("World Name", text: $worldName)
                Picker("Game Mode", selection: $gameMode) {
                    Text("Survival").tag(Int32(0))
                    Text("Creative").tag(Int32(1))
                    Text("Adventure").tag(Int32(2))
                    Text("Spectator").tag(Int32(3))
                }
                Picker("Difficulty", selection: $difficulty) {
                    Text("Peaceful").tag(Int32(0))
                    Text("Easy").tag(Int32(1))
                    Text("Normal").tag(Int32(2))
                    Text("Hard").tag(Int32(3))
                }
                Toggle("Allow Cheats", isOn: $cheats)
            }
        }
        .navigationTitle(world.name)
        .onAppear {
            worldName = world.name
            if let file = world.file {
                if let props = try? WorldEditor.shared.readWorldProperties(from: file) {
                    gameMode = props.gameMode
                    difficulty = props.difficulty
                    cheats = props.cheats
                }
            }
        }
    }
}

// MARK: - Quick Launch

struct QuickLaunchView: View {
    var body: some View {
        List {
            Section {
                QuickActionRow(icon: "square.and.arrow.down", title: "Import Minecraft", color: .blue)
                QuickActionRow(icon: "square.and.arrow.down.on.square", title: "Import Content", color: .orange)
                QuickActionRow(icon: "globe.desk", title: "CurseForge Browser", color: .purple)
                QuickActionRow(icon: "folder.fill", title: "Content Management", color: .green)
                QuickActionRow(icon: "person.circle", title: "Account Management", color: .indigo)
            }
        }
        .navigationTitle("Quick Actions")
    }
}

struct QuickActionRow: View {
    let icon: String
    let title: String
    let color: Color

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(color)
                .font(.title3)
                .frame(width: 30)
            Text(title)
                .font(.body)
        }
    }
}
