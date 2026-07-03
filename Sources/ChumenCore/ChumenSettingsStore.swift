import Foundation

public struct ChumenSettingsStore: Sendable {
    public let paths: ChumenPaths

    public init(paths: ChumenPaths) {
        self.paths = paths
    }

    public func load() -> ChumenRuntimeSettings {
        guard let data = try? Data(contentsOf: paths.settingsURL),
              var settings = try? JSONDecoder().decode(ChumenRuntimeSettings.self, from: data) else {
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
        if needsSave {
            try? save(settings)
        }
        return settings
    }

    public func save(_ settings: ChumenRuntimeSettings) throws {
        try paths.ensureDirectories()
        let data = try JSONEncoder().encode(settings)
        try data.write(to: paths.settingsURL, options: .atomic)
    }
}
