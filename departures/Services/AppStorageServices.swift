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

        #if os(iOS) || os(watchOS) || os(tvOS)
        query[kSecAttrAccessible] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        #endif

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

/// Persists the user's nearby-station preferences on this iPhone.
struct PreferencesStore: Sendable {
    private let key = "nearbyStationsPreferences"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func read() -> NearbyStationsPreferences {
        guard let data = defaults.data(forKey: key),
              let preferences = try? JSONDecoder().decode(NearbyStationsPreferences.self, from: data) else {
            return .default
        }
        return preferences
    }

    func save(_ preferences: NearbyStationsPreferences) {
        guard let data = try? JSONEncoder().encode(preferences) else { return }
        defaults.set(data, forKey: key)
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
