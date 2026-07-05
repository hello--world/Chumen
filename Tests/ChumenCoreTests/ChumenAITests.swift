import XCTest
@testable import ChumenCore

final class ChumenAITests: XCTestCase {
    func testRuntimeSettingsDecodesDefaultAISettingsWhenMissing() throws {
        let data = Data(#"{"corePath":"/tmp/mihomo"}"#.utf8)
        let settings = try JSONDecoder().decode(ChumenRuntimeSettings.self, from: data)

        XCTAssertTrue(settings.ai.isEnabled)
        XCTAssertEqual(settings.ai.baseURL, ChumenAISettings.localOllamaBaseURL)
        XCTAssertEqual(settings.ai.model, ChumenAISettings.localOllamaDefaultModel)
        XCTAssertTrue(settings.ai.usesLocalOllama)
        XCTAssertFalse(settings.ai.requiresAPIKey)
    }

    func testLocalOllamaDefaultsDoNotHardcodeModel() {
        var settings = ChumenAISettings(
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
}
