import Foundation

enum ChumenBuildConfiguration {
    case debug
    case release

    var titleKey: L10n.Key {
        switch self {
        case .debug:
            return .debugBuild
        case .release:
            return .releaseBuild
        }
    }
}

enum AppBuildInfo {
    // Packaged releases read these values from Packaging/Info.plist. SwiftPM debug runs do not have
    // that app bundle metadata, so the fallback mirrors the release plist and keeps the status menu
    // useful during development.
    private static let fallbackVersion = "0.1.0"
    private static let fallbackBuild = "1"

    static var configuration: ChumenBuildConfiguration {
        #if DEBUG
        return .debug
        #else
        return .release
        #endif
    }

    static var version: String {
        bundleString(for: "CFBundleShortVersionString") ?? fallbackVersion
    }

    static var build: String {
        bundleString(for: "CFBundleVersion") ?? fallbackBuild
    }

    static var buildDate: String? {
        bundleString(for: "ChumenBuildDate")
    }

    @MainActor
    static func menuTitle(model: AppModel) -> String {
        let versionText = build.isEmpty || build == version
            ? "v\(version)"
            : "v\(version) (\(build))"
        let dateText = buildDate.map { " · \($0)" } ?? ""
        return "\(versionText)\(dateText) · \(model.t(configuration.titleKey))"
    }

    private static func bundleString(for key: String) -> String? {
        guard let value = Bundle.main.object(forInfoDictionaryKey: key) as? String else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
