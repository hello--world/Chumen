import Foundation

public enum ChumenConfigurationBuilder {
    // mihomo can only consume plaintext YAML. The canonical runtime file is encrypted with this
    // process-local session key, while the temporary plaintext file returned by writeRuntimeConfig
    // lives under the user's temp directory, is chmod 0600, and is deleted right after reload or
    // shortly after process start. This keeps persistent disk state protected without pretending
    // the core can read encrypted config directly.
    private static let runtimeSessionKey: Data = {
        if let key = try? ChumenConfigProtectionKeyStore.randomBytes(count: 32) {
            return key
        }
        return Data(Data((UUID().uuidString + UUID().uuidString).utf8).prefix(32))
    }()

    // 这些顶层键由 GUI/CLI 设置统一接管，生成运行配置时必须覆盖用户 profile 里的同名值。
    private static let alwaysOverwrittenTopLevelKeys: Set<String> = [
        "mixed-port",
        "socks-port",
        "port",
        "redir-port",
        "tproxy-port",
        "external-controller",
        "external-controller-unix",
        "external-controller-cors",
        "external-ui",
        "external-ui-name",
        "external-ui-url",
        "secret",
        "allow-lan",
        "mode",
        "log-level",
        "ipv6",
        "unified-delay",
        "tun"
    ]

    @discardableResult
    public static func writeRuntimeConfig(
        settings: ChumenRuntimeSettings,
        paths: ChumenPaths,
        profileAppendixYAML: String = ""
    ) throws -> URL {
        try paths.ensureDirectories()
        let protection = ChumenConfigProtection(enabled: settings.protectConfigFiles)

        let profileYAML: String?
        if let profilePath = settings.profilePath, !profilePath.isEmpty {
            profileYAML = try protection.readText(at: URL(fileURLWithPath: profilePath))
        } else {
            profileYAML = nil
        }

        let yaml = runtimeYAML(
            profileYAML: profileYAML,
            settings: settings,
            socketPath: paths.externalControllerSocketURL.path,
            profileAppendixYAML: profileAppendixYAML
        )
        guard settings.protectConfigFiles else {
            try protection.writeText(yaml, to: paths.runtimeConfigURL)
            return paths.runtimeConfigURL
        }

        // Store the reproducible runtime YAML encrypted at the stable path for inspection/migration,
        // then hand the caller a short-lived plaintext URL for mihomo -f / controller reload.
        let protectedRuntime = try ChumenConfigProtection.encrypt(Data(yaml.utf8), key: runtimeSessionKey)
        try ChumenConfigProtection.writePlainData(protectedRuntime, to: paths.runtimeConfigURL)
        try cleanupRuntimePlaintextFiles(paths: paths)
        let runtimeURL = try runtimePlaintextURL(paths: paths)
        try ChumenConfigProtection.writePlainData(Data(yaml.utf8), to: runtimeURL)
        return runtimeURL
    }

    public static func cleanupRuntimePlaintextFiles(paths: ChumenPaths) throws {
        // 清理同时覆盖当前 temp 会话目录和旧版 Application Support/runtime 目录，
        // 这样升级后一旦重新生成配置，就能补偿清掉之前已经落盘的明文文件。
        for directory in runtimePlaintextCleanupDirectories(paths: paths) {
            try cleanupRuntimePlaintextFiles(in: directory)
            try? FileManager.default.removeItem(at: directory)
        }
    }

    public static func cleanupRuntimePlaintextFile(_ url: URL, paths: ChumenPaths) {
        // 只删除 Chumen 自己生成的 runtime 明文，避免误删用户传给 CLI reload-config 的文件。
        let parentDirectory = url.deletingLastPathComponent()
        let isCurrentRandomTempFile = parentDirectory.lastPathComponent.hasPrefix("chumen-runtime-session-")
            && isDescendant(parentDirectory, of: paths.runtimePlaintextRootDirectoryURL)
        let isLegacyAppSupportFile = url.lastPathComponent.hasPrefix("chumen-runtime-")
            && isDescendant(url, of: paths.appHome.appendingPathComponent("runtime", isDirectory: true))
        guard isCurrentRandomTempFile || isLegacyAppSupportFile else {
            return
        }
        try? FileManager.default.removeItem(at: url)
        if isCurrentRandomTempFile {
            try? FileManager.default.removeItem(at: parentDirectory)
        }
    }

    private static func cleanupRuntimePlaintextFiles(in directory: URL) throws {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: directory.path) else { return }
        let files = try fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil
        )
        for file in files where file.lastPathComponent.hasPrefix("chumen-runtime-") {
            try? fileManager.removeItem(at: file)
        }
    }

    private static func runtimePlaintextCleanupDirectories(paths: ChumenPaths) -> [URL] {
        var directories = [
            paths.appHome.appendingPathComponent("runtime", isDirectory: true)
        ]
        if let sessionDirectories = try? FileManager.default.contentsOfDirectory(
            at: paths.runtimePlaintextRootDirectoryURL,
            includingPropertiesForKeys: [.isDirectoryKey]
        ) {
            directories.append(contentsOf: sessionDirectories.filter { url in
                (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
                    && url.lastPathComponent.hasPrefix("chumen-runtime-session-")
            })
        }
        var seen = Set<String>()
        return directories.filter { seen.insert($0.standardizedFileURL.path).inserted }
    }

    private static func isDescendant(_ url: URL, of directory: URL) -> Bool {
        let directoryPath = directory.standardizedFileURL.path
        let filePath = url.standardizedFileURL.path
        return filePath == directoryPath || filePath.hasPrefix(directoryPath + "/")
    }

    private static func runtimePlaintextURL(paths: ChumenPaths) throws -> URL {
        let directory = paths.makeRuntimePlaintextSessionDirectoryURL()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try? FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: directory.path)
        return directory.appendingPathComponent("config.yaml")
    }

    public static func runtimeYAML(
        profileYAML: String?,
        settings: ChumenRuntimeSettings,
        socketPath: String?,
        profileAppendixYAML: String = ""
    ) -> String {
        let base = normalizedBaseYAML(profileYAML)
        let globallyExtended = applyingAppendixYAML(settings.configAppendixYAML, to: base)
        let profileExtended = applyingAppendixYAML(profileAppendixYAML, to: globallyExtended)
        // 保留订阅和扩展中的代理、规则和 provider，只移除 Chumen 明确负责的运行时键。
        let stripped = removeTopLevelKeys(overwrittenTopLevelKeys(settings: settings), from: profileExtended)
        let overrides = topLevelOverrides(settings: settings, socketPath: socketPath)

        if stripped.isEmpty {
            return overrides
        }

        return [stripped, overrides].filter { !$0.isEmpty }.joined(separator: "\n\n")
    }

    private static func overwrittenTopLevelKeys(settings: ChumenRuntimeSettings) -> Set<String> {
        var keys = alwaysOverwrittenTopLevelKeys
        if settings.enableDNS || settings.enableTun {
            keys.insert("dns")
        }
        if !settings.hostsYAML.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            keys.insert("hosts")
        }
        return keys
    }

    public static func removeTopLevelKeys(_ keys: Set<String>, from yaml: String) -> String {
        let lines = yaml.components(separatedBy: .newlines)
        var result: [String] = []
        var skippingBlock = false

        // 这里是一个受控的浅层 YAML 处理器，只处理顶层键，避免引入完整 YAML 依赖。
        for line in lines {
            if skippingBlock {
                if line.isEmpty {
                    continue
                }
                if indentation(of: line) > 0 {
                    continue
                }
                skippingBlock = false
            }

            if let key = topLevelKey(in: line), keys.contains(key) {
                if topLevelValue(in: line).isEmpty {
                    skippingBlock = true
                }
                continue
            }

            result.append(line)
        }

        return result.joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public static func topLevelKey(in line: String) -> String? {
        guard indentation(of: line) == 0 else { return nil }
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, !trimmed.hasPrefix("#"), !trimmed.hasPrefix("-") else { return nil }
        guard let colonIndex = trimmed.firstIndex(of: ":") else { return nil }
        let key = trimmed[..<colonIndex].trimmingCharacters(in: .whitespaces)
        return key.isEmpty ? nil : key
    }

    private static func normalizedBaseYAML(_ profileYAML: String?) -> String {
        guard let profileYAML, !profileYAML.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return defaultProfileYAML
        }
        return profileYAML.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func topLevelOverrides(settings: ChumenRuntimeSettings, socketPath: String?) -> String {
        var lines = [
            "# Generated by Chumen",
            "mixed-port: \(settings.mixedPort)",
            "allow-lan: \(yamlBool(settings.allowLAN))",
            "mode: \(settings.mode.rawValue)",
            "log-level: \(settings.logLevel.rawValue)",
            "external-controller: \(settings.externalControllerHost):\(settings.externalControllerPort)",
            "secret: \(yamlQuoted(settings.secret))",
            "ipv6: \(yamlBool(settings.ipv6))",
            "unified-delay: \(yamlBool(settings.unifiedDelay))"
        ]

        if settings.socksEnabled {
            lines.insert("socks-port: \(settings.socksPort)", after: "mixed-port: \(settings.mixedPort)")
        }
        if settings.httpEnabled {
            lines.insert("port: \(settings.httpPort)", after: "mixed-port: \(settings.mixedPort)")
        }
        if settings.redirEnabled {
            lines.append("redir-port: \(settings.redirPort)")
        }
        if settings.tproxyEnabled {
            lines.append("tproxy-port: \(settings.tproxyPort)")
        }

        if let socketPath, !socketPath.isEmpty {
            lines.insert("external-controller-unix: \(yamlQuoted(socketPath))", after: "external-controller: \(settings.externalControllerHost):\(settings.externalControllerPort)")
        }
        if !settings.externalUI.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            lines.append("external-ui: \(yamlQuoted(settings.externalUI))")
        }
        if !settings.externalUIName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            lines.append("external-ui-name: \(yamlQuoted(settings.externalUIName))")
        }
        if !settings.externalUIURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            lines.append("external-ui-url: \(yamlQuoted(settings.externalUIURL))")
        }
        if !settings.externalControllerCORSAllowOrigins.isEmpty {
            lines.append("external-controller-cors:")
            lines.append("  allow-private-network: \(yamlBool(settings.externalControllerCORSAllowPrivateNetwork))")
            lines.append("  allow-origins:")
            lines.append(contentsOf: settings.externalControllerCORSAllowOrigins.map { "    - \(yamlQuoted($0))" })
        }

        lines.append(contentsOf: tunLines(settings: settings))
        // TUN 依赖 DNS 劫持时，即使用户没有单独开启 DNS，也要生成 dns 段。
        if settings.enableDNS || settings.enableTun {
            lines.append(contentsOf: dnsLines(settings: settings))
        }
        if !settings.hostsYAML.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            lines.append("hosts:")
            lines.append(contentsOf: indentedBlock(settings.hostsYAML, spaces: 2))
        }

        return lines.joined(separator: "\n") + "\n"
    }

    private static var defaultProfileYAML: String {
        """
        proxies: []
        proxy-groups:
          - name: PROXY
            type: select
            proxies:
              - DIRECT
        rules:
          - MATCH,DIRECT
        tun:
          enable: false
          stack: gvisor
          auto-route: true
          strict-route: false
          auto-detect-interface: true
          dns-hijack:
            - any:53
        """
    }

    private static func tunLines(settings: ChumenRuntimeSettings) -> [String] {
        [
            "tun:",
            "  enable: \(yamlBool(settings.enableTun))",
            "  stack: \(settings.tunStack.rawValue)",
            "  device: \(yamlQuoted(settings.tunDevice.isEmpty ? "utun1024" : settings.tunDevice))",
            "  auto-route: \(yamlBool(settings.tunAutoRoute))",
            "  strict-route: \(yamlBool(settings.tunStrictRoute))",
            "  auto-detect-interface: \(yamlBool(settings.tunAutoDetectInterface))",
            "  mtu: \(settings.tunMTU)",
            "  dns-hijack:",
        ] + listLines(settings.tunDNSHijack.isEmpty ? ["any:53"] : settings.tunDNSHijack, indent: 4)
        + [
            "  route-exclude-address:"
        ] + listLines(settings.tunRouteExcludeAddress, indent: 4)
    }

    private static func dnsLines(settings: ChumenRuntimeSettings) -> [String] {
        let nameservers = settings.nameservers.isEmpty ? ChumenRuntimeSettings.defaultNameservers : settings.nameservers
        let defaultNameservers = settings.defaultNameservers.isEmpty ? ["system", "223.6.6.6", "8.8.8.8"] : settings.defaultNameservers
        var lines = [
            "dns:",
            "  enable: \(yamlBool(settings.enableDNS || settings.enableTun))",
            "  listen: \(yamlQuoted(settings.dnsListen))",
            "  enhanced-mode: \(settings.dnsMode.rawValue)",
            "  ipv6: \(yamlBool(settings.dnsIPv6))",
            "  fake-ip-range: \(yamlQuoted(settings.dnsFakeIPRange))",
            "  fake-ip-range6: \(yamlQuoted(settings.dnsFakeIPRange6))",
            "  fake-ip-filter-mode: \(settings.dnsFakeIPFilterMode.rawValue)",
            "  prefer-h3: \(yamlBool(settings.dnsPreferH3))",
            "  respect-rules: \(yamlBool(settings.dnsRespectRules))",
            "  use-hosts: \(yamlBool(settings.dnsUseHosts))",
            "  use-system-hosts: \(yamlBool(settings.dnsUseSystemHosts))",
            "  default-nameserver:"
        ]
        lines.append(contentsOf: listLines(defaultNameservers, indent: 4))
        lines.append("  nameserver:")
        lines.append(contentsOf: listLines(nameservers, indent: 4))
        lines.append("  fallback:")
        lines.append(contentsOf: listLines(settings.fallbackNameservers, indent: 4))
        lines.append("  proxy-server-nameserver:")
        lines.append(contentsOf: listLines(settings.proxyServerNameservers, indent: 4))
        lines.append("  direct-nameserver:")
        lines.append(contentsOf: listLines(settings.directNameservers, indent: 4))
        lines.append("  fake-ip-filter:")
        lines.append(contentsOf: listLines(settings.fakeIPFilters, indent: 4))
        lines.append("  fallback-filter:")
        lines.append("    geoip: \(yamlBool(settings.fallbackFilterGeoIP))")
        lines.append("    geoip-code: \(yamlQuoted(settings.fallbackFilterGeoIPCode))")
        lines.append("    ipcidr:")
        lines.append(contentsOf: listLines(settings.fallbackFilterIPCIDRs, indent: 6))
        lines.append("    domain:")
        lines.append(contentsOf: listLines(settings.fallbackFilterDomains, indent: 6))
        if !settings.nameserverPolicyYAML.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            lines.append("  nameserver-policy:")
            lines.append(contentsOf: indentedBlock(settings.nameserverPolicyYAML, spaces: 4))
        }
        return lines
    }

    private static func indentation(of line: String) -> Int {
        line.prefix { $0 == " " || $0 == "\t" }.count
    }

    private static func topLevelValue(in line: String) -> String {
        guard let colonIndex = line.firstIndex(of: ":") else { return "" }
        return String(line[line.index(after: colonIndex)...]).trimmingCharacters(in: .whitespaces)
    }

    private static func yamlQuoted(_ value: String) -> String {
        let escaped = value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        return "\"\(escaped)\""
    }

    private static func yamlBool(_ value: Bool) -> String {
        value ? "true" : "false"
    }

    private static func listLines(_ values: [String], indent: Int) -> [String] {
        guard !values.isEmpty else {
            return ["\(String(repeating: " ", count: indent))[]"]
        }
        return values.map { "\(String(repeating: " ", count: indent))- \(yamlQuoted($0))" }
    }

    private static func indentedBlock(_ yaml: String, spaces: Int) -> [String] {
        let prefix = String(repeating: " ", count: spaces)
        return yaml
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: .newlines)
            .map { line in line.isEmpty ? "" : prefix + line }
    }

    private static func normalizedAppendixYAML(_ yaml: String) -> String {
        yaml.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func applyingAppendixYAML(_ appendixYAML: String, to yaml: String) -> String {
        let appendix = normalizedAppendixYAML(appendixYAML)
        guard !appendix.isEmpty else {
            return yaml.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        let keys = topLevelKeys(in: appendix)
        let stripped = keys.isEmpty ? yaml : removeTopLevelKeys(keys, from: yaml)
        return [stripped, appendix]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n\n")
    }

    private static func topLevelKeys(in yaml: String) -> Set<String> {
        Set(yaml.components(separatedBy: .newlines).compactMap { topLevelKey(in: $0) })
    }
}

private extension Array where Element == String {
    mutating func insert(_ newElement: String, after existing: String) {
        guard let index = firstIndex(of: existing) else {
            append(newElement)
            return
        }
        insert(newElement, at: self.index(after: index))
    }
}
