import Foundation

public enum LogAnalysisLevel: String, CaseIterable, Codable, Sendable {
    case error
    case warning
    case info
    case debug
}

public struct LogAnalysisBucket: Identifiable, Equatable, Sendable {
    public let id: String
    public let label: String
    public let count: Int
}

public struct LogAnalysisIssue: Identifiable, Equatable, Sendable {
    public let id: String
    public let source: String
    public let level: LogAnalysisLevel
    public let message: String
}

public struct LogAnalysisSnapshot: Equatable, Sendable {
    public let totalLines: Int
    public let levelBuckets: [LogAnalysisBucket]
    public let sourceBuckets: [LogAnalysisBucket]
    public let frequentMessages: [LogAnalysisBucket]
    public let recentIssues: [LogAnalysisIssue]

    public var errorCount: Int {
        count(for: .error)
    }

    public var warningCount: Int {
        count(for: .warning)
    }

    public var aiContext: String {
        let levels = levelBuckets.map { "\($0.label)=\($0.count)" }.joined(separator: ", ")
        let sources = sourceBuckets.map { "\($0.label)=\($0.count)" }.joined(separator: ", ")
        let frequent = frequentMessages.map { "\($0.label)=\($0.count)" }.joined(separator: " | ")
        let issues = recentIssues.map { "[\($0.level.rawValue)] \($0.message)" }.joined(separator: " | ")
        return """
        Log analysis:
        - total lines: \(totalLines)
        - levels: \(levels.isEmpty ? "-" : levels)
        - sources: \(sources.isEmpty ? "-" : sources)
        - frequent issues: \(frequent.isEmpty ? "-" : frequent)
        - recent issues: \(issues.isEmpty ? "-" : issues)
        """
    }

    public func count(for level: LogAnalysisLevel) -> Int {
        levelBuckets.first { $0.id == level.rawValue }?.count ?? 0
    }
}

public enum LogAnalyzer {
    public static func analyze(
        processLog: String,
        runtimeLog: String,
        maxLinesPerSource: Int = 1_500,
        issueLimit: Int = 8,
        frequentLimit: Int = 6
    ) -> LogAnalysisSnapshot {
        let entries = parse(source: "process", text: processLog, maxLines: maxLinesPerSource) +
            parse(source: "runtime", text: runtimeLog, maxLines: maxLinesPerSource)
        let levelBuckets = LogAnalysisLevel.allCases.map { level in
            LogAnalysisBucket(
                id: level.rawValue,
                label: level.rawValue,
                count: entries.filter { $0.level == level }.count
            )
        }
        let sourceBuckets = grouped(entries.map(\.source), limit: 4)
        let issueEntries = entries.filter { $0.level == .error || $0.level == .warning }
        let recentIssues = issueEntries.suffix(issueLimit).reversed().enumerated().map { offset, entry in
            LogAnalysisIssue(
                id: "\(entry.source)-\(entries.count)-\(offset)",
                source: entry.source,
                level: entry.level,
                message: entry.message
            )
        }
        let frequentMessages = grouped(
            issueEntries.map { normalizedIssueKey($0.message) },
            limit: frequentLimit
        )

        return LogAnalysisSnapshot(
            totalLines: entries.count,
            levelBuckets: levelBuckets,
            sourceBuckets: sourceBuckets,
            frequentMessages: frequentMessages,
            recentIssues: recentIssues
        )
    }

    private static func parse(source: String, text: String, maxLines: Int) -> [LogEntry] {
        text.components(separatedBy: .newlines)
            .suffix(max(0, maxLines))
            .compactMap { rawLine in
                let message = compact(rawLine)
                guard !message.isEmpty else { return nil }
                return LogEntry(source: source, level: classify(message), message: message)
            }
    }

    private static func classify(_ message: String) -> LogAnalysisLevel {
        let lowercased = message.lowercased()
        if lowercased.contains("panic") ||
            lowercased.contains("fatal") ||
            lowercased.contains("error") ||
            lowercased.contains("failed") ||
            lowercased.contains("failure") ||
            lowercased.contains("permission denied") ||
            lowercased.contains("connection refused") ||
            lowercased.contains("timeout") {
            return .error
        }
        if lowercased.contains("warn") ||
            lowercased.contains("deprecated") ||
            lowercased.contains("unavailable") ||
            lowercased.contains("retry") ||
            lowercased.contains("conflict") {
            return .warning
        }
        if lowercased.contains("debug") || lowercased.contains("[dbg]") {
            return .debug
        }
        return .info
    }

    private static func grouped(_ labels: [String], limit: Int) -> [LogAnalysisBucket] {
        let counts = labels.reduce(into: [String: Int]()) { partial, label in
            let normalized = compact(label)
            guard !normalized.isEmpty else { return }
            partial[normalized, default: 0] += 1
        }
        return counts.map { label, count in
            LogAnalysisBucket(id: label, label: label, count: count)
        }
        .sorted {
            if $0.count != $1.count {
                return $0.count > $1.count
            }
            return $0.label < $1.label
        }
        .prefix(max(0, limit))
        .map { $0 }
    }

    private static func normalizedIssueKey(_ message: String) -> String {
        compact(message)
            .replacingOccurrences(
                of: #"\b(?:\d{1,3}\.){3}\d{1,3}\b"#,
                with: "<ip>",
                options: .regularExpression
            )
            .replacingOccurrences(
                of: #"\b[0-9a-f]{8,}\b"#,
                with: "<hex>",
                options: .regularExpression
            )
            .replacingOccurrences(
                of: #"\b\d+\b"#,
                with: "<n>",
                options: .regularExpression
            )
    }

    private static func compact(_ line: String) -> String {
        line
            .replacingOccurrences(of: #"\u001B\[[0-9;]*m"#, with: "", options: .regularExpression)
            .replacingOccurrences(
                of: #"^\s*\d{4}[-/]\d{2}[-/]\d{2}[T\s][^\s]+\s*"#,
                with: "",
                options: .regularExpression
            )
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private struct LogEntry: Equatable, Sendable {
    let source: String
    let level: LogAnalysisLevel
    let message: String
}
