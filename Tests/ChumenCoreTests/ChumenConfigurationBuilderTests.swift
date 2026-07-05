import XCTest
@testable import ChumenCore

final class ChumenConfigurationBuilderTests: XCTestCase {
    func testRuntimeYamlOverridesControllerAndPorts() {
        let profile = """
        mixed-port: 1
        port: 2
        dns:
          enable: false
        tun:
          enable: true
        external-controller: 0.0.0.0:1
        proxies: []
        rules:
          - MATCH,DIRECT
        """
        let settings = ChumenRuntimeSettings(
            mixedPort: ChumenRuntimeSettings.defaultMixedPort,
            socksPort: ChumenRuntimeSettings.defaultSocksPort,
            httpPort: ChumenRuntimeSettings.defaultHTTPPort,
            externalControllerPort: ChumenRuntimeSettings.defaultExternalControllerPort,
            secret: "secret",
            mode: .global
        )

        let yaml = ChumenConfigurationBuilder.runtimeYAML(
            profileYAML: profile,
            settings: settings,
            socketPath: "/tmp/chumen.sock"
        )

        XCTAssertFalse(yamlLines(yaml).contains("mixed-port: 1"))
        XCTAssertFalse(yamlLines(yaml).contains("port: 2"))
        XCTAssertTrue(yaml.contains("mixed-port: \(ChumenRuntimeSettings.defaultMixedPort)"))
        XCTAssertTrue(yaml.contains("socks-port: \(ChumenRuntimeSettings.defaultSocksPort)"))
        XCTAssertTrue(yaml.contains("port: \(ChumenRuntimeSettings.defaultHTTPPort)"))
        XCTAssertTrue(yaml.contains("external-controller: 127.0.0.1:\(ChumenRuntimeSettings.defaultExternalControllerPort)"))
        XCTAssertTrue(yaml.contains("external-controller-unix: \"/tmp/chumen.sock\""))
        XCTAssertTrue(yaml.contains("mode: global"))
        XCTAssertTrue(yaml.contains("tun:\n  enable: false"))
        XCTAssertTrue(yaml.contains("dns:\n  enable: false"))
    }

    func testRuntimeYamlPreservesProfileDNSAndHostsUnlessChumenOverridesThem() {
        let profile = """
        dns:
          enable: true
          nameserver:
            - 9.9.9.9
        hosts:
          router.local: 192.168.1.1
        proxies: []
        rules:
          - MATCH,DIRECT
        """

        let yaml = ChumenConfigurationBuilder.runtimeYAML(
            profileYAML: profile,
            settings: ChumenRuntimeSettings(enableTun: false, enableDNS: false, hostsYAML: ""),
            socketPath: nil
        )

        XCTAssertTrue(yaml.contains("dns:\n  enable: true\n  nameserver:\n    - 9.9.9.9"))
        XCTAssertTrue(yaml.contains("hosts:\n  router.local: 192.168.1.1"))
    }

    func testRuntimeYamlOverridesProfileDNSAndHostsWhenExplicitlyConfigured() {
        let profile = """
        dns:
          enable: true
          nameserver:
            - 9.9.9.9
        hosts:
          router.local: 192.168.1.1
        proxies: []
        rules:
          - MATCH,DIRECT
        """

        let yaml = ChumenConfigurationBuilder.runtimeYAML(
            profileYAML: profile,
            settings: ChumenRuntimeSettings(
                enableDNS: true,
                nameservers: ["1.1.1.1"],
                hostsYAML: "router.local: 192.168.2.1"
            ),
            socketPath: nil
        )

        XCTAssertFalse(yaml.contains("9.9.9.9"))
        XCTAssertFalse(yaml.contains("router.local: 192.168.1.1"))
        XCTAssertTrue(yaml.contains("    - \"1.1.1.1\""))
        XCTAssertTrue(yaml.contains("hosts:\n  router.local: 192.168.2.1"))
    }

    func testRuntimeYamlIncludesTunAndDNSSettings() {
        let settings = ChumenRuntimeSettings(
            allowLAN: true,
            ipv6: false,
            unifiedDelay: false,
            logLevel: .debug,
            enableTun: true,
            tunStack: .mixed,
            enableDNS: true,
            dnsListen: "127.0.0.1:1054",
            dnsMode: .redirHost,
            nameservers: ["https://example.com/dns-query", "1.1.1.1"]
        )

        let yaml = ChumenConfigurationBuilder.runtimeYAML(
            profileYAML: nil,
            settings: settings,
            socketPath: nil
        )

        XCTAssertTrue(yaml.contains("allow-lan: true"))
        XCTAssertTrue(yaml.contains("ipv6: false"))
        XCTAssertTrue(yaml.contains("unified-delay: false"))
        XCTAssertTrue(yaml.contains("log-level: debug"))
        XCTAssertTrue(yaml.contains("tun:\n  enable: true\n  stack: mixed"))
        XCTAssertTrue(yaml.contains("dns:\n  enable: true\n  listen: \"127.0.0.1:1054\"\n  enhanced-mode: redir-host"))
        XCTAssertTrue(yaml.contains("    - \"https://example.com/dns-query\""))
        XCTAssertTrue(yaml.contains("    - \"1.1.1.1\""))
    }

    func testRuntimeYamlIncludesAdvancedCoreSettings() {
        let settings = ChumenRuntimeSettings(
            redirEnabled: true,
            tproxyEnabled: true,
            externalUI: "/tmp/ui",
            externalUIName: "metacubexd",
            externalUIURL: "https://example.com/ui.zip",
            externalControllerCORSAllowOrigins: ["http://localhost:3000"],
            enableTun: true,
            tunDevice: "utun9",
            tunAutoRoute: false,
            tunStrictRoute: true,
            tunDNSHijack: ["any:53", "tcp://any:53"],
            tunRouteExcludeAddress: ["192.168.0.0/16"],
            enableDNS: true,
            dnsFakeIPFilterMode: .whitelist,
            dnsPreferH3: true,
            dnsRespectRules: true,
            defaultNameservers: ["system"],
            fallbackNameservers: ["tls://1.1.1.1"],
            fakeIPFilters: ["+.example.com"],
            nameserverPolicyYAML: "+.example.com:\n  - 1.1.1.1",
            hostsYAML: "router.local: 192.168.1.1",
            configAppendixYAML: "profile:\n  store-selected: true"
        )

        let yaml = ChumenConfigurationBuilder.runtimeYAML(
            profileYAML: "redir-port: 1\nexternal-ui: old\nhosts:\n  old: 1.1.1.1",
            settings: settings,
            socketPath: nil
        )

        XCTAssertFalse(yamlLines(yaml).contains("redir-port: 1"))
        XCTAssertFalse(yamlLines(yaml).contains("external-ui: old"))
        XCTAssertTrue(yaml.contains("redir-port: \(ChumenRuntimeSettings.defaultRedirPort)"))
        XCTAssertTrue(yaml.contains("tproxy-port: \(ChumenRuntimeSettings.defaultTProxyPort)"))
        XCTAssertTrue(yaml.contains("external-ui: \"/tmp/ui\""))
        XCTAssertTrue(yaml.contains("external-ui-name: \"metacubexd\""))
        XCTAssertTrue(yaml.contains("external-controller-cors:"))
        XCTAssertTrue(yaml.contains("  device: \"utun9\""))
        XCTAssertTrue(yaml.contains("  auto-route: false"))
        XCTAssertTrue(yaml.contains("  strict-route: true"))
        XCTAssertTrue(yaml.contains("  fake-ip-filter-mode: whitelist"))
        XCTAssertTrue(yaml.contains("  prefer-h3: true"))
        XCTAssertTrue(yaml.contains("  nameserver-policy:\n    +.example.com:\n      - 1.1.1.1"))
        XCTAssertTrue(yaml.contains("hosts:\n  router.local: 192.168.1.1"))
        XCTAssertTrue(yaml.contains("profile:\n  store-selected: true"))
    }

    func testRuntimeYamlAppliesGlobalAndProfileAppendixYAMLInOrder() {
        let profile = """
        proxies:
          - name: Base
            type: direct
        rules:
          - MATCH,DIRECT
        """
        let settings = ChumenRuntimeSettings(
            configAppendixYAML: """
            rules:
              - DOMAIN,global.example,DIRECT
            proxy-providers:
              remote:
                type: http
            """
        )

        let yaml = ChumenConfigurationBuilder.runtimeYAML(
            profileYAML: profile,
            settings: settings,
            socketPath: nil,
            profileAppendixYAML: """
            rules:
              - DOMAIN,profile.example,PROXY
            proxy-groups:
              - name: Auto
                type: select
                proxies:
                  - DIRECT
            """
        )

        XCTAssertTrue(yaml.contains("proxies:\n  - name: Base\n    type: direct"))
        XCTAssertTrue(yaml.contains("proxy-providers:\n  remote:\n    type: http"))
        XCTAssertTrue(yaml.contains("rules:\n  - DOMAIN,profile.example,PROXY"))
        XCTAssertTrue(yaml.contains("proxy-groups:\n  - name: Auto"))
        XCTAssertFalse(yaml.contains("MATCH,DIRECT"))
        XCTAssertFalse(yaml.contains("global.example"))
    }

    func testReplaceTopLevelBlockPreservesOtherProfileAppendixSections() {
        let appendix = """
        rules:
          - DOMAIN,old.example,DIRECT
        proxy-groups:
          - name: Auto
            type: select
            proxies:
              - DIRECT
        """

        let updated = ChumenConfigurationBuilder.replaceTopLevelBlock(
            "rules",
            in: appendix,
            with: """
            - DOMAIN,new.example,PROXY
            - MATCH,DIRECT
            """
        )

        XCTAssertTrue(updated.contains("rules:\n  - DOMAIN,new.example,PROXY\n  - MATCH,DIRECT"))
        XCTAssertTrue(updated.contains("proxy-groups:\n  - name: Auto"))
        XCTAssertFalse(updated.contains("old.example"))
    }

    func testRuntimeYamlAppliesRuleSectionPatch() {
        let profile = """
        rules:
          - DOMAIN,remove.example,DIRECT
          - DOMAIN,keep.example,DIRECT
        """
        let appendix = """
        rules:
          prepend:
            - DOMAIN,first.example,PROXY
          append:
            - MATCH,DIRECT
          delete:
            - DOMAIN,remove.example,DIRECT
        """

        let yaml = ChumenConfigurationBuilder.runtimeYAML(
            profileYAML: profile,
            settings: ChumenRuntimeSettings(),
            socketPath: nil,
            profileAppendixYAML: appendix
        )

        XCTAssertTrue(yaml.contains("""
        rules:
          - DOMAIN,first.example,PROXY
          - DOMAIN,keep.example,DIRECT
          - MATCH,DIRECT
        """))
        XCTAssertFalse(yaml.contains("remove.example"))
        XCTAssertFalse(yaml.contains("prepend:"))
        XCTAssertFalse(yaml.contains("append:"))
        XCTAssertFalse(yaml.contains("delete:"))
    }

    func testRuntimeYamlAppliesNamedSectionPatch() {
        let profile = """
        proxies:
          - name: Old
            type: direct
          - name: Keep
            type: direct
        proxy-groups:
          - name: OldGroup
            type: select
            proxies:
              - Old
          - name: KeepGroup
            type: select
            proxies:
              - Keep
        """
        let appendix = """
        proxies:
          prepend:
            - name: Extra
              type: direct
          append: []
          delete:
            - Old
        proxy-groups:
          prepend: []
          append:
            - name: ExtraGroup
              type: select
              proxies:
                - Extra
          delete:
            - OldGroup
        """

        let yaml = ChumenConfigurationBuilder.runtimeYAML(
            profileYAML: profile,
            settings: ChumenRuntimeSettings(),
            socketPath: nil,
            profileAppendixYAML: appendix
        )

        XCTAssertTrue(yaml.contains("proxies:\n  - name: Extra\n    type: direct\n  - name: Keep\n    type: direct"))
        XCTAssertTrue(yaml.contains("proxy-groups:\n  - name: KeepGroup"))
        XCTAssertTrue(yaml.contains("  - name: ExtraGroup"))
        XCTAssertFalse(yaml.contains("name: Old\n"))
        XCTAssertFalse(yaml.contains("name: OldGroup"))
        XCTAssertFalse(yaml.contains("prepend:"))
    }

    func testRemoveTopLevelBlock() {
        let yaml = """
        secret:
          nested: value
        proxies: []
        """

        let stripped = ChumenConfigurationBuilder.removeTopLevelKeys(["secret"], from: yaml)

        XCTAssertEqual(stripped, "proxies: []")
    }

    func testNetworkServiceParsingSkipsDisabledServices() {
        let output = """
        An asterisk (*) denotes that a network service is disabled.
        Wi-Fi
        *Thunderbolt Bridge
        USB 10/100/1000 LAN
        """

        XCTAssertEqual(SystemProxyManager.parseNetworkServices(output), ["Wi-Fi", "USB 10/100/1000 LAN"])
    }

    func testSystemProxyConfigParsingAndOwnership() {
        let output = """
        Enabled: Yes
        Server: localhost
        Port: 19881
        Authenticated Proxy Enabled: 0
        """

        let endpoint = SystemProxyManager.parseProxyConfig(output)
        XCTAssertTrue(endpoint.enabled)
        XCTAssertEqual(endpoint.server, "localhost")
        XCTAssertEqual(endpoint.port, 19881)
        XCTAssertTrue(endpoint.matches(host: "127.0.0.1", port: 19881))
        XCTAssertFalse(endpoint.matches(host: "127.0.0.1", port: 7897))
    }

    func testSystemProxyStateOnlyMatchesWhenAllEnabledEndpointsPointToChumen() {
        let state = SystemProxyState(
            service: "Wi-Fi",
            web: SystemProxyEndpoint(enabled: true, server: "127.0.0.1", port: 19881),
            secureWeb: SystemProxyEndpoint(enabled: true, server: "127.0.0.1", port: 19881),
            socks: SystemProxyEndpoint(enabled: true, server: "127.0.0.1", port: 7897)
        )

        XCTAssertTrue(state.isEnabled)
        XCTAssertFalse(state.matches(host: "127.0.0.1", port: 19881))
        XCTAssertEqual(state.summaryAddress, "127.0.0.1:19881, 127.0.0.1:7897")
    }

    func testSettingsStoreMigratesLegacyDefaultPorts() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let paths = ChumenPaths(appHome: directory)
        try paths.ensureDirectories()

        let legacyJSON = """
        {
          "corePath": "",
          "mixedPort": 7897,
          "socksPort": 7898,
          "httpPort": 7899,
          "externalControllerHost": "127.0.0.1",
          "externalControllerPort": 9097,
          "secret": "set-your-secret",
          "mode": "rule",
          "setSystemProxyOnStart": false,
          "clearSystemProxyOnStop": true
        }
        """
        try legacyJSON.write(to: paths.settingsURL, atomically: true, encoding: .utf8)

        let settings = ChumenSettingsStore(paths: paths).load()

        XCTAssertEqual(settings.mixedPort, ChumenRuntimeSettings.defaultMixedPort)
        XCTAssertEqual(settings.socksPort, ChumenRuntimeSettings.defaultSocksPort)
        XCTAssertEqual(settings.httpPort, ChumenRuntimeSettings.defaultHTTPPort)
        XCTAssertEqual(settings.externalControllerPort, ChumenRuntimeSettings.defaultExternalControllerPort)
        XCTAssertFalse(settings.enableTun)
        XCTAssertFalse(settings.enableDNS)
        XCTAssertEqual(settings.logLevel, .info)
        XCTAssertEqual(settings.nameservers, ChumenRuntimeSettings.defaultNameservers)
        XCTAssertEqual(settings.systemProxyHost, "127.0.0.1")
        XCTAssertTrue(settings.showStatusBarItem)
        XCTAssertFalse(settings.enableTunOnStart)
        XCTAssertTrue(settings.disableTunOnQuit)
        XCTAssertEqual(settings.statusBarDisplayMode, .stackedSpeed)
        XCTAssertFalse(settings.statusBarCustomTemplate.isEmpty)
        XCTAssertTrue(settings.dashboardHiddenSectionIDs.isEmpty)
        XCTAssertEqual(settings.coreProcessName, ChumenRuntimeSettings.defaultCoreProcessName)
        XCTAssertEqual(settings.managedCoreExecutableName, "chumen-door")
        XCTAssertFalse(settings.usesPlaceholderSecret)
        XCTAssertNotEqual(settings.secret, ChumenRuntimeSettings.placeholderSecret)
    }

    func testSettingsStoreMigratesLegacyBundledCorePath() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("chumen-core-path-migration-\(UUID().uuidString)", isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: root)
        }

        let paths = ChumenPaths(appHome: root.appendingPathComponent("app", isDirectory: true))
        try paths.ensureDirectories()
        let oldCore = root.appendingPathComponent("dist/\(previousAppBundleName)/Contents/Resources/mihomo")
        try FileManager.default.createDirectory(at: oldCore.deletingLastPathComponent(), withIntermediateDirectories: true)
        try "".write(to: oldCore, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: oldCore.path)

        let newCore = root.appendingPathComponent("bin/chumen-door")
        try FileManager.default.createDirectory(at: newCore.deletingLastPathComponent(), withIntermediateDirectories: true)
        try "".write(to: newCore, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: newCore.path)

        try """
        {
          "corePath": "\(oldCore.path)",
          "mixedPort": 19881,
          "socksPort": 19882,
          "httpPort": 19883,
          "externalControllerHost": "127.0.0.1",
          "externalControllerPort": 19897,
          "secret": "set-your-secret",
          "mode": "rule"
        }
        """.write(to: paths.settingsURL, atomically: true, encoding: .utf8)

        let previousCWD = FileManager.default.currentDirectoryPath
        XCTAssertTrue(FileManager.default.changeCurrentDirectoryPath(root.path))
        defer {
            FileManager.default.changeCurrentDirectoryPath(previousCWD)
        }

        let settings = ChumenSettingsStore(paths: paths).load()

        XCTAssertEqual(
            URL(fileURLWithPath: settings.corePath).resolvingSymlinksInPath().path,
            newCore.resolvingSymlinksInPath().path
        )
    }

    func testSettingsStoreMigratesLegacyProfilePath() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("chumen-profile-path-migration-\(UUID().uuidString)", isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: root)
        }

        let appHome = root.appendingPathComponent("io.github.chumen.native-macos", isDirectory: true)
        let paths = ChumenPaths(appHome: appHome)
        try paths.ensureDirectories()
        let legacyProfile = root
            .appendingPathComponent(previousAppSupportDirectoryName, isDirectory: true)
            .appendingPathComponent("profiles/profile.yaml")
        let migratedProfile = paths.profilesDirectoryURL.appendingPathComponent("profile.yaml")
        try "proxies: []\n".write(to: migratedProfile, atomically: true, encoding: .utf8)

        try """
        {
          "profilePath": "\(legacyProfile.path)",
          "mixedPort": 19881,
          "socksPort": 19882,
          "httpPort": 19883,
          "externalControllerHost": "127.0.0.1",
          "externalControllerPort": 19897,
          "secret": "set-your-secret",
          "mode": "rule"
        }
        """.write(to: paths.settingsURL, atomically: true, encoding: .utf8)

        let settings = ChumenSettingsStore(paths: paths).load()

        XCTAssertEqual(settings.profilePath, migratedProfile.path)
        let protection = ChumenConfigProtection(
            keyStore: ChumenConfigProtectionKeyStore(ageIdentityURL: paths.ageIdentityURL)
        )
        let storedSettings = try protection.readText(at: paths.settingsURL)
        XCTAssertFalse(storedSettings.contains(previousAppSupportDirectoryName))
    }

    func testPathsMigrateLegacyAppHomeAndRewriteStoredAbsolutePaths() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("chumen-legacy-migration-\(UUID().uuidString)", isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: root)
        }

        let legacy = root.appendingPathComponent(previousAppSupportDirectoryName, isDirectory: true)
        let migrated = root.appendingPathComponent("io.github.chumen.native-macos", isDirectory: true)
        let legacyProfile = legacy.appendingPathComponent("profiles/profile.yaml")
        try FileManager.default.createDirectory(
            at: legacy.appendingPathComponent("profiles", isDirectory: true),
            withIntermediateDirectories: true
        )
        try FileManager.default.createDirectory(
            at: legacy.appendingPathComponent("ipc", isDirectory: true),
            withIntermediateDirectories: true
        )
        try "proxies: []\n".write(to: legacyProfile, atomically: true, encoding: .utf8)
        try "stale".write(to: legacy.appendingPathComponent("ipc/chumen-mihomo.sock"), atomically: true, encoding: .utf8)
        try """
        {"profilePath":"\(legacyProfile.path)"}
        """.write(to: legacy.appendingPathComponent("settings.json"), atomically: true, encoding: .utf8)
        let escapedLegacyProfilePath = legacyProfile.path.replacingOccurrences(of: "/", with: "\\/")
        try """
        {"profiles":[{"filePath":"\(escapedLegacyProfilePath)"}]}
        """.write(to: legacy.appendingPathComponent("profiles.json"), atomically: true, encoding: .utf8)

        try ChumenPaths.migrateLegacyAppHomeIfNeeded(from: legacy, to: migrated, fileManager: .default)

        XCTAssertTrue(FileManager.default.fileExists(atPath: migrated.appendingPathComponent("profiles/profile.yaml").path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: migrated.appendingPathComponent("ipc").path))
        XCTAssertTrue(try String(contentsOf: migrated.appendingPathComponent("settings.json"), encoding: .utf8).contains(migrated.path))
        let migratedProfilesJSON = try String(contentsOf: migrated.appendingPathComponent("profiles.json"), encoding: .utf8)
        XCTAssertTrue(migratedProfilesJSON.contains(migrated.path.replacingOccurrences(of: "/", with: "\\/")))
        XCTAssertFalse(migratedProfilesJSON.contains(legacy.path))
        XCTAssertFalse(migratedProfilesJSON.contains(legacy.path.replacingOccurrences(of: "/", with: "\\/")))
    }

    func testPathsMigrationSkipsEncryptedStoredFiles() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("chumen-encrypted-legacy-migration-\(UUID().uuidString)", isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: root)
        }

        let legacy = root.appendingPathComponent(previousAppSupportDirectoryName, isDirectory: true)
        let migrated = root.appendingPathComponent("io.github.chumen.native-macos", isDirectory: true)
        let legacyProfile = legacy.appendingPathComponent("profiles/profile.yaml")
        try FileManager.default.createDirectory(at: legacy, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: migrated, withIntermediateDirectories: true)
        try "legacy".write(to: legacy.appendingPathComponent("settings.json"), atomically: true, encoding: .utf8)

        let key = Data(repeating: 9, count: 32)
        let encryptedSettings = try ChumenConfigProtection.encrypt(
            Data(#"{"profilePath":"\#(legacyProfile.path)"}"#.utf8),
            key: key
        )
        let encryptedProfiles = try ChumenConfigProtection.encrypt(
            Data(#"{"profiles":[{"filePath":"\#(legacyProfile.path)"}]}"#.utf8),
            key: key
        )
        try encryptedSettings.write(to: migrated.appendingPathComponent("settings.json"), options: .atomic)
        try encryptedProfiles.write(to: migrated.appendingPathComponent("profiles.json"), options: .atomic)

        try ChumenPaths.migrateLegacyAppHomeIfNeeded(from: legacy, to: migrated, fileManager: .default)

        let storedSettings = try Data(contentsOf: migrated.appendingPathComponent("settings.json"))
        let storedProfiles = try Data(contentsOf: migrated.appendingPathComponent("profiles.json"))
        XCTAssertTrue(ChumenConfigProtection.isProtected(storedSettings))
        XCTAssertTrue(ChumenConfigProtection.isProtected(storedProfiles))
        XCTAssertTrue(try String(data: ChumenConfigProtection.decrypt(storedSettings, key: key), encoding: .utf8)?.contains(legacy.path) == true)
        XCTAssertTrue(try String(data: ChumenConfigProtection.decrypt(storedProfiles, key: key), encoding: .utf8)?.contains(legacy.path) == true)
    }

    func testCoreProcessNameBuildsChumenExecutableName() {
        var settings = ChumenRuntimeSettings(coreProcessName: "chumen-door")
        XCTAssertEqual(settings.coreProcessName, "door")
        XCTAssertEqual(settings.managedCoreExecutableName, "chumen-door")

        settings.coreProcessName = "my/core name"
        XCTAssertEqual(settings.managedCoreExecutableName, "chumen-my-core-name")

        settings.coreProcessName = "   "
        XCTAssertEqual(settings.managedCoreExecutableName, "chumen-door")
    }

    private func yamlLines(_ yaml: String) -> Set<String> {
        Set(yaml.components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) })
    }

    private var previousAppToken: String {
        "lu" + "men"
    }

    private var previousAppSupportDirectoryName: String {
        "io.github." + previousAppToken + ".native-macos"
    }

    private var previousAppBundleName: String {
        "Lu" + "men.app"
    }
}
