import Foundation

// MARK: - OAuth2.0 Token

struct OAuth20Token: Codable {
    let tokenType: String
    let expiresIn: Int
    let scope: String
    let accessToken: String
    let refreshToken: String?
    let userId: String?

    enum CodingKeys: String, CodingKey {
        case tokenType = "token_type"
        case expiresIn = "expires_in"
        case scope
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case userId = "user_id"
    }
}

// MARK: - Xbox Token

struct XboxToken: Codable {
    let issueInstant: String
    let notAfter: String
    let token: String
    let displayClaims: [String: Any]

    enum CodingKeys: String, CodingKey {
        case issueInstant = "IssueInstant"
        case notAfter = "NotAfter"
        case token = "Token"
        case displayClaims = "DisplayClaims"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        issueInstant = try container.decode(String.self, forKey: .issueInstant)
        notAfter = try container.decode(String.self, forKey: .notAfter)
        token = try container.decode(String.self, forKey: .token)
        if let claims = try? container.decode([String: AnyCodable].self, forKey: .displayClaims) {
            displayClaims = claims.mapValues { $0.value }
        } else {
            displayClaims = [:]
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(issueInstant, forKey: .issueInstant)
        try container.encode(notAfter, forKey: .notAfter)
        try container.encode(token, forKey: .token)
        try container.encode(displayClaims as? [String: String] ?? [:], forKey: .displayClaims)
    }

    func toIdentityToken() -> String {
        if let xuiArr = displayClaims["xui"] as? [[String: Any]],
           let first = xuiArr.first,
           let uhs = first["uhs"] as? String {
            return "XBL3.0 x=\(uhs);\(token)"
        }
        return "XBL3.0 x=;\(token)"
    }
}

// MARK: - Xbox Device

struct XboxDeviceKey: Codable {
    let id: String
    let key: Data

    init() {
        self.id = UUID().uuidString
        var bytes = Data(count: 32)
        _ = bytes.withUnsafeMutableBytes { SecRandomCopyBytes(kSecRandomDefault, 32, $0.baseAddress!) }
        self.key = bytes
    }

    init(id: String, key: Data) {
        self.id = id
        self.key = key
    }
}

struct XboxDevice: Codable {
    let key: XboxDeviceKey
    let token: XboxDeviceToken
}

struct XboxDeviceToken: Codable {
    let token: String
    let issueInstant: String
    let notAfter: String
}

// MARK: - Auth Requests

struct XboxDeviceAuthRequest: Codable {
    let relyingParty: String
    let tokenType: String
    let deviceType: String
    let deviceVersion: String
    let deviceKey: XboxDeviceKey

    func request(session: URLSession) async throws -> XboxDeviceToken {
        let url = URL(string: "https://device.auth.xboxlive.com/device/authenticate")!
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONEncoder().encode(self)

        let data = try await session.data(for: req)
        return try JSONDecoder().decode(XboxDeviceToken.self, from: data)
    }
}

struct XboxUserAuthRequest: Codable {
    let relyingParty: String
    let tokenType: String
    let authMethod: String
    let siteName: String
    let rpsTicket: String

    func request(session: URLSession) async throws -> XboxToken {
        let url = URL(string: "https://user.auth.xboxlive.com/user/authenticate")!
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONEncoder().encode(self)

        let data = try await session.data(for: req)
        return try JSONDecoder().decode(XboxToken.self, from: data)
    }
}

struct XboxXSTSAuthRequest: Codable {
    let relyingParty: String
    let tokenType: String
    let sandbox: String
    let userTokens: [XboxToken]

    func request(session: URLSession) async throws -> XboxToken {
        let url = URL(string: "https://xsts.auth.xboxlive.com/xsts/authorize")!
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "RelyingParty": relyingParty,
            "TokenType": tokenType,
            "Sandbox": sandbox,
            "Properties": [
                "UserTokens": userTokens.map { $0.token },
                "SandboxId": sandbox
            ]
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let data = try await session.data(for: req)
        return try JSONDecoder().decode(XboxToken.self, from: data)
    }
}

struct XboxTitleAuthRequest: Codable {
    let relyingParty: String
    let tokenType: String
    let authMethod: String
    let siteName: String
    let rpsTicket: String
    let deviceToken: XboxDeviceToken
    let deviceKey: XboxDeviceKey

    func request(session: URLSession) async throws -> XboxTitleToken {
        let url = URL(string: "https://user.auth.xboxlive.com/user/authenticate")!
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONEncoder().encode(self)

        let data = try await session.data(for: req)
        return try JSONDecoder().decode(XboxTitleToken.self, from: data)
    }
}

struct XboxTitleToken: Codable {
    let token: String
    let issueInstant: String
    let notAfter: String
}

// MARK: - Helper

struct AnyCodable: Codable {
    let value: Any

    init(_ value: Any) { self.value = value }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let intVal = try? container.decode(Int.self) { value = intVal }
        else if let doubleVal = try? container.decode(Double.self) { value = doubleVal }
        else if let boolVal = try? container.decode(Bool.self) { value = boolVal }
        else if let stringVal = try? container.decode(String.self) { value = stringVal }
        else if let arrayVal = try? container.decode([AnyCodable].self) { value = arrayVal.map { $0.value } }
        else if let dictVal = try? container.decode([String: AnyCodable].self) { value = dictVal.mapValues { $0.value } }
        else { value = "" }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        if let intVal = value as? Int { try container.encode(intVal) }
        else if let doubleVal = value as? Double { try container.encode(doubleVal) }
        else if let boolVal = value as? Bool { try container.encode(boolVal) }
        else if let stringVal = value as? String { try container.encode(stringVal) }
        else if let arrayVal = value as? [Any] { try container.encode(arrayVal.map { AnyCodable($0) }) }
        else if let dictVal = value as? [String: Any] { try container.encode(dictVal.mapValues { AnyCodable($0) }) }
    }
}
