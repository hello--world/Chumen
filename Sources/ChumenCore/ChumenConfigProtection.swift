import CryptoKit
import Foundation
import Security

/// Centralizes config-at-rest protection.
///
/// Intent: Chumen stores proxy subscriptions, controller secrets, and generated runtime YAML under
/// Application Support. Those files are useful to Chumen but also easy for unrelated local software
/// to scan. Persistent settings/profile files therefore use a device-local Keychain master key so
/// they remain decryptable across launches. Truly per-launch keys are reserved for generated runtime
/// artifacts, because using them for persistent files would make the next app launch unable to read
/// its own configuration.
public struct ChumenConfigProtectionKeyStore: Sendable {
    private let service: String
    private let account: String

    public init(
        service: String = "io.github.chumen.native-macos.config-protection",
        account: String = "storage-master-key"
    ) {
        self.service = service
        self.account = account
    }

    public func loadOrCreateKey() throws -> Data {
        if let existing = try loadKey(), existing.count == 32 {
            return existing
        }
        let key = try Self.randomBytes(count: 32)
        try saveKey(key)
        return key
    }

    private func loadKey() throws -> Data? {
        var query = baseQuery()
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound {
            return nil
        }
        guard status == errSecSuccess else {
            throw ChumenError.commandFailed("Could not read config protection key from Keychain: \(status)")
        }
        return result as? Data
    }

    private func saveKey(_ key: Data) throws {
        SecItemDelete(baseQuery() as CFDictionary)

        var attributes = baseQuery()
        attributes[kSecValueData as String] = key
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly

        let status = SecItemAdd(attributes as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw ChumenError.commandFailed("Could not save config protection key to Keychain: \(status)")
        }
    }

    private func baseQuery() -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }

    static func randomBytes(count: Int) throws -> Data {
        var bytes = [UInt8](repeating: 0, count: count)
        let status = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        guard status == errSecSuccess else {
            throw ChumenError.commandFailed("Could not generate secure random bytes: \(status)")
        }
        return Data(bytes)
    }
}

public struct ChumenConfigProtection: Sendable {
    public let enabled: Bool
    public let keyStore: ChumenConfigProtectionKeyStore

    public init(
        enabled: Bool = true,
        keyStore: ChumenConfigProtectionKeyStore = ChumenConfigProtectionKeyStore()
    ) {
        self.enabled = enabled
        self.keyStore = keyStore
    }

    public func dataForReading(_ storedData: Data) throws -> Data {
        guard Self.isProtected(storedData) else { return storedData }
        return try Self.decrypt(storedData, key: keyStore.loadOrCreateKey())
    }

    public func dataForWriting(_ plainData: Data) throws -> Data {
        guard enabled else { return plainData }
        return try Self.encrypt(plainData, key: keyStore.loadOrCreateKey())
    }

    public func readText(at url: URL) throws -> String {
        let data = try dataForReading(Data(contentsOf: url))
        guard let text = String(data: data, encoding: .utf8) else {
            throw ChumenError.commandFailed("Protected config is not valid UTF-8: \(url.path)")
        }
        return text
    }

    public func writeText(_ text: String, to url: URL, fileManager: FileManager = .default) throws {
        try writeData(Data(text.utf8), to: url, fileManager: fileManager)
    }

    public func writeData(_ data: Data, to url: URL, fileManager: FileManager = .default) throws {
        let stored = try dataForWriting(data)
        try Self.writeStoredData(stored, to: url, fileManager: fileManager)
    }

    public func rewriteIfNeeded(at url: URL, fileManager: FileManager = .default) throws -> Bool {
        guard enabled, fileManager.fileExists(atPath: url.path) else { return false }
        let stored = try Data(contentsOf: url)
        guard !Self.isProtected(stored) else { return false }
        // Legacy plaintext files are migrated lazily on read paths so upgrades do not need a
        // separate one-shot migration command or block startup.
        try writeData(stored, to: url, fileManager: fileManager)
        return true
    }

    public static func isProtected(_ data: Data) -> Bool {
        data.count > magic.count && data.prefix(magic.count) == magic
    }

    public static func encrypt(_ plainData: Data, key: Data) throws -> Data {
        guard key.count == 32 else {
            throw ChumenError.commandFailed("Config protection key must be 32 bytes.")
        }
        let sealed = try AES.GCM.seal(plainData, using: SymmetricKey(data: key))
        guard let combined = sealed.combined else {
            throw ChumenError.commandFailed("Could not encode protected config payload.")
        }
        return magic + combined
    }

    public static func decrypt(_ storedData: Data, key: Data) throws -> Data {
        guard isProtected(storedData) else { return storedData }
        guard key.count == 32 else {
            throw ChumenError.commandFailed("Config protection key must be 32 bytes.")
        }
        let payload = storedData.dropFirst(magic.count)
        let sealed = try AES.GCM.SealedBox(combined: payload)
        return try AES.GCM.open(sealed, using: SymmetricKey(data: key))
    }

    public static func writePlainData(_ data: Data, to url: URL, fileManager: FileManager = .default) throws {
        try writeStoredData(data, to: url, fileManager: fileManager)
    }

    static func writeStoredData(_ data: Data, to url: URL, fileManager: FileManager = .default) throws {
        try fileManager.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: url, options: .atomic)
        try? fileManager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    }

    private static let magic = Data("CHUMENCFG1\n".utf8)
}
