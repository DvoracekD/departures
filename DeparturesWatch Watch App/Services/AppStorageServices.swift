import Foundation
import Security

struct KeychainTokenStore: Sendable {
    private let service = "dominik.dvoracek.departures.golemio"
    private let account = "x-access-token"

    func readToken() -> String? {
        var query = baseQuery()
        query[kSecReturnData] = true
        query[kSecMatchLimit] = kSecMatchLimitOne

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else {
            return nil
        }

        return String(data: data, encoding: .utf8)
    }

    func saveToken(_ token: String) throws {
        try deleteToken()

        guard let data = token.data(using: .utf8) else {
            throw KeychainTokenStoreError.invalidToken
        }

        var query = baseQuery()
        query[kSecValueData] = data
        query[kSecAttrAccessible] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainTokenStoreError.unhandledStatus(status)
        }
    }

    func deleteToken() throws {
        let status = SecItemDelete(baseQuery() as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainTokenStoreError.unhandledStatus(status)
        }
    }

    private func baseQuery() -> [CFString: Any] {
        [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account
        ]
    }
}

enum KeychainTokenStoreError: LocalizedError, Sendable {
    case invalidToken
    case unhandledStatus(OSStatus)

    var errorDescription: String? {
        switch self {
        case .invalidToken:
            return "The token could not be stored."
        case let .unhandledStatus(status):
            return "Keychain returned status \(status)."
        }
    }
}
