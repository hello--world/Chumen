import Foundation

/// Local rule-hit helper for UI diagnostics.
///
/// The mihomo `/rules` endpoint returns the currently expanded rule list, but it does not expose a
/// dry-run "which rule would match this input" endpoint. This matcher covers deterministic local
/// rules that can be evaluated from the visible type/payload pair and intentionally leaves provider
/// backed or geo databases to the core. `MATCH`/`FINAL` are treated as fallback hits only for the
/// ordered first-match check, not for list filtering.
public enum RuleMatcher {
    public static func firstMatch(
        for input: String,
        in rules: [MihomoRule],
        includingCatchAll: Bool = true
    ) -> RuleMatchResult? {
        let query = RuleQuery(input)
        guard !query.isEmpty else { return nil }

        for (index, rule) in rules.enumerated() where rule.disabled != true {
            if matches(rule, query: query, includeCatchAll: includingCatchAll) {
                return RuleMatchResult(index: index, rule: rule)
            }
        }
        return nil
    }

    public static func search(for input: String, in rules: [MihomoRule]) -> RuleSearchResult {
        let query = RuleQuery(input)
        guard !query.isEmpty else {
            return RuleSearchResult(match: nil, isFallbackMatch: false, matchingIndexes: Array(rules.indices))
        }

        var firstMatch: RuleMatchResult?
        var matchingIndexes: [Int] = []

        matchingIndexes.reserveCapacity(min(rules.count, 256))

        for (index, rule) in rules.enumerated() {
            let isSemanticMatch = matches(rule, query: query, includeCatchAll: false)
            let isTextMatch = ruleContainsText(rule, needle: query.lowercasedRaw)
            let isFallback = !isSemanticMatch
                && rule.disabled != true
                && normalizedPayload(rule.payload) == nil
                && isCatchAll(normalizedType(rule.type))

            if firstMatch == nil && (isSemanticMatch || isFallback) {
                firstMatch = RuleMatchResult(index: index, rule: rule)
            }

            if isSemanticMatch || isTextMatch || isFallback {
                matchingIndexes.append(index)
            }
        }

        let isFallbackMatch = firstMatch.map { result in
            let rule = result.rule
            return normalizedPayload(rule.payload) == nil && isCatchAll(normalizedType(rule.type))
        } ?? false

        return RuleSearchResult(
            match: firstMatch,
            isFallbackMatch: isFallbackMatch,
            matchingIndexes: matchingIndexes
        )
    }

    public static func ruleMatchesInput(_ rule: MihomoRule, input: String) -> Bool {
        let query = RuleQuery(input)
        guard !query.isEmpty else { return false }
        return matches(rule, query: query, includeCatchAll: false)
    }

    public static func matchingRuleIndexes(
        for input: String,
        in rules: [MihomoRule],
        including matchedIndex: Int? = nil
    ) -> [Int] {
        let query = RuleQuery(input)
        guard !query.isEmpty else { return Array(rules.indices) }

        return rules.enumerated().compactMap { index, rule in
            if matches(rule, query: query, includeCatchAll: false)
                || ruleContainsText(rule, needle: query.lowercasedRaw)
                || index == matchedIndex {
                return index
            }
            return nil
        }
    }

    public static func ruleContainsText(_ rule: MihomoRule, input: String) -> Bool {
        let needle = input.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !needle.isEmpty else { return true }
        return ruleContainsText(rule, needle: needle)
    }

    private static func ruleContainsText(_ rule: MihomoRule, needle: String) -> Bool {
        return [
            rule.type,
            rule.payload,
            rule.proxy
        ]
        .compactMap { $0?.lowercased() }
        .contains { $0.contains(needle) }
    }

    private static func matches(_ rule: MihomoRule, query: RuleQuery, includeCatchAll: Bool) -> Bool {
        guard rule.disabled != true else { return false }

        let type = normalizedType(rule.type)
        guard let payload = normalizedPayload(rule.payload) else {
            return includeCatchAll && isCatchAll(type)
        }

        switch type {
        case "DOMAIN", "DOMAINFULL":
            return query.host == normalizedDomain(payload)
        case "DOMAINSUFFIX":
            let suffix = normalizedDomain(payload)
            return query.host == suffix || query.host.hasSuffix(".\(suffix)")
        case "DOMAINKEYWORD":
            return query.host.contains(payload.lowercased())
        case "DOMAINREGEX":
            return regexMatches(payload, value: query.host)
        case "IPCIDR", "SRCIPCIDR", "DSTIPCIDR":
            guard let ip = query.ipv4 else { return false }
            return ipv4CIDR(payload, contains: ip)
        case "DSTPORT", "SRCPORT", "INPORT":
            guard let port = query.port else { return false }
            return Int(payload) == port
        case "PROCESSNAME":
            return query.lowercasedRaw == payload.lowercased()
        case "PROCESSPATH":
            return query.lowercasedRaw.contains(payload.lowercased())
        case "MATCH", "FINAL":
            return includeCatchAll
        default:
            return query.host == payload.lowercased() || query.lowercasedRaw == payload.lowercased()
        }
    }

    private static func normalizedType(_ value: String?) -> String {
        (value ?? "")
            .filter { $0.isLetter || $0.isNumber }
            .uppercased()
    }

    private static func normalizedPayload(_ value: String?) -> String? {
        guard let first = value?
            .split(separator: ",", maxSplits: 1)
            .first?
            .trimmingCharacters(in: .whitespacesAndNewlines),
            !first.isEmpty
        else {
            return nil
        }
        return first
    }

    private static func normalizedDomain(_ value: String) -> String {
        value
            .trimmingCharacters(in: CharacterSet(charactersIn: ". "))
            .lowercased()
    }

    private static func isCatchAll(_ type: String) -> Bool {
        type == "MATCH" || type == "FINAL"
    }

    private static func regexMatches(_ pattern: String, value: String) -> Bool {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return false
        }
        let range = NSRange(value.startIndex..<value.endIndex, in: value)
        return regex.firstMatch(in: value, range: range) != nil
    }

    private static func ipv4CIDR(_ cidr: String, contains ip: UInt32) -> Bool {
        let parts = cidr.split(separator: "/", maxSplits: 1).map(String.init)
        guard let network = ipv4Address(parts[0]) else { return false }
        let prefix = parts.count > 1 ? Int(parts[1]) : 32
        guard let prefix, (0...32).contains(prefix) else { return false }
        let mask: UInt32 = prefix == 0 ? 0 : UInt32.max << UInt32(32 - prefix)
        return (ip & mask) == (network & mask)
    }

    fileprivate static func ipv4Address(_ value: String) -> UInt32? {
        let octets = value.split(separator: ".")
        guard octets.count == 4 else { return nil }

        var result: UInt32 = 0
        for octet in octets {
            guard let number = UInt8(octet) else { return nil }
            result = (result << 8) | UInt32(number)
        }
        return result
    }
}

public struct RuleMatchResult: Equatable, Sendable {
    public let index: Int
    public let rule: MihomoRule
}

public struct RuleSearchResult: Equatable, Sendable {
    public let match: RuleMatchResult?
    public let isFallbackMatch: Bool
    public let matchingIndexes: [Int]
}

private struct RuleQuery {
    let raw: String
    let lowercasedRaw: String
    let host: String
    let ipv4: UInt32?
    let port: Int?

    var isEmpty: Bool {
        raw.isEmpty
    }

    init(_ input: String) {
        let rawValue = input.trimmingCharacters(in: .whitespacesAndNewlines)
        raw = rawValue
        lowercasedRaw = rawValue.lowercased()

        let parsed = Self.parseHostAndPort(rawValue)
        host = parsed.host
        port = parsed.port ?? Int(rawValue)
        ipv4 = RuleMatcher.ipv4Address(parsed.host)
    }

    private static func parseHostAndPort(_ input: String) -> (host: String, port: Int?) {
        guard !input.isEmpty else { return ("", nil) }

        let candidate = input.contains("://") ? input : "chumen://\(input)"
        if let components = URLComponents(string: candidate),
           let host = components.host,
           !host.isEmpty {
            return (normalizeHost(host), components.port)
        }

        let withoutPath = input.split(separator: "/", maxSplits: 1).first.map(String.init) ?? input
        let withoutUser = withoutPath.split(separator: "@", maxSplits: 1).last.map(String.init) ?? withoutPath
        let hostPort = splitHostPort(withoutUser)
        return (normalizeHost(hostPort.host), hostPort.port)
    }

    private static func splitHostPort(_ value: String) -> (host: String, port: Int?) {
        let parts = value.split(separator: ":", omittingEmptySubsequences: false)
        guard parts.count == 2,
              let last = parts.last,
              let port = Int(last)
        else {
            return (value, nil)
        }
        return (String(parts[0]), port)
    }

    private static func normalizeHost(_ value: String) -> String {
        value
            .trimmingCharacters(in: CharacterSet(charactersIn: "[] ."))
            .lowercased()
    }
}
