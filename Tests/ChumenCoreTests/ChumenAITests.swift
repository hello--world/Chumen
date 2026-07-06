import XCTest
@testable import ChumenCore

final class ChumenAITests: XCTestCase {
    func testRuntimeSettingsDecodesDefaultAISettingsWhenMissing() throws {
        let data = Data(#"{"corePath":"/tmp/mihomo"}"#.utf8)
        let settings = try JSONDecoder().decode(ChumenRuntimeSettings.self, from: data)

        XCTAssertTrue(settings.ai.isEnabled)
        XCTAssertEqual(settings.ai.baseURL, ChumenAISettings.localOllamaBaseURL)
        XCTAssertEqual(settings.ai.model, ChumenAISettings.localOllamaDefaultModel)
        XCTAssertEqual(settings.ai.provider, .localOllama)
        XCTAssertTrue(settings.ai.usesLocalOllama)
        XCTAssertFalse(settings.ai.requiresAPIKey)
    }

    func testLegacyRemoteAISettingsInferCustomEndpointProvider() throws {
        let data = Data("""
        {
          "corePath": "/tmp/mihomo",
          "ai": {
            "isEnabled": true,
            "baseURL": "https://api.openai.com/v1",
            "model": "gpt-test",
            "temperature": 0.1
          }
        }
        """.utf8)

        let settings = try JSONDecoder().decode(ChumenRuntimeSettings.self, from: data)

        XCTAssertEqual(settings.ai.provider, .customEndpoint)
        XCTAssertFalse(settings.ai.usesLocalOllama)
        XCTAssertTrue(settings.ai.requiresAPIKey)
    }

    func testLegacyLocalCodexAPISettingsInferCodexWebAPIProvider() throws {
        let data = Data("""
        {
          "corePath": "/tmp/mihomo",
          "ai": {
            "isEnabled": true,
            "baseURL": "http://127.0.0.1:18080/v1",
            "model": "gpt-5.5",
            "temperature": 0.1
          }
        }
        """.utf8)

        let settings = try JSONDecoder().decode(ChumenRuntimeSettings.self, from: data)

        XCTAssertEqual(settings.ai.provider, .codexWebAPI)
        XCTAssertTrue(settings.ai.usesCodexWebAPI)
        XCTAssertFalse(settings.ai.requiresAPIKey)
        XCTAssertTrue(settings.ai.acceptsOptionalAPIKey)
    }

    func testLocalOllamaDefaultsDoNotHardcodeModel() {
        var settings = ChumenAISettings(
            provider: .customEndpoint,
            baseURL: ChumenAISettings.remoteOpenAIBaseURL,
            model: "remote-model"
        )

        settings.useLocalOllamaDefaults()

        XCTAssertEqual(settings.baseURL, ChumenAISettings.localOllamaBaseURL)
        XCTAssertEqual(settings.model, "")
    }

    func testLocalOllamaDefaultsKeepExistingLocalChoice() {
        var settings = ChumenAISettings(model: "llama3.2:latest")

        settings.useLocalOllamaDefaults()

        XCTAssertEqual(settings.model, "llama3.2:latest")
    }

    func testRuntimeSettingsPersistsSelectedAIModel() throws {
        let settings = ChumenRuntimeSettings(
            corePath: "/tmp/mihomo",
            ai: ChumenAISettings(model: "gemma4:26b")
        )

        let data = try JSONEncoder().encode(settings)
        let decoded = try JSONDecoder().decode(ChumenRuntimeSettings.self, from: data)

        XCTAssertEqual(decoded.ai.model, "gemma4:26b")
        XCTAssertTrue(decoded.ai.usesLocalOllama)
    }

    func testRuntimeSettingsPersistsCodexWebAPIProviderWithOptionalAccessKey() throws {
        let settings = ChumenRuntimeSettings(
            corePath: "/tmp/mihomo",
            ai: ChumenAISettings(
                provider: .codexWebAPI,
                baseURL: ChumenAISettings.codexWebAPIBaseURL,
                model: ChumenAISettings.codexWebAPIDefaultModel
            )
        )

        let data = try JSONEncoder().encode(settings)
        let decoded = try JSONDecoder().decode(ChumenRuntimeSettings.self, from: data)

        XCTAssertEqual(decoded.ai.provider, .codexWebAPI)
        XCTAssertTrue(decoded.ai.usesCodexWebAPI)
        XCTAssertFalse(decoded.ai.requiresAPIKey)
        XCTAssertTrue(decoded.ai.acceptsOptionalAPIKey)
        XCTAssertEqual(decoded.ai.model, ChumenAISettings.codexWebAPIDefaultModel)
    }

    func testCodexWebAPIRequestBodyOmitsTemperature() throws {
        let settings = ChumenAISettings(
            provider: .codexWebAPI,
            baseURL: ChumenAISettings.codexWebAPIBaseURL,
            model: ChumenAISettings.codexWebAPIDefaultModel,
            temperature: 0.7
        )

        let data = try ChumenAIClient.chatCompletionsRequestBody(
            settings: settings,
            systemPrompt: "Return JSON.",
            messages: [ChumenAIChatMessage(role: .user, content: "hello")]
        )
        let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        XCTAssertEqual(object?["model"] as? String, ChumenAISettings.codexWebAPIDefaultModel)
        XCTAssertNil(object?["temperature"])
        XCTAssertEqual(object?["reasoning_effort"] as? String, "low")
    }

    func testLegacyCodexAgentSettingsMigrateToCodexWebAPI() throws {
        let settings = ChumenRuntimeSettings(
            corePath: "/tmp/mihomo",
            ai: ChumenAISettings(
                provider: .codexAgent,
                baseURL: ChumenAISettings.codexAgentBaseURL,
                model: ""
            )
        )

        let data = try JSONEncoder().encode(settings)
        let decoded = try JSONDecoder().decode(ChumenRuntimeSettings.self, from: data)

        XCTAssertEqual(decoded.ai.provider, .codexWebAPI)
        XCTAssertTrue(decoded.ai.usesCodexWebAPI)
        XCTAssertEqual(decoded.ai.baseURL, ChumenAISettings.codexWebAPIBaseURL)
        XCTAssertEqual(decoded.ai.model, ChumenAISettings.codexWebAPIDefaultModel)
    }

    func testAIResponseDecodesLegacyActionsAsPendingChanges() throws {
        let data = Data("""
        {
          "reply": "等待审核",
          "actions": [
            {
              "kind": "setMode",
              "title": "切换模式",
              "mode": "global"
            }
          ]
        }
        """.utf8)

        let response = try JSONDecoder().decode(ChumenAIResponse.self, from: data)

        XCTAssertEqual(response.reply, "等待审核")
        XCTAssertEqual(response.changes.count, 1)
        XCTAssertEqual(response.changes.first?.kind, .setMode)
        XCTAssertEqual(response.changes.first?.mode, .global)
    }

    func testAIResponseDecodesConfigAppendixDraft() throws {
        let data = Data("""
        {
          "reply": "生成了 YAML 草稿",
          "changes": [
            {
              "kind": "setConfigAppendix",
              "title": "追加 DNS",
              "configAppendixYAML": "dns:\\n  enable: true"
            }
          ]
        }
        """.utf8)

        let response = try JSONDecoder().decode(ChumenAIResponse.self, from: data)

        XCTAssertEqual(response.changes.first?.kind, .setConfigAppendix)
        XCTAssertEqual(response.changes.first?.configAppendixYAML, "dns:\n  enable: true")
    }

    func testCodexAgentTurnPromptKeepsTranscriptAndForbidsDirectMutation() {
        let prompt = ChumenCodexAppServerClient.codexTurnPrompt(messages: [
            ChumenAIChatMessage(role: .user, content: "帮我打开 TUN"),
            ChumenAIChatMessage(role: .assistant, content: "等待审核"),
            ChumenAIChatMessage(role: .user, content: "改成 rule")
        ])

        XCTAssertTrue(prompt.contains("USER:"))
        XCTAssertTrue(prompt.contains("帮我打开 TUN"))
        XCTAssertTrue(prompt.contains("Codex MCP tools"))
        XCTAssertTrue(prompt.contains("do not edit files"))
        XCTAssertTrue(prompt.contains("Return only the JSON object"))
    }

    func testCodexAgentLiveSmoke() async throws {
        guard ProcessInfo.processInfo.environment["CHUMEN_LIVE_CODEX_SMOKE"] == "1" else {
            throw XCTSkip("Set CHUMEN_LIVE_CODEX_SMOKE=1 to exercise the local Codex app-server.")
        }

        let response = try await ChumenCodexAppServerClient(timeoutSeconds: 90).complete(
            settings: ChumenAISettings(
                provider: .codexAgent,
                baseURL: ChumenAISettings.codexAgentBaseURL,
                model: ""
            ),
            systemPrompt: """
            Return only JSON in this exact shape:
            {"reply":"OK","changes":[]}
            """,
            messages: [
                ChumenAIChatMessage(role: .user, content: "只回复 OK")
            ]
        )

        XCTAssertEqual(response.reply.trimmingCharacters(in: .whitespacesAndNewlines), "OK")
        XCTAssertTrue(response.changes.isEmpty)
    }

    func testKnowledgeBaseAnswersAddProxyHelpWithoutCoreAPI() {
        let answer = ChumenAIKnowledgeBase.localHelpAnswer(
            for: "我要如何添加代理",
            language: .zhHans
        )

        XCTAssertNotNil(answer)
        XCTAssertTrue(answer?.contains("不需要先连接内核 API") == true)
        XCTAssertTrue(answer?.contains("前置追加 prepend") == true)
        XCTAssertTrue(answer?.contains("端口") == true)
    }

    func testKnowledgeBaseDoesNotInterceptConcreteProxyDraftRequest() {
        let answer = ChumenAIKnowledgeBase.localHelpAnswer(
            for: "帮我添加一个 vless 节点，服务器 1.1.1.1，端口 443",
            language: .zhHans
        )

        XCTAssertNil(answer)
    }

    func testKnowledgeStoreRetrievesChumenProxyWorkflow() {
        let context = ChumenAIKnowledgeStore.context(
            for: "我要如何添加代理",
            language: .zhHans,
            maxDocuments: 4,
            maxCharacters: 5_000
        )

        XCTAssertTrue(context.contains("Chumen") || context.contains("配置"))
        XCTAssertTrue(
            context.contains("编辑节点")
                || context.contains("追加")
                || context.contains("Add A Proxy Node")
        )
    }

    func testKnowledgeStoreRetrievesMihomoTunKnowledge() {
        let context = ChumenAIKnowledgeStore.context(
            for: "TUN macOS utun NetworkExtension",
            language: .en,
            maxDocuments: 4,
            maxCharacters: 5_000
        ).lowercased()

        XCTAssertTrue(context.contains("tun"))
        XCTAssertTrue(context.contains("mihomo") || context.contains("networkextension"))
    }
}
