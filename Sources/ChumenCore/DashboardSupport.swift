import Foundation

public extension ChumenRuntimeSettings {
    mutating func useExternalDashboard(at directoryURL: URL, name: String? = nil) {
        let dashboardName = name?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .nilIfEmpty ?? directoryURL.lastPathComponent

        externalUI = directoryURL.standardizedFileURL.path
        externalUIName = dashboardName
        externalUIURL = ""
    }

    mutating func clearExternalDashboard() {
        externalUI = ""
        externalUIName = ""
        externalUIURL = ""
    }

    func dashboardLaunchURL(paths _: ChumenPaths, language: AppLanguage) -> URL? {
        guard !externalUI.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }

        var components = controllerURLComponents(settings: self)
        components.path = "/ui/"

        if externalDashboardKind == .zashboard {
            let query = encodedDashboardQuery(
                settings: self,
                languageCode: language.zashboardLocaleCode
            )
            components.percentEncodedFragment = "/setup?\(query)"
        } else {
            components.queryItems = dashboardQueryItems(
                settings: self,
                languageCode: language.metaCubeXDLocaleCode
            )
        }

        return components.url
    }

    private var externalDashboardKind: ExternalDashboardKind {
        let normalizedName = externalUIName
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        if normalizedName.contains("zashboard") {
            return .zashboard
        }
        return .generic
    }
}

private enum ExternalDashboardKind {
    case generic
    case zashboard
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

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
