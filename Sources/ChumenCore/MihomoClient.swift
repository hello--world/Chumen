import Foundation

public struct MihomoClient: Sendable {
    public let baseURL: URL
    public let secret: String
    public let session: URLSession

    public init(baseURL: URL, secret: String, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.secret = secret
        self.session = session
    }

    public func version() async throws -> MihomoVersion {
        try await request(path: "/version")
    }

    public func configs() async throws -> MihomoConfigs {
        try await request(path: "/configs")
    }

    public func proxies() async throws -> MihomoProxiesResponse {
        try await request(path: "/proxies")
    }

    public func rules() async throws -> MihomoRulesResponse {
        try await request(path: "/rules")
    }

    public func proxyProviders() async throws -> MihomoProvidersResponse {
        try await request(path: "/providers/proxies")
    }

    public func ruleProviders() async throws -> MihomoProvidersResponse {
        try await request(path: "/providers/rules")
    }

    public func connections() async throws -> MihomoConnectionsResponse {
        try await request(path: "/connections")
    }

    public func traffic() async throws -> MihomoTraffic {
        try await request(path: "/traffic")
    }

    public func memory() async throws -> MihomoMemory {
        try await request(path: "/memory")
    }

    public func flushFakeIPCache() async throws {
        try await requestNoBody(path: "/cache/fakeip/flush", method: "POST", body: nil)
    }

    public func flushDNSCache() async throws {
        try await requestNoBody(path: "/cache/dns/flush", method: "POST", body: nil)
    }

    public func patchConfigs(_ patch: [String: MihomoJSONValue]) async throws {
        let body = try JSONEncoder().encode(patch)
        try await requestNoBody(path: "/configs", method: "PATCH", body: body)
    }

    public func reloadConfig(path: String = "", payload: String = "", force: Bool = true) async throws {
        let body = try JSONEncoder().encode(MihomoPathPayload(path: path, payload: payload))
        try await requestNoBody(pathComponents: ["configs"], queryItems: [URLQueryItem(name: "force", value: String(force))], method: "PUT", body: body)
    }

    public func updateConfigGeo(path: String = "", payload: String = "") async throws {
        let body = try JSONEncoder().encode(MihomoPathPayload(path: path, payload: payload))
        try await requestNoBody(path: "/configs/geo", method: "POST", body: body)
    }

    public func restartKernel(path: String = "", payload: String = "") async throws {
        let body = try JSONEncoder().encode(MihomoPathPayload(path: path, payload: payload))
        try await requestNoBody(path: "/restart", method: "POST", body: body)
    }

    public func upgrade(channel: String? = nil, force: Bool = false, path: String = "", payload: String = "") async throws {
        var queryItems: [URLQueryItem] = []
        if let channel, !channel.isEmpty {
            queryItems.append(URLQueryItem(name: "channel", value: channel))
        }
        if force {
            queryItems.append(URLQueryItem(name: "force", value: "true"))
        }
        let body = try JSONEncoder().encode(MihomoPathPayload(path: path, payload: payload))
        try await requestNoBody(pathComponents: ["upgrade"], queryItems: queryItems, method: "POST", body: body)
    }

    public func upgradeUI() async throws {
        try await requestNoBody(path: "/upgrade/ui", method: "POST", body: nil)
    }

    public func upgradeGeo(path: String = "", payload: String = "") async throws {
        let body = try JSONEncoder().encode(MihomoPathPayload(path: path, payload: payload))
        try await requestNoBody(path: "/upgrade/geo", method: "POST", body: body)
    }

    public func policyGroups() async throws -> MihomoJSONValue {
        try await request(path: "/group")
    }

    public func policyGroup(name: String) async throws -> MihomoJSONValue {
        try await request(pathComponents: ["group", name])
    }

    public func delayGroup(
        name: String,
        url: String = "https://www.gstatic.com/generate_204",
        timeout: Int = 5000,
        expected: String? = nil
    ) async throws -> MihomoJSONValue {
        var queryItems = [
            URLQueryItem(name: "url", value: url),
            URLQueryItem(name: "timeout", value: String(timeout))
        ]
        if let expected, !expected.isEmpty {
            queryItems.append(URLQueryItem(name: "expected", value: expected))
        }
        return try await request(pathComponents: ["group", name, "delay"], queryItems: queryItems)
    }

    public func delayProxy(name: String, url: String = "https://www.gstatic.com/generate_204", timeout: Int = 5000) async throws -> MihomoDelayResponse {
        try await request(pathComponents: ["proxies", name, "delay"], queryItems: [
            URLQueryItem(name: "url", value: url),
            URLQueryItem(name: "timeout", value: String(timeout))
        ])
    }

    public func setMode(_ mode: ProxyMode) async throws {
        try await patchConfigs(["mode": .string(mode.rawValue)])
    }

    public func proxy(name: String) async throws -> MihomoProxy {
        try await request(pathComponents: ["proxies", name])
    }

    public func selectProxy(group: String, name: String) async throws {
        let body = try JSONEncoder().encode(["name": name])
        try await requestNoBody(pathComponents: ["proxies", group], method: "PUT", body: body)
    }

    public func clearProxySelection(group: String) async throws {
        try await requestNoBody(pathComponents: ["proxies", group], method: "DELETE", body: nil)
    }

    public func closeConnection(id: String) async throws {
        try await requestNoBody(pathComponents: ["connections", id], method: "DELETE", body: nil)
    }

    public func closeAllConnections() async throws {
        try await requestNoBody(path: "/connections", method: "DELETE", body: nil)
    }

    public func updateProxyProvider(name: String) async throws {
        try await requestNoBody(pathComponents: ["providers", "proxies", name], method: "PUT", body: nil)
    }

    public func proxyProvider(name: String) async throws -> MihomoProvider {
        try await request(pathComponents: ["providers", "proxies", name])
    }

    public func healthcheckProxyProvider(name: String) async throws {
        try await requestNoBody(pathComponents: ["providers", "proxies", name, "healthcheck"], method: "GET", body: nil)
    }

    public func proxyProviderProxy(provider: String, proxy: String) async throws -> MihomoProviderProxy {
        try await request(pathComponents: ["providers", "proxies", provider, proxy])
    }

    public func healthcheckProxyProviderProxy(
        provider: String,
        proxy: String,
        url: String = "https://www.gstatic.com/generate_204",
        timeout: Int = 5000
    ) async throws -> MihomoJSONValue {
        try await request(
            pathComponents: ["providers", "proxies", provider, proxy, "healthcheck"],
            queryItems: [
                URLQueryItem(name: "url", value: url),
                URLQueryItem(name: "timeout", value: String(timeout))
            ]
        )
    }

    public func updateRuleProvider(name: String) async throws {
        try await requestNoBody(pathComponents: ["providers", "rules", name], method: "PUT", body: nil)
    }

    public func ruleProvider(name: String) async throws -> MihomoProvider {
        try await request(pathComponents: ["providers", "rules", name])
    }

    public func disableRules(_ states: [String: Bool]) async throws {
        let body = try JSONEncoder().encode(states)
        try await requestNoBody(path: "/rules/disable", method: "PATCH", body: body)
    }

    public func dnsQuery(name: String, type: String = "A") async throws -> MihomoJSONValue {
        try await request(pathComponents: ["dns", "query"], queryItems: [
            URLQueryItem(name: "name", value: name),
            URLQueryItem(name: "type", value: type)
        ])
    }

    public func storage(key: String) async throws -> MihomoJSONValue {
        try await request(pathComponents: ["storage", key])
    }

    public func putStorage(key: String, value: MihomoJSONValue) async throws {
        let body = try JSONEncoder().encode(value)
        try await requestNoBody(pathComponents: ["storage", key], method: "PUT", body: body)
    }

    public func deleteStorage(key: String) async throws {
        try await requestNoBody(pathComponents: ["storage", key], method: "DELETE", body: nil)
    }

    public func debugGC() async throws {
        try await requestNoBody(path: "/debug/gc", method: "PUT", body: nil)
    }

    public func raw(path: String, method: String = "GET", body: Data? = nil) async throws -> MihomoRawResponse {
        let (data, response) = try await data(path: path, method: method, body: body)
        return MihomoRawResponse(statusCode: response.statusCode, body: String(data: data, encoding: .utf8) ?? "")
    }

    // 统一的 HTTP 出口：所有 typed API 和 raw API 都经过这里加 Bearer token、超时和错误体解析。
    private func request<T: Decodable>(path: String, method: String = "GET", body: Data? = nil) async throws -> T {
        let (data, _) = try await data(path: path, method: method, body: body)
        return try JSONDecoder().decode(T.self, from: data)
    }

    private func request<T: Decodable>(
        pathComponents: [String],
        queryItems: [URLQueryItem] = [],
        method: String = "GET",
        body: Data? = nil
    ) async throws -> T {
        let (data, _) = try await data(
            pathComponents: pathComponents,
            queryItems: queryItems,
            method: method,
            body: body
        )
        return try JSONDecoder().decode(T.self, from: data)
    }

    private func requestNoBody(path: String, method: String, body: Data?) async throws {
        _ = try await data(path: path, method: method, body: body)
    }

    private func requestNoBody(pathComponents: [String], method: String, body: Data?) async throws {
        _ = try await data(pathComponents: pathComponents, method: method, body: body)
    }

    private func requestNoBody(pathComponents: [String], queryItems: [URLQueryItem], method: String, body: Data?) async throws {
        _ = try await data(pathComponents: pathComponents, queryItems: queryItems, method: method, body: body)
    }

    private func data(path: String, method: String, body: Data?) async throws -> (Data, HTTPURLResponse) {
        let components = path
            .split(separator: "/")
            .map(String.init)
        return try await data(pathComponents: components, method: method, body: body)
    }

    private func data(pathComponents: [String], method: String, body: Data?) async throws -> (Data, HTTPURLResponse) {
        try await data(pathComponents: pathComponents, queryItems: [], method: method, body: body)
    }

    private func data(pathComponents: [String], queryItems: [URLQueryItem], method: String, body: Data?) async throws -> (Data, HTTPURLResponse) {
        // 使用 pathComponents 构造 URL，可以安全处理带空格、斜杠或中文的策略组/节点名。
        let url = pathComponents.reduce(baseURL) { partial, component in
            partial.appendingPathComponent(component)
        }
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        if !queryItems.isEmpty {
            components?.queryItems = queryItems
        }
        var request = URLRequest(url: components?.url ?? url)
        request.httpMethod = method
        request.timeoutInterval = 5
        if !secret.isEmpty {
            request.setValue("Bearer \(secret)", forHTTPHeaderField: "Authorization")
        }
        if let body {
            request.httpBody = body
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw ChumenError.invalidControllerURL
        }
        guard (200..<300).contains(http.statusCode) else {
            let bodyText = String(data: data, encoding: .utf8) ?? ""
            throw ChumenError.httpStatus(Int(http.statusCode), bodyText)
        }
        return (data, http)
    }
}

public struct MihomoRawResponse: Codable, Equatable, Sendable {
    public let statusCode: Int
    public let body: String
}

public struct MihomoPathPayload: Codable, Equatable, Sendable {
    public let path: String
    public let payload: String

    public init(path: String = "", payload: String = "") {
        self.path = path
        self.payload = payload
    }
}

public indirect enum MihomoJSONValue: Codable, Equatable, Sendable {
    case null
    case bool(Bool)
    case number(Double)
    case string(String)
    case array([MihomoJSONValue])
    case object([String: MihomoJSONValue])

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Double.self) {
            self = .number(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([MihomoJSONValue].self) {
            self = .array(value)
        } else {
            self = .object(try container.decode([String: MihomoJSONValue].self))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .null:
            try container.encodeNil()
        case let .bool(value):
            try container.encode(value)
        case let .number(value):
            try container.encode(value)
        case let .string(value):
            try container.encode(value)
        case let .array(value):
            try container.encode(value)
        case let .object(value):
            try container.encode(value)
        }
    }
}

public struct MihomoVersion: Codable, Equatable, Sendable {
    public let version: String?
    public let premium: Bool?
    public let meta: Bool?
}

public struct MihomoConfigs: Codable, Equatable, Sendable {
    public let port: Int?
    public let socksPort: Int?
    public let mixedPort: Int?
    public let redirPort: Int?
    public let tproxyPort: Int?
    public let mode: String?
    public let allowLAN: Bool?
    public let logLevel: String?
    public let ipv6: Bool?
    public let unifiedDelay: Bool?
    public let externalController: String?
    public let externalUI: String?
    public let tun: MihomoJSONValue?
    public let dns: MihomoJSONValue?
    public let tunnels: MihomoJSONValue?

    enum CodingKeys: String, CodingKey {
        case port
        case socksPort = "socks-port"
        case mixedPort = "mixed-port"
        case redirPort = "redir-port"
        case tproxyPort = "tproxy-port"
        case mode
        case allowLAN = "allow-lan"
        case logLevel = "log-level"
        case ipv6
        case unifiedDelay = "unified-delay"
        case externalController = "external-controller"
        case externalUI = "external-ui"
        case tun
        case dns
        case tunnels
    }
}

public struct MihomoTraffic: Codable, Equatable, Sendable {
    public let up: Int64?
    public let down: Int64?
    public let upTotal: Int64?
    public let downTotal: Int64?
}

public struct MihomoMemory: Codable, Equatable, Sendable {
    public let inuse: Int64?
    public let oslimit: Int64?
}

public struct MihomoProxiesResponse: Codable, Equatable, Sendable {
    public let proxies: [String: MihomoProxy]
}

public struct MihomoProxy: Codable, Identifiable, Equatable, Sendable {
    public var id: String { name }

    public let name: String
    public let type: String?
    public let now: String?
    public let all: [String]?
    public let history: [MihomoProxyHistory]?
    public let udp: Bool?
    public let xudp: Bool?
    public let tfo: Bool?
    public let mptcp: Bool?
    public let smux: Bool?

    public var isGroup: Bool {
        all?.isEmpty == false
    }
}

public struct MihomoProxyHistory: Codable, Equatable, Sendable {
    public let time: String?
    public let delay: Int?
}

public struct MihomoDelayResponse: Codable, Equatable, Sendable {
    public let delay: Int
}

public struct ProxyGroupSnapshot: Codable, Identifiable, Equatable, Sendable {
    public var id: String { name }
    public let name: String
    public let type: String
    public let selected: String
    public let options: [String]

    public init(proxy: MihomoProxy) {
        self.name = proxy.name
        self.type = proxy.type ?? "unknown"
        self.selected = proxy.now ?? ""
        self.options = proxy.all ?? []
    }
}

public struct MihomoConnectionsResponse: Codable, Equatable, Sendable {
    public let downloadTotal: Int64?
    public let uploadTotal: Int64?
    public let connections: [MihomoConnection]

    enum CodingKeys: String, CodingKey {
        case downloadTotal
        case uploadTotal
        case connections
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        downloadTotal = try container.decodeIfPresent(Int64.self, forKey: .downloadTotal)
        uploadTotal = try container.decodeIfPresent(Int64.self, forKey: .uploadTotal)
        connections = try container.decodeIfPresent([MihomoConnection].self, forKey: .connections) ?? []
    }

    public init(downloadTotal: Int64? = nil, uploadTotal: Int64? = nil, connections: [MihomoConnection] = []) {
        self.downloadTotal = downloadTotal
        self.uploadTotal = uploadTotal
        self.connections = connections
    }
}

public struct MihomoConnection: Codable, Identifiable, Equatable, Sendable {
    public let id: String
    public let upload: Int64?
    public let download: Int64?
    public let start: String?
    public let chains: [String]?
    public let rule: String?
    public let rulePayload: String?
    public let metadata: MihomoConnectionMetadata?
}

public struct MihomoConnectionMetadata: Codable, Equatable, Sendable {
    public let network: String?
    public let type: String?
    public let sourceIP: String?
    public let destinationIP: String?
    public let sourcePort: String?
    public let destinationPort: String?
    public let host: String?
    public let dnsMode: String?
    public let process: String?
    public let processPath: String?
    public let specialProxy: String?
}

public struct MihomoRulesResponse: Codable, Equatable, Sendable {
    public let rules: [MihomoRule]
}

public struct MihomoProvidersResponse: Codable, Equatable, Sendable {
    public let providers: [String: MihomoProvider]
}

public struct MihomoProvider: Codable, Identifiable, Equatable, Sendable {
    public var id: String { name }

    public let name: String
    public let type: String?
    public let vehicleType: String?
    public let behavior: String?
    public let updatedAt: String?
    public let proxies: [MihomoProviderProxy]?

    enum CodingKeys: String, CodingKey {
        case name
        case type
        case vehicleType
        case behavior
        case updatedAt
        case proxies
    }
}

public struct MihomoProviderProxy: Codable, Identifiable, Equatable, Sendable {
    public var id: String { name }

    public let name: String
    public let type: String?
    public let udp: Bool?
    public let history: [MihomoProxyHistory]?
}

public struct MihomoRule: Codable, Identifiable, Equatable, Sendable {
    public var id: String {
        "\(type ?? "")|\(payload ?? "")|\(proxy ?? "")"
    }

    public let type: String?
    public let payload: String?
    public let proxy: String?
    public let size: Int?
    public let disabled: Bool?
}
