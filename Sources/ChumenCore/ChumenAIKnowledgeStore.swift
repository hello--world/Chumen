import Foundation

public struct ChumenAIKnowledgeSnippet: Equatable, Sendable {
    public let title: String
    public let source: String
    public let excerpt: String
    public let score: Int
}

public enum ChumenAIKnowledgeStore {
    // Intent: the app chat needs practical product knowledge even when the core is offline.
    // Bundle a small markdown snapshot and retrieve relevant excerpts locally instead of relying on
    // the model to infer Chumen workflows from live runtime status.
    public static func context(
        for prompt: String,
        language: AppLanguage,
        maxDocuments: Int = 4,
        maxCharacters: Int = 6_500
    ) -> String {
        snippets(
            for: prompt,
            language: language,
            maxDocuments: maxDocuments,
            maxCharacters: maxCharacters
        )
        .map { snippet in
            """
            Source: \(snippet.source)
            Title: \(snippet.title)
            \(snippet.excerpt)
            """
        }
        .joined(separator: "\n\n---\n\n")
    }

    public static func snippets(
        for prompt: String,
        language: AppLanguage,
        maxDocuments: Int = 4,
        maxCharacters: Int = 6_500
    ) -> [ChumenAIKnowledgeSnippet] {
        let terms = queryTerms(for: prompt)
        guard !terms.isEmpty else { return [] }

        var remainingCharacters = max(0, maxCharacters)
        guard remainingCharacters > 0 else { return [] }

        return documents
            .map { document in
                (document, score(document: document, terms: terms, language: language))
            }
            .filter { $0.1 > 0 }
            .sorted {
                if $0.1 != $1.1 {
                    return $0.1 > $1.1
                }
                return $0.0.source < $1.0.source
            }
            .prefix(max(0, maxDocuments))
            .compactMap { document, score in
                guard remainingCharacters > 0 else { return nil }
                let limit = min(2_000, remainingCharacters)
                let excerpt = excerpt(from: document.content, terms: terms, maxCharacters: limit)
                remainingCharacters -= excerpt.count
                return ChumenAIKnowledgeSnippet(
                    title: document.title,
                    source: document.source,
                    excerpt: excerpt,
                    score: score
                )
            }
    }

    private struct KnowledgeDocument: Sendable {
        let title: String
        let source: String
        let content: String
    }

    private static let documents: [KnowledgeDocument] = loadDocuments()

    private static func loadDocuments() -> [KnowledgeDocument] {
        knowledgeRoots()
            .flatMap(markdownFiles(in:))
            .compactMap { url in
                guard let content = try? String(contentsOf: url, encoding: .utf8) else { return nil }
                return KnowledgeDocument(
                    title: title(from: content, fallback: url.deletingPathExtension().lastPathComponent),
                    source: sourcePath(for: url),
                    content: content
                )
            }
            .sorted { $0.source < $1.source }
    }

    private static func knowledgeRoots() -> [URL] {
        var roots: [URL] = []
        for bundled in bundledKnowledgeRoots() where FileManager.default.fileExists(atPath: bundled.path) {
            roots.append(bundled)
        }

        let workingDirectory = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let developmentRoot = workingDirectory.appendingPathComponent(
            "Sources/ChumenCore/Resources/Knowledge",
            isDirectory: true
        )
        if FileManager.default.fileExists(atPath: developmentRoot.path), !roots.contains(developmentRoot) {
            roots.append(developmentRoot)
        }
        return roots
    }

    private static func bundledKnowledgeRoots() -> [URL] {
        let bundleName = "Chumen_ChumenCore.bundle"
        let candidates = [
            // SwiftPM's generated Bundle.module accessor expects package resource bundles beside
            // the app bundle root when an executable is hand-wrapped as a macOS .app.
            Bundle.main.bundleURL.appendingPathComponent(bundleName, isDirectory: true),
            // Older Chumen packages placed the resource bundle in the conventional macOS Resources
            // directory. Keep this fallback so missing package resources reduce AI context instead
            // of crashing the whole app.
            Bundle.main.resourceURL?.appendingPathComponent(bundleName, isDirectory: true)
        ].compactMap { $0 }

        return candidates.map { bundleURL in
            bundleURL
                .appendingPathComponent("Resources", isDirectory: true)
                .appendingPathComponent("Knowledge", isDirectory: true)
        }
    }

    private static func markdownFiles(in root: URL) -> [URL] {
        guard let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        return enumerator.compactMap { item -> URL? in
            guard let url = item as? URL, url.pathExtension.lowercased() == "md" else { return nil }
            return url
        }
    }

    private static func title(from content: String, fallback: String) -> String {
        if let frontmatterTitle = content
            .components(separatedBy: .newlines)
            .first(where: { $0.trimmingCharacters(in: .whitespaces).hasPrefix("title:") })?
            .split(separator: ":", maxSplits: 1)
            .last?
            .trimmingCharacters(in: CharacterSet(charactersIn: " \"")) {
            return frontmatterTitle
        }

        if let heading = content
            .components(separatedBy: .newlines)
            .first(where: { $0.hasPrefix("# ") }) {
            return String(heading.dropFirst(2)).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return fallback
    }

    private static func sourcePath(for url: URL) -> String {
        let path = url.path
        guard let range = path.range(of: "Knowledge/") else {
            return url.lastPathComponent
        }
        return String(path[range.upperBound...])
    }

    private static func queryTerms(for prompt: String) -> [String] {
        let lowercased = prompt.lowercased()
        var terms = Set<String>()
        for token in lowercased.components(separatedBy: CharacterSet.alphanumerics.inverted) {
            if token.count >= 2 {
                terms.insert(token)
            }
        }

        let aliases: [(needles: [String], terms: [String])] = [
            (["代理", "节点", "proxy", "node"], ["代理", "节点", "proxy", "proxies", "node", "adapter"]),
            (["规则", "命中", "rule"], ["规则", "命中", "rule", "rules", "match"]),
            (["订阅", "subscription", "provider"], ["订阅", "subscription", "provider", "proxy-provider"]),
            (["追加", "覆盖", "prepend", "append", "delete"], ["追加", "覆盖", "prepend", "append", "delete", "overlay"]),
            (["tun", "utun", "vpn"], ["tun", "utun", "vpn", "helper", "networkextension"]),
            (["系统代理", "networksetup", "system proxy"], ["系统代理", "networksetup", "system proxy"]),
            (["内核", "core", "api", "controller"], ["内核", "core", "api", "controller", "mihomo"]),
            (["配置", "yaml", "config"], ["配置", "yaml", "config", "profile"]),
            (["智能体", "ai", "ollama", "chat"], ["智能体", "assistant", "ai", "ollama", "chat"]),
            (["错误", "失败", "无法", "排障", "troubleshoot", "failed"], ["错误", "失败", "无法", "排障", "troubleshooting", "failed"])
        ]
        for alias in aliases where alias.needles.contains(where: { lowercased.contains($0) }) {
            terms.formUnion(alias.terms)
        }
        return Array(terms)
    }

    private static func score(document: KnowledgeDocument, terms: [String], language: AppLanguage) -> Int {
        let haystack = "\(document.title)\n\(document.source)\n\(document.content)".lowercased()
        var score = 0
        for term in terms {
            guard !term.isEmpty else { continue }
            let titleWeight = document.title.lowercased().contains(term) ? 8 : 0
            let sourceWeight = document.source.lowercased().contains(term) ? 4 : 0
            let bodyWeight = min(8, haystack.components(separatedBy: term).count - 1)
            score += titleWeight + sourceWeight + bodyWeight
        }

        if document.source.hasPrefix("chumen/") {
            score += 5
        }
        switch resolved(language) {
        case .zhHans:
            if document.source.hasSuffix(".zh.md") { score += 6 }
            if document.source.hasSuffix(".en.md") { score -= 4 }
        case .en, .system:
            if document.source.hasSuffix(".en.md") { score += 6 }
            if document.source.hasSuffix(".zh.md") { score -= 4 }
        }
        return score
    }

    private static func excerpt(from content: String, terms: [String], maxCharacters: Int) -> String {
        let cleaned = content
            .components(separatedBy: .newlines)
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("---") }
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard cleaned.count > maxCharacters else { return cleaned }

        let lowercased = cleaned.lowercased()
        let firstMatchOffset = terms
            .compactMap { term -> Int? in
                guard let range = lowercased.range(of: term.lowercased()) else { return nil }
                return lowercased.distance(from: lowercased.startIndex, to: range.lowerBound)
            }
            .min() ?? 0
        let startOffset = max(0, firstMatchOffset - 420)
        let endOffset = min(cleaned.count, startOffset + maxCharacters)
        let start = cleaned.index(cleaned.startIndex, offsetBy: startOffset)
        let end = cleaned.index(cleaned.startIndex, offsetBy: endOffset)
        let prefix = startOffset > 0 ? "...\n" : ""
        let suffix = endOffset < cleaned.count ? "\n..." : ""
        return prefix + cleaned[start..<end].trimmingCharacters(in: .whitespacesAndNewlines) + suffix
    }

    private static func resolved(_ language: AppLanguage) -> AppLanguage {
        switch language {
        case .system:
            AppLanguage.defaultLanguage()
        case .zhHans, .en:
            language
        }
    }
}
