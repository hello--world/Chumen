import XCTest
@testable import ChumenCore

final class ChumenConfigProtectionTests: XCTestCase {
    func testLegacyProtectedEnvelopeStillDecryptsForMigration() throws {
        let key = Data(repeating: 7, count: 32)
        let plain = Data("proxies:\n  - server: example.com\n".utf8)

        let encrypted = try ChumenConfigProtection.encrypt(plain, key: key)
        let decrypted = try ChumenConfigProtection.decrypt(encrypted, key: key)

        XCTAssertTrue(ChumenConfigProtection.isProtected(encrypted))
        XCTAssertNotEqual(encrypted, plain)
        XCTAssertEqual(decrypted, plain)
    }

    func testConfigProtectionWritesAgeEnvelope() throws {
        guard let corePath = ChumenRuntimeSettings.firstExecutableCoreCandidate() else {
            throw XCTSkip("mihomo binary is required for age protection")
        }
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("chumen-config-protection-\(UUID().uuidString)", isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: root)
        }
        let keyStore = ChumenConfigProtectionKeyStore(
            service: "io.github.chumen.tests.\(UUID().uuidString)",
            account: "config-protection",
            ageIdentityURL: root.appendingPathComponent("age-identity.json")
        )
        let protection = ChumenConfigProtection(
            enabled: true,
            keyStore: keyStore,
            corePath: corePath
        )
        let plain = Data("rules:\n  - MATCH,DIRECT\n".utf8)

        let stored = try protection.dataForWriting(plain)

        XCTAssertTrue(ChumenConfigProtection.isAgeProtected(stored))
        XCTAssertFalse(ChumenConfigProtection.isLegacyProtected(stored))
        XCTAssertEqual(try protection.dataForReading(stored), plain)
    }

    func testAgeProtectedReadDoesNotCreateMissingIdentity() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("chumen-missing-age-key-\(UUID().uuidString)", isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: root)
        }
        let identityURL = root.appendingPathComponent("age-identity.json")
        let keyStore = ChumenConfigProtectionKeyStore(
            service: "io.github.chumen.tests.\(UUID().uuidString)",
            account: "config-protection",
            ageIdentityURL: identityURL
        )
        let protection = ChumenConfigProtection(enabled: true, keyStore: keyStore)
        let stored = Data("-----BEGIN AGE ENCRYPTED FILE-----\nmissing-key\n".utf8)

        XCTAssertThrowsError(try protection.dataForReading(stored))
        XCTAssertFalse(FileManager.default.fileExists(atPath: identityURL.path))
    }

    func testAgeProtectedReadFallsBackToKeychainWhenLocalIdentityIsStale() throws {
        guard let corePath = ChumenRuntimeSettings.firstExecutableCoreCandidate() else {
            throw XCTSkip("mihomo binary is required for age protection")
        }
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("chumen-stale-local-age-key-\(UUID().uuidString)", isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: root)
        }

        let service = "io.github.chumen.tests.\(UUID().uuidString)"
        let account = "config-protection"
        let paths = ChumenPaths(appHome: root)
        try paths.ensureDirectories()
        let correctKeyPair = try MihomoAgeRuntimeProtection.generateKeyPair(corePath: corePath)
        let staleKeyPair = try MihomoAgeRuntimeProtection.generateKeyPair(corePath: corePath)
        let keychainStore = ChumenConfigProtectionKeyStore(
            service: service,
            account: account,
            ageIdentityURL: paths.ageIdentityURL,
            useKeychainForAgeKey: true
        )
        defer {
            try? keychainStore.deleteStoredAgeKeyPair()
        }
        try keychainStore.storeAgeKeyPair(correctKeyPair)
        try JSONEncoder().encode(staleKeyPair).write(to: paths.ageIdentityURL, options: .atomic)

        let stored = try MihomoAgeRuntimeProtection.encrypt(
            Data("proxies: []\n".utf8),
            publicKey: correctKeyPair.publicKey,
            corePath: corePath
        )
        let localStore = ChumenConfigProtectionKeyStore(
            service: service,
            account: account,
            ageIdentityURL: paths.ageIdentityURL
        )
        let protection = ChumenConfigProtection(enabled: true, keyStore: localStore, corePath: corePath)

        XCTAssertEqual(try protection.dataForReading(stored), Data("proxies: []\n".utf8))
    }

    func testProtectedReadErrorIncludesPathWithoutGoStack() throws {
        guard let corePath = ChumenRuntimeSettings.firstExecutableCoreCandidate() else {
            throw XCTSkip("mihomo binary is required for age protection")
        }
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("chumen-readable-age-error-\(UUID().uuidString)", isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: root)
        }

        let paths = ChumenPaths(appHome: root)
        try paths.ensureDirectories()
        let correctKeyPair = try MihomoAgeRuntimeProtection.generateKeyPair(corePath: corePath)
        let wrongKeyPair = try MihomoAgeRuntimeProtection.generateKeyPair(corePath: corePath)
        let profileURL = paths.profilesDirectoryURL.appendingPathComponent("profile.yaml")
        let stored = try MihomoAgeRuntimeProtection.encrypt(
            Data("proxies: []\n".utf8),
            publicKey: correctKeyPair.publicKey,
            corePath: corePath
        )
        try stored.write(to: profileURL, options: .atomic)
        try JSONEncoder().encode(wrongKeyPair).write(to: paths.ageIdentityURL, options: .atomic)

        let keyStore = ChumenConfigProtectionKeyStore(
            service: "io.github.chumen.tests.\(UUID().uuidString)",
            account: "config-protection",
            ageIdentityURL: paths.ageIdentityURL
        )
        let protection = ChumenConfigProtection(enabled: true, keyStore: keyStore, corePath: corePath)

        XCTAssertThrowsError(try protection.readText(at: profileURL)) { error in
            let message = error.localizedDescription
            XCTAssertTrue(message.contains(profileURL.path))
            XCTAssertTrue(message.contains("chumen-door age decrypt failed"))
            XCTAssertTrue(message.contains("stored age identity cannot decrypt"))
            XCTAssertFalse(message.contains("chumen-door age age failed"))
            XCTAssertFalse(message.contains("goroutine"))
        }
    }

    func testReadOnlySettingsLoadDoesNotMigratePlaintextOrCreateAgeIdentity() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("chumen-readonly-settings-\(UUID().uuidString)", isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: root)
        }

        let paths = ChumenPaths(appHome: root)
        try paths.ensureDirectories()
        let settings = ChumenRuntimeSettings(
            corePath: "/tmp/missing-mihomo",
            protectConfigFiles: true,
            protectAgeKeyWithPIN: true
        )
        try JSONEncoder().encode(settings).write(to: paths.settingsURL, options: .atomic)
        let keyStore = ChumenConfigProtectionKeyStore(
            service: "io.github.chumen.tests.\(UUID().uuidString)",
            account: "config-protection",
            ageIdentityURL: paths.ageIdentityURL
        )
        let store = ChumenSettingsStore(paths: paths, protectionKeyStore: keyStore)

        let loaded = store.load(migrateOnLoad: false)

        XCTAssertTrue(loaded.protectAgeKeyWithPIN)
        XCTAssertFalse(ChumenConfigProtection.isAgeProtected(try Data(contentsOf: paths.settingsURL)))
        XCTAssertFalse(FileManager.default.fileExists(atPath: paths.ageIdentityURL.path))
    }

    func testRewriteMigratesLegacyEnvelopeToAgeEnvelope() throws {
        guard let corePath = ChumenRuntimeSettings.firstExecutableCoreCandidate() else {
            throw XCTSkip("mihomo binary is required for age protection")
        }
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("chumen-legacy-protection-\(UUID().uuidString)", isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: root)
        }
        let keyStore = ChumenConfigProtectionKeyStore(
            service: "io.github.chumen.tests.\(UUID().uuidString)",
            account: "config-protection",
            ageIdentityURL: root.appendingPathComponent("age-identity.json")
        )
        let protection = ChumenConfigProtection(
            enabled: true,
            keyStore: keyStore,
            corePath: corePath
        )
        let fileURL = root.appendingPathComponent("profile.yaml")
        let plain = Data("proxies: []\n".utf8)
        let legacyKey = try keyStore.loadOrCreateKey()
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try ChumenConfigProtection.encrypt(plain, key: legacyKey).write(to: fileURL)

        XCTAssertTrue(try protection.rewriteIfNeeded(at: fileURL))
        let rewritten = try Data(contentsOf: fileURL)

        XCTAssertTrue(ChumenConfigProtection.isAgeProtected(rewritten))
        XCTAssertFalse(ChumenConfigProtection.isLegacyProtected(rewritten))
        XCTAssertEqual(try protection.dataForReading(rewritten), plain)
    }

    func testRuntimeSettingsProtectsConfigFilesByDefault() {
        XCTAssertTrue(ChumenRuntimeSettings().protectConfigFiles)
        XCTAssertTrue(ChumenRuntimeSettings().protectAgeKeyWithPIN)
        XCTAssertFalse(ChumenRuntimeSettings().securitySetupCompleted)
    }

    func testMissingSecuritySetupMarkerDoesNotInterruptExistingInstalls() throws {
        let legacyJSON = """
        {
          "corePath": "",
          "mixedPort": 19881,
          "socksPort": 19882,
          "httpPort": 19883,
          "redirPort": 19884,
          "tproxyPort": 19885,
          "externalControllerHost": "127.0.0.1",
          "externalControllerPort": 19897,
          "systemProxyHost": "127.0.0.1",
          "secret": "abc",
          "protectConfigFiles": true,
          "protectAgeKeyWithPIN": false
        }
        """.data(using: .utf8)!

        let decoded = try JSONDecoder().decode(ChumenRuntimeSettings.self, from: legacyJSON)

        XCTAssertTrue(decoded.securitySetupCompleted)
    }

    func testRuntimeConfigWritesAgeEncryptedCanonicalFileWithoutPlainSessionFile() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("chumen-runtime-protection-\(UUID().uuidString)", isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: root)
        }

        let paths = ChumenPaths(appHome: root)
        try paths.ensureDirectories()
        let profileURL = paths.profilesDirectoryURL.appendingPathComponent("profile.yaml")
        try "proxies: []\nrules:\n  - MATCH,DIRECT\n".write(to: profileURL, atomically: true, encoding: .utf8)

        let runtimeURL = try ChumenConfigurationBuilder.writeRuntimeConfig(
            settings: ChumenRuntimeSettings(corePath: "/tmp/fake-mihomo", profilePath: profileURL.path, secret: "secret"),
            paths: paths,
            ageProtection: FakeAgeProtection()
        )

        XCTAssertEqual(runtimeURL.path, paths.runtimeConfigURL.path)
        XCTAssertTrue(ChumenConfigProtection.isAgeProtected(try Data(contentsOf: paths.runtimeConfigURL)))
        let storedRuntime = try String(contentsOf: runtimeURL, encoding: .utf8)
        XCTAssertTrue(storedRuntime.hasPrefix("-----BEGIN AGE ENCRYPTED FILE-----"))
        XCTAssertFalse(storedRuntime.contains("MATCH,DIRECT"))

        ChumenConfigurationBuilder.cleanupRuntimePlaintextFile(runtimeURL, paths: paths)
        XCTAssertTrue(FileManager.default.fileExists(atPath: runtimeURL.path))
    }

    func testRuntimeConfigUsesProtectionKeyStoreAgeIdentityForMihomoSecret() throws {
        guard let corePath = ChumenRuntimeSettings.firstExecutableCoreCandidate() else {
            throw XCTSkip("mihomo binary is required for age protection")
        }
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("chumen-runtime-key-store-\(UUID().uuidString)", isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: root)
        }

        let paths = ChumenPaths(appHome: root)
        let keyStore = ChumenConfigProtectionKeyStore(
            service: "io.github.chumen.tests.\(UUID().uuidString)",
            account: "config-protection",
            ageIdentityURL: paths.ageIdentityURL
        )
        let settings = ChumenRuntimeSettings(
            corePath: corePath,
            secret: "secret",
            protectConfigFiles: true
        )

        let runtimeURL = try ChumenConfigurationBuilder.writeRuntimeConfig(
            settings: settings,
            paths: paths,
            protectionKeyStore: keyStore
        )
        let stored = try Data(contentsOf: runtimeURL)
        let keyPair = try XCTUnwrap(keyStore.loadAgeKeyPairIfPresent())
        let plain = try MihomoAgeRuntimeProtection.decrypt(
            stored,
            secretKey: keyPair.secretKey,
            corePath: corePath
        )
        let yaml = try XCTUnwrap(String(data: plain, encoding: .utf8))

        XCTAssertTrue(ChumenConfigProtection.isAgeProtected(stored))
        XCTAssertTrue(yaml.contains("# Generated by Chumen"))
        XCTAssertTrue(yaml.contains("mixed-port: \(ChumenRuntimeSettings.defaultMixedPort)"))
    }
}

private struct FakeAgeProtection: MihomoAgeRuntimeProtecting {
    func encryptRuntimeConfig(_ plainData: Data, corePath: String) throws -> Data {
        XCTAssertEqual(corePath, "/tmp/fake-mihomo")
        let digest = plainData.count
        return Data("-----BEGIN AGE ENCRYPTED FILE-----\nfake-\(digest)\n".utf8)
    }

    func secretKey(corePath: String) throws -> String {
        XCTAssertEqual(corePath, "/tmp/fake-mihomo")
        return "AGE-SECRET-KEY-TEST"
    }
}
