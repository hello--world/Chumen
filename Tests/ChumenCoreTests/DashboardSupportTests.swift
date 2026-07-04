import XCTest
@testable import ChumenCore

final class DashboardSupportTests: XCTestCase {
    func testExternalDashboardDirectoryUpdatesRuntimeSettings() {
        let directory = URL(fileURLWithPath: "/tmp/MetaCubeXD", isDirectory: true)
        var settings = ChumenRuntimeSettings(externalUI: "", externalUIName: "", externalUIURL: "https://example.com/ui.zip")

        settings.useExternalDashboard(at: directory)

        XCTAssertEqual(settings.externalUI, directory.standardizedFileURL.path)
        XCTAssertEqual(settings.externalUIName, "MetaCubeXD")
        XCTAssertEqual(settings.externalUIURL, "")
    }

    func testClearsExternalDashboardSettings() {
        var settings = ChumenRuntimeSettings(
            externalUI: "/tmp/ui",
            externalUIName: "metacubexd",
            externalUIURL: "https://example.com/ui.zip"
        )

        settings.clearExternalDashboard()

        XCTAssertEqual(settings.externalUI, "")
        XCTAssertEqual(settings.externalUIName, "")
        XCTAssertEqual(settings.externalUIURL, "")
    }

    func testNoLaunchURLUntilExternalDashboardIsConfigured() {
        let settings = ChumenRuntimeSettings(externalUI: "", externalUIName: "", externalUIURL: "")

        XCTAssertNil(settings.dashboardLaunchURL(paths: ChumenPaths(appHome: URL(fileURLWithPath: "/tmp/chumen")), language: .en))
    }

    func testBuildsMetaCubeXDLaunchURLWithControllerSecretAndLanguage() throws {
        var settings = ChumenRuntimeSettings(
            externalControllerHost: "127.0.0.1",
            externalControllerPort: 19897,
            secret: "key with space"
        )
        settings.useExternalDashboard(at: URL(fileURLWithPath: "/tmp/metacubexd", isDirectory: true), name: "metacubexd")

        let url = try XCTUnwrap(settings.dashboardLaunchURL(paths: ChumenPaths(appHome: URL(fileURLWithPath: "/tmp/chumen")), language: .zhHans))
        let components = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false))
        let query = dictionary(from: components.queryItems)

        XCTAssertEqual(components.scheme, "http")
        XCTAssertEqual(components.host, "127.0.0.1")
        XCTAssertEqual(components.port, 19897)
        XCTAssertEqual(components.path, "/ui/")
        XCTAssertEqual(query["hostname"], "127.0.0.1")
        XCTAssertEqual(query["port"], "19897")
        XCTAssertEqual(query["secret"], "key with space")
        XCTAssertEqual(query["type"], "clash")
        XCTAssertEqual(query["http"], "1")
        XCTAssertEqual(query["lang"], "zh")
    }

    func testBuildsZashboardLaunchURLWithHashSetupRoute() throws {
        var settings = ChumenRuntimeSettings(
            externalControllerHost: "localhost",
            externalControllerPort: 19897,
            secret: "secret/key"
        )
        settings.useExternalDashboard(at: URL(fileURLWithPath: "/tmp/zashboard", isDirectory: true), name: "zashboard")

        let url = try XCTUnwrap(settings.dashboardLaunchURL(paths: ChumenPaths(appHome: URL(fileURLWithPath: "/tmp/chumen")), language: .en))
        let components = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false))
        let fragment = try XCTUnwrap(components.fragment)
        let queryStart = try XCTUnwrap(fragment.firstIndex(of: "?"))
        let queryString = String(fragment[fragment.index(after: queryStart)...])
        let query = dictionary(from: URLComponents(string: "http://z?\(queryString)")?.queryItems)

        XCTAssertEqual(components.scheme, "http")
        XCTAssertEqual(components.host, "localhost")
        XCTAssertEqual(components.port, 19897)
        XCTAssertEqual(components.path, "/ui/")
        XCTAssertEqual(String(fragment[..<queryStart]), "/setup")
        XCTAssertEqual(query["hostname"], "localhost")
        XCTAssertEqual(query["port"], "19897")
        XCTAssertEqual(query["secret"], "secret/key")
        XCTAssertEqual(query["type"], "clash")
        XCTAssertEqual(query["http"], "1")
        XCTAssertEqual(query["lang"], "en-US")
    }
}

private func dictionary(from queryItems: [URLQueryItem]?) -> [String: String] {
    Dictionary(uniqueKeysWithValues: (queryItems ?? []).map { ($0.name, $0.value ?? "") })
}
