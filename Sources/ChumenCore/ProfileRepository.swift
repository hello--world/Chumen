import Foundation

public struct ProxyProfile: Codable, Identifiable, Equatable, Sendable {
    public var id: String
    public var name: String
    public var filePath: String
    public var remoteURL: String?
    public var sourceClient: String?
    public var sourcePath: String?
    public var sourceFingerprint: String?
    public var configAppendixYAML: String?
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: String = UUID().uuidString,
        name: String,
        filePath: String,
        remoteURL: String? = nil,
        sourceClient: String? = nil,
        sourcePath: String? = nil,
        sourceFingerprint: String? = nil,
        configAppendixYAML: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.filePath = filePath
        self.remoteURL = remoteURL
        self.sourceClient = sourceClient
        self.sourcePath = sourcePath
        self.sourceFingerprint = sourceFingerprint
        self.configAppendixYAML = configAppendixYAML
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

public struct ProfileLibrary: Codable, Equatable, Sendable {
    public var activeProfileID: String?
    public var profiles: [ProxyProfile]

    public init(activeProfileID: String? = nil, profiles: [ProxyProfile] = []) {
        self.activeProfileID = activeProfileID
        self.profiles = profiles
    }

    public var activeProfile: ProxyProfile? {
        profiles.first { $0.id == activeProfileID }
    }
}

@MainActor
public final class ProfileRepository {
    private let paths: ChumenPaths
    private let fileManager: FileManager
    private let session: URLSession

    public init(
        paths: ChumenPaths,
        fileManager: FileManager = .default,
        session: URLSession = .shared
    ) {
        self.paths = paths
        self.fileManager = fileManager
        self.session = session
    }

    public func load() -> ProfileLibrary {
        guard let data = try? Data(contentsOf: paths.profileLibraryURL),
              var library = try? JSONDecoder().decode(ProfileLibrary.self, from: data) else {
            return ProfileLibrary()
        }
        // 配置库也保存绝对路径，改名/迁移后需要在读取时修正并写回。
        var changed = false
        for index in library.profiles.indices {
            let migratedPath = paths.rewriteLegacyAppHomePath(library.profiles[index].filePath)
            if migratedPath != library.profiles[index].filePath {
                library.profiles[index].filePath = migratedPath
                changed = true
            }
        }
        if changed {
            try? save(library)
        }
        return library
    }

    public func save(_ library: ProfileLibrary) throws {
        try paths.ensureDirectories(fileManager: fileManager)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(library)
        try data.write(to: paths.profileLibraryURL, options: .atomic)
    }

    public func importLocalProfile(from sourceURL: URL, name: String? = nil, into library: inout ProfileLibrary) throws -> ProxyProfile {
        try paths.ensureDirectories(fileManager: fileManager)
        let id = UUID().uuidString
        let targetURL = paths.profilesDirectoryURL.appendingPathComponent("\(id).yaml")
        if fileManager.fileExists(atPath: targetURL.path) {
            try fileManager.removeItem(at: targetURL)
        }
        try fileManager.copyItem(at: sourceURL, to: targetURL)

        let profile = ProxyProfile(
            id: id,
            name: cleanName(name ?? sourceURL.deletingPathExtension().lastPathComponent, fallback: "Local Profile"),
            filePath: targetURL.path
        )
        library.profiles.append(profile)
        if library.activeProfileID == nil {
            library.activeProfileID = profile.id
        }
        try save(library)
        return profile
    }

    public func importRemoteProfile(urlString: String, name: String? = nil, into library: inout ProfileLibrary) async throws -> ProxyProfile {
        guard let normalizedURLString = try normalizedRemoteURL(urlString),
              let url = URL(string: normalizedURLString) else {
            throw ChumenError.commandFailed("Invalid subscription URL.")
        }
        let data = try await downloadProfile(url: url)
        try paths.ensureDirectories(fileManager: fileManager)

        let id = UUID().uuidString
        let targetURL = paths.profilesDirectoryURL.appendingPathComponent("\(id).yaml")
        try data.write(to: targetURL, options: .atomic)

        let profile = ProxyProfile(
            id: id,
            name: cleanName(name ?? url.host ?? "Remote Profile", fallback: "Remote Profile"),
            filePath: targetURL.path,
            remoteURL: normalizedURLString
        )
        library.profiles.append(profile)
        if library.activeProfileID == nil {
            library.activeProfileID = profile.id
        }
        try save(library)
        return profile
    }

    public func discoverExternalProfiles(homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser) -> [ExternalProfileCandidate] {
        ExternalProfileImporter.discover(
            sources: ExternalProfileImporter.defaultSources(homeDirectory: homeDirectory),
            fileManager: fileManager
        )
    }

    public func importExternalProfiles(
        _ candidates: [ExternalProfileCandidate],
        into library: inout ProfileLibrary
    ) throws -> ExternalProfileImportSummary {
        try paths.ensureDirectories(fileManager: fileManager)

        var summary = ExternalProfileImportSummary()
        // 用内容指纹去重，比单纯文件名更可靠；不同客户端可能把同一订阅保存成不同文件名。
        var knownFingerprints = existingProfileFingerprints(in: library)

        for candidate in candidates {
            do {
                let sourceURL = URL(fileURLWithPath: candidate.filePath)
                let data = try Data(contentsOf: sourceURL)
                let fingerprint = Self.contentFingerprint(data)
                if knownFingerprints.contains(fingerprint) {
                    summary.skipped.append(ExternalProfileImportSkipped(candidate: candidate, reason: "duplicate"))
                    continue
                }

                let id = UUID().uuidString
                let targetURL = paths.profilesDirectoryURL.appendingPathComponent("\(id).yaml")
                try data.write(to: targetURL, options: .atomic)

                let profile = ProxyProfile(
                    id: id,
                    name: uniqueName(
                        "\(candidate.sourceName) - \(candidate.name)",
                        existingNames: Set(library.profiles.map(\.name))
                    ),
                    filePath: targetURL.path,
                    // 能从其他客户端识别到订阅 URL 时保留下来，后续更新就不需要用户重新粘贴。
                    remoteURL: candidate.remoteURL,
                    sourceClient: candidate.sourceName,
                    sourcePath: candidate.filePath,
                    sourceFingerprint: fingerprint
                )
                library.profiles.append(profile)
                if library.activeProfileID == nil {
                    library.activeProfileID = profile.id
                }
                knownFingerprints.insert(fingerprint)
                summary.imported.append(profile)
            } catch {
                summary.failed.append(ExternalProfileImportFailure(
                    candidate: candidate,
                    message: error.localizedDescription
                ))
            }
        }

        try save(library)
        return summary
    }

    public func update(_ profile: ProxyProfile, in library: inout ProfileLibrary) async throws -> ProxyProfile {
        guard let remoteURL = profile.remoteURL, let url = URL(string: remoteURL) else {
            throw ChumenError.commandFailed("This profile has no remote subscription URL.")
        }
        let data = try await downloadProfile(url: url)
        try data.write(to: URL(fileURLWithPath: profile.filePath), options: .atomic)

        var updated = profile
        updated.updatedAt = Date()
        if let index = library.profiles.firstIndex(where: { $0.id == profile.id }) {
            library.profiles[index] = updated
        }
        try save(library)
        return updated
    }

    public func delete(_ profile: ProxyProfile, from library: inout ProfileLibrary) throws {
        library.profiles.removeAll { $0.id == profile.id }
        if library.activeProfileID == profile.id {
            library.activeProfileID = library.profiles.first?.id
        }

        let fileURL = URL(fileURLWithPath: profile.filePath)
        if fileManager.fileExists(atPath: fileURL.path) {
            try fileManager.removeItem(at: fileURL)
        }
        try save(library)
    }

    public func saveContent(_ profile: ProxyProfile, content: String, in library: inout ProfileLibrary) throws -> ProxyProfile {
        try content.write(to: URL(fileURLWithPath: profile.filePath), atomically: true, encoding: .utf8)

        var updated = profile
        updated.updatedAt = Date()
        if let index = library.profiles.firstIndex(where: { $0.id == profile.id }) {
            library.profiles[index] = updated
        }
        try save(library)
        return updated
    }

    public func saveContentAndMetadata(
        _ profile: ProxyProfile,
        content: String,
        name: String,
        remoteURL: String?,
        in library: inout ProfileLibrary
    ) throws -> ProxyProfile {
        let normalizedRemoteURL = try normalizedRemoteURL(remoteURL)
        try content.write(to: URL(fileURLWithPath: profile.filePath), atomically: true, encoding: .utf8)

        var updated = profile
        updated.name = cleanName(name, fallback: profile.name)
        updated.remoteURL = normalizedRemoteURL
        updated.updatedAt = Date()
        if let index = library.profiles.firstIndex(where: { $0.id == profile.id }) {
            library.profiles[index] = updated
        }
        try save(library)
        return updated
    }

    public func rename(_ profile: ProxyProfile, name: String, in library: inout ProfileLibrary) throws -> ProxyProfile {
        var updated = profile
        updated.name = cleanName(name, fallback: profile.name)
        updated.updatedAt = Date()
        if let index = library.profiles.firstIndex(where: { $0.id == profile.id }) {
            library.profiles[index] = updated
        }
        try save(library)
        return updated
    }

    public func updateMetadata(
        _ profile: ProxyProfile,
        name: String,
        remoteURL: String?,
        in library: inout ProfileLibrary
    ) throws -> ProxyProfile {
        var updated = profile
        updated.name = cleanName(name, fallback: profile.name)
        updated.remoteURL = try normalizedRemoteURL(remoteURL)
        updated.updatedAt = Date()
        if let index = library.profiles.firstIndex(where: { $0.id == profile.id }) {
            library.profiles[index] = updated
        }
        try save(library)
        return updated
    }

    public func update(
        _ profile: ProxyProfile,
        usingHTTPProxyHost host: String,
        port: Int,
        in library: inout ProfileLibrary
    ) async throws -> ProxyProfile {
        guard let remoteURL = profile.remoteURL, let url = URL(string: remoteURL) else {
            throw ChumenError.commandFailed("This profile has no remote subscription URL.")
        }

        let configuration = URLSessionConfiguration.ephemeral
        configuration.connectionProxyDictionary = [
            "HTTPEnable": true,
            "HTTPProxy": host,
            "HTTPPort": port,
            "HTTPSEnable": true,
            "HTTPSProxy": host,
            "HTTPSPort": port
        ]
        let proxySession = URLSession(configuration: configuration)
        let data = try await downloadProfile(url: url, sessionOverride: proxySession)
        try data.write(to: URL(fileURLWithPath: profile.filePath), options: .atomic)

        var updated = profile
        updated.updatedAt = Date()
        if let index = library.profiles.firstIndex(where: { $0.id == profile.id }) {
            library.profiles[index] = updated
        }
        try save(library)
        return updated
    }

    public func updateConfigAppendix(
        _ profile: ProxyProfile,
        yaml: String,
        in library: inout ProfileLibrary
    ) throws -> ProxyProfile {
        var updated = profile
        let trimmed = yaml.trimmingCharacters(in: .whitespacesAndNewlines)
        updated.configAppendixYAML = trimmed.isEmpty ? nil : yaml
        updated.updatedAt = Date()
        if let index = library.profiles.firstIndex(where: { $0.id == profile.id }) {
            library.profiles[index] = updated
        }
        try save(library)
        return updated
    }

    private func downloadProfile(url: URL, sessionOverride: URLSession? = nil) async throws -> Data {
        var request = URLRequest(url: url)
        request.timeoutInterval = 30
        request.setValue("Chumen/1.0", forHTTPHeaderField: "User-Agent")
        let session = sessionOverride ?? self.session
        let (data, response) = try await session.data(for: request)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw ChumenError.httpStatus(http.statusCode, String(data: data, encoding: .utf8) ?? "")
        }
        guard !data.isEmpty else {
            throw ChumenError.commandFailed("Downloaded profile is empty.")
        }
        return data
    }

    private func existingProfileFingerprints(in library: ProfileLibrary) -> Set<String> {
        Set(library.profiles.compactMap { profile in
            if let fingerprint = profile.sourceFingerprint {
                return fingerprint
            }
            guard let data = try? Data(contentsOf: URL(fileURLWithPath: profile.filePath)) else {
                return nil
            }
            return Self.contentFingerprint(data)
        })
    }

    private func uniqueName(_ raw: String, existingNames: Set<String>) -> String {
        let base = cleanName(raw, fallback: "External Profile")
        guard existingNames.contains(base) else { return base }
        var index = 2
        while existingNames.contains("\(base) \(index)") {
            index += 1
        }
        return "\(base) \(index)"
    }

    private func normalizedRemoteURL(_ raw: String?) throws -> String? {
        guard let raw else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        guard let url = URL(string: trimmed), url.scheme != nil, url.host != nil else {
            throw ChumenError.commandFailed("Invalid subscription URL.")
        }
        return trimmed
    }

    private static func contentFingerprint(_ data: Data) -> String {
        var hash: UInt64 = 0xcbf29ce484222325
        for byte in data {
            hash ^= UInt64(byte)
            hash = hash &* 0x100000001b3
        }
        return String(format: "%016llx", hash)
    }

    private func cleanName(_ raw: String, fallback: String) -> String {
        let name = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? fallback : name
    }
}
