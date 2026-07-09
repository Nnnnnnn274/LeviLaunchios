import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var settings: FeatureSettings
    @EnvironmentObject private var versionManager: VersionManager
    @State private var selectedTab: Tab = .launch
    @State private var showAccountPicker = false

    enum Tab: String, CaseIterable {
        case launch = "Launch"
        case instances = "Instances"
        case content = "Content"
        case settings = "Settings"
        case about = "About"

        var icon: String {
            switch self {
            case .launch: return "play.circle.fill"
            case .instances: return "square.grid.2x2.fill"
            case .content: return "folder.fill"
            case .settings: return "gearshape.fill"
            case .about: return "info.circle.fill"
            }
        }
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            MainLaunchView()
                .tabItem {
                    Label(Tab.launch.rawValue, systemImage: Tab.launch.icon)
                }
                .tag(Tab.launch)

            InstancesView()
                .tabItem {
                    Label(Tab.instances.rawValue, systemImage: Tab.instances.icon)
                }
                .tag(Tab.instances)

            ContentManagementView()
                .tabItem {
                    Label(Tab.content.rawValue, systemImage: Tab.content.icon)
                }
                .tag(Tab.content)

            SettingsView()
                .tabItem {
                    Label(Tab.settings.rawValue, systemImage: Tab.settings.icon)
                }
                .tag(Tab.settings)

            AboutView()
                .tabItem {
                    Label(Tab.about.rawValue, systemImage: Tab.about.icon)
                }
                .tag(Tab.about)
        }
        .overlay(alignment: .topTrailing) {
            Button {
                showAccountPicker = true
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "person.circle")
                    if let account = MsftAccountStore.activeAccount {
                        Text(account.xboxGamertag ?? "Account")
                            .font(.caption)
                    }
                }
                .padding(8)
                .background(Capsule().fill(.ultraThinMaterial))
                .padding(.trailing)
            }
        }
        .sheet(isPresented: $showAccountPicker) {
            AccountsView()
        }
    }
}
