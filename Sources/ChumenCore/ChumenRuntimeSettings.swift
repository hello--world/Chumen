import Foundation
import Security

public enum ProxyMode: String, CaseIterable, Codable, Identifiable, Sendable {
    case rule
    case global
    case direct

    public var id: String { rawValue }
}

public enum AppLanguage: String, CaseIterable, Codable, Identifiable, Sendable {
    case system
    case zhHans
    case en

    public var id: String { rawValue }

    public static func defaultLanguage(preferredLanguages: [String] = Locale.preferredLanguages) -> Self {
        guard let first = preferredLanguages.first?.lowercased() else {
            return .system
        }
        return first.hasPrefix("zh") ? .zhHans : .en
    }

    public var metaCubeXDLocaleCode: String {
        switch resolved {
        case .zhHans:
            "zh"
        case .en, .system:
            "en"
        }
    }

    public var zashboardLocaleCode: String {
        switch resolved {
        case .zhHans:
            "zh-CN"
        case .en, .system:
            "en-US"
        }
    }

    private var resolved: Self {
        self == .system ? Self.defaultLanguage() : self
    }
}

public enum CoreLogLevel: String, CaseIterable, Codable, Identifiable, Sendable {
    case debug
    case info
    case warning
    case error
    case silent

    public var id: String { rawValue }
}

public enum TunStack: String, CaseIterable, Codable, Identifiable, Sendable {
    case system
    case gvisor
    case mixed

    public var id: String { rawValue }
}

public enum DNSMode: String, CaseIterable, Codable, Identifiable, Sendable {
    case fakeIP = "fake-ip"
    case redirHost = "redir-host"

    public var id: String { rawValue }
}

public enum DNSFakeIPFilterMode: String, CaseIterable, Codable, Identifiable, Sendable {
    case blacklist
    case whitelist

    public var id: String { rawValue }
}

public enum StatusBarDisplayMode: String, CaseIterable, Codable, Identifiable, Sendable {
    case iconOnly = "icon-only"
    case appName = "app-name"
    case status
    case speed
    case stackedSpeed = "stacked-speed"
    case traffic
    case statusAndSpeed = "status-speed"
    case custom

    public var id: String { rawValue }
}

public enum ChumenAgeKeyStorageKind: String, CaseIterable, Codable, Identifiable, Sendable {
    case local
    case keychain

    public var id: String { rawValue }
}

public struct ChumenRuntimeSettings: Codable, Equatable, Sendable {
    public static let placeholderSecret = "set-your-secret"
    public static let defaultMixedPort = 19881
    public static let defaultSocksPort = 19882
    public static let defaultHTTPPort = 19883
    public static let defaultRedirPort = 19884
    public static let defaultTProxyPort = 19885
    public static let defaultExternalControllerPort = 19897
    public static let defaultDNSListen = "127.0.0.1:1053"
    public static let defaultStatusBarCustomTemplate = "↑{up}/s ↓{down}/s"
    public static let defaultNameservers = [
        "https://dns.alidns.com/dns-query",
        "https://doh.pub/dns-query"
    ]

    private static let legacyDefaultMixedPort = 7897
    private static let legacyDefaultSocksPort = 7898
    private static let legacyDefaultHTTPPort = 7899
    private static let legacyDefaultExternalControllerPort = 9097
    private static let legacyStatusBarCustomTemplate = "{state} {mode} | U {up}/s D {down}/s"
    private static let previousAppBundleName = "Lu" + "men.app"

    public var corePath: String
    public var profilePath: String?
    public var mixedPort: Int
    public var socksPort: Int
    public var httpPort: Int
    public var redirPort: Int
    public var tproxyPort: Int
    public var socksEnabled: Bool
    public var httpEnabled: Bool
    public var redirEnabled: Bool
    public var tproxyEnabled: Bool
    public var externalControllerHost: String
    public var externalControllerPort: Int
    public var systemProxyHost: String
    public var secret: String
    public var externalUI: String
    public var externalUIName: String
    public var externalUIURL: String
    public var externalControllerCORSAllowPrivateNetwork: Bool
    public var externalControllerCORSAllowOrigins: [String]
    public var mode: ProxyMode
    public var activeProfileID: String?
    public var autoStartCoreOnLaunch: Bool
    public var setSystemProxyOnStart: Bool
    public var clearSystemProxyOnStop: Bool
    public var language: AppLanguage?
    public var showStatusBarItem: Bool
    public var statusBarDisplayMode: StatusBarDisplayMode
    public var statusBarCustomTemplate: String
    public var allowLAN: Bool
    public var ipv6: Bool
    public var unifiedDelay: Bool
    public var logLevel: CoreLogLevel
    public var enableTun: Bool
    public var tunStack: TunStack
    public var tunDevice: String
    public var tunAutoRoute: Bool
    public var tunStrictRoute: Bool
    public var tunAutoDetectInterface: Bool
    public var tunDNSHijack: [String]
    public var tunMTU: Int
    public var tunRouteExcludeAddress: [String]
    public var enableDNS: Bool
    public var dnsListen: String
    public var dnsMode: DNSMode
    public var dnsIPv6: Bool
    public var dnsFakeIPRange: String
    public var dnsFakeIPRange6: String
    public var dnsFakeIPFilterMode: DNSFakeIPFilterMode
    public var dnsPreferH3: Bool
    public var dnsRespectRules: Bool
    public var dnsUseHosts: Bool
    public var dnsUseSystemHosts: Bool
    public var nameservers: [String]
    public var defaultNameservers: [String]
    public var fallbackNameservers: [String]
    public var proxyServerNameservers: [String]
    public var directNameservers: [String]
    public var fakeIPFilters: [String]
    public var fallbackFilterGeoIP: Bool
    public var fallbackFilterGeoIPCode: String
    public var fallbackFilterIPCIDRs: [String]
    public var fallbackFilterDomains: [String]
    public var nameserverPolicyYAML: String
    public var hostsYAML: String
    public var configAppendixYAML: String
    public var protectConfigFiles: Bool
    public var protectAgeKeyWithPIN: Bool
    public var securitySetupCompleted: Bool
    public var ageKeyStorage: ChumenAgeKeyStorageKind
    public var ai: ChumenAISettings

    public init(
        corePath: String = "",
        profilePath: String? = nil,
        mixedPort: Int = Self.defaultMixedPort,
        socksPort: Int = Self.defaultSocksPort,
        httpPort: Int = Self.defaultHTTPPort,
        redirPort: Int = Self.defaultRedirPort,
        tproxyPort: Int = Self.defaultTProxyPort,
        socksEnabled: Bool = true,
        httpEnabled: Bool = true,
        redirEnabled: Bool = false,
        tproxyEnabled: Bool = false,
        externalControllerHost: String = "127.0.0.1",
        externalControllerPort: Int = Self.defaultExternalControllerPort,
        systemProxyHost: String = "127.0.0.1",
        secret: String = Self.generateSecret(),
        externalUI: String = "",
        externalUIName: String = "",
        externalUIURL: String = "",
        externalControllerCORSAllowPrivateNetwork: Bool = true,
        externalControllerCORSAllowOrigins: [String] = [],
        mode: ProxyMode = .rule,
        activeProfileID: String? = nil,
        autoStartCoreOnLaunch: Bool = true,
        setSystemProxyOnStart: Bool = false,
        clearSystemProxyOnStop: Bool = true,
        language: AppLanguage? = nil,
        showStatusBarItem: Bool = true,
        statusBarDisplayMode: StatusBarDisplayMode = .stackedSpeed,
        statusBarCustomTemplate: String = Self.defaultStatusBarCustomTemplate,
        allowLAN: Bool = false,
        ipv6: Bool = true,
        unifiedDelay: Bool = true,
        logLevel: CoreLogLevel = .info,
        enableTun: Bool = false,
        tunStack: TunStack = .gvisor,
        tunDevice: String = "utun1024",
        tunAutoRoute: Bool = true,
        tunStrictRoute: Bool = false,
        tunAutoDetectInterface: Bool = true,
        tunDNSHijack: [String] = ["any:53"],
        tunMTU: Int = 1500,
        tunRouteExcludeAddress: [String] = [],
        enableDNS: Bool = false,
        dnsListen: String = Self.defaultDNSListen,
        dnsMode: DNSMode = .fakeIP,
        dnsIPv6: Bool = true,
        dnsFakeIPRange: String = "198.18.0.1/16",
        dnsFakeIPRange6: String = "fdfe:dcba:9876::1/64",
        dnsFakeIPFilterMode: DNSFakeIPFilterMode = .blacklist,
        dnsPreferH3: Bool = false,
        dnsRespectRules: Bool = false,
        dnsUseHosts: Bool = false,
        dnsUseSystemHosts: Bool = false,
        nameservers: [String] = Self.defaultNameservers,
        defaultNameservers: [String] = ["system", "223.6.6.6", "8.8.8.8"],
        fallbackNameservers: [String] = [],
        proxyServerNameservers: [String] = Self.defaultNameservers,
        directNameservers: [String] = [],
        fakeIPFilters: [String] = ["*.lan", "*.local", "*.arpa", "time.*.com", "ntp.*.com", "+.market.xiaomi.com", "*.msftncsi.com", "www.msftconnecttest.com"],
        fallbackFilterGeoIP: Bool = true,
        fallbackFilterGeoIPCode: String = "CN",
        fallbackFilterIPCIDRs: [String] = ["240.0.0.0/4", "0.0.0.0/32"],
        fallbackFilterDomains: [String] = ["+.google.com", "+.facebook.com", "+.youtube.com"],
        nameserverPolicyYAML: String = "",
        hostsYAML: String = "",
        configAppendixYAML: String = "",
        protectConfigFiles: Bool = true,
        protectAgeKeyWithPIN: Bool = true,
        securitySetupCompleted: Bool = false,
        ageKeyStorage: ChumenAgeKeyStorageKind = .local,
        ai: ChumenAISettings = ChumenAISettings()
    ) {
        self.corePath = corePath
        self.profilePath = profilePath
        self.mixedPort = mixedPort
        self.socksPort = socksPort
        self.httpPort = httpPort
        self.redirPort = redirPort
        self.tproxyPort = tproxyPort
        self.socksEnabled = socksEnabled
        self.httpEnabled = httpEnabled
        self.redirEnabled = redirEnabled
        self.tproxyEnabled = tproxyEnabled
        self.externalControllerHost = externalControllerHost
        self.externalControllerPort = externalControllerPort
        self.systemProxyHost = systemProxyHost
        self.secret = secret
        self.externalUI = externalUI
        self.externalUIName = externalUIName
        self.externalUIURL = externalUIURL
        self.externalControllerCORSAllowPrivateNetwork = externalControllerCORSAllowPrivateNetwork
        self.externalControllerCORSAllowOrigins = externalControllerCORSAllowOrigins
        self.mode = mode
        self.activeProfileID = activeProfileID
        self.autoStartCoreOnLaunch = autoStartCoreOnLaunch
        self.setSystemProxyOnStart = setSystemProxyOnStart
        self.clearSystemProxyOnStop = clearSystemProxyOnStop
        self.language = language
        self.showStatusBarItem = showStatusBarItem
        self.statusBarDisplayMode = statusBarDisplayMode
        self.statusBarCustomTemplate = statusBarCustomTemplate
        self.allowLAN = allowLAN
        self.ipv6 = ipv6
        self.unifiedDelay = unifiedDelay
        self.logLevel = logLevel
        self.enableTun = enableTun
        self.tunStack = tunStack
        self.tunDevice = tunDevice
        self.tunAutoRoute = tunAutoRoute
        self.tunStrictRoute = tunStrictRoute
        self.tunAutoDetectInterface = tunAutoDetectInterface
        self.tunDNSHijack = tunDNSHijack
        self.tunMTU = tunMTU
        self.tunRouteExcludeAddress = tunRouteExcludeAddress
        self.enableDNS = enableDNS
        self.dnsListen = dnsListen
        self.dnsMode = dnsMode
        self.dnsIPv6 = dnsIPv6
        self.dnsFakeIPRange = dnsFakeIPRange
        self.dnsFakeIPRange6 = dnsFakeIPRange6
        self.dnsFakeIPFilterMode = dnsFakeIPFilterMode
        self.dnsPreferH3 = dnsPreferH3
        self.dnsRespectRules = dnsRespectRules
        self.dnsUseHosts = dnsUseHosts
        self.dnsUseSystemHosts = dnsUseSystemHosts
        self.nameservers = nameservers
        self.defaultNameservers = defaultNameservers
        self.fallbackNameservers = fallbackNameservers
        self.proxyServerNameservers = proxyServerNameservers
        self.directNameservers = directNameservers
        self.fakeIPFilters = fakeIPFilters
        self.fallbackFilterGeoIP = fallbackFilterGeoIP
        self.fallbackFilterGeoIPCode = fallbackFilterGeoIPCode
        self.fallbackFilterIPCIDRs = fallbackFilterIPCIDRs
        self.fallbackFilterDomains = fallbackFilterDomains
        self.nameserverPolicyYAML = nameserverPolicyYAML
        self.hostsYAML = hostsYAML
        self.configAppendixYAML = configAppendixYAML
        self.protectConfigFiles = protectConfigFiles
        self.protectAgeKeyWithPIN = protectAgeKeyWithPIN
        self.securitySetupCompleted = securitySetupCompleted
        self.ageKeyStorage = ageKeyStorage
        self.ai = ai
    }

    public var usesPlaceholderSecret: Bool {
        let normalized = secret.trimmingCharacters(in: .whitespacesAndNewlines)
        return normalized.isEmpty || normalized == Self.placeholderSecret
    }

    @discardableResult
    public mutating func ensureRandomSecret() -> Bool {
        guard usesPlaceholderSecret else { return false }
        secret = Self.generateSecret()
        return true
    }

    public static func generateSecret(byteCount: Int = 24) -> String {
        var bytes = [UInt8](repeating: 0, count: byteCount)
        let status = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        if status == errSecSuccess {
            return bytes.map { String(format: "%02x", $0) }.joined()
        }
        return (UUID().uuidString + UUID().uuidString)
            .replacingOccurrences(of: "-", with: "")
            .lowercased()
    }

    enum CodingKeys: String, CodingKey {
        case corePath
        case profilePath
        case mixedPort
        case socksPort
        case httpPort
        case redirPort
        case tproxyPort
        case socksEnabled
        case httpEnabled
        case redirEnabled
        case tproxyEnabled
        case externalControllerHost
        case externalControllerPort
        case systemProxyHost
        case secret
        case externalUI
        case externalUIName
        case externalUIURL
        case externalControllerCORSAllowPrivateNetwork
        case externalControllerCORSAllowOrigins
        case mode
        case activeProfileID
        case autoStartCoreOnLaunch
        case setSystemProxyOnStart
        case clearSystemProxyOnStop
        case language
        case showStatusBarItem
        case statusBarDisplayMode
        case statusBarCustomTemplate
        case allowLAN
        case ipv6
        case unifiedDelay
        case logLevel
        case enableTun
        case tunStack
        case tunDevice
        case tunAutoRoute
        case tunStrictRoute
        case tunAutoDetectInterface
        case tunDNSHijack
        case tunMTU
        case tunRouteExcludeAddress
        case enableDNS
        case dnsListen
        case dnsMode
        case dnsIPv6
        case dnsFakeIPRange
        case dnsFakeIPRange6
        case dnsFakeIPFilterMode
        case dnsPreferH3
        case dnsRespectRules
        case dnsUseHosts
        case dnsUseSystemHosts
        case nameservers
        case defaultNameservers
        case fallbackNameservers
        case proxyServerNameservers
        case directNameservers
        case fakeIPFilters
        case fallbackFilterGeoIP
        case fallbackFilterGeoIPCode
        case fallbackFilterIPCIDRs
        case fallbackFilterDomains
        case nameserverPolicyYAML
        case hostsYAML
        case configAppendixYAML
        case protectConfigFiles
        case protectAgeKeyWithPIN
        case securitySetupCompleted
        case ageKeyStorage
        case ai
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let decodedStatusBarTemplate = try container.decodeIfPresent(String.self, forKey: .statusBarCustomTemplate)
        let statusBarCustomTemplate = decodedStatusBarTemplate == Self.legacyStatusBarCustomTemplate
            ? Self.defaultStatusBarCustomTemplate
            : (decodedStatusBarTemplate ?? Self.defaultStatusBarCustomTemplate)
        self.init(
            corePath: try container.decodeIfPresent(String.self, forKey: .corePath) ?? "",
            profilePath: try container.decodeIfPresent(String.self, forKey: .profilePath),
            mixedPort: try container.decodeIfPresent(Int.self, forKey: .mixedPort) ?? Self.defaultMixedPort,
            socksPort: try container.decodeIfPresent(Int.self, forKey: .socksPort) ?? Self.defaultSocksPort,
            httpPort: try container.decodeIfPresent(Int.self, forKey: .httpPort) ?? Self.defaultHTTPPort,
            redirPort: try container.decodeIfPresent(Int.self, forKey: .redirPort) ?? Self.defaultRedirPort,
            tproxyPort: try container.decodeIfPresent(Int.self, forKey: .tproxyPort) ?? Self.defaultTProxyPort,
            socksEnabled: try container.decodeIfPresent(Bool.self, forKey: .socksEnabled) ?? true,
            httpEnabled: try container.decodeIfPresent(Bool.self, forKey: .httpEnabled) ?? true,
            redirEnabled: try container.decodeIfPresent(Bool.self, forKey: .redirEnabled) ?? false,
            tproxyEnabled: try container.decodeIfPresent(Bool.self, forKey: .tproxyEnabled) ?? false,
            externalControllerHost: try container.decodeIfPresent(String.self, forKey: .externalControllerHost) ?? "127.0.0.1",
            externalControllerPort: try container.decodeIfPresent(Int.self, forKey: .externalControllerPort) ?? Self.defaultExternalControllerPort,
            systemProxyHost: try container.decodeIfPresent(String.self, forKey: .systemProxyHost) ?? "127.0.0.1",
            secret: try container.decodeIfPresent(String.self, forKey: .secret) ?? "",
            externalUI: try container.decodeIfPresent(String.self, forKey: .externalUI) ?? "",
            externalUIName: try container.decodeIfPresent(String.self, forKey: .externalUIName) ?? "",
            externalUIURL: try container.decodeIfPresent(String.self, forKey: .externalUIURL) ?? "",
            externalControllerCORSAllowPrivateNetwork: try container.decodeIfPresent(Bool.self, forKey: .externalControllerCORSAllowPrivateNetwork) ?? true,
            externalControllerCORSAllowOrigins: try container.decodeIfPresent([String].self, forKey: .externalControllerCORSAllowOrigins) ?? [],
            mode: (try? container.decode(ProxyMode.self, forKey: .mode)) ?? .rule,
            activeProfileID: try container.decodeIfPresent(String.self, forKey: .activeProfileID),
            autoStartCoreOnLaunch: try container.decodeIfPresent(Bool.self, forKey: .autoStartCoreOnLaunch) ?? true,
            setSystemProxyOnStart: try container.decodeIfPresent(Bool.self, forKey: .setSystemProxyOnStart) ?? false,
            clearSystemProxyOnStop: try container.decodeIfPresent(Bool.self, forKey: .clearSystemProxyOnStop) ?? true,
            language: try container.decodeIfPresent(AppLanguage.self, forKey: .language),
            showStatusBarItem: try container.decodeIfPresent(Bool.self, forKey: .showStatusBarItem) ?? true,
            statusBarDisplayMode: (try? container.decode(StatusBarDisplayMode.self, forKey: .statusBarDisplayMode)) ?? .stackedSpeed,
            statusBarCustomTemplate: statusBarCustomTemplate,
            allowLAN: try container.decodeIfPresent(Bool.self, forKey: .allowLAN) ?? false,
            ipv6: try container.decodeIfPresent(Bool.self, forKey: .ipv6) ?? true,
            unifiedDelay: try container.decodeIfPresent(Bool.self, forKey: .unifiedDelay) ?? true,
            logLevel: (try? container.decode(CoreLogLevel.self, forKey: .logLevel)) ?? .info,
            enableTun: try container.decodeIfPresent(Bool.self, forKey: .enableTun) ?? false,
            tunStack: (try? container.decode(TunStack.self, forKey: .tunStack)) ?? .gvisor,
            tunDevice: try container.decodeIfPresent(String.self, forKey: .tunDevice) ?? "utun1024",
            tunAutoRoute: try container.decodeIfPresent(Bool.self, forKey: .tunAutoRoute) ?? true,
            tunStrictRoute: try container.decodeIfPresent(Bool.self, forKey: .tunStrictRoute) ?? false,
            tunAutoDetectInterface: try container.decodeIfPresent(Bool.self, forKey: .tunAutoDetectInterface) ?? true,
            tunDNSHijack: try container.decodeIfPresent([String].self, forKey: .tunDNSHijack) ?? ["any:53"],
            tunMTU: try container.decodeIfPresent(Int.self, forKey: .tunMTU) ?? 1500,
            tunRouteExcludeAddress: try container.decodeIfPresent([String].self, forKey: .tunRouteExcludeAddress) ?? [],
            enableDNS: try container.decodeIfPresent(Bool.self, forKey: .enableDNS) ?? false,
            dnsListen: try container.decodeIfPresent(String.self, forKey: .dnsListen) ?? Self.defaultDNSListen,
            dnsMode: (try? container.decode(DNSMode.self, forKey: .dnsMode)) ?? .fakeIP,
            dnsIPv6: try container.decodeIfPresent(Bool.self, forKey: .dnsIPv6) ?? true,
            dnsFakeIPRange: try container.decodeIfPresent(String.self, forKey: .dnsFakeIPRange) ?? "198.18.0.1/16",
            dnsFakeIPRange6: try container.decodeIfPresent(String.self, forKey: .dnsFakeIPRange6) ?? "fdfe:dcba:9876::1/64",
            dnsFakeIPFilterMode: (try? container.decode(DNSFakeIPFilterMode.self, forKey: .dnsFakeIPFilterMode)) ?? .blacklist,
            dnsPreferH3: try container.decodeIfPresent(Bool.self, forKey: .dnsPreferH3) ?? false,
            dnsRespectRules: try container.decodeIfPresent(Bool.self, forKey: .dnsRespectRules) ?? false,
            dnsUseHosts: try container.decodeIfPresent(Bool.self, forKey: .dnsUseHosts) ?? false,
            dnsUseSystemHosts: try container.decodeIfPresent(Bool.self, forKey: .dnsUseSystemHosts) ?? false,
            nameservers: try container.decodeIfPresent([String].self, forKey: .nameservers) ?? Self.defaultNameservers,
            defaultNameservers: try container.decodeIfPresent([String].self, forKey: .defaultNameservers) ?? ["system", "223.6.6.6", "8.8.8.8"],
            fallbackNameservers: try container.decodeIfPresent([String].self, forKey: .fallbackNameservers) ?? [],
            proxyServerNameservers: try container.decodeIfPresent([String].self, forKey: .proxyServerNameservers) ?? Self.defaultNameservers,
            directNameservers: try container.decodeIfPresent([String].self, forKey: .directNameservers) ?? [],
            fakeIPFilters: try container.decodeIfPresent([String].self, forKey: .fakeIPFilters) ?? ["*.lan", "*.local", "*.arpa", "time.*.com", "ntp.*.com", "+.market.xiaomi.com", "*.msftncsi.com", "www.msftconnecttest.com"],
            fallbackFilterGeoIP: try container.decodeIfPresent(Bool.self, forKey: .fallbackFilterGeoIP) ?? true,
            fallbackFilterGeoIPCode: try container.decodeIfPresent(String.self, forKey: .fallbackFilterGeoIPCode) ?? "CN",
            fallbackFilterIPCIDRs: try container.decodeIfPresent([String].self, forKey: .fallbackFilterIPCIDRs) ?? ["240.0.0.0/4", "0.0.0.0/32"],
            fallbackFilterDomains: try container.decodeIfPresent([String].self, forKey: .fallbackFilterDomains) ?? ["+.google.com", "+.facebook.com", "+.youtube.com"],
            nameserverPolicyYAML: try container.decodeIfPresent(String.self, forKey: .nameserverPolicyYAML) ?? "",
            hostsYAML: try container.decodeIfPresent(String.self, forKey: .hostsYAML) ?? "",
            configAppendixYAML: try container.decodeIfPresent(String.self, forKey: .configAppendixYAML) ?? "",
            protectConfigFiles: try container.decodeIfPresent(Bool.self, forKey: .protectConfigFiles) ?? true,
            // Existing settings files from before this flag existed should not suddenly require a
            // PIN on upgrade. Brand-new installs still use the initializer default of true.
            protectAgeKeyWithPIN: try container.decodeIfPresent(Bool.self, forKey: .protectAgeKeyWithPIN) ?? false,
            // Missing means "existing install before the onboarding marker existed". Treat it as
            // completed so upgrades do not unexpectedly block on a first-run screen.
            securitySetupCompleted: try container.decodeIfPresent(Bool.self, forKey: .securitySetupCompleted) ?? true,
            ageKeyStorage: try container.decodeIfPresent(ChumenAgeKeyStorageKind.self, forKey: .ageKeyStorage) ?? .local,
            ai: try container.decodeIfPresent(ChumenAISettings.self, forKey: .ai) ?? ChumenAISettings()
        )
    }

    public var controllerBaseURL: URL? {
        URL(string: "http://\(externalControllerHost):\(externalControllerPort)")
    }

    public var usesLegacyDefaultPorts: Bool {
        mixedPort == Self.legacyDefaultMixedPort &&
            socksPort == Self.legacyDefaultSocksPort &&
            httpPort == Self.legacyDefaultHTTPPort &&
            externalControllerPort == Self.legacyDefaultExternalControllerPort
    }

    public var usesLegacyBundledCorePath: Bool {
        corePath.contains("/\(Self.previousAppBundleName)/Contents/Resources/")
    }

    public mutating func migrateLegacyDefaultPorts() {
        guard usesLegacyDefaultPorts else { return }
        mixedPort = Self.defaultMixedPort
        socksPort = Self.defaultSocksPort
        httpPort = Self.defaultHTTPPort
        externalControllerPort = Self.defaultExternalControllerPort
    }

    public static func defaultCoreCandidates(fileManager: FileManager = .default) -> [String] {
        var candidates: [String] = []

        if let bundled = Bundle.main.executableURL?.deletingLastPathComponent() {
            candidates.append(contentsOf: coreNames.map { bundled.appendingPathComponent($0).path })
            candidates.append(contentsOf: coreNames.map { bundled.appendingPathComponent("../Resources/\($0)").standardized.path })
        }

        let cwd = URL(fileURLWithPath: fileManager.currentDirectoryPath, isDirectory: true)
        let roots = [
            cwd,
            cwd.deletingLastPathComponent(),
            cwd.deletingLastPathComponent().deletingLastPathComponent()
        ]

        for root in roots {
            let sidecar = root.appendingPathComponent("src-tauri/sidecar", isDirectory: true)
            candidates.append(contentsOf: coreNames.map { sidecar.appendingPathComponent($0).path })

            let localBin = root.appendingPathComponent("bin", isDirectory: true)
            candidates.append(contentsOf: coreNames.map { localBin.appendingPathComponent($0).path })
        }

        candidates.append(contentsOf: [
            "/opt/homebrew/bin/mihomo",
            "/usr/local/bin/mihomo",
            "/usr/bin/mihomo"
        ])

        var seen = Set<String>()
        return candidates.filter { seen.insert($0).inserted }
    }

    public static func firstExecutableCoreCandidate(fileManager: FileManager = .default) -> String? {
        defaultCoreCandidates(fileManager: fileManager)
            .first { fileManager.isExecutableFile(atPath: $0) }
    }

    private static let coreNames = [
        "verge-mihomo",
        "verge-mihomo-alpha",
        "verge-mihomo-aarch64-apple-darwin",
        "verge-mihomo-x86_64-apple-darwin",
        "verge-mihomo-alpha-aarch64-apple-darwin",
        "verge-mihomo-alpha-x86_64-apple-darwin",
        "mihomo"
    ]
}
