import Foundation

public enum ChumenConfigurationBuilder {
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
    private static let sectionPatchKeys: Set<String> = ["rules", "proxies", "proxy-groups"]
    private static let sectionPatchOperationKeys: Set<String> = ["prepend", "append", "delete"]

    private struct YAMLTopLevelBlock {
        let key: String
        let text: String
        let body: String
    }

    private struct YAMLSequencePatch {
        let prepend: String
        let append: String
        let delete: String
    }

    private struct YAMLListItem {
        let raw: String
        let scalar: String
        let name: String?
    }

    @discardableResult
    public static func writeRuntimeConfig(
        settings: ChumenRuntimeSettings,
        paths: ChumenPaths,
        profileAppendixYAML: String = "",
        protectionKeyStore: ChumenConfigProtectionKeyStore? = nil,
        ageProtection: MihomoAgeRuntimeProtecting? = nil
    ) throws -> URL {
        try paths.ensureDirectories()
        let keyStore = protectionKeyStore ?? ChumenConfigProtectionKeyStore(ageIdentityURL: paths.ageIdentityURL)
        let protection = ChumenConfigProtection(
            enabled: settings.protectConfigFiles,
            keyStore: keyStore,
            corePath: settings.corePath
        )

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

        // Runtime config must be encrypted in a format mihomo itself understands. Using mihomo's
        // built-in age command keeps Chumen out of the parser/decryptor path and removes the old
        // plaintext temp-file bridge: the stable -f path is now the encrypted file mihomo consumes.
        let encryptedRuntime: Data
        if let ageProtection {
            encryptedRuntime = try ageProtection.encryptRuntimeConfig(Data(yaml.utf8), corePath: settings.corePath)
        } else {
            // Production runtime encryption uses the same persistent/unlocked age key pair as
            // config-at-rest protection. The same secret is later passed through CLASH_AGE_SECRET_KEY,
            // so mihomo receives a matching identity for the recipient block in this file.
            let keyPair = try keyStore.loadOrCreateAgeKeyPair(corePath: settings.corePath)
            encryptedRuntime = try MihomoAgeRuntimeProtection.encrypt(
                Data(yaml.utf8),
                publicKey: keyPair.publicKey,
                corePath: settings.corePath
            )
        }
        try ChumenConfigProtection.writePlainData(encryptedRuntime, to: paths.runtimeConfigURL)
        try cleanupRuntimePlaintextFiles(paths: paths)
        return paths.runtimeConfigURL
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

    public static func replaceTopLevelBlock(_ key: String, in yaml: String, with editedBlock: String) -> String {
        let stripped = removeTopLevelKeys([key], from: yaml)
        let normalizedBlock = normalizedTopLevelBlock(key, editedBlock)
        return [stripped, normalizedBlock]
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .joined(separator: "\n\n")
    }

    public static func defaultSectionPatchBlock(for key: String) -> String {
        """
        \(key):
          prepend: []
          append: []
          delete: []
        """
    }

    public static func isSectionPatchBlock(_ block: String, key: String) -> Bool {
        topLevelBlocksOrdered(in: block).contains { item in
            item.key == key && sequencePatch(from: item.body) != nil
        }
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
            lines.insert(
                "external-controller-unix: \(yamlQuoted(socketPath))",
                after: "external-controller: \(settings.externalControllerHost):\(settings.externalControllerPort)"
            )
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

    private static func normalizedTopLevelBlock(_ key: String, _ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "\(key): []" }

        if let firstLine = trimmed.components(separatedBy: .newlines).first,
           topLevelKey(in: firstLine) == key {
            return trimmed
        }

        let nested = trimmed.components(separatedBy: .newlines)
            .map { $0.isEmpty ? "" : "  \($0)" }
            .joined(separator: "\n")
        return "\(key):\n\(nested)"
    }

    private static func applyingAppendixYAML(_ appendixYAML: String, to yaml: String) -> String {
        let appendix = normalizedAppendixYAML(appendixYAML)
        guard !appendix.isEmpty else {
            return yaml.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        let blocks = topLevelBlocksOrdered(in: appendix)
        guard !blocks.isEmpty else {
            return [yaml, appendix]
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .joined(separator: "\n\n")
        }

        var overwrittenKeys: Set<String> = []
        var appendixBlocks: [String] = []
        for block in blocks {
            overwrittenKeys.insert(block.key)
            if let merged = mergedSectionPatch(block, into: yaml) {
                appendixBlocks.append(merged)
            } else {
                appendixBlocks.append(block.text)
            }
        }

        let stripped = overwrittenKeys.isEmpty ? yaml : removeTopLevelKeys(overwrittenKeys, from: yaml)
        return ([stripped] + appendixBlocks)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n\n")
    }

    private static func topLevelKeys(in yaml: String) -> Set<String> {
        Set(topLevelBlocksOrdered(in: yaml).map(\.key))
    }

    private static func topLevelBlocksOrdered(in yaml: String) -> [YAMLTopLevelBlock] {
        let lines = yaml.components(separatedBy: .newlines)
        var blocks: [YAMLTopLevelBlock] = []
        var currentKey: String?
        var currentLines: [String] = []

        func flush() {
            guard let currentKey else { return }
            let text = currentLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { return }
            blocks.append(YAMLTopLevelBlock(
                key: currentKey,
                text: text,
                body: topLevelBlockBody(currentLines)
            ))
        }

        for line in lines {
            if let key = topLevelKey(in: line) {
                flush()
                currentKey = key
                currentLines = [line]
            } else if currentKey != nil {
                currentLines.append(line)
            }
        }
        flush()

        return blocks
    }

    private static func topLevelBlockBody(_ lines: [String]) -> String {
        guard let first = lines.first else { return "" }
        let inline = topLevelValue(in: first)
        guard inline.isEmpty else { return inline }
        return unindented(lines.dropFirst()).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func mergedSectionPatch(_ block: YAMLTopLevelBlock, into yaml: String) -> String? {
        guard sectionPatchKeys.contains(block.key),
              let patch = sequencePatch(from: block.body) else {
            return nil
        }

        let originalBody = topLevelBlocksOrdered(in: yaml)
            .last { $0.key == block.key }?
            .body ?? ""
        let deletes = deletionTokens(in: patch.delete, namedItems: block.key != "rules")
        let originalItems = yamlListItems(in: originalBody).filter { item in
            if let name = item.name, deletes.contains(name) {
                return false
            }
            return !deletes.contains(item.scalar)
        }
        let merged = yamlListItems(in: patch.prepend)
            + originalItems
            + yamlListItems(in: patch.append)
        return renderTopLevelList(key: block.key, items: merged)
    }

    private static func sequencePatch(from body: String) -> YAMLSequencePatch? {
        var currentOperation: String?
        var operationLines: [String: [String]] = [:]
        var foundOperation = false

        for line in body.components(separatedBy: .newlines) {
            if let key = topLevelKey(in: line), sectionPatchOperationKeys.contains(key) {
                foundOperation = true
                currentOperation = key
                let inlineValue = topLevelValue(in: line)
                if inlineValue.isEmpty || inlineValue == "[]" {
                    operationLines[key] = operationLines[key] ?? []
                } else {
                    operationLines[key, default: []].append(contentsOf: inlineListItems(inlineValue))
                }
                continue
            }

            if let currentOperation {
                operationLines[currentOperation, default: []].append(line)
            }
        }

        guard foundOperation else { return nil }
        return YAMLSequencePatch(
            prepend: normalizedPatchBucket(operationLines["prepend"] ?? []),
            append: normalizedPatchBucket(operationLines["append"] ?? []),
            delete: normalizedPatchBucket(operationLines["delete"] ?? [])
        )
    }

    private static func normalizedPatchBucket(_ lines: [String]) -> String {
        let text = unindented(lines).trimmingCharacters(in: .whitespacesAndNewlines)
        return text == "[]" ? "" : text
    }

    private static func yamlListItems(in body: String) -> [YAMLListItem] {
        let lines = body.components(separatedBy: .newlines)
        var items: [YAMLListItem] = []
        var current: [String] = []

        func flush() {
            let raw = current.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            guard !raw.isEmpty else { return }
            let scalar = stripListMarker(raw.components(separatedBy: .newlines).first ?? "")
            items.append(YAMLListItem(raw: raw, scalar: scalar, name: yamlItemName(in: raw)))
        }

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if indentation(of: line) == 0, trimmed.hasPrefix("-") {
                flush()
                current = [line]
            } else if !current.isEmpty {
                current.append(line)
            }
        }
        flush()

        return items
    }

    private static func deletionTokens(in body: String, namedItems: Bool) -> Set<String> {
        var tokens = Set<String>()
        for item in yamlListItems(in: body) {
            if namedItems, let name = item.name {
                tokens.insert(name)
            }
            if !item.scalar.isEmpty {
                tokens.insert(item.scalar)
            }
        }
        return tokens
    }

    private static func renderTopLevelList(key: String, items: [YAMLListItem]) -> String {
        guard !items.isEmpty else { return "\(key): []" }
        let body = items.map(\.raw).joined(separator: "\n")
        return normalizedTopLevelBlock(key, body)
    }

    private static func yamlItemName(in raw: String) -> String? {
        let lines = raw.components(separatedBy: .newlines)
        guard let first = lines.first else { return nil }
        let firstValue = stripListMarker(first)
        if firstValue.hasPrefix("name:") {
            return unquotedYAMLScalar(String(firstValue.dropFirst("name:".count)))
        }
        if firstValue.hasPrefix("{") {
            return parseInlineYAMLMap(firstValue)["name"]
        }
        for line in lines.dropFirst() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("name:") {
                return unquotedYAMLScalar(String(trimmed.dropFirst("name:".count)))
            }
        }
        return nil
    }

    private static func parseInlineYAMLMap(_ value: String) -> [String: String] {
        let trimmed = value.trimmingCharacters(in: CharacterSet(charactersIn: "{} "))
        var result: [String: String] = [:]
        for pair in trimmed.split(separator: ",") {
            guard let colon = pair.firstIndex(of: ":") else { continue }
            let key = String(pair[..<colon]).trimmingCharacters(in: .whitespacesAndNewlines)
            let value = unquotedYAMLScalar(String(pair[pair.index(after: colon)...]))
            if !key.isEmpty {
                result[key] = value
            }
        }
        return result
    }

    private static func stripListMarker(_ line: String) -> String {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard trimmed.hasPrefix("-") else { return trimmed }
        return String(trimmed.dropFirst()).trimmingCharacters(in: .whitespaces)
    }

    private static func inlineListItems(_ value: String) -> [String] {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("["), trimmed.hasSuffix("]") else {
            return ["- \(trimmed)"]
        }
        let inner = trimmed.dropFirst().dropLast()
        return inner
            .split(separator: ",")
            .map { unquotedYAMLScalar(String($0)) }
            .filter { !$0.isEmpty }
            .map { "- \($0)" }
    }

    private static func unquotedYAMLScalar(_ value: String) -> String {
        value.trimmingCharacters(in: CharacterSet(charactersIn: " \t\n\r\"'"))
    }

    private static func unindented<S: Sequence>(_ lines: S) -> String where S.Element == String {
        let lines = Array(lines)
        let indents = lines
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .map(indentation)
            .filter { $0 > 0 }
        guard let commonIndent = indents.min() else {
            return lines.joined(separator: "\n")
        }
        return lines.map { removeLeadingSpaces(commonIndent, from: $0) }.joined(separator: "\n")
    }

    private static func removeLeadingSpaces(_ count: Int, from line: String) -> String {
        var index = line.startIndex
        var removed = 0
        while removed < count, index < line.endIndex, line[index] == " " {
            index = line.index(after: index)
            removed += 1
        }
        return String(line[index...])
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
