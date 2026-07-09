import Foundation
import Security

struct EncryptionUtils {
    struct KeyPair {
        let publicKey: SecKey
        let privateKey: SecKey
    }

    static func createKeyPair() throws -> KeyPair {
        let attributes: [String: Any] = [
            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
            kSecAttrKeySizeInBits as String: 256,
            kSecPrivateKeyAttrs as String: [
                kSecAttrIsPermanent as String: false
            ] as [String: Any],
            kSecPublicKeyAttrs as String: [
                kSecAttrIsPermanent as String: false
            ] as [String: Any]
        ]

        var error: Unmanaged<CFError>?
        guard let privateKey = SecKeyCreateRandomKey(attributes as CFDictionary, &error) else {
            throw error?.takeRetainedValue() ?? CryptoError.keyGenerationFailed
        }
        guard let publicKey = SecKeyCopyPublicKey(privateKey) else {
            throw CryptoError.keyGenerationFailed
        }
        return KeyPair(publicKey: publicKey, privateKey: privateKey)
    }
}

enum CryptoError: LocalizedError {
    case keyGenerationFailed

    var errorDescription: String? {
        switch self {
        case .keyGenerationFailed: return "Failed to generate cryptographic key"
        }
    }
}
