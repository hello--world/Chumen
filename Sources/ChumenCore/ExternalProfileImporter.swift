import Foundation

public struct ExternalProfileSource: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var name: String
    public var rootPath: String

    public init(id: String, name: String, rootPath: String) {
        self.id = id
        self.name = name
        self.rootPath = rootPath
    }
}

public struct ExternalProfileCandidate: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var sourceID: String
    public var sourceName: String
    public var name: String
    public var filePath: String
    public var rootPath: String
    public var remoteURL: String?
    public var fileSize: Int64
    public var modifiedAt: Date?

    public init(
        sourceID: String,
        sourceName: String,
        name: String,
        filePath: String,
        rootPath: String,
        remoteURL: String? = nil,
        fileSize: Int64 = 0,
        modifiedAt: Date? = nil
    ) {
        self.id = "\(sourceID)|\(filePath)"
        self.sourceID = sourceID
        self.sourceName = sourceName
        self.name = name
        self.filePath = filePath
        self.rootPath = rootPath
        self.remoteURL = remoteURL
        self.fileSize = fileSize
        self.modifiedAt = modifiedAt
    }
}

public struct ExternalProfileImportSkipped: Codable, Equatable, Sendable {
    public var candidate: ExternalProfileCandidate
    public var reason: String
}

public struct ExternalProfileImportFailure: Codable, Equatable, Sendable {
    public var candidate: ExternalProfileCandidate
    public var message: String
}

public struct ExternalProfileImportSummary: Codable, Equatable, Sendable {
    public var imported: [ProxyProfile]
    public var skipped: [ExternalProfileImportSkipped]
    public var failed: [ExternalProfileImportFailure]

    public init(
        imported: [ProxyProfile] = [],
        skipped: [ExternalProfileImportSkipped] = [],
        failed: [ExternalProfileImportFailure] = []
    ) {
        self.imported = imported
        self.skipped = skipped
        self.failed = failed
    }
}

public enum ExternalProfileImporter {
    public static func defaultSources(homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser) -> [ExternalProfileSource] {
        let appSupport = homeDirectory.appendingPathComponent("Library/Application Support", isDirectory: true)
        let config = homeDirectory.appendingPathComponent(".config", isDirectory: true)
        let sourceDefinitions: [(String, String, URL)] = [
            ("clash-verge-rev", "Clash Verge Rev", appSupport.appendingPathComponent("io.github.clash-verge-rev.clash-verge-rev", isDirectory: true)),
            ("clash-verge-rev-dev", "Clash Verge Rev Dev", appSupport.appendingPathComponent("io.github.clash-verge-rev.clash-verge-rev.dev", isDirectory: true)),
            ("clash-verge", "Clash Verge", appSupport.appendingPathComponent("clash-verge", isDirectory: true)),
            ("clashx-meta", "ClashX Meta", appSupport.appendingPathComponent("com.metacubex.ClashX.meta", isDirectory: true)),
            ("clashx", "ClashX", appSupport.appendingPathComponent("ClashX", isDirectory: true)),
            ("clashx-pro", "ClashX Pro", appSupport.appendingPathComponent("ClashX Pro", isDirectory: true)),
            ("clashx-west2", "ClashX", appSupport.appendingPathComponent("com.west2online.ClashX", isDirectory: true)),
            ("clashx-pro-west2", "ClashX Pro", appSupport.appendingPathComponent("com.west2online.ClashXPro", isDirectory: true)),
            ("mihomo-party", "Mihomo Party", appSupport.appendingPathComponent("mihomo-party", isDirectory: true)),
            ("clash-nyanpasu", "Clash Nyanpasu", appSupport.appendingPathComponent("clash-nyanpasu", isDirectory: true)),
            ("nyanpasu", "Clash Nyanpasu", appSupport.appendingPathComponent("Clash Nyanpasu", isDirectory: true)),
            ("stash", "Stash", appSupport.appendingPathComponent("Stash", isDirectory: true)),
            ("stash-bundle", "Stash", appSupport.appendingPathComponent("com.stash.Stash", isDirectory: true)),
            ("config-clash", "~/.config/clash", config.appendingPathComponent("clash", isDirectory: true)),
            ("config-clash-meta", "~/.config/clash.meta", config.appendingPathComponent("clash.meta", isDirectory: true)),
            ("config-mihomo", "~/.config/mihomo", config.appendingPathComponent("mihomo", isDirectory: true)),
            ("config-mihomo-party", "~/.config/mihomo-party", config.appendingPathComponent("mihomo-party", isDirectory: true))
        ]

        var seenPaths = Set<String>()
        return sourceDefinitions.compactMap { id, name, url in
            let path = url.standardizedFileURL.path
            guard seenPaths.insert(path).inserted else { return nil }
            return ExternalProfileSource(id: id, name: name, rootPath: path)
        }
    }

    public static func discover(
        sources: [ExternalProfileSource] = defaultSources(),
        fileManager: FileManager = .default
    ) -> [ExternalProfileCandidate] {
        var candidates: [ExternalProfileCandidate] = []
        var seenPaths = Set<String>()

        for source in sources {
            let rootURL = URL(fileURLWithPath: source.rootPath, isDirectory: true)
            var isDirectory: ObjCBool = false
            guard fileManager.fileExists(atPath: rootURL.path, isDirectory: &isDirectory), isDirectory.boolValue else {
                continue
            }

            let metadataByFile = profileMetadata(rootURL: rootURL, fileManager: fileManager)
            let baseDepth = rootURL.standardizedFileURL.pathComponents.count
            guard let enumerator = fileManager.enumerator(
                at: rootURL,
                includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey, .contentModificationDateKey],
                options: [.skipsHiddenFiles, .skipsPackageDescendants]
            ) else {
                continue
            }

            for case let fileURL as URL in enumerator {
                let values = try? fileURL.resourceValues(forKeys: [.isDirectoryKey, .fileSizeKey, .contentModificationDateKey])
                if values?.isDirectory == true {
                    if shouldSkipDirectory(fileURL) || fileURL.standardizedFileURL.pathComponents.count - baseDepth >= 5 {
                        enumerator.skipDescendants()
                    }
                    continue
                }

                guard isYAML(fileURL), !shouldSkipFile(fileURL) else { continue }
                let standardizedPath = fileURL.standardizedFileURL.path
                guard seenPaths.insert(standardizedPath).inserted else { continue }
                guard isLikelyRuntimeConfig(fileURL, fileManager: fileManager) else { continue }

                let metadata = metadataByFile[standardizedPath] ?? metadataByFile[fileURL.lastPathComponent]
                let fallbackName = fileURL.deletingPathExtension().lastPathComponent
                candidates.append(ExternalProfileCandidate(
                    sourceID: source.id,
                    sourceName: source.name,
                    name: cleanName(metadata?.name ?? fallbackName, fallback: fallbackName),
                    filePath: standardizedPath,
                    rootPath: rootURL.standardizedFileURL.path,
                    remoteURL: normalizedURL(metadata?.remoteURL),
                    fileSize: Int64(values?.fileSize ?? 0),
                    modifiedAt: values?.contentModificationDate
                ))
            }
        }

        return candidates.sorted {
            if $0.sourceName != $1.sourceName {
                return $0.sourceName.localizedStandardCompare($1.sourceName) == .orderedAscending
            }
            if $0.name != $1.name {
                return $0.name.localizedStandardCompare($1.name) == .orderedAscending
            }
            return $0.filePath.localizedStandardCompare($1.filePath) == .orderedAscending
        }
    }

    static func isLikelyRuntimeConfig(_ fileURL: URL, fileManager: FileManager = .default) -> Bool {
        guard let handle = try? FileHandle(forReadingFrom: fileURL) else { return false }
        defer { try? handle.close() }

        let data = (try? handle.read(upToCount: 512 * 1024)) ?? Data()
        guard !data.isEmpty, let text = String(data: data, encoding: .utf8) else { return false }

        var score = 0
        var metadataScore = 0
        for line in text.split(whereSeparator: \.isNewline).prefix(2_000) {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, !trimmed.hasPrefix("#") else { continue }
            guard let colon = trimmed.firstIndex(of: ":") else { continue }
            let key = String(trimmed[..<colon]).trimmingCharacters(in: CharacterSet(charactersIn: " \"'"))
            switch key {
            case "proxies", "proxy-providers":
                score += 4
            case "proxy-groups":
                score += 3
            case "rules", "rule-providers":
                score += 2
            case "mixed-port", "port", "socks-port", "redir-port", "tproxy-port", "listeners":
                score += 2
            case "tun", "dns", "hosts", "mode", "allow-lan", "external-controller":
                score += 1
            case "items", "current", "uid", "type", "file":
                metadataScore += 1
            default:
                break
            }
            if score >= 3 {
                return true
            }
        }

        return score >= 3 && metadataScore < 3
    }

    private struct ProfileMetadata {
        var name: String?
        var remoteURL: String?
    }

    private static func profileMetadata(rootURL: URL, fileManager: FileManager) -> [String: ProfileMetadata] {
        var metadataByFile: [String: ProfileMetadata] = [:]
        for metadataName in ["profiles.yaml", "profile.yaml"] {
            let metadataURL = rootURL.appendingPathComponent(metadataName)
            guard fileManager.fileExists(atPath: metadataURL.path),
                  let text = try? String(contentsOf: metadataURL, encoding: .utf8) else {
                continue
            }

            for item in parseProfileItems(text) {
                if let type = item["type"]?.lowercased(), ["merge", "script", "rules", "proxies", "groups"].contains(type) {
                    continue
                }
                let name = cleanName(item["name"] ?? item["uid"] ?? item["id"] ?? "", fallback: "")
                let metadata = ProfileMetadata(
                    name: name.isEmpty ? nil : name,
                    remoteURL: normalizedURL(item["url"])
                )
                guard metadata.name != nil || metadata.remoteURL != nil else { continue }

                let fileCandidates = metadataFileCandidates(item: item)
                for file in fileCandidates {
                    metadataByFile[file] = metadata
                    metadataByFile[rootURL.appendingPathComponent(file).standardizedFileURL.path] = metadata
                    metadataByFile[rootURL.appendingPathComponent("profiles", isDirectory: true).appendingPathComponent(file).standardizedFileURL.path] = metadata
                }
            }
        }
        return metadataByFile
    }

    private static func parseProfileItems(_ text: String) -> [[String: String]] {
        var items: [[String: String]] = []
        var current: [String: String] = [:]

        func commit() {
            if !current.isEmpty {
                items.append(current)
                current = [:]
            }
        }

        for rawLine in text.split(whereSeparator: \.isNewline) {
            var line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.isEmpty, !line.hasPrefix("#") else { continue }
            if line.hasPrefix("- ") {
                commit()
                line.removeFirst(2)
            }
            guard let colon = line.firstIndex(of: ":") else { continue }
            let key = String(line[..<colon]).trimmingCharacters(in: CharacterSet(charactersIn: " \"'"))
            let value = cleanMetadataValue(String(line[line.index(after: colon)...]))
            if ["uid", "id", "name", "file", "type", "url"].contains(key), !value.isEmpty {
                current[key] = value
            }
        }
        commit()
        return items
    }

    private static func metadataFileCandidates(item: [String: String]) -> [String] {
        var files: [String] = []
        if let file = item["file"], isYAMLFilename(file) {
            files.append(file)
        }
        if let id = item["id"], !id.isEmpty {
            files.append("\(id).yaml")
        }
        if let uid = item["uid"], !uid.isEmpty {
            files.append("\(uid).yaml")
        }
        return Array(Set(files))
    }

    private static func cleanMetadataValue(_ raw: String) -> String {
        let withoutComment = stripYAMLComment(raw)
        let trimmed = withoutComment.trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
        if trimmed.lowercased() == "null" || trimmed == "~" {
            return ""
        }
        return trimmed
    }

    private static func stripYAMLComment(_ raw: String) -> String {
        var previous: Character?
        for index in raw.indices {
            if raw[index] == "#", previous?.isWhitespace != false {
                return String(raw[..<index])
            }
            previous = raw[index]
        }
        return raw
    }

    private static func shouldSkipDirectory(_ url: URL) -> Bool {
        let name = url.lastPathComponent.lowercased()
        return [
            "logs",
            "log",
            "cache",
            "caches",
            "icons",
            "ruleset",
            "rule-set",
            "substore",
            "sidecar",
            "service",
            "ipc",
            "web",
            "node_modules",
            "clash-verge-rev-backup",
            "clash-verge-rev-backup-dev"
        ].contains(name)
    }

    private static func shouldSkipFile(_ url: URL) -> Bool {
        let name = url.lastPathComponent.lowercased()
        return [
            "profiles.yaml",
            "verge.yaml",
            "dns_config.yaml",
            "override.yaml",
            "window_state.yaml",
            ".window-state.yaml",
            "clash-verge-check.yaml",
            "clash-verge.yaml"
        ].contains(name)
    }

    private static func isYAML(_ url: URL) -> Bool {
        isYAMLFilename(url.lastPathComponent)
    }

    private static func isYAMLFilename(_ filename: String) -> Bool {
        let lowercased = filename.lowercased()
        return lowercased.hasSuffix(".yaml") || lowercased.hasSuffix(".yml")
    }

    private static func cleanName(_ raw: String, fallback: String) -> String {
        let name = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? fallback : name
    }

    private static func normalizedURL(_ raw: String?) -> String? {
        guard let raw else { return nil }
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty,
              let url = URL(string: value),
              let scheme = url.scheme?.lowercased(),
              ["http", "https"].contains(scheme) else {
            return nil
        }
        return value
    }
}
