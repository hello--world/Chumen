import XCTest
@testable import ChumenCore

final class ConnectionTrafficAccumulatorTests: XCTestCase {
    func testAccumulatesDeltasByTerminalChain() {
        var accumulator = ConnectionTrafficAccumulator()

        accumulator.apply(connections: [
            connection(id: "direct", upload: 100, download: 200, chains: ["DIRECT"]),
            connection(id: "proxy", upload: 300, download: 400, chains: ["Proxy"])
        ])

        XCTAssertEqual(accumulator.directUploadTotal, 0)
        XCTAssertEqual(accumulator.directDownloadTotal, 0)
        XCTAssertEqual(accumulator.proxyUploadTotal, 0)
        XCTAssertEqual(accumulator.proxyDownloadTotal, 0)

        accumulator.apply(connections: [
            connection(id: "direct", upload: 130, download: 260, chains: ["DIRECT"]),
            connection(id: "proxy", upload: 450, download: 430, chains: ["Proxy"])
        ])

        XCTAssertEqual(accumulator.directUploadTotal, 30)
        XCTAssertEqual(accumulator.directDownloadTotal, 60)
        XCTAssertEqual(accumulator.proxyUploadTotal, 150)
        XCTAssertEqual(accumulator.proxyDownloadTotal, 30)
    }

    func testTreatsMissingChainAsUnknownAndDropsClosedBaselines() {
        var accumulator = ConnectionTrafficAccumulator()

        accumulator.apply(connections: [
            connection(id: "unknown", upload: 10, download: 10, chains: nil)
        ])
        accumulator.apply(connections: [
            connection(id: "unknown", upload: 25, download: 30, chains: nil)
        ])

        XCTAssertEqual(accumulator.unknownUploadTotal, 15)
        XCTAssertEqual(accumulator.unknownDownloadTotal, 20)

        accumulator.apply(connections: [])
        accumulator.apply(connections: [
            connection(id: "unknown", upload: 1000, download: 1000, chains: ["DIRECT"])
        ])

        XCTAssertEqual(accumulator.directUploadTotal, 0)
        XCTAssertEqual(accumulator.directDownloadTotal, 0)
    }

    func testCanIncludeInitialSamplesAfterTelemetryReset() {
        var accumulator = ConnectionTrafficAccumulator()

        accumulator.apply(
            connections: [
                connection(id: "direct", upload: 10, download: 20, chains: ["DIRECT"]),
                connection(id: "proxy", upload: 30, download: 40, chains: ["Auto"])
            ],
            includeInitialSamples: true
        )

        XCTAssertEqual(accumulator.directUploadTotal, 10)
        XCTAssertEqual(accumulator.directDownloadTotal, 20)
        XCTAssertEqual(accumulator.proxyUploadTotal, 30)
        XCTAssertEqual(accumulator.proxyDownloadTotal, 40)

        accumulator.apply(connections: [
            connection(id: "direct", upload: 15, download: 26, chains: ["DIRECT"]),
            connection(id: "proxy", upload: 38, download: 45, chains: ["Auto"])
        ])

        XCTAssertEqual(accumulator.directUploadTotal, 15)
        XCTAssertEqual(accumulator.directDownloadTotal, 26)
        XCTAssertEqual(accumulator.proxyUploadTotal, 38)
        XCTAssertEqual(accumulator.proxyDownloadTotal, 45)
    }

    private func connection(id: String, upload: Int64, download: Int64, chains: [String]?) -> MihomoConnection {
        MihomoConnection(
            id: id,
            upload: upload,
            download: download,
            start: nil,
            chains: chains,
            rule: nil,
            rulePayload: nil,
            metadata: nil
        )
    }
}
