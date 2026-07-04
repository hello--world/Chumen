import XCTest
@testable import ChumenCore

final class ConnectionAnalysisTests: XCTestCase {
    func testConnectionAnalysisGroupsRoutesHostsAndProcesses() {
        let snapshot = ConnectionAnalyzer.analyze([
            connection(id: "1", host: "example.com", process: "Safari", chains: ["Proxy"], upload: 120, download: 380),
            connection(id: "2", host: "example.com", process: "Safari", chains: ["DIRECT"], upload: 30, download: 70),
            connection(id: "3", host: "api.test", process: "curl", chains: ["Auto", "Proxy"], upload: 10, download: 20)
        ])

        XCTAssertEqual(snapshot.activeCount, 3)
        XCTAssertEqual(snapshot.uploadBytes, 160)
        XCTAssertEqual(snapshot.downloadBytes, 470)
        XCTAssertEqual(snapshot.routeBuckets.first(where: { $0.label == "proxy" })?.count, 2)
        XCTAssertEqual(snapshot.routeBuckets.first(where: { $0.label == "direct" })?.count, 1)
        XCTAssertEqual(snapshot.topHosts.first?.label, "example.com")
        XCTAssertEqual(snapshot.topHosts.first?.count, 2)
        XCTAssertEqual(snapshot.topProcesses.first?.label, "Safari")
    }

    private func connection(
        id: String,
        host: String,
        process: String,
        chains: [String],
        upload: Int64,
        download: Int64
    ) -> MihomoConnection {
        MihomoConnection(
            id: id,
            upload: upload,
            download: download,
            start: nil,
            chains: chains,
            rule: "DOMAIN",
            rulePayload: host,
            metadata: MihomoConnectionMetadata(
                network: "tcp",
                type: "HTTP",
                sourceIP: nil,
                destinationIP: nil,
                sourcePort: nil,
                destinationPort: "443",
                host: host,
                dnsMode: nil,
                process: process,
                processPath: nil,
                specialProxy: nil
            )
        )
    }
}
