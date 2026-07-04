import Foundation

public struct ChumenAISettings: Codable, Equatable, Sendable {
    public static let localOllamaBaseURL = "http://127.0.0.1:11434/v1"
    public static let localOllamaDefaultModel = "qwen2.5:7b"
    public static let remoteOpenAIBaseURL = "https://api.openai.com/v1"

    public var isEnabled: Bool
    public var baseURL: String
    public var model: String
    public var temperature: Double

    public init(
        isEnabled: Bool = true,
        baseURL: String = Self.localOllamaBaseURL,
        model: String = Self.localOllamaDefaultModel,
        temperature: Double = 0.2
    ) {
        self.isEnabled = isEnabled
        self.baseURL = baseURL
        self.model = model
        self.temperature = temperature
    }

    public var usesLocalOllama: Bool {
        guard let components = URLComponents(string: baseURL.trimmingCharacters(in: .whitespacesAndNewlines)),
              let host = components.host?.lowercased() else {
            return false
        }
        let localHosts: Set<String> = ["127.0.0.1", "localhost", "::1"]
        return localHosts.contains(host) && (components.port ?? 11434) == 11434
    }

    public var requiresAPIKey: Bool {
        !usesLocalOllama
    }

    public mutating func useLocalOllamaDefaults() {
        isEnabled = true
        baseURL = Self.localOllamaBaseURL
        if model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
            model == "gpt-4o-mini" {
            model = Self.localOllamaDefaultModel
        }
    }
}

public enum ChumenAIChatRole: String, Codable, Sendable {
    case system
    case user
    case assistant
}

public struct ChumenAIChatMessage: Identifiable, Codable, Equatable, Sendable {
    public var id: String
    public var role: ChumenAIChatRole
    public var content: String
    public var createdAt: Date

    public init(
        id: String = UUID().uuidString,
        role: ChumenAIChatRole,
        content: String,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.role = role
        self.content = content
        self.createdAt = createdAt
    }
}

public enum ChumenAIChangeKind: String, Codable, CaseIterable, Sendable {
    case importSubscription
    case setMode
    case setTun
    case setSystemProxy
    case setConfigAppendix
    case reloadRuntimeConfig
}

public struct ChumenAIProposedChange: Identifiable, Codable, Equatable, Sendable {
    public var id: String
    public var kind: ChumenAIChangeKind
    public var title: String
    public var detail: String
    public var diff: String
    public var subscriptionURL: String?
    public var profileName: String?
    public var mode: ProxyMode?
    public var enabled: Bool?
    public var configAppendixYAML: String?

    public init(
        id: String = UUID().uuidString,
        kind: ChumenAIChangeKind,
        title: String,
        detail: String = "",
        diff: String = "",
        subscriptionURL: String? = nil,
        profileName: String? = nil,
        mode: ProxyMode? = nil,
        enabled: Bool? = nil,
        configAppendixYAML: String? = nil
    ) {
        self.id = id
        self.kind = kind
        self.title = title
        self.detail = detail
        self.diff = diff
        self.subscriptionURL = subscriptionURL
        self.profileName = profileName
        self.mode = mode
        self.enabled = enabled
        self.configAppendixYAML = configAppendixYAML
    }

    enum CodingKeys: String, CodingKey {
        case id
        case kind
        case title
        case detail
        case diff
        case subscriptionURL
        case profileName
        case mode
        case enabled
        case configAppendixYAML
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
        kind = try container.decode(ChumenAIChangeKind.self, forKey: .kind)
        title = try container.decodeIfPresent(String.self, forKey: .title) ?? kind.rawValue
        detail = try container.decodeIfPresent(String.self, forKey: .detail) ?? ""
        diff = try container.decodeIfPresent(String.self, forKey: .diff) ?? ""
        subscriptionURL = try container.decodeIfPresent(String.self, forKey: .subscriptionURL)
        profileName = try container.decodeIfPresent(String.self, forKey: .profileName)
        mode = try container.decodeIfPresent(ProxyMode.self, forKey: .mode)
        enabled = try container.decodeIfPresent(Bool.self, forKey: .enabled)
        configAppendixYAML = try container.decodeIfPresent(String.self, forKey: .configAppendixYAML)
    }
}

public struct ChumenAIResponse: Decodable, Equatable, Sendable {
    public var reply: String
    public var changes: [ChumenAIProposedChange]

    public init(reply: String, changes: [ChumenAIProposedChange] = []) {
        self.reply = reply
        self.changes = changes
    }

    enum CodingKeys: String, CodingKey {
        case reply
        case changes
        case actions
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        reply = try container.decodeIfPresent(String.self, forKey: .reply) ?? ""
        changes = try container.decodeIfPresent([ChumenAIProposedChange].self, forKey: .changes)
            ?? container.decodeIfPresent([ChumenAIProposedChange].self, forKey: .actions)
            ?? []
    }
}

public enum ChumenAIKnowledgeBase {
    public static let text = """
    Chumen is a native macOS controller for mihomo. The assistant may only propose reversible draft changes.
    The user must review the proposed diff and click Apply before Chumen writes settings or imports profiles.

    Allowed proposed change kinds:
    - importSubscription: import a remote profile subscription. Required: subscriptionURL. Optional: profileName.
    - setMode: change mihomo mode. Required mode: rule, global, or direct.
    - setTun: enable or disable TUN. Required enabled: true or false. TUN changes restart the core when it is running.
    - setSystemProxy: enable or disable macOS system proxy. Required enabled: true or false.
    - setConfigAppendix: replace the global Chumen append YAML. Required: configAppendixYAML.
    - reloadRuntimeConfig: regenerate Chumen runtime YAML and ask mihomo to reload it.

    Relevant mihomo configuration topics include proxy, proxy-groups, rules, rule-providers, proxy-providers,
    dns, tun, mixed-port, socks-port, port, redir-port, tproxy-port, external-controller, secret, external-ui,
    allow-lan, ipv6, unified-delay, log-level, hosts, profile, and sniffer.

    Output only JSON:
    {
      "reply": "short user-facing explanation",
      "changes": [
        {
          "kind": "importSubscription|setMode|setTun|setSystemProxy|setConfigAppendix|reloadRuntimeConfig",
          "title": "short title",
          "detail": "why this change is proposed",
          "subscriptionURL": "optional URL",
          "profileName": "optional display name",
          "mode": "rule|global|direct when kind is setMode",
          "enabled": true,
          "configAppendixYAML": "optional YAML when kind is setConfigAppendix"
        }
      ]
    }
    """
}

public struct ChumenAIClient: Sendable {
    public init() {}

    public func complete(
        settings: ChumenAISettings,
        apiKey: String,
        systemPrompt: String,
        messages: [ChumenAIChatMessage]
    ) async throws -> ChumenAIResponse {
        let base = settings.baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let model = settings.model.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !base.isEmpty, !model.isEmpty else {
            throw ChumenError.commandFailed("AI base URL or model is empty.")
        }
        guard var components = URLComponents(string: base) else {
            throw ChumenError.commandFailed("Invalid AI base URL.")
        }
        components.path = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/")) + "/chat/completions"
        components.path = "/" + components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard let url = components.url else {
            throw ChumenError.commandFailed("Invalid AI chat completions URL.")
        }

        let requestMessages = [OpenAIChatMessage(role: .system, content: systemPrompt)] + messages.map {
            OpenAIChatMessage(role: $0.role, content: $0.content)
        }
        let payload = OpenAIChatRequest(
            model: model,
            messages: requestMessages,
            temperature: settings.temperature
        )

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(payload)

        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw ChumenError.httpStatus(http.statusCode, body)
        }

        let decoded = try JSONDecoder().decode(OpenAIChatResponse.self, from: data)
        let content = decoded.choices.first?.message.content.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return Self.parseAssistantContent(content)
    }

    private static func parseAssistantContent(_ content: String) -> ChumenAIResponse {
        for candidate in jsonCandidates(from: content) {
            if let data = candidate.data(using: .utf8),
               let response = try? JSONDecoder().decode(ChumenAIResponse.self, from: data) {
                return response
            }
        }
        return ChumenAIResponse(reply: content, changes: [])
    }

    private static func jsonCandidates(from content: String) -> [String] {
        var candidates = [content]
        if let fenced = fencedJSON(in: content) {
            candidates.insert(fenced, at: 0)
        }
        if let object = firstJSONObject(in: content) {
            candidates.insert(object, at: 0)
        }
        return candidates
    }

    private static func fencedJSON(in content: String) -> String? {
        guard let fenceStart = content.range(of: "```") else { return nil }
        let afterFence = content[fenceStart.upperBound...]
        let bodyStart: String.Index
        if let lineEnd = afterFence.firstIndex(of: "\n") {
            bodyStart = afterFence.index(after: lineEnd)
        } else {
            bodyStart = afterFence.startIndex
        }
        guard let fenceEnd = afterFence[bodyStart...].range(of: "```") else { return nil }
        return String(afterFence[bodyStart..<fenceEnd.lowerBound])
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func firstJSONObject(in content: String) -> String? {
        guard let start = content.firstIndex(of: "{") else { return nil }
        var depth = 0
        var inString = false
        var isEscaped = false

        var index = start
        while index < content.endIndex {
            let character = content[index]
            if inString {
                if isEscaped {
                    isEscaped = false
                } else if character == "\\" {
                    isEscaped = true
                } else if character == "\"" {
                    inString = false
                }
            } else {
                if character == "\"" {
                    inString = true
                } else if character == "{" {
                    depth += 1
                } else if character == "}" {
                    depth -= 1
                    if depth == 0 {
                        return String(content[start...index])
                    }
                }
            }
            index = content.index(after: index)
        }
        return nil
    }
}

private struct OpenAIChatRequest: Encodable {
    let model: String
    let messages: [OpenAIChatMessage]
    let temperature: Double
}

private struct OpenAIChatMessage: Codable {
    let role: ChumenAIChatRole
    let content: String
}

private struct OpenAIChatResponse: Decodable {
    struct Choice: Decodable {
        struct Message: Decodable {
            let content: String
        }

        let message: Message
    }

    let choices: [Choice]
}
