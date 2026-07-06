import SystemConfiguration
import XCTest
@testable import ChumenCore

final class SystemProxyManagerTests: XCTestCase {
    func testDynamicStoreProxyStateParsing() {
        let proxies: [String: Any] = [
            kSCPropNetProxiesHTTPEnable as String: 1,
            kSCPropNetProxiesHTTPProxy as String: "localhost",
            kSCPropNetProxiesHTTPPort as String: 19881,
            kSCPropNetProxiesHTTPSEnable as String: true,
            kSCPropNetProxiesHTTPSProxy as String: "127.0.0.1",
            kSCPropNetProxiesHTTPSPort as String: "19881",
            kSCPropNetProxiesSOCKSEnable as String: "off"
        ]

        let state = SystemProxyManager.currentState(fromDynamicStoreProxies: proxies, service: "Active")

        XCTAssertEqual(state.service, "Active")
        XCTAssertTrue(state.web.enabled)
        XCTAssertEqual(state.web.server, "localhost")
        XCTAssertEqual(state.web.port, 19881)
        XCTAssertTrue(state.secureWeb.enabled)
        XCTAssertEqual(state.secureWeb.server, "127.0.0.1")
        XCTAssertEqual(state.secureWeb.port, 19881)
        XCTAssertFalse(state.socks.enabled)
        XCTAssertTrue(state.matches(host: "127.0.0.1", port: 19881))
    }
}
