import Foundation
import ImageIO
import UniformTypeIdentifiers

final class ScreenshotManager {
    static let shared = ScreenshotManager()
    private let fileManager = FileManager.default

    func listScreenshots(in screenshotsDir: URL) -> [ScreenshotItem] {
        guard let contents = try? fileManager.contentsOfDirectory(at: screenshotsDir,
                                                                    includingPropertiesForKeys: [.contentModificationDateKey]) else {
            return []
        }
        return contents.compactMap { url -> ScreenshotItem? in
            guard let type = try? url.resourceValues(forKeys: [.contentTypeKey]).contentType,
                  type.conforms(to: .image) else { return nil }
            var item = ScreenshotItem(file: url)
            if let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil),
               let props = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [CFString: Any] {
                let w = props[kCGImagePropertyPixelWidth] as? CGFloat
                let h = props[kCGImagePropertyPixelHeight] as? CGFloat
                if let w = w, let h = h {
                    item.dimensions = CGSize(width: w, height: h)
                }
            }
            item.captureTime = (try? url.resourceValues(forKeys: [.contentModificationDateKey])).flatMap { $0.contentModificationDate }
            return item
        }.sorted { ($0.captureTime ?? Date()) > ($1.captureTime ?? Date()) }
    }

    func deleteScreenshot(_ item: ScreenshotItem) throws {
        try fileManager.removeItem(at: item.file)
    }
}
