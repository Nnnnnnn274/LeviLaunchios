import SwiftUI

struct CrashView: View {
    let crashLog: CrashReporter.CrashLog
    @State private var showShareSheet = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 50))
                        .foregroundStyle(.red)

                    Text("Minecraft Crashed")
                        .font(.title.bold())

                    Text(crashLog.type.rawValue)
                        .font(.headline)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(.red.opacity(0.15)))
                }
                .frame(maxWidth: .infinity)
                .padding()

                GroupBox("Summary") {
                    Text(crashLog.summary)
                        .font(.body)
                }

                GroupBox("Details") {
                    Text(crashLog.details)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospaced()
                }

                HStack(spacing: 16) {
                    Button(action: { showShareSheet = true }) {
                        Label("Share Log", systemImage: "square.and.arrow.up")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)

                    if let url = crashLog.logFileURL {
                        ShareLink(item: url) {
                            Label("Export", systemImage: "doc.badge.arrow.up")
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Crash Report")
        .navigationBarTitleDisplayMode(.inline)
    }
}
