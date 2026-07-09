import Foundation

struct ServerItem: Identifiable, Codable {
    var id = UUID()
    var name: String
    var address: String
    var port: UInt16 = 19132
    var isManual: Bool = true

    var displayAddress: String {
        "\(address):\(port)"
    }
}
