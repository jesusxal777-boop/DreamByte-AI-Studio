import Foundation
import Security

/// Stores user-provided provider secrets in this app's Keychain namespace.
/// Never log, export, sync, or include these values in a project file.
struct KeychainSecretStore {
    enum StoreError: LocalizedError {
        case unexpectedStatus(OSStatus)

        var errorDescription: String? {
            switch self {
            case .unexpectedStatus(let status):
                return "Keychain operation failed (status \(status))."
            }
        }
    }

    private let service = "studios.dreambyte.ai-studio.provider-keys"

    func containsKey(for provider: AIProvider) -> Bool {
        (try? readKey(for: provider)) != nil
    }

    func save(_ key: String, for provider: AIProvider) throws {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            try deleteKey(for: provider)
            return
        }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: provider.keychainAccount
        ]
        let attributes: [String: Any] = [kSecValueData as String: Data(trimmed.utf8)]
        let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)

        if updateStatus == errSecItemNotFound {
            var insert = query
            insert[kSecValueData as String] = Data(trimmed.utf8)
            insert[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
            let status = SecItemAdd(insert as CFDictionary, nil)
            guard status == errSecSuccess else { throw StoreError.unexpectedStatus(status) }
        } else if updateStatus != errSecSuccess {
            throw StoreError.unexpectedStatus(updateStatus)
        }
    }

    func readKey(for provider: AIProvider) throws -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: provider.keychainAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = result as? Data,
              let value = String(data: data, encoding: .utf8) else {
            throw StoreError.unexpectedStatus(status)
        }
        return value
    }

    func deleteKey(for provider: AIProvider) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: provider.keychainAccount
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw StoreError.unexpectedStatus(status)
        }
    }
}
