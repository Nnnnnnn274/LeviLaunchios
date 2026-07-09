import SwiftUI

struct AboutView: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    VStack(spacing: 8) {
                        Image(systemName: "leaf.fill")
                            .font(.system(size: 80))
                            .foregroundStyle(.green)

                        Text("LeviLauncher")
                            .font(.largeTitle.bold())

                        Text("iOS Port")
                            .font(.title3)
                            .foregroundStyle(.secondary)

                        Text("Version \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.0")")
                            .font(.subheadline)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.top, 40)

                    Text("A lightweight, open-source launcher for Minecraft: Bedrock Edition.")
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)

                    VStack(alignment: .leading, spacing: 12) {
                        LinkRow(icon: "link", title: "GitHub", url: "https://github.com/LiteLDev/LeviLauncher")
                        LinkRow(icon: "link", title: "Patreon", url: "https://patreon.com/LiteLDev")
                        LinkRow(icon: "play.rectangle", title: "YouTube", url: "https://youtube.com/@LiteLDev")
                    }
                    .padding()

                    VStack(spacing: 4) {
                        Text("Created by LeviMC Organization")
                            .font(.caption)
                        Text("Licensed under Apache 2.0")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.bottom)
                }
            }
            .navigationTitle("About")
        }
    }
}

struct LinkRow: View {
    let icon: String
    let title: String
    let url: String

    var body: some View {
        Button {
            if let url = URL(string: url) {
                UIApplication.shared.open(url)
            }
        } label: {
            HStack {
                Image(systemName: icon)
                    .frame(width: 24)
                Text(title)
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.caption)
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 8).fill(.ultraThinMaterial))
        }
        .buttonStyle(.plain)
    }
}
