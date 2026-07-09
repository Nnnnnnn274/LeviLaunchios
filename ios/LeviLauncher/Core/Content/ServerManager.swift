import Foundation

final class ServerManager {
    static let shared = ServerManager()

    func listServers(from fileURL: URL) -> [ServerItem] {
        guard let data = try? String(contentsOf: fileURL, encoding: .utf8) else { return [] }
        var servers: [ServerItem] = []
        for line in data.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty, !trimmed.hasPrefix("#") else { continue }
            let parts = trimmed.components(separatedBy: ":")
            if parts.count == 2, let port = UInt16(parts[1].trimmingCharacters(in: .whitespaces)) {
                servers.append(ServerItem(name: parts[0].trimmingCharacters(in: .whitespaces),
                                          address: parts[0].trimmingCharacters(in: .whitespaces),
                                          port: port))
            } else {
                servers.append(ServerItem(name: trimmed, address: trimmed))
            }
        }
        return servers
    }

    func saveServers(_ servers: [ServerItem], to fileURL: URL) throws {
        var lines: [String] = [
            "# Saved servers file",
            "# Format: name:port (port defaults to 19132 if omitted)",
            ""
        ]
        for server in servers {
            lines.append("\(server.name)\(server.port != 19132 ? ":\(server.port)" : "")")
        }
        try lines.joined(separator: "\n").write(to: fileURL, atomically: true, encoding: .utf8)
    }

    func addServer(_ server: ServerItem, to fileURL: URL) throws {
        var servers = listServers(from: fileURL)
        servers.append(server)
        try saveServers(servers, to: fileURL)
    }

    func removeServer(_ server: ServerItem, from fileURL: URL) throws {
        var servers = listServers(from: fileURL)
        servers.removeAll { $0.id == server.id }
        try saveServers(servers, to: fileURL)
    }
}
