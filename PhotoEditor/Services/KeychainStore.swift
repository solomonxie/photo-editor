import Foundation
import Security

nonisolated enum KeychainStore {
    static let service = AppNamespace.value
    /// Pre-multi-key single key, migrated by AIKeyStore.
    static let legacyAIKey = "ai.api.key"

    static func save(_ value: String, forKey key: String) {
        delete(forKey: key)
        let attributes: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
            kSecValueData as String: Data(value.utf8),
        ]
        SecItemAdd(attributes as CFDictionary, nil)
    }

    static func load(forKey key: String) -> String? {
        for query in [scoped(key), unscoped(key)] {
            var q = query
            q[kSecReturnData as String] = true
            q[kSecMatchLimit as String] = kSecMatchLimitOne
            var result: AnyObject?
            if SecItemCopyMatching(q as CFDictionary, &result) == errSecSuccess, let data = result as? Data {
                return String(data: data, encoding: .utf8)
            }
        }
        return nil
    }

    static func delete(forKey key: String) {
        SecItemDelete(scoped(key) as CFDictionary)
        SecItemDelete(unscoped(key) as CFDictionary)
    }

    private static func scoped(_ key: String) -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: service,
         kSecAttrAccount as String: key]
    }

    /// Items written by the scaffold had no service attribute.
    private static func unscoped(_ key: String) -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrAccount as String: key]
    }
}
