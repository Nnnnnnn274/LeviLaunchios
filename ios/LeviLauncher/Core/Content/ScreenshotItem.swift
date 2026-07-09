import Foundation

struct ScreenshotItem: Identifiable {
    var id = UUID()
    var file: URL
    var dimensions: CGSize?
    var captureTime: Date?

    var formattedDimensions: String {
        guard let dim = dimensions else { return "Unknown size" }
        return "\(Int(dim.width))x\(Int(dim.height))"
    }
}
