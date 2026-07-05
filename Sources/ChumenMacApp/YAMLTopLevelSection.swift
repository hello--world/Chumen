import ChumenCore

struct YAMLTopLevelSection: Equatable, Sendable {
    var key: String
    var body: String

    static func parse(_ yaml: String) -> [YAMLTopLevelSection] {
        let lines = yaml.components(separatedBy: .newlines)
        var sections: [YAMLTopLevelSection] = []
        var currentKey: String?
        var currentInlineValue = ""
        var currentBody: [String] = []

        func flush() {
            guard let currentKey else { return }
            let body = currentBody.isEmpty
                ? currentInlineValue
                : currentBody.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            sections.append(YAMLTopLevelSection(key: currentKey, body: body))
        }

        for line in lines {
            if let key = ChumenConfigurationBuilder.topLevelKey(in: line) {
                flush()
                currentKey = key
                currentInlineValue = topLevelValue(in: line)
                currentBody = []
            } else if currentKey != nil {
                currentBody.append(line)
            }
        }

        flush()
        return sections
    }

    static func render(_ sections: [YAMLTopLevelSection]) -> String {
        sections
            .map(renderSection)
            .filter { !$0.isEmpty }
            .joined(separator: "\n\n")
    }

    private static func renderSection(_ section: YAMLTopLevelSection) -> String {
        let key = section.key.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ":", with: "")
        guard !key.isEmpty else { return "" }

        let body = section.body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !body.isEmpty else { return "\(key):" }

        if shouldRenderInline(body) {
            return "\(key): \(body)"
        }

        return "\(key):\n\(indented(body))"
    }

    private static func shouldRenderInline(_ body: String) -> Bool {
        guard !body.contains("\n") else { return false }

        let trimmed = body.trimmingCharacters(in: .whitespaces)
        guard !trimmed.hasPrefix("-") else { return false }
        if trimmed.hasPrefix("[") || trimmed.hasPrefix("{") {
            return true
        }
        return !trimmed.contains(":")
    }

    private static func indented(_ body: String) -> String {
        body.components(separatedBy: .newlines)
            .map { line in
                guard !line.isEmpty else { return line }
                if line.hasPrefix(" ") || line.hasPrefix("\t") {
                    return line
                }
                return "  \(line)"
            }
            .joined(separator: "\n")
    }

    private static func topLevelValue(in line: String) -> String {
        guard let colonIndex = line.firstIndex(of: ":") else { return "" }
        return line[line.index(after: colonIndex)...]
            .trimmingCharacters(in: .whitespaces)
    }
}
