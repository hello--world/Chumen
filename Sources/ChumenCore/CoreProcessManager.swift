import Darwin
import Foundation

public final class CoreProcessManager: @unchecked Sendable {
    public let paths: ChumenPaths
    public var onLog: (@Sendable (String) -> Void)?
    public var onExit: (@Sendable (Int32) -> Void)?

    private let fileManager: FileManager
    private let ageProtection: MihomoAgeRuntimeProtecting?
    private var protectionKeyStore: ChumenConfigProtectionKeyStore
    private var process: Process?
    private var logHandle: FileHandle?
    // Tracks the runtime file passed to mihomo. With config protection enabled this is an age
    // encrypted YAML file, not a transient plaintext bridge.
    private var activeRuntimeConfigURL: URL?

    public init(
        paths: ChumenPaths,
        fileManager: FileManager = .default,
        protectionKeyStore: ChumenConfigProtectionKeyStore? = nil,
        ageProtection: MihomoAgeRuntimeProtecting? = nil
    ) {
        self.paths = paths
        self.fileManager = fileManager
        self.protectionKeyStore = protectionKeyStore ?? ChumenConfigProtectionKeyStore(ageIdentityURL: paths.ageIdentityURL)
        self.ageProtection = ageProtection
    }

    public func updateProtectionKeyStore(_ keyStore: ChumenConfigProtectionKeyStore) {
        // The GUI can unlock or disable PIN protection without recreating the process manager. The
        // manager only stores the keyStore reference used for future config generation; already
        // running mihomo processes keep their current runtime config until restart/reload.
        self.protectionKeyStore = keyStore
    }

    public var isRunning: Bool {
        process?.isRunning == true || !managedSidecarProcessIDs(excluding: nil).isEmpty
    }

    public var hasManagedSidecar: Bool {
        !managedSidecarProcessIDs(excluding: nil).isEmpty
    }

    public func managedRSSBytes() -> Int64? {
        var pids = Set<Int32>()
        if let process, process.isRunning {
            pids.insert(process.processIdentifier)
        }
        pids.formUnion(managedSidecarProcessIDs(excluding: nil))
        guard !pids.isEmpty else { return nil }

        let ps = Process()
        ps.executableURL = URL(fileURLWithPath: "/bin/ps")
        ps.arguments = [
            "-o",
            "rss=",
            "-p",
            pids.sorted().map(String.init).joined(separator: ",")
        ]

        let pipe = Pipe()
        ps.standardOutput = pipe
        ps.standardError = Pipe()

        do {
            try ps.run()
        } catch {
            return nil
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        ps.waitUntilExit()
        guard let output = String(data: data, encoding: .utf8) else { return nil }
        let totalKilobytes = output
            .split(whereSeparator: \.isWhitespace)
            .compactMap { Int64($0) }
            .reduce(Int64(0), +)
        return totalKilobytes > 0 ? totalKilobytes * 1024 : nil
    }

    public func start(settings: ChumenRuntimeSettings, profileAppendixYAML: String = "") throws {
        guard !isRunning else { throw ChumenError.processAlreadyRunning }
        let launchSettings = try managedLaunchSettings(from: settings)

        // 每次启动都重新生成并测试 runtime YAML，确保 GUI 设置和订阅内容同步到 mihomo。
        try terminateManagedSidecars(waitForExit: true)
        let runtimeConfigURL = try ChumenConfigurationBuilder.writeRuntimeConfig(
            settings: launchSettings,
            paths: paths,
            profileAppendixYAML: profileAppendixYAML,
            protectionKeyStore: protectionKeyStore,
            ageProtection: ageProtection
        )
        do {
            try prepareLogFile()
            let ageSecretKey = try runtimeAgeSecretKey(settings: launchSettings)
            try validateRuntimeConfig(settings: launchSettings, runtimeConfigURL: runtimeConfigURL, ageSecretKey: ageSecretKey)

            if launchSettings.enableTun {
                // TUN 通常需要特权网络能力，交给 helper 以 LaunchDaemon 方式启动内核。
                try startPrivileged(settings: launchSettings, runtimeConfigURL: runtimeConfigURL, ageSecretKey: ageSecretKey)
                activeRuntimeConfigURL = runtimeConfigURL
                scheduleLegacyRuntimeCleanup(runtimeConfigURL)
                return
            }

            // 普通代理模式用当前用户直接拉起 mihomo，并通过 Unix socket 暴露 controller。
            let process = Process()
            process.executableURL = URL(fileURLWithPath: launchSettings.corePath)
            process.currentDirectoryURL = paths.appHome
            process.arguments = [
                "-d",
                paths.appHome.path,
                "-f",
                runtimeConfigURL.path,
                "-ext-ctl-unix",
                paths.externalControllerSocketURL.path
            ]
            process.environment = coreEnvironment(ageSecretKey: ageSecretKey)

            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = pipe
            pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
                let data = handle.availableData
                guard !data.isEmpty, let text = String(data: data, encoding: .utf8) else { return }
                self?.appendLog(text)
            }

            process.terminationHandler = { [weak self] process in
                let status = process.terminationStatus
                self?.appendLog("\n[core exited with status \(status)]\n")
                guard let self, self.process === process else { return }
                self.process = nil
                self.onExit?(status)
            }

            try process.run()
            self.process = process
            activeRuntimeConfigURL = runtimeConfigURL
            scheduleLegacyRuntimeCleanup(runtimeConfigURL)
            appendLog("[core started] \(launchSettings.corePath)\n")
        } catch {
            ChumenConfigurationBuilder.cleanupRuntimePlaintextFile(runtimeConfigURL, paths: paths)
            throw error
        }
    }

    public func stop(waitForExit: Bool = false) {
        guard let process else {
            do {
                try terminateManagedSidecars(waitForExit: waitForExit)
                try? ChumenConfigurationBuilder.cleanupRuntimePlaintextFiles(paths: paths)
            } catch {
                appendLog("[core stop failed] \(error.localizedDescription)\n")
            }
            return
        }
        self.process = nil
        process.terminate()

        if waitForExit {
            waitUntilProcessExits(process)
        } else if process.isRunning {
            DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 2) { [weak process] in
                if process?.isRunning == true {
                    process?.interrupt()
                }
            }
        }
        appendLog("[core stop requested]\n")
        do {
            try terminateManagedSidecars(excluding: process.processIdentifier, waitForExit: waitForExit)
            try? ChumenConfigurationBuilder.cleanupRuntimePlaintextFiles(paths: paths)
            activeRuntimeConfigURL = nil
        } catch {
            appendLog("[core stop failed] \(error.localizedDescription)\n")
        }
    }

    public func restart(settings: ChumenRuntimeSettings, profileAppendixYAML: String = "") throws {
        stop(waitForExit: true)
        try start(settings: settings, profileAppendixYAML: profileAppendixYAML)
    }

    deinit {
        process?.terminate()
        logHandle?.closeFile()
        try? ChumenConfigurationBuilder.cleanupRuntimePlaintextFiles(paths: paths)
    }

    public func appendEventLog(_ message: String) {
        if logHandle == nil {
            try? prepareLogFile()
        }
        appendLog("[app \(Self.isoTimestamp())] \(message)\n")
    }

    private func prepareLogFile() throws {
        try paths.ensureDirectories(fileManager: fileManager)
        if !fileManager.fileExists(atPath: paths.sidecarLogURL.path) {
            fileManager.createFile(atPath: paths.sidecarLogURL.path, contents: nil)
        }
        logHandle?.closeFile()
        logHandle = try FileHandle(forWritingTo: paths.sidecarLogURL)
        try logHandle?.seekToEnd()
    }

    private func appendLog(_ text: String) {
        if let data = text.data(using: .utf8) {
            try? logHandle?.write(contentsOf: data)
        }
        onLog?(text)
    }

    private func managedLaunchSettings(from settings: ChumenRuntimeSettings) throws -> ChumenRuntimeSettings {
        guard !settings.corePath.isEmpty else { throw ChumenError.missingCorePath }
        guard fileManager.isExecutableFile(atPath: settings.corePath) else {
            throw ChumenError.coreNotExecutable(settings.corePath)
        }

        var launchSettings = settings
        launchSettings.corePath = try prepareManagedCoreExecutable(
            sourcePath: settings.corePath,
            executableName: settings.managedCoreExecutableName
        )
        return launchSettings
    }

    private func prepareManagedCoreExecutable(sourcePath: String, executableName: String) throws -> String {
        // Process names come from the executable basename. Use a Chumen-controlled symlink basename
        // instead of copying the binary so core updates are picked up immediately and no stale 40 MB
        // managed copy can be launched after the user changes or upgrades the selected core.
        try paths.ensureDirectories(fileManager: fileManager)
        let sourceURL = URL(fileURLWithPath: sourcePath)
        let targetURL = paths.managedCoreDirectoryURL.appendingPathComponent(executableName)
        if sourceURL.standardizedFileURL.path == targetURL.standardizedFileURL.path {
            return targetURL.path
        }
        let existingSymlink = try? fileManager.destinationOfSymbolicLink(atPath: targetURL.path)
        if fileManager.fileExists(atPath: targetURL.path) || existingSymlink != nil {
            try fileManager.removeItem(at: targetURL)
        }
        try fileManager.createSymbolicLink(at: targetURL, withDestinationURL: sourceURL)
        return targetURL.path
    }

    private func validateRuntimeConfig(settings: ChumenRuntimeSettings, runtimeConfigURL: URL, ageSecretKey: String?) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: settings.corePath)
        process.currentDirectoryURL = paths.appHome
        process.arguments = [
            "-t",
            "-d",
            paths.appHome.path,
            "-f",
            runtimeConfigURL.path
        ]
        process.environment = coreEnvironment(ageSecretKey: ageSecretKey)

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        try process.run()
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""
        if !output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            appendLog("[core config validation]\n\(output)\n")
        }

        // 先执行 mihomo -t，配置错误时不进入真正启动流程，错误信息直接回到 UI/CLI。
        guard process.terminationStatus == 0 else {
            let message = output.trimmingCharacters(in: .whitespacesAndNewlines)
            throw ChumenError.commandFailed(message.isEmpty ? "Core rejected the generated configuration." : message)
        }
    }

    private func scheduleLegacyRuntimeCleanup(_ url: URL) {
        // Intent: runtime protection now keeps the stable -f file encrypted for
        // mihomo. This delayed cleanup exists only for old temp/plaintext paths
        // that may still be produced by tests or left behind by older versions.
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 5) { [paths] in
            ChumenConfigurationBuilder.cleanupRuntimePlaintextFile(url, paths: paths)
        }
    }

    private func startPrivileged(settings: ChumenRuntimeSettings, runtimeConfigURL: URL, ageSecretKey: String?) throws {
        appendLog("[core privileged start requested] \(settings.corePath)\n")
        try ensurePrivilegedHelperInstalled(settings: settings)
        let response = try privilegedHelperClient().send(privilegedHelperRequest(
            command: "start",
            settings: settings,
            runtimeConfigURL: runtimeConfigURL,
            ageSecretKey: ageSecretKey
        ))
        appendLog("[core privileged helper start] \(response.message) pid=\(response.pid.map(String.init) ?? "-")\n")
    }

    private func stopPrivilegedSidecars(pids: [Int32]) throws {
        do {
            let response = try privilegedHelperClient().send(privilegedHelperRequest(
                command: "stop",
                settings: nil,
                runtimeConfigURL: activeRuntimeConfigURL
            ))
            appendLog("[core privileged helper stop] \(response.message)\n")
            return
        } catch {
            appendLog("[core privileged helper stop failed] \(error.localizedDescription)\n")
        }

        // helper 不可用时兜底走一次管理员脚本，避免 TUN 内核残留在后台。
        let pidList = pids.map(String.init).joined(separator: " ")
        let label = Self.privilegedLaunchDaemonLabel
        let plistPath = Self.privilegedLaunchDaemonPlistPath
        let script = """
        #!/bin/sh
        set +e
        /bin/launchctl bootout system/\(label) >/dev/null 2>&1
        /bin/launchctl bootout system \(Self.shellQuote(plistPath)) >/dev/null 2>&1
        for pid in \(pidList); do
          kill "$pid" 2>/dev/null
        done
        sleep 1
        for pid in \(pidList); do
          kill -KILL "$pid" 2>/dev/null
        done
        rm -f \(Self.shellQuote(paths.privilegedCorePIDURL.path))
        rm -f \(Self.shellQuote(plistPath))
        exit 0
        """
        try runPrivilegedScript(script, at: paths.privilegedStopScriptURL)
    }

    private func ensurePrivilegedHelperInstalled(settings: ChumenRuntimeSettings) throws {
        if privilegedHelperIsAvailable() {
            return
        }
        appendLog("[privileged helper install requested]\n")
        try installPrivilegedHelper(settings: settings)

        var lastError: Error?
        for _ in 0..<24 {
            if privilegedHelperIsAvailable() {
                appendLog("[privileged helper ready]\n")
                return
            }
            do {
                _ = try privilegedHelperClient().send(PrivilegedHelperRequest(command: "ping"))
            } catch {
                lastError = error
            }
            Thread.sleep(forTimeInterval: 0.25)
        }
        throw ChumenError.commandFailed("Privileged helper did not become available: \(lastError?.localizedDescription ?? "unknown error")")
    }

    private func privilegedHelperIsAvailable() -> Bool {
        (try? privilegedHelperClient().send(PrivilegedHelperRequest(command: "ping")))?.ok == true
    }

    private func privilegedHelperClient() -> PrivilegedHelperClient {
        PrivilegedHelperClient(socketURL: paths.privilegedHelperSocketURL)
    }

    private func privilegedHelperRequest(
        command: String,
        settings: ChumenRuntimeSettings?,
        runtimeConfigURL: URL? = nil,
        ageSecretKey: String? = nil
    ) -> PrivilegedHelperRequest {
        PrivilegedHelperRequest(
            command: command,
            corePath: settings?.corePath,
            appHome: paths.appHome.path,
            runtimeConfigPath: runtimeConfigURL?.path ?? activeRuntimeConfigURL?.path ?? paths.runtimeConfigURL.path,
            controllerSocketPath: paths.externalControllerSocketURL.path,
            logPath: paths.sidecarLogURL.path,
            pidPath: paths.privilegedCorePIDURL.path,
            ageSecretKey: ageSecretKey
        )
    }

    private func runtimeAgeSecretKey(settings: ChumenRuntimeSettings) throws -> String? {
        guard settings.protectConfigFiles else { return nil }
        if let ageProtection {
            return try ageProtection.secretKey(corePath: settings.corePath)
        }
        return try protectionKeyStore.loadOrCreateAgeKeyPair(corePath: settings.corePath).secretKey
    }

    private func coreEnvironment(ageSecretKey: String?) -> [String: String] {
        var environment = ProcessInfo.processInfo.environment
        if let ageSecretKey, !ageSecretKey.isEmpty {
            environment["CLASH_AGE_SECRET_KEY"] = ageSecretKey
        } else {
            environment.removeValue(forKey: "CLASH_AGE_SECRET_KEY")
        }
        return environment
    }

    private func installPrivilegedHelper(settings: ChumenRuntimeSettings) throws {
        let helperSourcePath = try bundledHelperPath(settings: settings)
        let helperLogPath = paths.logsDirectoryURL.appendingPathComponent("helper.log").path
        let userID = getuid()
        let groupID = getgid()
        let plist = Self.helperLaunchDaemonPlist(
            helperPath: Self.privilegedHelperInstallPath,
            socketPath: paths.privilegedHelperSocketURL.path,
            logPath: helperLogPath,
            allowedUID: userID,
            allowedGID: groupID,
            label: Self.privilegedHelperLaunchDaemonLabel
        )
        // 安装新 helper 前清掉旧代号的 LaunchDaemon，避免两个特权服务同时管理内核。
        let quotedAppHome = Self.shellQuote(paths.appHome.path)
        let quotedLogsDirectory = Self.shellQuote(paths.logsDirectoryURL.path)
        let quotedSocketDirectory = Self.shellQuote(paths.socketDirectoryURL.path)
        let script = """
        #!/bin/sh
        set -eu
        umask 022
        /bin/launchctl bootout system/\(Self.privilegedHelperLaunchDaemonLabel) >/dev/null 2>&1 || true
        /bin/launchctl bootout system \(Self.shellQuote(Self.privilegedHelperLaunchDaemonPlistPath)) >/dev/null 2>&1 || true
        /bin/launchctl bootout system/\(Self.privilegedLaunchDaemonLabel) >/dev/null 2>&1 || true
        /bin/launchctl bootout system \(Self.shellQuote(Self.privilegedLaunchDaemonPlistPath)) >/dev/null 2>&1 || true
        /bin/launchctl bootout system/\(Self.legacyPrivilegedHelperLaunchDaemonLabel) >/dev/null 2>&1 || true
        /bin/launchctl bootout system \(Self.shellQuote(Self.legacyPrivilegedHelperLaunchDaemonPlistPath)) >/dev/null 2>&1 || true
        /bin/launchctl bootout system/\(Self.legacyPrivilegedLaunchDaemonLabel) >/dev/null 2>&1 || true
        /bin/launchctl bootout system \(Self.shellQuote(Self.legacyPrivilegedLaunchDaemonPlistPath)) >/dev/null 2>&1 || true
        /bin/rm -f \(Self.shellQuote(Self.privilegedLaunchDaemonPlistPath))
        /bin/rm -f \(Self.shellQuote(Self.legacyPrivilegedLaunchDaemonPlistPath))
        /bin/rm -f \(Self.shellQuote(Self.legacyPrivilegedHelperLaunchDaemonPlistPath))
        /bin/rm -f \(Self.shellQuote(Self.legacyPrivilegedHelperInstallPath))
        /bin/mkdir -p /Library/PrivilegedHelperTools \(quotedAppHome) \(quotedLogsDirectory) \(quotedSocketDirectory)
        /bin/cp \(Self.shellQuote(helperSourcePath)) \(Self.shellQuote(Self.privilegedHelperInstallPath))
        /usr/sbin/chown root:wheel \(Self.shellQuote(Self.privilegedHelperInstallPath))
        /bin/chmod 755 \(Self.shellQuote(Self.privilegedHelperInstallPath))
        /usr/sbin/chown \(userID):\(groupID) \(quotedAppHome) \(quotedLogsDirectory) \(quotedSocketDirectory) 2>/dev/null || true
        /bin/rm -f \(Self.shellQuote(paths.privilegedHelperSocketURL.path))
        /bin/cat > \(Self.shellQuote(Self.privilegedHelperLaunchDaemonPlistPath)) <<'CHUMEN_HELPER_PLIST'
        \(plist)
        CHUMEN_HELPER_PLIST
        /usr/sbin/chown root:wheel \(Self.shellQuote(Self.privilegedHelperLaunchDaemonPlistPath))
        /bin/chmod 644 \(Self.shellQuote(Self.privilegedHelperLaunchDaemonPlistPath))
        /bin/launchctl bootstrap system \(Self.shellQuote(Self.privilegedHelperLaunchDaemonPlistPath))
        /bin/launchctl kickstart -k system/\(Self.privilegedHelperLaunchDaemonLabel) >/dev/null 2>&1 || true
        exit 0
        """
        try runPrivilegedScript(script, at: paths.privilegedStartScriptURL)
    }

    private func bundledHelperPath(settings: ChumenRuntimeSettings) throws -> String {
        let executableDirectory = URL(fileURLWithPath: CommandLine.arguments[0]).deletingLastPathComponent()
        let candidates = [
            Bundle.main.resourceURL?.appendingPathComponent("ChumenHelper"),
            URL(fileURLWithPath: settings.corePath).deletingLastPathComponent().appendingPathComponent("ChumenHelper"),
            executableDirectory.appendingPathComponent("ChumenHelper")
        ].compactMap { $0 }

        for candidate in candidates where fileManager.isExecutableFile(atPath: candidate.path) {
            return candidate.path
        }
        throw ChumenError.commandFailed("Bundled privileged helper was not found.")
    }

    private func runPrivilegedScript(_ script: String, at scriptURL: URL) throws {
        try paths.ensureDirectories(fileManager: fileManager)
        try script.write(to: scriptURL, atomically: true, encoding: .utf8)
        try fileManager.setAttributes([.posixPermissions: 0o700], ofItemAtPath: scriptURL.path)

        let command = "/bin/sh \(Self.shellQuote(scriptURL.path))"
        let appleScript = "do shell script \(Self.appleScriptString(command)) with administrator privileges"

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", appleScript]

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        try process.run()
        process.waitUntilExit()

        let output = String(data: outputPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let errorOutput = String(data: errorPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        guard process.terminationStatus == 0 else {
            let message = [output, errorOutput]
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .joined(separator: "\n")
            throw ChumenError.commandFailed(message.isEmpty ? "Administrator authorization failed." : message)
        }
    }

    private func waitUntilProcessExits(_ process: Process) {
        for _ in 0..<20 {
            if !process.isRunning {
                return
            }
            Thread.sleep(forTimeInterval: 0.1)
        }

        if process.isRunning {
            process.interrupt()
        }
    }

    private func terminateManagedSidecars(excluding excludedPID: Int32? = nil, waitForExit: Bool) throws {
        let pids = managedSidecarProcessIDs(excluding: excludedPID)
        guard !pids.isEmpty else { return }

        var deniedPids: [Int32] = []
        for pid in pids {
            if kill(pid, SIGTERM) != 0, errno == EPERM {
                deniedPids.append(pid)
            }
        }

        if !deniedPids.isEmpty {
            appendLog("[core privileged stop requested] \(deniedPids.map(String.init).joined(separator: ","))\n")
            try stopPrivilegedSidecars(pids: deniedPids)
        }

        guard waitForExit else { return }
        for _ in 0..<20 {
            if pids.allSatisfy({ !processExists(pid: $0) }) {
                return
            }
            Thread.sleep(forTimeInterval: 0.1)
        }
    }

    private func managedSidecarProcessIDs(excluding excludedPID: Int32?) -> [Int32] {
        let ps = Process()
        ps.executableURL = URL(fileURLWithPath: "/bin/ps")
        ps.arguments = ["-axo", "pid=,command="]

        let pipe = Pipe()
        ps.standardOutput = pipe
        ps.standardError = Pipe()

        do {
            try ps.run()
        } catch {
            return []
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        ps.waitUntilExit()
        guard let output = String(data: data, encoding: .utf8) else { return [] }

        let appHomePath = paths.appHome.path
        let controllerSocketPath = paths.externalControllerSocketURL.path
        let ownPID = Int32(ProcessInfo.processInfo.processIdentifier)

        return output.split(separator: "\n").compactMap { line -> Int32? in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard let firstSpace = trimmed.firstIndex(where: { $0 == " " || $0 == "\t" }) else { return nil }
            let pidText = trimmed[..<firstSpace]
            let command = trimmed[firstSpace...]
            guard let pid = Int32(pidText), pid != ownPID, pid != excludedPID else { return nil }
            guard command.contains(appHomePath),
                  command.contains(controllerSocketPath),
                  command.contains("-ext-ctl-unix") else { return nil }
            return pid
        }
    }

    private func processExists(pid: Int32) -> Bool {
        kill(pid, 0) == 0
    }

    private static func shellQuote(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    private static func appleScriptString(_ value: String) -> String {
        "\"" + value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
        + "\""
    }

    private static let privilegedLaunchDaemonLabel = "io.github.chumen.native-macos.mihomo"
    private static let privilegedLaunchDaemonPlistPath = "/Library/LaunchDaemons/io.github.chumen.native-macos.mihomo.plist"
    private static let privilegedHelperLaunchDaemonLabel = "io.github.chumen.native-macos.helper"
    private static let privilegedHelperLaunchDaemonPlistPath = "/Library/LaunchDaemons/io.github.chumen.native-macos.helper.plist"
    private static let privilegedHelperInstallPath = "/Library/PrivilegedHelperTools/io.github.chumen.native-macos.helper"
    private static let previousAppToken = "lu" + "men"
    private static let previousBundleID = "io.github." + previousAppToken + ".native-macos"
    private static let legacyPrivilegedLaunchDaemonLabel = previousBundleID + ".mihomo"
    private static let legacyPrivilegedLaunchDaemonPlistPath = "/Library/LaunchDaemons/" + legacyPrivilegedLaunchDaemonLabel + ".plist"
    private static let legacyPrivilegedHelperLaunchDaemonLabel = previousBundleID + ".helper"
    private static let legacyPrivilegedHelperLaunchDaemonPlistPath = "/Library/LaunchDaemons/" + legacyPrivilegedHelperLaunchDaemonLabel + ".plist"
    private static let legacyPrivilegedHelperInstallPath = "/Library/PrivilegedHelperTools/" + legacyPrivilegedHelperLaunchDaemonLabel

    private static func helperLaunchDaemonPlist(
        helperPath: String,
        socketPath: String,
        logPath: String,
        allowedUID: uid_t,
        allowedGID: gid_t,
        label: String
    ) -> String {
        """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>Label</key>
            <string>\(xmlEscape(label))</string>
            <key>ProgramArguments</key>
            <array>
                <string>\(xmlEscape(helperPath))</string>
                <string>--socket</string>
                <string>\(xmlEscape(socketPath))</string>
                <string>--allowed-uid</string>
                <string>\(allowedUID)</string>
                <string>--allowed-gid</string>
                <string>\(allowedGID)</string>
            </array>
            <key>StandardOutPath</key>
            <string>\(xmlEscape(logPath))</string>
            <key>StandardErrorPath</key>
            <string>\(xmlEscape(logPath))</string>
            <key>RunAtLoad</key>
            <true/>
            <key>KeepAlive</key>
            <true/>
        </dict>
        </plist>
        """
    }

    private static func launchDaemonPlist(settings: ChumenRuntimeSettings, paths: ChumenPaths, label: String) -> String {
        """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>Label</key>
            <string>\(xmlEscape(label))</string>
            <key>ProgramArguments</key>
            <array>
                <string>\(xmlEscape(settings.corePath))</string>
                <string>-d</string>
                <string>\(xmlEscape(paths.appHome.path))</string>
                <string>-f</string>
                <string>\(xmlEscape(paths.runtimeConfigURL.path))</string>
                <string>-ext-ctl-unix</string>
                <string>\(xmlEscape(paths.externalControllerSocketURL.path))</string>
            </array>
            <key>WorkingDirectory</key>
            <string>\(xmlEscape(paths.appHome.path))</string>
            <key>StandardOutPath</key>
            <string>\(xmlEscape(paths.sidecarLogURL.path))</string>
            <key>StandardErrorPath</key>
            <string>\(xmlEscape(paths.sidecarLogURL.path))</string>
            <key>RunAtLoad</key>
            <true/>
        </dict>
        </plist>
        """
    }

    private static func xmlEscape(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
    }

    private static func isoTimestamp() -> String {
        ISO8601DateFormatter().string(from: Date())
    }
}
