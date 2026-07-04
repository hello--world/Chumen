import XCTest
@testable import ChumenCore

final class LogAnalysisTests: XCTestCase {
    func testLogAnalysisClassifiesLevelsAndFindsFrequentIssues() {
        let snapshot = LogAnalyzer.analyze(
            processLog: """
            2026-07-04 09:00:00 info core started
            2026-07-04 09:00:01 error dial 1.2.3.4 failed
            2026-07-04 09:00:02 error dial 5.6.7.8 failed
            """,
            runtimeLog: """
            [warning] route conflict detected
            debug websocket ping
            """
        )

        XCTAssertEqual(snapshot.totalLines, 5)
        XCTAssertEqual(snapshot.count(for: .error), 2)
        XCTAssertEqual(snapshot.count(for: .warning), 1)
        XCTAssertEqual(snapshot.count(for: .debug), 1)
        XCTAssertEqual(snapshot.sourceBuckets.first(where: { $0.label == "process" })?.count, 3)
        XCTAssertEqual(snapshot.sourceBuckets.first(where: { $0.label == "runtime" })?.count, 2)
        XCTAssertEqual(snapshot.frequentMessages.first?.label, "error dial <ip> failed")
        XCTAssertEqual(snapshot.frequentMessages.first?.count, 2)
        XCTAssertEqual(snapshot.recentIssues.first?.level, .warning)
    }
}
