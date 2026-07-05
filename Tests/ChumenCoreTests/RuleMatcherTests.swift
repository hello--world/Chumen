import XCTest
@testable import ChumenCore

final class RuleMatcherTests: XCTestCase {
    func testDomainSuffixMatchesExactAndSubdomain() {
        let rule = rule(type: "DomainSuffix", payload: "poe.com", proxy: "Proxy")

        XCTAssertTrue(RuleMatcher.ruleMatchesInput(rule, input: "poe.com"))
        XCTAssertTrue(RuleMatcher.ruleMatchesInput(rule, input: "https://chat.poe.com/path"))
        XCTAssertFalse(RuleMatcher.ruleMatchesInput(rule, input: "notpoe.com"))
    }

    func testDomainRuleRequiresExactHost() {
        let rule = rule(type: "DOMAIN", payload: "api.example.com", proxy: "Proxy")

        XCTAssertTrue(RuleMatcher.ruleMatchesInput(rule, input: "api.example.com"))
        XCTAssertFalse(RuleMatcher.ruleMatchesInput(rule, input: "www.api.example.com"))
    }

    func testIPCIDRMatchesIPv4Range() {
        let rule = rule(type: "IPCIDR", payload: "23.95.246.0/24", proxy: "Proxy")

        XCTAssertTrue(RuleMatcher.ruleMatchesInput(rule, input: "23.95.246.214"))
        XCTAssertFalse(RuleMatcher.ruleMatchesInput(rule, input: "23.95.247.1"))
    }

    func testFirstMatchSkipsDisabledRules() {
        let disabled = rule(type: "DomainSuffix", payload: "poe.com", proxy: "Disabled", disabled: true)
        let enabled = rule(type: "DomainSuffix", payload: "poe.com", proxy: "Enabled")

        let match = RuleMatcher.firstMatch(for: "chat.poe.com", in: [disabled, enabled])

        XCTAssertEqual(match?.index, 1)
        XCTAssertEqual(match?.rule.proxy, "Enabled")
    }

    func testFirstMatchUsesCatchAllAsFallback() {
        let catchAll = rule(type: "MATCH", payload: "", proxy: "DIRECT")

        let match = RuleMatcher.firstMatch(for: "unknown.example", in: [catchAll])

        XCTAssertEqual(match?.index, 0)
        XCTAssertEqual(match?.rule.proxy, "DIRECT")
        XCTAssertNil(RuleMatcher.firstMatch(for: "unknown.example", in: [catchAll], includingCatchAll: false))
        XCTAssertFalse(RuleMatcher.ruleMatchesInput(catchAll, input: "unknown.example"))
    }

    func testSearchReturnsSpecificMatchAndFilteredIndexes() {
        let rules = [
            rule(type: "DomainSuffix", payload: "example.com", proxy: "Proxy"),
            rule(type: "DomainSuffix", payload: "other.com", proxy: "Proxy"),
            rule(type: "MATCH", payload: "", proxy: "DIRECT")
        ]

        let result = RuleMatcher.search(for: "www.example.com", in: rules)

        XCTAssertEqual(result.match?.index, 0)
        XCTAssertFalse(result.isFallbackMatch)
        XCTAssertEqual(result.matchingIndexes, [0, 2])
    }

    func testSearchMarksCatchAllMatchAsFallback() {
        let result = RuleMatcher.search(
            for: "unknown.example",
            in: [rule(type: "MATCH", payload: "", proxy: "DIRECT")]
        )

        XCTAssertEqual(result.match?.index, 0)
        XCTAssertTrue(result.isFallbackMatch)
        XCTAssertEqual(result.matchingIndexes, [0])
    }

    private func rule(
        type: String,
        payload: String,
        proxy: String,
        disabled: Bool = false
    ) -> MihomoRule {
        MihomoRule(type: type, payload: payload, proxy: proxy, size: nil, disabled: disabled)
    }
}
