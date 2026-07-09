import Foundation

struct TitleDefaultStore: Codable {
    let defaultUser: String

    static var filename: String { "TitleDefault.json" }

    func save(to dir: URL) {
        let url = dir.appendingPathComponent(Self.filename)
        try? JSONEncoder().encode(self).write(to: url, options: .atomic)
    }
}
