import XCTest
@testable import ChumenCore

final class ExternalProfileCandidateSearchTests: XCTestCase {
    func testFilterDoesNotMatchHiddenUsersHomePrefix() {
        let home = URL(fileURLWithPath: "/Users/alice", isDirectory: true)
        let config = ExternalProfileCandidate(
            sourceID: "config-clash-meta",
            sourceName: "~/.config/clash.meta",
            name: "config",
            filePath: "/Users/alice/.config/clash.meta/config.yaml",
            rootPath: "/Users/alice/.config/clash.meta"
        )
        let usProxy = ExternalProfileCandidate(
            sourceID: "clash-verge-rev",
            sourceName: "Clash Verge Rev",
            name: "us-west",
            filePath: "/Users/alice/Library/Application Support/io.github.clash-verge-rev.clash-verge-rev/profiles/us-west.yaml",
            rootPath: "/Users/alice/Library/Application Support/io.github.clash-verge-rev.clash-verge-rev"
        )

        let matches = ExternalProfileCandidateSearch.filter(
            [config, usProxy],
            query: "us",
            homeDirectory: home
        )

        XCTAssertEqual(matches.map(\.id), [usProxy.id])
    }

    func testFilterRanksNameBeforePinyinBeforeMetadata() {
        let home = URL(fileURLWithPath: "/Users/alice", isDirectory: true)
        let metadataOnly = ExternalProfileCandidate(
            sourceID: "clash-verge-rev",
            sourceName: "Clash Verge Rev",
            name: "config",
            filePath: "/Users/alice/Library/Application Support/io.github.clash-verge-rev.clash-verge-rev/profiles/ceshi.yaml",
            rootPath: "/Users/alice/Library/Application Support/io.github.clash-verge-rev.clash-verge-rev"
        )
        let pinyinName = ExternalProfileCandidate(
            sourceID: "clash-verge-rev",
            sourceName: "Clash Verge Rev",
            name: "测试",
            filePath: "/Users/alice/Library/Application Support/io.github.clash-verge-rev.clash-verge-rev/profiles/china.yaml",
            rootPath: "/Users/alice/Library/Application Support/io.github.clash-verge-rev.clash-verge-rev"
        )
        let englishName = ExternalProfileCandidate(
            sourceID: "clash-verge-rev",
            sourceName: "Clash Verge Rev",
            name: "ceshi-node",
            filePath: "/Users/alice/Library/Application Support/io.github.clash-verge-rev.clash-verge-rev/profiles/node.yaml",
            rootPath: "/Users/alice/Library/Application Support/io.github.clash-verge-rev.clash-verge-rev"
        )

        let matches = ExternalProfileCandidateSearch.filter(
            [metadataOnly, pinyinName, englishName],
            query: "ceshi",
            homeDirectory: home
        )

        XCTAssertEqual(matches.map(\.id), [englishName.id, pinyinName.id, metadataOnly.id])
    }

    func testFilterKeepsMetadataMatchesAfterNameMatches() {
        let home = URL(fileURLWithPath: "/Users/alice", isDirectory: true)
        let supportOnly = ExternalProfileCandidate(
            sourceID: "clash-verge-rev",
            sourceName: "Clash Verge Rev",
            name: "config",
            filePath: "/Users/alice/Library/Application Support/io.github.clash-verge-rev.clash-verge-rev/profiles/internal.yaml",
            rootPath: "/Users/alice/Library/Application Support/io.github.clash-verge-rev.clash-verge-rev",
            remoteURL: "https://example.com/us/subscription.yaml"
        )
        let usProxy = ExternalProfileCandidate(
            sourceID: "clash-verge-rev",
            sourceName: "Clash Verge Rev",
            name: "us-west",
            filePath: "/Users/alice/Library/Application Support/io.github.clash-verge-rev.clash-verge-rev/profiles/us-west.yaml",
            rootPath: "/Users/alice/Library/Application Support/io.github.clash-verge-rev.clash-verge-rev"
        )

        let matches = ExternalProfileCandidateSearch.filter(
            [supportOnly, usProxy],
            query: "us",
            homeDirectory: home
        )

        XCTAssertEqual(matches.map(\.id), [usProxy.id, supportOnly.id])
    }

    func testFilterMatchesDisplayedHomeRelativePath() {
        let home = URL(fileURLWithPath: "/Users/alice", isDirectory: true)
        let config = ExternalProfileCandidate(
            sourceID: "config-clash-meta",
            sourceName: "~/.config/clash.meta",
            name: "config",
            filePath: "/Users/alice/.config/clash.meta/config.yaml",
            rootPath: "/Users/alice/.config/clash.meta"
        )

        let matches = ExternalProfileCandidateSearch.filter(
            [config],
            query: ".config yaml",
            homeDirectory: home
        )

        XCTAssertEqual(matches.map(\.id), [config.id])
    }

    func testDisplayPathUsesTildeForHomeDirectory() {
        let home = URL(fileURLWithPath: "/Users/alice", isDirectory: true)

        XCTAssertEqual(
            ExternalProfileCandidateSearch.displayPath(
                "/Users/alice/.config/clash.meta/config.yaml",
                homeDirectory: home
            ),
            "~/.config/clash.meta/config.yaml"
        )
    }
}
