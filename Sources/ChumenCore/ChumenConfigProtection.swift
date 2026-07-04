import CryptoKit
import Foundation
import Security

/// Centralizes config-at-rest protection.
///
/// Intent: Chumen stores proxy subscriptions and controller secrets under Application Support.
/// New protected files use mihomo's age envelope instead of a Chumen-only ciphertext format, so the
/// project has one config encryption model. The legacy AES path remains read-only for migration from
/// older CHUMENCFG1 files.
///
/// Security boundary: this is not a defense against root, a user who knows the macOS password, or
/// malware already running as the same user. The purpose is narrower: keep proxy details out of
/// ordinary plaintext files so casual disk scans, backups, and accidental folder sharing do not
/// expose subscriptions and nodes directly.
public struct ChumenConfigProtectionKeyStore: Sendable {
    private let service: String
    private let account: String
    private let ageIdentityURL: URL?
    private let useKeychainForAgeKey: Bool
    private let ageKeyPairOverride: MihomoAgeKeyPair?

    public init(
        service: String = "io.github.chumen.native-macos.config-protection",
        account: String = "storage-master-key",
        ageIdentityURL: URL? = nil,
        useKeychainForAgeKey: Bool = false,
        ageKeyPair: MihomoAgeKeyPair? = nil
    ) {
        self.service = service
        self.account = account
        self.ageIdentityURL = ageIdentityURL ?? Self.defaultAgeIdentityURL()
        self.useKeychainForAgeKey = useKeychainForAgeKey
        self.ageKeyPairOverride = ageKeyPair
    }

    public func loadOrCreateKey() throws -> Data {
        if let existing = try loadKey(), existing.count == 32 {
            return existing
        }
        let key = try Self.randomBytes(count: 32)
        try saveKey(key)
        return key
    }

    public func loadOrCreateAgeKeyPair(corePath: String) throws -> MihomoAgeKeyPair {
        if let ageKeyPairOverride {
            return ageKeyPairOverride
        }
        if let existing = try loadAgeKeyPair() {
            return existing
        }
        if pinVaultExists {
            throw ChumenError.commandFailed("PIN-protected age key is locked.")
        }
        let keyPair = try MihomoAgeRuntimeProtection.generateKeyPair(corePath: corePath)
        try saveAgeKeyPair(keyPair)
        return keyPair
    }

    public func loadAgeKeyPairIfPresent() throws -> MihomoAgeKeyPair? {
        if let ageKeyPairOverride {
            return ageKeyPairOverride
        }
        return try loadAgeKeyPair()
    }

    public func loadAgeKeyPairsForReading() throws -> [MihomoAgeKeyPair] {
        if let ageKeyPairOverride {
            return [ageKeyPairOverride]
        }

        // Reading has to be more forgiving than writing because older builds could leave a stale
        // raw local age identity while the matching identity still lives in Keychain. Try the
        // configured storage first, then compatibility fallback candidates without persisting or
        // printing any secret material.
        let preferred: [ChumenAgeKeyStorageKind] = useKeychainForAgeKey ? [.keychain, .local] : [.local, .keychain]
        var candidates: [MihomoAgeKeyPair] = []
        for storage in preferred {
            guard let keyPair = try loadAgeKeyPair(from: storage) else { continue }
            if !candidates.contains(keyPair) {
                candidates.append(keyPair)
            }
        }
        return candidates
    }

    public func storeAgeKeyPair(_ keyPair: MihomoAgeKeyPair) throws {
        try saveAgeKeyPair(keyPair)
    }

    public func deleteStoredAgeKeyPair() throws {
        if let ageIdentityURL, FileManager.default.fileExists(atPath: ageIdentityURL.path) {
            try FileManager.default.removeItem(at: ageIdentityURL)
        }
        let status = SecItemDelete(baseQuery(account: ageAccount) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw ChumenError.commandFailed("Could not delete age config protection key from Keychain: \(status)")
        }
    }

    private func loadKey() throws -> Data? {
        var query = baseQuery(account: account)
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
        SecItemDelete(baseQuery(account: account) as CFDictionary)

        var attributes = baseQuery(account: account)
        attributes[kSecValueData as String] = key
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly

        let status = SecItemAdd(attributes as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw ChumenError.commandFailed("Could not save config protection key to Keychain: \(status)")
        }
    }

    private func loadAgeKeyPair() throws -> MihomoAgeKeyPair? {
        let preferred: [ChumenAgeKeyStorageKind] = useKeychainForAgeKey ? [.keychain, .local] : [.local, .keychain]
        for storage in preferred {
            if let keyPair = try loadAgeKeyPair(from: storage) {
                return keyPair
            }
        }
        return nil
    }

    private func loadAgeKeyPair(from storage: ChumenAgeKeyStorageKind) throws -> MihomoAgeKeyPair? {
        switch storage {
        case .local:
            guard let ageIdentityURL,
                  FileManager.default.fileExists(atPath: ageIdentityURL.path) else {
                return nil
            }
            return try JSONDecoder().decode(MihomoAgeKeyPair.self, from: Data(contentsOf: ageIdentityURL))
        case .keychain:
            return try loadAgeKeyPairFromKeychain()
        }
    }

    private func loadAgeKeyPairFromKeychain() throws -> MihomoAgeKeyPair? {
        // Keychain is optional. Default installs read it only as a compatibility fallback for older
        // builds or when the user explicitly chose Keychain storage. Reading never migrates by
        // itself because storage location is a user choice; explicit save/move paths do migration.
        var query = baseQuery(account: ageAccount)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound {
            return nil
        }
        guard status == errSecSuccess else {
            throw ChumenError.commandFailed("Could not read age config protection key from Keychain: \(status)")
        }
        guard let data = result as? Data else { return nil }
        return try JSONDecoder().decode(MihomoAgeKeyPair.self, from: data)
    }

    private func saveAgeKeyPair(_ keyPair: MihomoAgeKeyPair) throws {
        if useKeychainForAgeKey {
            try saveAgeKeyPairToKeychain(keyPair)
            if let ageIdentityURL, FileManager.default.fileExists(atPath: ageIdentityURL.path) {
                try FileManager.default.removeItem(at: ageIdentityURL)
            }
            return
        }

        guard let ageIdentityURL else {
            return
        }
        try FileManager.default.createDirectory(at: ageIdentityURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(keyPair).write(to: ageIdentityURL, options: .atomic)
        try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: ageIdentityURL.path)
        try deleteLegacyKeychainAgeKeyPair()
    }

    private func saveAgeKeyPairToKeychain(_ keyPair: MihomoAgeKeyPair) throws {
        SecItemDelete(baseQuery(account: ageAccount) as CFDictionary)

        var attributes = baseQuery(account: ageAccount)
        attributes[kSecValueData as String] = try JSONEncoder().encode(keyPair)
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly

        let status = SecItemAdd(attributes as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw ChumenError.commandFailed("Could not save age config protection key to Keychain: \(status)")
        }
    }

    private func deleteLegacyKeychainAgeKeyPair() throws {
        let status = SecItemDelete(baseQuery(account: ageAccount) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw ChumenError.commandFailed("Could not delete legacy age config protection key from Keychain: \(status)")
        }
    }

    private var ageAccount: String {
        account + ".age-identity"
    }

    private func baseQuery(account: String) -> [String: Any] {
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

    private static func defaultAgeIdentityURL() -> URL? {
        try? ChumenPaths.defaultPaths().ageIdentityURL
    }

    private var pinVaultExists: Bool {
        guard let ageIdentityURL else { return false }
        let paths = ChumenPaths(appHome: ageIdentityURL.deletingLastPathComponent())
        return ChumenPINVault(paths: paths).exists
    }
}

public struct ChumenConfigProtection: Sendable {
    public let enabled: Bool
    public let keyStore: ChumenConfigProtectionKeyStore
    public let corePath: String?

    public init(
        enabled: Bool = true,
        keyStore: ChumenConfigProtectionKeyStore = ChumenConfigProtectionKeyStore(),
        corePath: String? = nil
    ) {
        self.enabled = enabled
        self.keyStore = keyStore
        self.corePath = corePath
    }

    public func dataForReading(_ storedData: Data) throws -> Data {
        if Self.isAgeProtected(storedData) {
            // Reads must never generate a new identity: a fresh key cannot decrypt existing files
            // and would also leave a misleading plaintext age-identity.json on disk. Creation is
            // limited to explicit write/setup paths.
            let keyPairs = try keyStore.loadAgeKeyPairsForReading()
            guard !keyPairs.isEmpty else {
                throw ChumenError.commandFailed("Missing age config protection key.")
            }
            let corePath = try resolvedCorePath()
            var lastError: Error?
            for keyPair in keyPairs {
                do {
                    return try MihomoAgeRuntimeProtection.decrypt(
                        storedData,
                        secretKey: keyPair.secretKey,
                        corePath: corePath
                    )
                } catch {
                    lastError = error
                }
            }
            throw lastError ?? ChumenError.commandFailed("Could not decrypt age protected config.")
        }
        if Self.isLegacyProtected(storedData) {
            return try Self.decrypt(storedData, key: keyStore.loadOrCreateKey())
        }
        return storedData
    }

    public func dataForWriting(_ plainData: Data) throws -> Data {
        guard enabled else { return plainData }
        let corePath = try resolvedCorePath()
        let keyPair = try keyStore.loadOrCreateAgeKeyPair(corePath: corePath)
        return try MihomoAgeRuntimeProtection.encrypt(plainData, publicKey: keyPair.publicKey, corePath: corePath)
    }

    public func readText(at url: URL) throws -> String {
        let storedData = try Data(contentsOf: url)
        let data: Data
        do {
            data = try dataForReading(storedData)
        } catch {
            throw ChumenError.commandFailed(
                "Could not read protected config \(url.path): \(error.localizedDescription)"
            )
        }
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
        guard !Self.isAgeProtected(stored) else { return false }
        // Legacy plaintext files are migrated lazily on read paths so upgrades do not need a
        // separate one-shot migration command or block startup. Legacy CHUMENCFG1 files are decoded
        // once and rewritten as mihomo age envelopes, so new writes no longer produce Chumen-only
        // ciphertext.
        try writeData(try dataForReading(stored), to: url, fileManager: fileManager)
        return true
    }

    public static func isProtected(_ data: Data) -> Bool {
        isAgeProtected(data) || isLegacyProtected(data)
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
        guard isLegacyProtected(storedData) else { return storedData }
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

    public static func isAgeProtected(_ data: Data) -> Bool {
        data.starts(with: ageMagic)
    }

    public static func isLegacyProtected(_ data: Data) -> Bool {
        data.count > magic.count && data.prefix(magic.count) == magic
    }

    private func resolvedCorePath() throws -> String {
        if let corePath, !corePath.isEmpty, FileManager.default.isExecutableFile(atPath: corePath) {
            return corePath
        }
        if let candidate = ChumenRuntimeSettings.firstExecutableCoreCandidate() {
            return candidate
        }
        throw ChumenError.missingCorePath
    }

    private static let ageMagic = Data("-----BEGIN AGE ENCRYPTED FILE-----".utf8)
    private static let magic = Data("CHUMENCFG1\n".utf8)
}
