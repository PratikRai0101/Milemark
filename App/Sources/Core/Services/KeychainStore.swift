import Foundation
import Security

/// A place to keep a secret on the device.
///
/// The access token for a connected service is a password in everything but
/// name, so it goes in the keychain rather than in the app's own storage and
/// rather than in the runs file. The keychain is protected by the device's
/// passcode and does not travel with a backup of the app's documents.
public struct KeychainStore {
    /// The service the items belong to.
    private let service: String

    public init(service: String = "app.milemark.credentials") {
        self.service = service
    }

    /// Stores a value, replacing anything already there under the same key.
    public func set(_ value: String, for key: String) -> Bool {
        guard let data = value.data(using: .utf8) else { return false }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
        ]
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            // The token is only needed while the app is in front of the
            // reader, and it is never needed on a locked device.
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
        ]

        let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if updateStatus == errSecSuccess { return true }
        if updateStatus == errSecItemNotFound {
            var insert = query
            insert.merge(attributes) { current, _ in current }
            return SecItemAdd(insert as CFDictionary, nil) == errSecSuccess
        }
        return false
    }

    /// Reads a value, if there is one.
    public func get(_ key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess,
              let data = result as? Data,
              let value = String(data: data, encoding: .utf8)
        else { return nil }
        return value
    }

    /// Removes a value.
    public func remove(_ key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
        ]
        SecItemDelete(query as CFDictionary)
    }
}
