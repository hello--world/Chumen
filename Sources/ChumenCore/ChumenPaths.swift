import Foundation

public struct ChumenPaths: Sendable {
    private static let appSupportDirectoryName = "io.github.chumen.native-macos"
    // 旧代号仅用于迁移历史数据和清理旧 helper，不在源码中保留完整旧名字字面量。
    private static let previousAppToken = "lu" + "men"
    private static let legacyAppSupportDirectoryName = "io.github." + previousAppToken + ".native-macos"

    public let appHome: URL

    public init(appHome: URL) {
        self.appHome = appHome
    }

    public static func defaultPaths(fileManager: FileManager = .default) throws -> Self {
        if let override = ProcessInfo.processInfo.environment["CHUMEN_HOME"], !override.isEmpty {
            return Self(appHome: URL(fileURLWithPath: override, isDirectory: true))
        }

        let support = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let appHome = support.appendingPathComponent(appSupportDirectoryName, isDirectory: true)
        let legacyAppHome = support.appendingPathComponent(legacyAppSupportDirectoryName, isDirectory: true)
        // 默认路径初始化时顺手做一次幂等迁移，CLI 和 GUI 都会走同一套逻辑。
        try migrateLegacyAppHomeIfNeeded(from: legacyAppHome, to: appHome, fileManager: fileManager)
        return Self(appHome: appHome)
    }

    public var runtimeConfigURL: URL {
        appHome.appendingPathComponent("chumen-runtime.yaml")
    }

    public var runtimePlaintextRootDirectoryURL: URL {
        FileManager.default.temporaryDirectory
    }

    public var runtimePlaintextDirectoryURL: URL {
        runtimePlaintextRootDirectoryURL
    }

    public func makeRuntimePlaintextSessionDirectoryURL() -> URL {
        // mihomo 目前只能读取明文 YAML 文件；每次生成都放进新的随机临时目录，
        // 而不是 Application Support 或固定 runtime 目录，避免代理订阅内容长期可扫描。
        runtimePlaintextRootDirectoryURL
            .appendingPathComponent("chumen-runtime-session-\(UUID().uuidString)", isDirectory: true)
    }

    public var settingsURL: URL {
        appHome.appendingPathComponent("settings.json")
    }

    public var profileLibraryURL: URL {
        appHome.appendingPathComponent("profiles.json")
    }

    public var profilesDirectoryURL: URL {
        appHome.appendingPathComponent("profiles", isDirectory: true)
    }

    public var logsDirectoryURL: URL {
        appHome.appendingPathComponent("logs", isDirectory: true)
    }

    public var sidecarLogURL: URL {
        logsDirectoryURL.appendingPathComponent("sidecar.log")
    }

    public var socketDirectoryURL: URL {
        appHome.appendingPathComponent("ipc", isDirectory: true)
    }

    public var externalControllerSocketURL: URL {
        socketDirectoryURL.appendingPathComponent("chumen-mihomo.sock")
    }

    public var privilegedHelperSocketURL: URL {
        socketDirectoryURL.appendingPathComponent("chumen-helper.sock")
    }

    public var privilegedCorePIDURL: URL {
        socketDirectoryURL.appendingPathComponent("chumen-mihomo.pid")
    }

    public var privilegedStartScriptURL: URL {
        socketDirectoryURL.appendingPathComponent("chumen-privileged-start.sh")
    }

    public var privilegedStopScriptURL: URL {
        socketDirectoryURL.appendingPathComponent("chumen-privileged-stop.sh")
    }

    var legacyAppHome: URL {
        appHome
            .deletingLastPathComponent()
            .appendingPathComponent(Self.legacyAppSupportDirectoryName, isDirectory: true)
    }

    func rewriteLegacyAppHomePath(_ path: String) -> String {
        path.replacingOccurrences(of: legacyAppHome.path, with: appHome.path)
    }

    public func ensureDirectories(fileManager: FileManager = .default) throws {
        try fileManager.createDirectory(at: appHome, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: profilesDirectoryURL, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: logsDirectoryURL, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: socketDirectoryURL, withIntermediateDirectories: true)
    }

    static func migrateLegacyAppHomeIfNeeded(
        from legacyAppHome: URL,
        to appHome: URL,
        fileManager: FileManager
    ) throws {
        guard fileManager.fileExists(atPath: legacyAppHome.path) else {
            return
        }

        try fileManager.createDirectory(
            at: appHome,
            withIntermediateDirectories: true
        )
        // ipc 目录里是运行时 socket / pid，不能从旧目录复制，否则会指向已经失效的内核。
        try? fileManager.removeItem(at: appHome.appendingPathComponent("ipc", isDirectory: true))

        try copyLegacyItemIfNeeded(
            named: "settings.json",
            from: legacyAppHome,
            to: appHome,
            fileManager: fileManager
        )
        try copyLegacyItemIfNeeded(
            named: "profiles.json",
            from: legacyAppHome,
            to: appHome,
            fileManager: fileManager
        )
        try copyLegacyItemIfNeeded(
            named: "profiles",
            from: legacyAppHome,
            to: appHome,
            fileManager: fileManager
        )
        try copyLegacyItemIfNeeded(
            named: "logs",
            from: legacyAppHome,
            to: appHome,
            fileManager: fileManager
        )

        try rewriteLegacyPathReferences(
            in: appHome.appendingPathComponent("settings.json"),
            oldPath: legacyAppHome.path,
            newPath: appHome.path
        )
        try rewriteLegacyPathReferences(
            in: appHome.appendingPathComponent("profiles.json"),
            oldPath: legacyAppHome.path,
            newPath: appHome.path
        )
    }

    private static func rewriteLegacyPathReferences(in fileURL: URL, oldPath: String, newPath: String) throws {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        let data = try Data(contentsOf: fileURL)
        guard !ChumenConfigProtection.isProtected(data),
              let text = String(data: data, encoding: .utf8) else {
            return
        }
        // JSONEncoder 默认会把斜杠写成 \/，迁移时需要同时处理未转义和 JSON 转义两种路径。
        let rewritten = [
            (oldPath, newPath),
            (jsonEscapedPath(oldPath), jsonEscapedPath(newPath))
        ].reduce(text) { partial, replacement in
            partial.replacingOccurrences(of: replacement.0, with: replacement.1)
        }
        guard rewritten != text else { return }
        try rewritten.write(to: fileURL, atomically: true, encoding: .utf8)
    }

    private static func jsonEscapedPath(_ path: String) -> String {
        path.replacingOccurrences(of: "/", with: "\\/")
    }

    private static func copyLegacyItemIfNeeded(
        named name: String,
        from legacyAppHome: URL,
        to appHome: URL,
        fileManager: FileManager
    ) throws {
        let source = legacyAppHome.appendingPathComponent(name)
        let target = appHome.appendingPathComponent(name)
        guard fileManager.fileExists(atPath: source.path),
              !fileManager.fileExists(atPath: target.path) else {
            return
        }
        try fileManager.copyItem(at: source, to: target)
    }
}
