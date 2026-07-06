import Foundation

/// Centralizes runtime identity for packaged variants.
///
/// Release and debug apps can run side by side only if they do not share ports, Application
/// Support directories, Keychain services, Unix sockets, or privileged helper labels. Packaging
/// writes variant-specific Info.plist keys; SwiftPM/tests keep the release defaults.
public enum ChumenAppIdentity {
    public static let releaseBundleIdentifier = "io.github.chumen.native-macos"
    private static let previousAppToken = "lu" + "men"
    static let legacyBundleIdentifier = "io.github." + previousAppToken + ".native-macos"

    public static var bundleIdentifier: String {
        let value = Bundle.main.bundleIdentifier?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let value,
           value == releaseBundleIdentifier || value.hasPrefix("\(releaseBundleIdentifier).") {
            return value
        }
        return releaseBundleIdentifier
    }

    public static var appSupportDirectoryName: String {
        bundleIdentifier
    }

    public static var shouldMigrateLegacyAppSupport: Bool {
        appSupportDirectoryName == releaseBundleIdentifier
    }

    public static var defaultMixedPort: Int {
        bundleInt(for: "ChumenDefaultMixedPort", fallback: 19881)
    }

    public static var defaultSocksPort: Int {
        bundleInt(for: "ChumenDefaultSocksPort", fallback: 19882)
    }

    public static var defaultHTTPPort: Int {
        bundleInt(for: "ChumenDefaultHTTPPort", fallback: 19883)
    }

    public static var defaultRedirPort: Int {
        bundleInt(for: "ChumenDefaultRedirPort", fallback: 19884)
    }

    public static var defaultTProxyPort: Int {
        bundleInt(for: "ChumenDefaultTProxyPort", fallback: 19885)
    }

    public static var defaultExternalControllerPort: Int {
        bundleInt(for: "ChumenDefaultExternalControllerPort", fallback: 19897)
    }

    public static var defaultDNSListen: String {
        bundleString(for: "ChumenDefaultDNSListen") ?? "127.0.0.1:1053"
    }

    public static var defaultTunDevice: String {
        bundleString(for: "ChumenDefaultTunDevice") ?? "utun1024"
    }

    public static var defaultCoreProcessName: String {
        bundleString(for: "ChumenDefaultCoreProcessName") ?? "door"
    }

    public static func keychainService(suffix: String) -> String {
        "\(bundleIdentifier).\(suffix)"
    }

    public static var privilegedLaunchDaemonLabel: String {
        "\(bundleIdentifier).mihomo"
    }

    public static var privilegedLaunchDaemonPlistPath: String {
        "/Library/LaunchDaemons/\(privilegedLaunchDaemonLabel).plist"
    }

    public static var privilegedHelperLaunchDaemonLabel: String {
        "\(bundleIdentifier).helper"
    }

    public static var privilegedHelperLaunchDaemonPlistPath: String {
        "/Library/LaunchDaemons/\(privilegedHelperLaunchDaemonLabel).plist"
    }

    public static var privilegedHelperInstallPath: String {
        "/Library/PrivilegedHelperTools/\(privilegedHelperLaunchDaemonLabel)"
    }

    static var legacyPrivilegedLaunchDaemonLabel: String {
        "\(legacyBundleIdentifier).mihomo"
    }

    static var legacyPrivilegedLaunchDaemonPlistPath: String {
        "/Library/LaunchDaemons/\(legacyPrivilegedLaunchDaemonLabel).plist"
    }

    static var legacyPrivilegedHelperLaunchDaemonLabel: String {
        "\(legacyBundleIdentifier).helper"
    }

    static var legacyPrivilegedHelperLaunchDaemonPlistPath: String {
        "/Library/LaunchDaemons/\(legacyPrivilegedHelperLaunchDaemonLabel).plist"
    }

    static var legacyPrivilegedHelperInstallPath: String {
        "/Library/PrivilegedHelperTools/\(legacyPrivilegedHelperLaunchDaemonLabel)"
    }

    private static func bundleInt(for key: String, fallback: Int) -> Int {
        switch Bundle.main.object(forInfoDictionaryKey: key) {
        case let value as Int:
            return value
        case let value as NSNumber:
            return value.intValue
        case let value as String:
            return Int(value.trimmingCharacters(in: .whitespacesAndNewlines)) ?? fallback
        default:
            return fallback
        }
    }

    private static func bundleString(for key: String) -> String? {
        guard let value = Bundle.main.object(forInfoDictionaryKey: key) as? String else {
            return nil
        }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
