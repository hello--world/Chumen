import Foundation

public enum BundledDashboard: String, CaseIterable, Codable, Identifiable, Sendable {
    case metacubexd
    case zashboard

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .metacubexd:
            "MetaCubeXD"
        case .zashboard:
            "zashboard"
        }
    }

    public var externalUIName: String {
        rawValue
    }

    public var externalUIURL: String {
        switch self {
        case .metacubexd:
            "https://github.com/MetaCubeX/metacubexd/archive/refs/heads/gh-pages.zip"
        case .zashboard:
            "https://github.com/Zephyruso/zashboard/releases/latest/download/dist-no-fonts.zip"
        }
    }

    public func matches(settings: ChumenRuntimeSettings, paths: ChumenPaths) -> Bool {
        guard settings.externalUIName == externalUIName else {
            return false
        }

        let configuredPath = standardizedPath(settings.externalUI)
        return configuredPath == standardizedPath(paths.dashboardsDirectoryURL.path) ||
            configuredPath == standardizedPath(paths.dashboardDirectoryURL(for: self).path)
    }

    public func launchURL(settings: ChumenRuntimeSettings, language: AppLanguage) -> URL? {
        var components = controllerURLComponents(settings: settings)
        switch self {
        case .metacubexd:
            components.path = "/ui/"
            components.queryItems = dashboardQueryItems(
                settings: settings,
                languageCode: language.metaCubeXDLocaleCode
            )
        case .zashboard:
            components.path = "/ui/"
            let query = encodedDashboardQuery(
                settings: settings,
                languageCode: language.zashboardLocaleCode
            )
            components.percentEncodedFragment = "/setup?\(query)"
        }
        return components.url
    }
}

public extension ChumenPaths {
    var dashboardsDirectoryURL: URL {
        appHome.appendingPathComponent("dashboards", isDirectory: true)
    }

    func dashboardDirectoryURL(for dashboard: BundledDashboard) -> URL {
        dashboardsDirectoryURL.appendingPathComponent(dashboard.rawValue, isDirectory: true)
    }
}

public extension ChumenRuntimeSettings {
    mutating func useBundledDashboard(_ dashboard: BundledDashboard, paths: ChumenPaths) {
        externalUI = paths.dashboardsDirectoryURL.path
        externalUIName = dashboard.externalUIName
        externalUIURL = dashboard.externalUIURL
    }

    func bundledDashboard(paths: ChumenPaths) -> BundledDashboard? {
        BundledDashboard.allCases.first { $0.matches(settings: self, paths: paths) }
    }

    func dashboardLaunchURL(paths: ChumenPaths, language: AppLanguage) -> URL? {
        if let dashboard = bundledDashboard(paths: paths) {
            return dashboard.launchURL(settings: self, language: language)
        }

        var components = controllerURLComponents(settings: self)
        components.path = "/ui"
        components.queryItems = dashboardQueryItems(
            settings: self,
            languageCode: language.metaCubeXDLocaleCode
        )
        return components.url
    }
}

public struct BundledDashboardInstaller {
    public static let markerFileName = ".chumen-dashboard-version"

    private let paths: ChumenPaths
    private let resourceRoot: URL?
    private let fileManager: FileManager

    public init(
        paths: ChumenPaths,
        resourceRoot: URL? = Bundle.main.resourceURL?.appendingPathComponent("Dashboards", isDirectory: true),
        fileManager: FileManager = .default
    ) {
        self.paths = paths
        self.resourceRoot = resourceRoot
        self.fileManager = fileManager
    }

    public func installAvailableDashboards() throws -> [BundledDashboard] {
        try fileManager.createDirectory(at: paths.dashboardsDirectoryURL, withIntermediateDirectories: true)

        var installed: [BundledDashboard] = []
        for dashboard in BundledDashboard.allCases {
            if try install(dashboard) != nil {
                installed.append(dashboard)
            }
        }
        return installed
    }

    @discardableResult
    public func install(_ dashboard: BundledDashboard) throws -> URL? {
        guard let sourceURL = bundledDirectoryURL(for: dashboard) else {
            return nil
        }

        let destinationURL = paths.dashboardDirectoryURL(for: dashboard)
        if try shouldReplaceInstalledDashboard(sourceURL: sourceURL, destinationURL: destinationURL) {
            if fileManager.fileExists(atPath: destinationURL.path) {
                try fileManager.removeItem(at: destinationURL)
            }
            try fileManager.createDirectory(at: paths.dashboardsDirectoryURL, withIntermediateDirectories: true)
            try fileManager.copyItem(at: sourceURL, to: destinationURL)
        }

        return destinationURL
    }

    public func bundledDirectoryURL(for dashboard: BundledDashboard) -> URL? {
        guard let resourceRoot else {
            return nil
        }
        let url = resourceRoot.appendingPathComponent(dashboard.rawValue, isDirectory: true)
        return isDashboardDirectory(url) ? url : nil
    }

    private func shouldReplaceInstalledDashboard(sourceURL: URL, destinationURL: URL) throws -> Bool {
        guard isDashboardDirectory(destinationURL) else {
            return true
        }

        guard let sourceMarker = try marker(at: sourceURL) else {
            return false
        }
        return try marker(at: destinationURL) != sourceMarker
    }

    private func isDashboardDirectory(_ url: URL) -> Bool {
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            return false
        }
        return fileManager.fileExists(atPath: url.appendingPathComponent("index.html").path)
    }

    private func marker(at directoryURL: URL) throws -> String? {
        let markerURL = directoryURL.appendingPathComponent(Self.markerFileName)
        guard fileManager.fileExists(atPath: markerURL.path) else {
            return nil
        }
        return try String(contentsOf: markerURL, encoding: .utf8)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private func standardizedPath(_ path: String) -> String {
    URL(fileURLWithPath: path).standardizedFileURL.path
}

private func controllerURLComponents(settings: ChumenRuntimeSettings) -> URLComponents {
    var components = URLComponents()
    components.scheme = "http"
    components.host = settings.externalControllerHost
    components.port = settings.externalControllerPort
    return components
}

private func dashboardQueryItems(settings: ChumenRuntimeSettings, languageCode: String) -> [URLQueryItem] {
    [
        URLQueryItem(name: "hostname", value: dashboardHostname(settings.externalControllerHost)),
        URLQueryItem(name: "port", value: String(settings.externalControllerPort)),
        URLQueryItem(name: "secret", value: settings.secret),
        URLQueryItem(name: "type", value: "clash"),
        URLQueryItem(name: "http", value: "1"),
        URLQueryItem(name: "label", value: "Chumen"),
        URLQueryItem(name: "lang", value: languageCode),
        URLQueryItem(name: "language", value: languageCode),
        URLQueryItem(name: "locale", value: languageCode)
    ]
}

private func encodedDashboardQuery(settings: ChumenRuntimeSettings, languageCode: String) -> String {
    var components = URLComponents()
    components.queryItems = dashboardQueryItems(settings: settings, languageCode: languageCode)
    return components.percentEncodedQuery ?? ""
}

private func dashboardHostname(_ host: String) -> String {
    if host.contains(":"), !host.hasPrefix("[") {
        return "[\(host)]"
    }
    return host
}
