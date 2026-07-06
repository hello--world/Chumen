import Foundation

public enum ChumenAIProvider: String, Codable, CaseIterable, Identifiable, Sendable {
    case localOllama = "local-ollama"
    case codexWebAPI = "codex-web-api"
    case customEndpoint = "custom-endpoint"
    /// Legacy app-server path kept only so older settings files can decode.
    case codexAgent = "codex-agent"

    public var id: String { rawValue }
}

public struct ChumenAISettings: Codable, Equatable, Sendable {
    public static let localOllamaBaseURL = "http://127.0.0.1:11434/v1"
    public static let localOllamaDefaultModel = ""
    public static let codexWebAPIBaseURL = "http://127.0.0.1:18080/v1"
    public static let codexWebAPIDefaultModel = "gpt-5.5"
    public static let remoteOpenAIBaseURL = "https://api.openai.com/v1"
    public static let codexAgentBaseURL = "codex://app-server"

    public var isEnabled: Bool
    public var provider: ChumenAIProvider
    public var baseURL: String
    public var model: String
    public var temperature: Double

    public init(
        isEnabled: Bool = true,
        provider: ChumenAIProvider = .localOllama,
        baseURL: String = Self.localOllamaBaseURL,
        model: String = Self.localOllamaDefaultModel,
        temperature: Double = 0.2
    ) {
        self.isEnabled = isEnabled
        self.provider = provider
        self.baseURL = baseURL
        self.model = model
        self.temperature = temperature
    }

    public var usesLocalOllama: Bool {
        provider == .localOllama
    }

    public var usesCodexAgent: Bool {
        provider == .codexAgent
    }

    public var usesCodexWebAPI: Bool {
        provider == .codexWebAPI
    }

    public var requiresAPIKey: Bool {
        provider == .customEndpoint
    }

    public var acceptsOptionalAPIKey: Bool {
        provider == .codexWebAPI
    }

    public mutating func useLocalOllamaDefaults() {
        let wasLocalOllama = provider == .localOllama
        isEnabled = true
        provider = .localOllama
        baseURL = Self.localOllamaBaseURL
        // Local Ollama must be driven by the machine's actual /api/tags list. When switching from a
        // custom endpoint, drop the remote model so the UI forces a local model choice.
        if !wasLocalOllama {
            model = Self.localOllamaDefaultModel
        }
    }

    public mutating func useCustomEndpointDefaults() {
        isEnabled = true
        provider = .customEndpoint
        baseURL = Self.remoteOpenAIBaseURL
        model = ""
    }

    public mutating func useCodexWebAPIDefaults() {
        isEnabled = true
        provider = .codexWebAPI
        baseURL = Self.codexWebAPIBaseURL
        model = Self.codexWebAPIDefaultModel
    }

    public mutating func useCodexAgentDefaults() {
        isEnabled = true
        provider = .codexAgent
        baseURL = Self.codexAgentBaseURL
        model = ""
    }

    enum CodingKeys: String, CodingKey {
        case isEnabled
        case provider
        case baseURL
        case model
        case temperature
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        isEnabled = try container.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? true
        baseURL = try container.decodeIfPresent(String.self, forKey: .baseURL) ?? Self.localOllamaBaseURL
        model = try container.decodeIfPresent(String.self, forKey: .model) ?? Self.localOllamaDefaultModel
        temperature = try container.decodeIfPresent(Double.self, forKey: .temperature) ?? 0.2
        if let decodedProvider = try container.decodeIfPresent(ChumenAIProvider.self, forKey: .provider) {
            if decodedProvider == .codexAgent {
                provider = .codexWebAPI
                if baseURL == Self.codexAgentBaseURL {
                    baseURL = Self.codexWebAPIBaseURL
                }
                if model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    model = Self.codexWebAPIDefaultModel
                }
            } else {
                provider = decodedProvider
            }
        } else {
            provider = Self.inferredLegacyProvider(baseURL: baseURL)
        }
    }

    private static func inferredLegacyProvider(baseURL: String) -> ChumenAIProvider {
        guard let components = URLComponents(string: baseURL.trimmingCharacters(in: .whitespacesAndNewlines)),
              let host = components.host?.lowercased() else {
            return .customEndpoint
        }
        let localHosts: Set<String> = ["127.0.0.1", "localhost", "::1"]
        if localHosts.contains(host), (components.port ?? 11434) == 11434 {
            return .localOllama
        }
        if localHosts.contains(host), components.port == 18080 {
            return .codexWebAPI
        }
        return .customEndpoint
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
    Product help and configuration editing questions do not require the mihomo core API to be connected.

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

    Chumen app knowledge summary:
    - Chumen app knowledge answers where to operate in the GUI, how profile editing works, what requires
      review, and why core/API/TUN/PIN states behave as they do.
    - mihomo knowledge answers field-level YAML syntax, protocol fields, and controller API behavior.
    - Prefer Chumen app knowledge for usage/tutorial questions, then use mihomo knowledge for exact config fields.
    - Append overlays support proxies, proxy-groups, and rules with prepend, append, and delete operations.
    - A core API outage affects live runtime data and tools, but not profile editing guidance or offline drafts.

    How to add a proxy node in Chumen:
    - This is a profile editing task, not a live core API task.
    - Open Config, choose the target profile, then use Edit Nodes.
    - In the append overlay editor, choose prepend or append, fill name, node type, server, port,
      and protocol-specific fields. Node type and port may be custom typed, not only selected.
    - Save the profile overlay, then apply or reload the runtime config. If the core is stopped,
      the change takes effect the next time it starts.
    - If the user has a subscription URL, import the subscription instead of manually adding nodes.
      If traffic should use the new node, add it to a proxy group and add or adjust rules.

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

    /// Intent: common product-help questions should not be sent through runtime status reasoning.
    /// Local models tend to overfit the current "core API unavailable" context, so deterministic
    /// answers keep help/tutorial flows useful even when the mihomo controller is stopped.
    public static func localHelpAnswer(for prompt: String, language: AppLanguage) -> String? {
        let normalized = prompt.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard isHowToQuestion(normalized), mentionsProxyAddition(normalized) else { return nil }

        switch resolved(language) {
        case .zhHans:
            return """
            添加代理不需要先连接内核 API，这是配置编辑问题：
            1. 打开“配置”，找到要修改的配置。
            2. 点“编辑节点”，在“追加覆盖”里选“前置追加 prepend”或“后置追加 append”。
            3. 填名称、节点类型、服务器、端口和协议字段；节点类型和端口都可以手动输入，不限下拉项。
            4. 保存后应用或重载配置；内核运行时会热重载，没运行时下次启动生效。
            订阅链接走“导入订阅”；要让流量使用新节点，再到“编辑代理组/编辑规则”把它加进策略。
            """
        case .en, .system:
            return """
            Adding a proxy does not require the core API first; it is a profile editing task:
            1. Open Config and choose the profile you want to edit.
            2. Click Edit Nodes, then choose prepend or append in the append overlay.
            3. Fill name, node type, server, port, and protocol fields. Node type and port accept custom typed values.
            4. Save, then apply or reload the runtime config. If the core is stopped, it takes effect on next start.
            For a subscription URL, use Import Subscription. To route traffic through the new node, add it to a proxy group and adjust rules.
            """
        }
    }

    private static func resolved(_ language: AppLanguage) -> AppLanguage {
        switch language {
        case .system:
            AppLanguage.defaultLanguage()
        case .zhHans, .en:
            language
        }
    }

    private static func isHowToQuestion(_ prompt: String) -> Bool {
        containsAny(prompt, [
            "如何", "怎么", "怎样", "咋", "教程", "步骤", "不会",
            "how", "where", "guide", "tutorial", "steps"
        ])
    }

    private static func mentionsProxyAddition(_ prompt: String) -> Bool {
        containsAny(prompt, ["添加", "新增", "增加", "导入", "add", "create", "import"]) &&
            containsAny(prompt, ["代理", "节点", "订阅", "proxy", "node", "subscription"])
    }

    private static func containsAny(_ text: String, _ needles: [String]) -> Bool {
        needles.contains { text.contains($0) }
    }
}

public struct ChumenAIClient: Sendable {
    public init() {}

    public func listOllamaModels(baseURL: String) async throws -> [String] {
        guard var components = URLComponents(string: baseURL.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            throw ChumenError.commandFailed("Invalid Ollama base URL.")
        }
        // Ollama's OpenAI-compatible chat endpoint lives under /v1, while the local model catalog
        // is served by /api/tags. Build the catalog URL from the configured host/port instead of
        // assuming the user kept the default URL string.
        components.path = "/api/tags"
        components.query = nil
        guard let url = components.url else {
            throw ChumenError.commandFailed("Invalid Ollama model URL.")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 3

        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw ChumenError.httpStatus(http.statusCode, body)
        }

        let decoded = try JSONDecoder().decode(OllamaTagsResponse.self, from: data)
        return decoded.models
            .map { $0.name.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    public func complete(
        settings: ChumenAISettings,
        apiKey: String,
        systemPrompt: String,
        messages: [ChumenAIChatMessage]
    ) async throws -> ChumenAIResponse {
        if settings.usesCodexAgent {
            return try await ChumenCodexAppServerClient().complete(
                settings: settings,
                systemPrompt: systemPrompt,
                messages: messages
            )
        }

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

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let authorizationKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        if !authorizationKey.isEmpty {
            request.setValue("Bearer \(authorizationKey)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = try Self.chatCompletionsRequestBody(
            settings: settings,
            systemPrompt: systemPrompt,
            messages: messages
        )

        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw ChumenError.httpStatus(http.statusCode, body)
        }

        let decoded = try JSONDecoder().decode(OpenAIChatResponse.self, from: data)
        let content = decoded.choices.first?.message.content.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return Self.parseAssistantContent(content)
    }

    static func chatCompletionsRequestBody(
        settings: ChumenAISettings,
        systemPrompt: String,
        messages: [ChumenAIChatMessage]
    ) throws -> Data {
        let requestMessages = [OpenAIChatMessage(role: .system, content: systemPrompt)] + messages.map {
            OpenAIChatMessage(role: $0.role, content: $0.content)
        }
        let payload = OpenAIChatRequest(
            model: settings.model.trimmingCharacters(in: .whitespacesAndNewlines),
            messages: requestMessages,
            temperature: settings.usesCodexWebAPI ? nil : settings.temperature,
            reasoningEffort: settings.usesCodexWebAPI ? "low" : nil
        )
        return try JSONEncoder().encode(payload)
    }

    static func parseAssistantContent(_ content: String) -> ChumenAIResponse {
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
    let temperature: Double?
    let reasoningEffort: String?

    enum CodingKeys: String, CodingKey {
        case model
        case messages
        case temperature
        case reasoningEffort = "reasoning_effort"
    }
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

private struct OllamaTagsResponse: Decodable {
    struct Model: Decodable {
        let name: String
    }

    let models: [Model]
}
