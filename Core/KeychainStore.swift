import Foundation
import Security

public protocol SecretStore {
    func get(_ key: String) -> String?
    func set(_ value: String, for key: String) throws
    func delete(_ key: String) throws
}

public enum SecretStoreError: Error {
    case unexpectedStatus(OSStatus)
}

public final class KeychainSecretStore: SecretStore {
    private let service: String
    public init(service: String = "com.mo.DSBalanceMonitor") {
        self.service = service
    }

    public func get(_ key: String) -> String? {
        var query = baseQuery(key)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    public func set(_ value: String, for key: String) throws {
        let data = Data(value.utf8)
        let status = SecItemUpdate(baseQuery(key) as CFDictionary,
                                   [kSecValueData as String: data] as CFDictionary)
        if status == errSecItemNotFound {
            var query = baseQuery(key)
            query[kSecValueData as String] = data
            query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
            let addStatus = SecItemAdd(query as CFDictionary, nil)
            guard addStatus == errSecSuccess else { throw SecretStoreError.unexpectedStatus(addStatus) }
        } else if status != errSecSuccess {
            throw SecretStoreError.unexpectedStatus(status)
        }
    }

    public func delete(_ key: String) throws {
        let status = SecItemDelete(baseQuery(key) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw SecretStoreError.unexpectedStatus(status)
        }
    }

    private func baseQuery(_ key: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
        ]
    }
}

public final class InMemorySecretStore: SecretStore {
    private var storage: [String: String] = [:]
    private let lock = NSLock()
    public init() {}

    public func get(_ key: String) -> String? {
        lock.lock(); defer { lock.unlock() }
        return storage[key]
    }
    public func set(_ value: String, for key: String) throws {
        lock.lock(); defer { lock.unlock() }
        storage[key] = value
    }
    public func delete(_ key: String) throws {
        lock.lock(); defer { lock.unlock() }
        storage.removeValue(forKey: key)
    }
}

/// Local-device secret storage. Keys are hand-entered in the Settings UI and
/// persisted in UserDefaults so they survive ad-hoc re-signing/rebuilds.
/// Plaintext on disk — not suitable for shared machines (Keychain support can
/// be re-enabled once the app is signed with a stable identity).
public final class UserDefaultsSecretStore: SecretStore {
    private let defaults: UserDefaults
    private let keyPrefix = "dsbalance.secret."

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func get(_ key: String) -> String? {
        defaults.string(forKey: keyPrefix + key)
    }

    public func set(_ value: String, for key: String) throws {
        defaults.set(value, forKey: keyPrefix + key)
    }

    public func delete(_ key: String) throws {
        defaults.removeObject(forKey: keyPrefix + key)
    }
}
