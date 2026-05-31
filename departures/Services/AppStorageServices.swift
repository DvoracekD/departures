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

struct ConfigurationStore: Sendable {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func loadConnection() -> ConnectionConfiguration? {
        load(ConnectionConfiguration.self, forKey: StorageKey.connection)
    }

    func saveConnection(_ connection: ConnectionConfiguration) throws {
        try save(connection, forKey: StorageKey.connection)
    }

    func clearConnection() {
        defaults.removeObject(forKey: StorageKey.connection)
    }

    func loadSnapshot() -> DepartureSnapshot? {
        load(DepartureSnapshot.self, forKey: StorageKey.snapshot)
    }

    func saveSnapshot(_ snapshot: DepartureSnapshot) throws {
        try save(snapshot, forKey: StorageKey.snapshot)
    }

    func clearSnapshot() {
        defaults.removeObject(forKey: StorageKey.snapshot)
    }

    private func load<T: Decodable>(_ type: T.Type, forKey key: String) -> T? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    private func save<T: Encodable>(_ value: T, forKey key: String) throws {
        let data = try JSONEncoder().encode(value)
        defaults.set(data, forKey: key)
    }
}

private enum StorageKey {
    static let connection = "connection.configuration"
    static let snapshot = "departure.snapshot"
}
