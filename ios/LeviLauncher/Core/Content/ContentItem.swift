import Foundation

class ContentItem: Identifiable {
    let id = UUID()
    var name: String
    var file: URL?
    var size: UInt64
    var lastModified: Date
    var isEnabled: Bool

    init(name: String, file: URL?) {
        self.name = name
        self.file = file
        self.size = Self.calculateSize(file)
        self.lastModified = (try? file?.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? Date()
        self.isEnabled = false
    }

    var formattedSize: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(size))
    }

    var formattedLastModified: String {
        let df = DateFormatter()
        df.dateFormat = "MMM dd, yyyy HH:mm"
        return df.string(from: lastModified)
    }

    var type: String { "" }
    var description: String { "" }
    var isValid: Bool { true }

    private static func calculateSize(_ url: URL?) -> UInt64 {
        guard let url = url else { return 0 }
        guard let resourceValues = try? url.resourceValues(forKeys: [.fileSizeKey, .isDirectoryKey]) else {
            return 0
        }
        if resourceValues.isDirectory == true {
            guard let enumerator = FileManager.default.enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey]) else {
                return 0
            }
            var total: UInt64 = 0
            for case let fileURL as URL in enumerator {
                let fileSize = (try? fileURL.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0
                total += UInt64(fileSize)
            }
            return total
        }
        return UInt64(resourceValues.fileSize ?? 0)
    }
}
