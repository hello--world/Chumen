import CryptoKit
import Foundation
import Security

/// Stores the persistent age identity behind a user-facing PIN/password.
///
/// Intent: Keychain is convenient but it is still tied to the logged-in macOS user. The PIN vault is
/// a simple "防熟人 / 防扫描" layer around the age identity: Chumen cannot decrypt settings,
/// subscriptions, or nodes without an unlock path for the age key. By default that unlock path is
/// automatic so the app behaves normally; when app-lock is enabled, the automatic copy is removed
/// and the PIN becomes the required launch credential.
/// This is not a root/admin boundary, and the KDF is intentionally lightweight enough to keep the
/// feature simple instead of pretending to be high-assurance secret storage.
public struct ChumenPINVault: Sendable {
    public struct StoredVault: Codable, Equatable, Sendable {
        public var version: Int
        public var saltHex: String
        public var sealedKeyPairBase64: String
        public var lockAppOnLaunch: Bool
        public var autoSealedKeyPairBase64: String?

        public init(
            version: Int,
            saltHex: String,
            sealedKeyPairBase64: String,
            lockAppOnLaunch: Bool,
            autoSealedKeyPairBase64: String? = nil
        ) {
            self.version = version
            self.saltHex = saltHex
            self.sealedKeyPairBase64 = sealedKeyPairBase64
            self.lockAppOnLaunch = lockAppOnLaunch
            self.autoSealedKeyPairBase64 = autoSealedKeyPairBase64
        }
    }

    public let vaultURL: URL
    public let autoUnlockKeyURL: URL
    private let service: String
    private let account: String

    public init(
        paths: ChumenPaths,
        service: String = ChumenAppIdentity.keychainService(suffix: "pin-vault"),
        account: String = "age-key-vault"
    ) {
        self.vaultURL = paths.pinVaultURL
        self.autoUnlockKeyURL = paths.pinAutoUnlockKeyURL
        self.service = service
        self.account = account
    }

    public var exists: Bool {
        localExists || keychainExists
    }

    public func storageKind() -> ChumenAgeKeyStorageKind? {
        if localExists {
            return .local
        }
        return keychainExists ? .keychain : nil
    }

    public func load(preferredStorage: ChumenAgeKeyStorageKind? = nil) throws -> StoredVault? {
        guard let data = try storedData(preferredStorage: preferredStorage) else { return nil }
        return try JSONDecoder().decode(StoredVault.self, from: data)
    }

    public func create(
        pin: String,
        keyPair: MihomoAgeKeyPair,
        lockAppOnLaunch: Bool,
        storage: ChumenAgeKeyStorageKind
    ) throws {
        let salt = try Self.randomBytes(count: 16)
        let key = Self.derivedKey(pin: pin, salt: salt)
        let plain = try JSONEncoder().encode(keyPair)
        let sealed = try AES.GCM.seal(plain, using: key)
        guard let combined = sealed.combined else {
            throw ChumenError.commandFailed("Could not encode PIN vault payload.")
        }
        let vault = StoredVault(
            version: 1,
            saltHex: salt.hexString,
            sealedKeyPairBase64: combined.base64EncodedString(),
            lockAppOnLaunch: lockAppOnLaunch,
            autoSealedKeyPairBase64: lockAppOnLaunch ? nil : try autoSeal(keyPair)
        )
        try save(vault, storage: storage)
        try delete(storage: storage == .local ? .keychain : .local)
    }

    public func unlock(pin: String, preferredStorage: ChumenAgeKeyStorageKind? = nil) throws -> MihomoAgeKeyPair {
        guard let vault = try load(preferredStorage: preferredStorage) else {
            throw ChumenError.commandFailed("PIN vault is not configured.")
        }
        guard vault.version == 1 else {
            throw ChumenError.commandFailed("Unsupported PIN vault version: \(vault.version)")
        }
        guard let salt = Data(hexString: vault.saltHex),
              let sealedData = Data(base64Encoded: vault.sealedKeyPairBase64) else {
            throw ChumenError.commandFailed("PIN vault is corrupt.")
        }
        let sealed = try AES.GCM.SealedBox(combined: sealedData)
        let plain = try AES.GCM.open(sealed, using: Self.derivedKey(pin: pin, salt: salt))
        return try JSONDecoder().decode(MihomoAgeKeyPair.self, from: plain)
    }

    public func autoUnlock(preferredStorage: ChumenAgeKeyStorageKind? = nil) throws -> MihomoAgeKeyPair {
        guard let vault = try load(preferredStorage: preferredStorage) else {
            throw ChumenError.commandFailed("PIN vault is not configured.")
        }
        guard let sealedBase64 = vault.autoSealedKeyPairBase64,
              let sealedData = Data(base64Encoded: sealedBase64) else {
            throw ChumenError.commandFailed("PIN vault auto unlock is not configured.")
        }
        let sealed = try AES.GCM.SealedBox(combined: sealedData)
        let plain = try AES.GCM.open(sealed, using: SymmetricKey(data: try loadAutoUnlockKey()))
        return try JSONDecoder().decode(MihomoAgeKeyPair.self, from: plain)
    }

    public func updateLockAppOnLaunch(
        _ enabled: Bool,
        keyPair: MihomoAgeKeyPair? = nil,
        storage: ChumenAgeKeyStorageKind? = nil
    ) throws {
        guard var vault = try load(preferredStorage: storage) else { return }
        vault.lockAppOnLaunch = enabled
        if enabled {
            vault.autoSealedKeyPairBase64 = nil
            try deleteAutoUnlockKey()
        } else if let keyPair {
            vault.autoSealedKeyPairBase64 = try autoSeal(keyPair)
        }
        try save(vault, storage: storage ?? storageKind() ?? .local)
    }

    public func move(to storage: ChumenAgeKeyStorageKind) throws {
        guard let vault = try load() else { return }
        try save(vault, storage: storage)
        try delete(storage: storage == .local ? .keychain : .local)
    }

    public func delete(storage: ChumenAgeKeyStorageKind? = nil) throws {
        switch storage {
        case .local:
            if localExists {
                try FileManager.default.removeItem(at: vaultURL)
            }
        case .keychain:
            try deleteKeychainVault()
        case nil:
            if localExists {
                try FileManager.default.removeItem(at: vaultURL)
            }
            try deleteKeychainVault()
            try deleteAutoUnlockKey()
        }
    }

    public static func validatePIN(_ pin: String) throws {
        guard !pin.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ChumenError.commandFailed("PIN cannot be empty.")
        }
    }

    private static func derivedKey(pin: String, salt: Data) -> SymmetricKey {
        var data = Data(pin.utf8)
        data.append(salt)
        var digest = SHA256.hash(data: data)
        // A small fixed stretch keeps casual offline guessing less trivial without adding a heavy
        // dependency or creating noticeable UI delay for the simple PIN use case.
        for _ in 0..<9_999 {
            data = Data(digest)
            data.append(salt)
            digest = SHA256.hash(data: data)
        }
        return SymmetricKey(data: Data(digest))
    }

    private static func randomBytes(count: Int) throws -> Data {
        var bytes = [UInt8](repeating: 0, count: count)
        let status = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        guard status == errSecSuccess else {
            throw ChumenError.commandFailed("Could not generate PIN vault salt: \(status)")
        }
        return Data(bytes)
    }

    private var localExists: Bool {
        FileManager.default.fileExists(atPath: vaultURL.path)
    }

    private var keychainExists: Bool {
        (try? keychainData()) != nil
    }

    private func storedData(preferredStorage: ChumenAgeKeyStorageKind?) throws -> Data? {
        let order: [ChumenAgeKeyStorageKind]
        switch preferredStorage {
        case .some(.local):
            order = [.local, .keychain]
        case .some(.keychain):
            order = [.keychain, .local]
        case .none:
            order = [.local, .keychain]
        }

        for storage in order {
            switch storage {
            case .local:
                if localExists {
                    return try Data(contentsOf: vaultURL)
                }
            case .keychain:
                if let data = try keychainData() {
                    return data
                }
            }
        }
        return nil
    }

    private func save(_ vault: StoredVault, storage: ChumenAgeKeyStorageKind) throws {
        let data = try JSONEncoder().encode(vault)
        switch storage {
        case .local:
            try FileManager.default.createDirectory(at: vaultURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try data.write(to: vaultURL, options: .atomic)
            try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: vaultURL.path)
        case .keychain:
            try saveKeychainVault(data)
        }
    }

    private func autoSeal(_ keyPair: MihomoAgeKeyPair) throws -> String {
        let plain = try JSONEncoder().encode(keyPair)
        let sealed = try AES.GCM.seal(plain, using: SymmetricKey(data: try loadOrCreateAutoUnlockKey()))
        guard let combined = sealed.combined else {
            throw ChumenError.commandFailed("Could not encode PIN vault auto unlock payload.")
        }
        return combined.base64EncodedString()
    }

    private func loadOrCreateAutoUnlockKey() throws -> Data {
        if let existing = try loadAutoUnlockKeyIfPresent() {
            return existing
        }
        let key = try Self.randomBytes(count: 32)
        try FileManager.default.createDirectory(at: autoUnlockKeyURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try key.write(to: autoUnlockKeyURL, options: .atomic)
        try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: autoUnlockKeyURL.path)
        return key
    }

    private func loadAutoUnlockKey() throws -> Data {
        guard let key = try loadAutoUnlockKeyIfPresent() else {
            throw ChumenError.commandFailed("PIN vault auto unlock key is missing.")
        }
        return key
    }

    private func loadAutoUnlockKeyIfPresent() throws -> Data? {
        guard FileManager.default.fileExists(atPath: autoUnlockKeyURL.path) else { return nil }
        let data = try Data(contentsOf: autoUnlockKeyURL)
        guard data.count == 32 else {
            throw ChumenError.commandFailed("PIN vault auto unlock key is corrupt.")
        }
        return data
    }

    private func deleteAutoUnlockKey() throws {
        if FileManager.default.fileExists(atPath: autoUnlockKeyURL.path) {
            try FileManager.default.removeItem(at: autoUnlockKeyURL)
        }
    }

    private func keychainData() throws -> Data? {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound {
            return nil
        }
        guard status == errSecSuccess else {
            throw ChumenError.commandFailed("Could not read PIN vault from Keychain: \(status)")
        }
        return result as? Data
    }

    private func saveKeychainVault(_ data: Data) throws {
        SecItemDelete(baseQuery as CFDictionary)

        var attributes = baseQuery
        attributes[kSecValueData as String] = data
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly

        let status = SecItemAdd(attributes as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw ChumenError.commandFailed("Could not save PIN vault to Keychain: \(status)")
        }
    }

    private func deleteKeychainVault() throws {
        let status = SecItemDelete(baseQuery as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw ChumenError.commandFailed("Could not delete PIN vault from Keychain: \(status)")
        }
    }

    private var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }
}

private extension Data {
    var hexString: String {
        map { String(format: "%02x", $0) }.joined()
    }

    init?<S: StringProtocol>(hexString: S) {
        guard hexString.count.isMultiple(of: 2) else { return nil }
        var bytes: [UInt8] = []
        bytes.reserveCapacity(hexString.count / 2)
        var index = hexString.startIndex
        while index < hexString.endIndex {
            let next = hexString.index(index, offsetBy: 2)
            guard let byte = UInt8(hexString[index..<next], radix: 16) else { return nil }
            bytes.append(byte)
            index = next
        }
        self = Data(bytes)
    }
}
