import Foundation

public struct ChumenSettingsStore: Sendable {
    public let paths: ChumenPaths
    private let protectionKeyStore: ChumenConfigProtectionKeyStore

    public init(
        paths: ChumenPaths,
        protectionKeyStore: ChumenConfigProtectionKeyStore = ChumenConfigProtectionKeyStore()
    ) {
        self.paths = paths
        self.protectionKeyStore = protectionKeyStore
    }

    public func load() -> ChumenRuntimeSettings {
        // Settings are the first file read during startup, so this store must understand both the
        // new encrypted envelope and older plaintext JSON. Successful plaintext loads are written
        // back through save(_:) so protection turns on without a separate migration step.
        guard let storedData = try? Data(contentsOf: paths.settingsURL) else {
            var defaults = ChumenRuntimeSettings()
            if let candidate = ChumenRuntimeSettings.firstExecutableCoreCandidate() {
                defaults.corePath = candidate
            }
            try? save(defaults)
            return defaults
        }
        let storedDataWasProtected = ChumenConfigProtection.isProtected(storedData)
        let plainData: Data
        do {
            plainData = try ChumenConfigProtection(enabled: true, keyStore: protectionKeyStore)
                .dataForReading(storedData)
        } catch {
            var defaults = ChumenRuntimeSettings()
            if let candidate = ChumenRuntimeSettings.firstExecutableCoreCandidate() {
                defaults.corePath = candidate
            }
            return defaults
        }
        guard var settings = try? JSONDecoder().decode(ChumenRuntimeSettings.self, from: plainData) else {
            var defaults = ChumenRuntimeSettings()
            if let candidate = ChumenRuntimeSettings.firstExecutableCoreCandidate() {
                defaults.corePath = candidate
            }
            try? save(defaults)
            return defaults
        }
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
        if settings.protectConfigFiles, !storedDataWasProtected {
            needsSave = true
        }
        if needsSave {
            try? save(settings)
        }
        return settings
    }

    public func save(_ settings: ChumenRuntimeSettings) throws {
        try paths.ensureDirectories()
        let data = try JSONEncoder().encode(settings)
        let protection = ChumenConfigProtection(
            enabled: settings.protectConfigFiles,
            keyStore: protectionKeyStore
        )
        try protection.writeData(data, to: paths.settingsURL)
    }
}
