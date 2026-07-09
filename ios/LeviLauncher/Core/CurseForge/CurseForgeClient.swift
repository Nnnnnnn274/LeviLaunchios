import Foundation

actor CurseForgeClient {
    static let shared = CurseForgeClient()

    private let session: URLSession
    private let baseURL = "https://api.curseforge.com"
    private let apiKey: String

    struct SearchResult: Codable {
        let id: Int
        let name: String
        let summary: String?
        let slug: String?
        let logo: CurseForgeImage?
        let links: CurseForgeLinks?
        let latestFiles: [CurseForgeFile]?
        let dateModified: String?
        let dateCreated: String?
    }

    struct CurseForgeImage: Codable {
        let id: Int
        let url: String?
        let thumbnailUrl: String?
    }

    struct CurseForgeLinks: Codable {
        let websiteUrl: String?
        let wikiUrl: String?
        let issuesUrl: String?
        let sourceUrl: String?
    }

    struct CurseForgeFile: Codable, Identifiable {
        let id: Int
        let displayName: String?
        let fileName: String?
        let fileDate: String?
        let fileLength: Int?
        let downloadUrl: String?
        let gameVersion: [String]?
        let releaseType: Int? // 1 = Release, 2 = Beta, 3 = Alpha
    }

    struct CurseForgeCategory: Codable, Identifiable {
        let id: Int
        let name: String
        let slug: String
        let gameId: Int
        let isClass: Bool?
        let classId: Int?
        let parentCategoryId: Int?
    }

    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        self.session = URLSession(configuration: config)
        self.apiKey = Self.loadAPIKey()
    }

    private static func loadAPIKey() -> String {
        if let path = Bundle.main.path(forResource: "CurseForge", ofType: "plist"),
           let dict = NSDictionary(contentsOfFile: path),
           let key = dict["APIKey"] as? String {
            return key
        }
        return ""
    }

    func searchMods(query: String, categoryId: Int? = nil, sort: Int = 0,
                    page: Int = 0, pageSize: Int = 20) async throws -> [SearchResult] {
        var components = URLComponents(string: "\(baseURL)/v1/mods/search")!
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "gameId", value: "432"),
            URLQueryItem(name: "searchFilter", value: query),
            URLQueryItem(name: "pageSize", value: "\(pageSize)"),
            URLQueryItem(name: "index", value: "\(page * pageSize)"),
        ]
        if let categoryId = categoryId {
            queryItems.append(URLQueryItem(name: "categoryId", value: "\(categoryId)"))
        }
        if sort > 0 {
            queryItems.append(URLQueryItem(name: "sortOrder", value: "\(sort)"))
        }
        components.queryItems = queryItems

        var request = URLRequest(url: components.url!)
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")

        let data = try await session.data(for: request)
        let response = try JSONDecoder().decode(CurseForgeResponse<[SearchResult]>.self, from: data)
        return response.data ?? []
    }

    func getMod(modId: Int) async throws -> SearchResult? {
        var request = URLRequest(url: URL(string: "\(baseURL)/v1/mods/\(modId)")!)
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")

        let data = try await session.data(for: request)
        let response = try JSONDecoder().decode(CurseForgeResponse<SearchResult>.self, from: data)
        return response.data
    }

    func getFiles(modId: Int, page: Int = 0, pageSize: Int = 50) async throws -> [CurseForgeFile] {
        var components = URLComponents(string: "\(baseURL)/v1/mods/\(modId)/files")!
        components.queryItems = [
            URLQueryItem(name: "pageSize", value: "\(pageSize)"),
            URLQueryItem(name: "index", value: "\(page * pageSize)")
        ]

        var request = URLRequest(url: components.url!)
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")

        let data = try await session.data(for: request)
        let response = try JSONDecoder().decode(CurseForgeResponse<[CurseForgeFile]>.self, from: data)
        return response.data ?? []
    }

    func getCategories() async throws -> [CurseForgeCategory] {
        var components = URLComponents(string: "\(baseURL)/v1/categories")!
        components.queryItems = [URLQueryItem(name: "gameId", value: "432")]

        var request = URLRequest(url: components.url!)
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")

        let data = try await session.data(for: request)
        let response = try JSONDecoder().decode(CurseForgeResponse<[CurseForgeCategory]>.self, from: data)
        return response.data ?? []
    }

    func downloadFile(_ file: CurseForgeFile, to url: URL) async throws {
        guard let downloadUrl = file.downloadUrl else { throw CurseForgeError.noDownloadURL }

        var request = URLRequest(url: URL(string: downloadUrl)!)
        let (data, _) = try await session.data(for: request)
        try data.write(to: url, options: .atomic)
    }
}

struct CurseForgeResponse<T: Codable>: Codable {
    let data: T?
}

enum CurseForgeError: LocalizedError {
    case noDownloadURL
    case apiError(String)

    var errorDescription: String? {
        switch self {
        case .noDownloadURL: return "No download URL available"
        case .apiError(let msg): return "CurseForge API error: \(msg)"
        }
    }
}
