import ChumenCore
import Foundation
import Textual

enum AIAssistantRendering {
    // The assistant lives on the overview page, so transcript rendering cost directly affects tab
    // switching. Keep only the visible window hot; AppModel still owns the complete conversation for
    // prompt context and persistence.
    static let visibleMessageLimit = 18

    // Textual renders cached AttributedString documents, but pathological model output can still
    // produce very large layout trees. Keep oversized replies selectable as plain text instead of
    // blocking navigation.
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
        // AI replies should not trigger implicit remote image or attachment work, so image syntax is
        // rendered as a normal link instead.
        content.replacingOccurrences(of: "![", with: "[")
    }
}

struct AIAssistantMarkdownDocument {
    let source: String
    let attributedString: AttributedString
}

struct CachedAIMarkdownParser: MarkupParser {
    let attributedString: AttributedString

    func attributedString(for input: String) throws -> AttributedString {
        attributedString
    }
}

@MainActor
final class AIAssistantMarkdownCache: ObservableObject {
    private var entries: [String: AIAssistantMarkdownDocument] = [:]
    private var fingerprints: [String: String] = [:]
    private let parser = AttributedStringMarkdownParser(baseURL: nil)

    func prepare(messages: [ChumenAIChatMessage]) {
        let visibleMessages = AIAssistantRendering.visibleMessages(from: messages)
        var nextEntries: [String: AIAssistantMarkdownDocument] = [:]
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

            let source = AIAssistantRendering.markdownSource(for: message.content)
            guard let attributedString = try? parser.attributedString(for: source) else { continue }
            nextEntries[message.id] = AIAssistantMarkdownDocument(
                source: source,
                attributedString: attributedString
            )
        }

        guard nextFingerprints != fingerprints else { return }
        objectWillChange.send()
        entries = nextEntries
        fingerprints = nextFingerprints
    }

    func document(for message: ChumenAIChatMessage) -> AIAssistantMarkdownDocument? {
        guard fingerprints[message.id] == Self.fingerprint(for: message) else { return nil }
        return entries[message.id]
    }

    private static func fingerprint(for message: ChumenAIChatMessage) -> String {
        "\(message.content.count):\(message.content.hashValue)"
    }
}
