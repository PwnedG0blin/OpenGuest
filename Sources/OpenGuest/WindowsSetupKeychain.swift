import Foundation
import Security

/// Only credentials explicitly saved by the user, scoped to this data folder.
enum WindowsSetupKeychain {
    struct Credential: Codable {
        let name: String
        let password: String
    }
    private static func query(storageID: String) -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: "org.pwnedg0blin.openguest.windows.setup",
         kSecAttrAccount as String: storageID]
    }
    static func save(_ credential: Credential, storageID: String) throws {
        let base = query(storageID: storageID)
        let data = try JSONEncoder().encode(credential)
        let values: [String: Any] = [kSecValueData as String: data,
            kSecAttrLabel as String: "OpenGuest · Windows-Einrichtung"]
        var result = SecItemUpdate(base as CFDictionary, values as CFDictionary)
        if result == errSecItemNotFound {
            result = SecItemAdd(base.merging(values) { _, new in new } as CFDictionary, nil)
        }
        guard result == errSecSuccess else { throw failure(result) }
    }
    static func load(storageID: String) throws -> Credential? {
        var request = query(storageID: storageID)
        request[kSecReturnData as String] = true
        request[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(request as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess else { throw failure(status) }
        guard let data = result as? Data else { throw failure(errSecDecode) }
        return try JSONDecoder().decode(Credential.self, from: data)
    }
    private static func failure(_ status: OSStatus) -> NSError {
        NSError(domain: NSOSStatusErrorDomain, code: Int(status), userInfo: [NSLocalizedDescriptionKey:
            "Schlüsselbund: \(SecCopyErrorMessageString(status, nil) as String? ?? "Zugriff fehlgeschlagen")"])
    }
}
