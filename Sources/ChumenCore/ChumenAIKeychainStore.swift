import Foundation
import Security

public struct ChumenAIKeychainStore: Sendable {
    private let service: String
    private let account: String

    public init(
        service: String = "io.github.chumen.native-macos.ai",
        account: String = "llm-api-key"
    ) {
        self.service = service
        self.account = account
    }

    public func saveAPIKey(_ key: String) throws {
        let data = Data(key.utf8)
        let query = baseQuery()
        SecItemDelete(query as CFDictionary)

        var attributes = query
        attributes[kSecValueData as String] = data
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly

        let status = SecItemAdd(attributes as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw ChumenError.commandFailed("Could not save AI API key to Keychain: \(status)")
        }
    }

    public func loadAPIKey() throws -> String? {
        var query = baseQuery()
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound {
            return nil
        }
        guard status == errSecSuccess else {
            throw ChumenError.commandFailed("Could not read AI API key from Keychain: \(status)")
        }
        guard let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    public func deleteAPIKey() throws {
        let status = SecItemDelete(baseQuery() as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw ChumenError.commandFailed("Could not delete AI API key from Keychain: \(status)")
        }
    }

    public func hasAPIKey() -> Bool {
        let key = try? loadAPIKey()
        return key?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
    }

    private func baseQuery() -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }
}
