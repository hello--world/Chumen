import ChumenCore
import Foundation
import MarkdownUI

enum AIAssistantRendering {
    // The assistant lives on the overview page, so transcript rendering cost directly affects tab
    // switching. Keep only the visible window hot; AppModel still owns the complete conversation for
    // prompt context and persistence.
    static let visibleMessageLimit = 18

    // MarkdownUI is cached per message, but pathological model output can still produce very large
    // layout trees. Keep oversized replies selectable as plain text instead of blocking navigation.
    static let markdownCharacterLimit = 24_000

    static func visibleMessages(from messages: [ChumenAIChatMessage]) -> [ChumenAIChatMessage] {
        guard messages.count > visibleMessageLimit else { return messages }
        return Array(messages.suffix(visibleMessageLimit))
    }

    static func shouldRenderMarkdown(_ content: String) -> Bool {
        guard content.count <= markdownCharacterLimit else { return false }
        return content.contains("*") ||
            content.contains("#") ||
            content.contains("`") ||
            content.contains("[") ||
            content.contains("- ") ||
            content.contains("1. ") ||
            content.contains(">") ||
            content.contains("|")
    }

    static func markdownSource(for content: String) -> String {
        // MarkdownUI supports images through NetworkImage. AI replies should not trigger implicit
        // remote image loads, so image syntax is rendered as a normal link instead.
        content.replacingOccurrences(of: "![", with: "[")
    }
}

@MainActor
final class AIAssistantMarkdownCache: ObservableObject {
    private var entries: [String: MarkdownContent] = [:]
    private var fingerprints: [String: String] = [:]

    func prepare(messages: [ChumenAIChatMessage]) {
        let visibleMessages = AIAssistantRendering.visibleMessages(from: messages)
        var nextEntries: [String: MarkdownContent] = [:]
        var nextFingerprints: [String: String] = [:]

        for message in visibleMessages {
            let fingerprint = Self.fingerprint(for: message)
            nextFingerprints[message.id] = fingerprint

            if fingerprints[message.id] == fingerprint, let cached = entries[message.id] {
                nextEntries[message.id] = cached
                continue
            }

            guard AIAssistantRendering.shouldRenderMarkdown(message.content) else {
                continue
            }

            nextEntries[message.id] = MarkdownContent(
                AIAssistantRendering.markdownSource(for: message.content)
            )
        }

        guard nextFingerprints != fingerprints else { return }
        entries = nextEntries
        fingerprints = nextFingerprints
        objectWillChange.send()
    }

    func content(for message: ChumenAIChatMessage) -> MarkdownContent? {
        guard fingerprints[message.id] == Self.fingerprint(for: message) else { return nil }
        return entries[message.id]
    }

    private static func fingerprint(for message: ChumenAIChatMessage) -> String {
        "\(message.content.count):\(message.content.hashValue)"
    }
}
