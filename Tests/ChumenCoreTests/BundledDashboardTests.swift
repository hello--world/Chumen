import XCTest
@testable import ChumenCore

final class BundledDashboardTests: XCTestCase {
    func testInstallsAvailableBundledDashboardsAndAppliesPresetSettings() throws {
        let fixture = try DashboardFixture()
        try fixture.makeDashboard(.metacubexd, marker: "metacubexd 1.0")
        try fixture.makeDashboard(.zashboard, marker: "zashboard 1.0")

        let installer = BundledDashboardInstaller(
            paths: fixture.paths,
            resourceRoot: fixture.resourceRoot,
            fileManager: fixture.fileManager
        )
        let installed = try installer.installAvailableDashboards()

        XCTAssertEqual(installed, [.metacubexd, .zashboard])
        XCTAssertTrue(fixture.installedIndexExists(for: .metacubexd))
        XCTAssertTrue(fixture.installedIndexExists(for: .zashboard))

        var settings = ChumenRuntimeSettings(externalUI: "", externalUIName: "", externalUIURL: "")
        settings.useBundledDashboard(.zashboard, paths: fixture.paths)

        XCTAssertEqual(settings.externalUI, fixture.paths.dashboardsDirectoryURL.path)
        XCTAssertEqual(settings.externalUIName, "zashboard")
        XCTAssertEqual(settings.bundledDashboard(paths: fixture.paths), .zashboard)
        XCTAssertTrue(settings.externalUIURL.contains("Zephyruso/zashboard"))
    }

    func testReplacesInstalledDashboardWhenBundledMarkerChanges() throws {
        let fixture = try DashboardFixture()
        try fixture.makeDashboard(.metacubexd, marker: "metacubexd 1.0", body: "old")

        let installer = BundledDashboardInstaller(
            paths: fixture.paths,
            resourceRoot: fixture.resourceRoot,
            fileManager: fixture.fileManager
        )
        try installer.install(.metacubexd)
        try fixture.makeDashboard(.metacubexd, marker: "metacubexd 2.0", body: "new")

        try installer.install(.metacubexd)

        let installedIndex = fixture.paths
            .dashboardDirectoryURL(for: .metacubexd)
            .appendingPathComponent("index.html")
        XCTAssertEqual(try String(contentsOf: installedIndex, encoding: .utf8), "new")
    }

    func testBuildsMetaCubeXDLaunchURLWithControllerSecretAndLanguage() throws {
        let fixture = try DashboardFixture()
        var settings = ChumenRuntimeSettings(
            externalControllerHost: "127.0.0.1",
            externalControllerPort: 19897,
            secret: "key with space"
        )
        settings.useBundledDashboard(.metacubexd, paths: fixture.paths)

        let url = try XCTUnwrap(settings.dashboardLaunchURL(paths: fixture.paths, language: .zhHans))
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
        let fixture = try DashboardFixture()
        var settings = ChumenRuntimeSettings(
            externalControllerHost: "localhost",
            externalControllerPort: 19897,
            secret: "secret/key"
        )
        settings.useBundledDashboard(.zashboard, paths: fixture.paths)

        let url = try XCTUnwrap(settings.dashboardLaunchURL(paths: fixture.paths, language: .en))
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

private final class DashboardFixture {
    let fileManager = FileManager.default
    let root: URL
    let resourceRoot: URL
    let paths: ChumenPaths

    init() throws {
        root = fileManager.temporaryDirectory
            .appendingPathComponent("chumen-dashboard-tests-\(UUID().uuidString)", isDirectory: true)
        resourceRoot = root
            .appendingPathComponent("bundle", isDirectory: true)
            .appendingPathComponent("Dashboards", isDirectory: true)
        paths = ChumenPaths(appHome: root.appendingPathComponent("home", isDirectory: true))
        try fileManager.createDirectory(at: resourceRoot, withIntermediateDirectories: true)
    }

    deinit {
        try? fileManager.removeItem(at: root)
    }

    func makeDashboard(_ dashboard: BundledDashboard, marker: String, body: String = "") throws {
        let directory = resourceRoot.appendingPathComponent(dashboard.rawValue, isDirectory: true)
        if fileManager.fileExists(atPath: directory.path) {
            try fileManager.removeItem(at: directory)
        }
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        try body.write(to: directory.appendingPathComponent("index.html"), atomically: true, encoding: .utf8)
        try marker.write(
            to: directory.appendingPathComponent(BundledDashboardInstaller.markerFileName),
            atomically: true,
            encoding: .utf8
        )
    }

    func installedIndexExists(for dashboard: BundledDashboard) -> Bool {
        fileManager.fileExists(
            atPath: paths
                .dashboardDirectoryURL(for: dashboard)
                .appendingPathComponent("index.html")
                .path
        )
    }
}
