import Foundation
import SystemConfiguration

public struct SystemProxyManager: Sendable {
    public var host: String
    public var port: Int
    public var bypassDomains: [String]

    public init(
        host: String = "127.0.0.1",
        port: Int = ChumenRuntimeSettings.defaultMixedPort,
        bypassDomains: [String] = Self.defaultBypassDomains
    ) {
        self.host = host
        self.port = port
        self.bypassDomains = bypassDomains
    }

    public func enable() throws {
        try apply(enabled: true)
    }

    public func disable() throws {
        try apply(enabled: false)
    }

    public func services() throws -> [String] {
        let output = try Self.runNetworkSetup(["-listallnetworkservices"])
        return Self.parseNetworkServices(output)
    }

    public func currentState() throws -> SystemProxyState {
        if let state = Self.currentDynamicStoreState() {
            return state
        }
        return try currentStateUsingNetworkSetup()
    }

    private func currentStateUsingNetworkSetup() throws -> SystemProxyState {
        let services = try services()
        guard !services.isEmpty else {
            return SystemProxyState(service: nil, webEnabled: false, secureWebEnabled: false, socksEnabled: false)
        }

        let states = try services.map { service in
            let web = try Self.runNetworkSetup(["-getwebproxy", service])
            let secureWeb = try Self.runNetworkSetup(["-getsecurewebproxy", service])
            let socks = try Self.runNetworkSetup(["-getsocksfirewallproxy", service])

            return SystemProxyState(
                service: service,
                web: Self.parseProxyConfig(web),
                secureWeb: Self.parseProxyConfig(secureWeb),
                socks: Self.parseProxyConfig(socks)
            )
        }

        if let owned = states.first(where: { $0.matches(host: host, port: port) }) {
            return owned
        }
        if let enabled = states.first(where: \.isEnabled) {
            return enabled
        }
        return states[0]
    }

    static func currentState(fromDynamicStoreProxies proxies: [String: Any], service: String = "macOS") -> SystemProxyState {
        SystemProxyState(
            service: service,
            web: SystemProxyEndpoint(
                enabled: proxyEnabled(proxies[kSCPropNetProxiesHTTPEnable as String]),
                server: proxyString(proxies[kSCPropNetProxiesHTTPProxy as String]),
                port: proxyPort(proxies[kSCPropNetProxiesHTTPPort as String])
            ),
            secureWeb: SystemProxyEndpoint(
                enabled: proxyEnabled(proxies[kSCPropNetProxiesHTTPSEnable as String]),
                server: proxyString(proxies[kSCPropNetProxiesHTTPSProxy as String]),
                port: proxyPort(proxies[kSCPropNetProxiesHTTPSPort as String])
            ),
            socks: SystemProxyEndpoint(
                enabled: proxyEnabled(proxies[kSCPropNetProxiesSOCKSEnable as String]),
                server: proxyString(proxies[kSCPropNetProxiesSOCKSProxy as String]),
                port: proxyPort(proxies[kSCPropNetProxiesSOCKSPort as String])
            )
        )
    }

    private static func currentDynamicStoreState() -> SystemProxyState? {
        guard let proxies = SCDynamicStoreCopyProxies(nil) as? [String: Any] else {
            return nil
        }
        // Reading the current proxy via SystemConfiguration avoids spawning networksetup for every
        // service on every UI refresh. networksetup stays on the write path where macOS persists
        // per-service proxy settings.
        return currentState(fromDynamicStoreProxies: proxies)
    }

    public static func parseNetworkServices(_ output: String) -> [String] {
        output
            .components(separatedBy: .newlines)
            .dropFirst()
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && !$0.hasPrefix("*") }
    }

    private func apply(enabled: Bool) throws {
        let services = try services()
        guard !services.isEmpty else {
            throw ChumenError.systemProxyFailed("No active macOS network services found.")
        }

        var failures: [String] = []
        for service in services {
            do {
                if enabled {
                    try enable(service: service)
                } else {
                    try disable(service: service)
                }
            } catch {
                failures.append("\(service): \(error.localizedDescription)")
            }
        }

        if !failures.isEmpty {
            throw ChumenError.systemProxyFailed(failures.joined(separator: "\n"))
        }
    }

    private func enable(service: String) throws {
        try Self.runNetworkSetup(["-setwebproxy", service, host, "\(port)"])
        try Self.runNetworkSetup(["-setsecurewebproxy", service, host, "\(port)"])
        try Self.runNetworkSetup(["-setsocksfirewallproxy", service, host, "\(port)"])
        if !bypassDomains.isEmpty {
            try Self.runNetworkSetup(["-setproxybypassdomains", service] + bypassDomains)
        }
        try Self.runNetworkSetup(["-setwebproxystate", service, "on"])
        try Self.runNetworkSetup(["-setsecurewebproxystate", service, "on"])
        try Self.runNetworkSetup(["-setsocksfirewallproxystate", service, "on"])
    }

    private func disable(service: String) throws {
        try Self.runNetworkSetup(["-setwebproxystate", service, "off"])
        try Self.runNetworkSetup(["-setsecurewebproxystate", service, "off"])
        try Self.runNetworkSetup(["-setsocksfirewallproxystate", service, "off"])
    }

    @discardableResult
    private static func runNetworkSetup(_ arguments: [String]) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/networksetup")
        process.arguments = arguments

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        try process.run()
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""
        guard process.terminationStatus == 0 else {
            throw ChumenError.commandFailed(output.isEmpty ? "networksetup failed" : output)
        }
        return output
    }

    public static let defaultBypassDomains = [
        "127.0.0.1",
        "localhost",
        "*.local",
        "192.168.0.0/16",
        "10.0.0.0/8",
        "172.16.0.0/12",
        "*.crashlytics.com"
    ]

    public static func parseProxyConfig(_ output: String) -> SystemProxyEndpoint {
        var enabled = false
        var server: String?
        var port: Int?

        for line in output.components(separatedBy: .newlines) {
            let parts = line.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
            guard parts.count == 2 else { continue }
            let key = parts[0].trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let value = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)

            switch key {
            case "enabled":
                let normalized = value.lowercased()
                enabled = normalized == "yes" || normalized == "on" || normalized == "1"
            case "server":
                server = value.isEmpty ? nil : value
            case "port":
                port = Int(value)
            default:
                continue
            }
        }

        return SystemProxyEndpoint(enabled: enabled, server: server, port: port)
    }

    private static func proxyEnabled(_ value: Any?) -> Bool {
        if let value = value as? Bool {
            return value
        }
        if let value = value as? NSNumber {
            return value.intValue != 0
        }
        if let value = value as? String {
            let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            return normalized == "yes" || normalized == "on" || normalized == "true" || normalized == "1"
        }
        return false
    }

    private static func proxyString(_ value: Any?) -> String? {
        guard let value = value as? String else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func proxyPort(_ value: Any?) -> Int? {
        if let value = value as? Int {
            return value
        }
        if let value = value as? NSNumber {
            return value.intValue
        }
        if let value = value as? String {
            return Int(value.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        return nil
    }
}

public struct SystemProxyEndpoint: Codable, Equatable, Sendable {
    public let enabled: Bool
    public let server: String?
    public let port: Int?

    public init(enabled: Bool, server: String? = nil, port: Int? = nil) {
        self.enabled = enabled
        self.server = server
        self.port = port
    }

    public var address: String? {
        guard let server, let port else { return nil }
        return "\(server):\(port)"
    }

    public func matches(host: String, port: Int) -> Bool {
        enabled && self.port == port && Self.normalizedHost(server) == Self.normalizedHost(host)
    }

    private static func normalizedHost(_ host: String?) -> String? {
        guard let host else { return nil }
        let normalized = host.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        switch normalized {
        case "localhost", "::1", "0:0:0:0:0:0:0:1":
            return "127.0.0.1"
        default:
            return normalized
        }
    }
}

public struct SystemProxyState: Codable, Equatable, Sendable {
    public let service: String?
    public let web: SystemProxyEndpoint
    public let secureWeb: SystemProxyEndpoint
    public let socks: SystemProxyEndpoint

    public init(
        service: String?,
        web: SystemProxyEndpoint,
        secureWeb: SystemProxyEndpoint,
        socks: SystemProxyEndpoint
    ) {
        self.service = service
        self.web = web
        self.secureWeb = secureWeb
        self.socks = socks
    }

    public init(
        service: String?,
        webEnabled: Bool,
        secureWebEnabled: Bool,
        socksEnabled: Bool
    ) {
        self.init(
            service: service,
            web: SystemProxyEndpoint(enabled: webEnabled),
            secureWeb: SystemProxyEndpoint(enabled: secureWebEnabled),
            socks: SystemProxyEndpoint(enabled: socksEnabled)
        )
    }

    public var webEnabled: Bool {
        web.enabled
    }

    public var secureWebEnabled: Bool {
        secureWeb.enabled
    }

    public var socksEnabled: Bool {
        socks.enabled
    }

    public var isEnabled: Bool {
        webEnabled || secureWebEnabled || socksEnabled
    }

    public var enabledAddresses: [String] {
        [web, secureWeb, socks].compactMap { endpoint in
            endpoint.enabled ? endpoint.address : nil
        }
    }

    public var summaryAddress: String? {
        let addresses = Array(Set(enabledAddresses)).sorted()
        guard !addresses.isEmpty else { return nil }
        return addresses.joined(separator: ", ")
    }

    public func matches(host: String, port: Int) -> Bool {
        let enabledEndpoints = [web, secureWeb, socks].filter(\.enabled)
        guard !enabledEndpoints.isEmpty else { return false }
        return enabledEndpoints.allSatisfy { $0.matches(host: host, port: port) }
    }
}
