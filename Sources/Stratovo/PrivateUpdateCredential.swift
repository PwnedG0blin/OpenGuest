import Foundation
import Security

/// Repository-scoped read credential; never written to preferences or logs.
enum PrivateUpdateCredential {
    private static var query: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: "org.pwnedg0blin.openguest.private-updates",
         kSecAttrAccount as String: "PwnedG0blin/Stratovo-Private"]
    }
    static func read() throws -> String? {
        var query = Self.query
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = result as? Data,
              let token = String(data: data, encoding: .utf8) else { throw failure() }
        return token
    }
    static func save(_ token: String) throws {
        let data = Data(token.utf8)
        let status = SecItemUpdate(query as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        if status == errSecItemNotFound {
            var item = query; item[kSecValueData as String] = data
            item[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
            guard SecItemAdd(item as CFDictionary, nil) == errSecSuccess else { throw failure() }
        } else if status != errSecSuccess { throw failure() }
    }
    static func remove() throws {
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw failure() }
    }
    private static func failure() -> NSError {
        PrivateUpdateAPI.failure("Der GitHub-Zugang konnte im macOS-Schlüsselbund nicht gelesen oder gespeichert werden. Bitte den Schlüsselbund entsperren und erneut verbinden.")
    }
}
