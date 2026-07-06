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

struct AIAssistantMarkdownDocument: Sendable {
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
    private var prepareTask: Task<Void, Never>?

    func prepare(messages: [ChumenAIChatMessage], log: ((String) -> Void)? = nil) {
        let visibleMessages = AIAssistantRendering.visibleMessages(from: messages)
        var nextEntries: [String: AIAssistantMarkdownDocument] = [:]
        var nextFingerprints: [String: String] = [:]
        var jobs: [MarkdownRenderJob] = []

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
            jobs.append(
                MarkdownRenderJob(
                    id: message.id,
                    source: source,
                    characterCount: message.content.count
                )
            )
        }

        guard nextFingerprints != fingerprints else { return }
        prepareTask?.cancel()
        objectWillChange.send()
        entries = nextEntries
        fingerprints = nextFingerprints

        guard !jobs.isEmpty else {
            prepareTask = nil
            log?("ai markdown cache updated; visibleMessages=\(visibleMessages.count); renderJobs=0")
            return
        }

        let totalCharacters = jobs.reduce(0) { $0 + $1.characterCount }
        log?(
            "ai markdown render start; visibleMessages=\(visibleMessages.count); " +
                "renderJobs=\(jobs.count); characters=\(totalCharacters)"
        )

        prepareTask = Task { [weak self, nextFingerprints, nextEntries, jobs] in
            let started = Date()
            let renderedEntries = await Task.detached(priority: .utility) {
                var rendered: [String: AIAssistantMarkdownDocument] = [:]
                for job in jobs {
                    if Task.isCancelled { return rendered }
                    guard let attributedString = try? AttributedString(markdown: job.source) else {
                        continue
                    }
                    rendered[job.id] = AIAssistantMarkdownDocument(
                        source: job.source,
                        attributedString: attributedString
                    )
                }
                return rendered
            }.value

            guard !Task.isCancelled, let self else { return }
            guard self.fingerprints == nextFingerprints else {
                log?("ai markdown render discarded; newer transcript is active")
                return
            }

            var completedEntries = nextEntries
            for (id, document) in renderedEntries {
                completedEntries[id] = document
            }
            self.prepareTask = nil
            self.objectWillChange.send()
            self.entries = completedEntries
            let elapsedMs = Int(Date().timeIntervalSince(started) * 1_000)
            log?(
                "ai markdown render finished; rendered=\(renderedEntries.count)/\(jobs.count); " +
                    "elapsedMs=\(elapsedMs)"
            )
        }
    }

    func document(for message: ChumenAIChatMessage) -> AIAssistantMarkdownDocument? {
        guard fingerprints[message.id] == Self.fingerprint(for: message) else { return nil }
        return entries[message.id]
    }

    private static func fingerprint(for message: ChumenAIChatMessage) -> String {
        "\(message.content.count):\(message.content.hashValue)"
    }

    private struct MarkdownRenderJob: Sendable {
        let id: String
        let source: String
        let characterCount: Int
    }
}
