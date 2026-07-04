import Foundation

public struct ChumenSettingsStore: Sendable {
    public let paths: ChumenPaths
    private let protectionKeyStore: ChumenConfigProtectionKeyStore

    public init(
        paths: ChumenPaths,
        protectionKeyStore: ChumenConfigProtectionKeyStore? = nil
    ) {
        self.paths = paths
        self.protectionKeyStore = protectionKeyStore ?? ChumenConfigProtectionKeyStore(ageIdentityURL: paths.ageIdentityURL)
    }

    public func load(migrateOnLoad: Bool = true) -> ChumenRuntimeSettings {
        // Settings are the first file read during startup, so this store must understand both the
        // new encrypted envelope and older plaintext JSON. Successful plaintext loads are written
        // back through save(_:) so protection turns on without a separate migration step. PIN setup
        // uses read-only loading so startup can show the PIN prompt without first creating raw keys.
        do {
            return try loadOrThrow(migrateOnLoad: migrateOnLoad)
        } catch {
            return Self.defaultSettings()
        }
    }

    public func loadOrThrow(migrateOnLoad: Bool = true) throws -> ChumenRuntimeSettings {
        // PIN-protected startup uses this throwing path so a locked or wrong-key settings file never
        // collapses into defaults and later overwrites the real encrypted configuration.
        guard let storedData = try? Data(contentsOf: paths.settingsURL) else {
            return Self.defaultSettings()
        }
        let storedDataWasAgeProtected = ChumenConfigProtection.isAgeProtected(storedData)
        let plainData = try ChumenConfigProtection(enabled: true, keyStore: protectionKeyStore)
            .dataForReading(storedData)
        var settings = try JSONDecoder().decode(ChumenRuntimeSettings.self, from: plainData)
        var needsSave = false
        // 设置加载是迁移入口：旧端口、旧 core 路径和旧 profile 路径都在这里自动修正并写回。
        if (settings.corePath.isEmpty || !FileManager.default.isExecutableFile(atPath: settings.corePath)),
           let candidate = ChumenRuntimeSettings.firstExecutableCoreCandidate() {
            settings.corePath = candidate
            needsSave = true
        }
        if settings.usesLegacyBundledCorePath,
           let candidate = ChumenRuntimeSettings.firstExecutableCoreCandidate() {
            settings.corePath = candidate
            needsSave = true
        }
        if let profilePath = settings.profilePath {
            let migratedProfilePath = paths.rewriteLegacyAppHomePath(profilePath)
            if migratedProfilePath != profilePath {
                settings.profilePath = migratedProfilePath
                needsSave = true
            }
        }
        if settings.usesLegacyDefaultPorts {
            settings.migrateLegacyDefaultPorts()
            needsSave = true
        }
        if settings.ensureRandomSecret() {
            needsSave = true
        }
        if settings.protectConfigFiles, !storedDataWasAgeProtected {
            needsSave = true
        }
        if needsSave && migrateOnLoad {
            try? save(settings)
        }
        return settings
    }

    public func save(_ settings: ChumenRuntimeSettings) throws {
        try paths.ensureDirectories()
        let data = try JSONEncoder().encode(settings)
        let protection = ChumenConfigProtection(
            enabled: settings.protectConfigFiles,
            keyStore: protectionKeyStore,
            corePath: settings.corePath
        )
        try protection.writeData(data, to: paths.settingsURL)
    }

    public static func defaultSettings() -> ChumenRuntimeSettings {
        var defaults = ChumenRuntimeSettings()
        if let candidate = ChumenRuntimeSettings.firstExecutableCoreCandidate() {
            defaults.corePath = candidate
        }
        return defaults
    }
}
