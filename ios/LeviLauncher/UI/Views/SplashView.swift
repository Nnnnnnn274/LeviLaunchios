import SwiftUI

struct SplashView: View {
    @State private var opacity: Double = 0
    @State private var scale: CGFloat = 0.8
    @State private var progress: Double = 0

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "leaf.fill")
                .font(.system(size: 100))
                .foregroundStyle(.green)
                .scaleEffect(scale)
                .opacity(opacity)

            Text("LeviLauncher")
                .font(.largeTitle.bold())
                .opacity(opacity)

            Text("Loading...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .opacity(opacity)

            ProgressView(value: progress, total: 1.0)
                .progressViewStyle(.linear)
                .frame(width: 200)
                .opacity(opacity)

            Spacer()
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.8)) {
                opacity = 1
                scale = 1
            }
            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: false)) {
                progress = 1
            }
        }
    }
}
