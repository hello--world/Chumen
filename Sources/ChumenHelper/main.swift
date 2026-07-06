import Darwin
import Foundation
import ChumenCore

private final class HelperServer: @unchecked Sendable {
    let socketPath: String
    let allowedUID: uid_t
    let allowedGID: gid_t
    private let queue = DispatchQueue(label: "io.github.chumen.helper.core")
    private var currentProcess: Process?
    private var currentRuntimeConfigPath: String?
    private var currentAppHome: String?
    private var currentPIDPath: String?
    private var currentLogHandle: FileHandle?

    init(socketPath: String, allowedUID: uid_t, allowedGID: gid_t) {
        self.socketPath = socketPath
        self.allowedUID = allowedUID
        self.allowedGID = allowedGID
    }

    func run() throws -> Never {
        let parent = URL(fileURLWithPath: socketPath).deletingLastPathComponent()
        try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
        unlink(socketPath)

        let serverFD = Darwin.socket(AF_UNIX, SOCK_STREAM, 0)
        guard serverFD >= 0 else {
            throw HelperError("socket failed: errno \(errno)")
        }
        defer { Darwin.close(serverFD) }

        var reuse = 1
        setsockopt(serverFD, SOL_SOCKET, SO_REUSEADDR, &reuse, socklen_t(MemoryLayout<Int32>.size))

        try ChumenUnixSocket.withAddress(path: socketPath) { address, length in
            guard Darwin.bind(serverFD, address, length) == 0 else {
                throw HelperError("bind failed: errno \(errno)")
            }
        }

        chown(socketPath, allowedUID, allowedGID)
        chmod(socketPath, S_IRUSR | S_IWUSR)

        guard Darwin.listen(serverFD, 16) == 0 else {
            throw HelperError("listen failed: errno \(errno)")
        }

        while true {
            let clientFD = Darwin.accept(serverFD, nil, nil)
            guard clientFD >= 0 else {
                if errno == EINTR { continue }
                continue
            }
            DispatchQueue.global(qos: .userInitiated).async {
                self.handleClient(clientFD)
            }
        }
    }

    private func handleClient(_ clientFD: Int32) {
        defer { Darwin.close(clientFD) }
        do {
            try verifyPeer(clientFD)
            let request = try readRequest(clientFD)
            let response = try queue.sync {
                try handle(request)
            }
            try write(response, to: clientFD)
        } catch {
            try? write(PrivilegedHelperResponse(ok: false, message: error.localizedDescription), to: clientFD)
        }
    }

    private func verifyPeer(_ clientFD: Int32) throws {
        var peerUID = uid_t()
        var peerGID = gid_t()
        guard getpeereid(clientFD, &peerUID, &peerGID) == 0 else {
            throw HelperError("getpeereid failed: errno \(errno)")
        }
        guard peerUID == allowedUID || peerUID == 0 else {
            throw HelperError("client uid \(peerUID) is not allowed")
        }
    }

    private func readRequest(_ clientFD: Int32) throws -> PrivilegedHelperRequest {
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 4096)
        while data.count < 64 * 1024 {
            let count = Darwin.recv(clientFD, &buffer, buffer.count, 0)
            if count > 0 {
                data.append(buffer, count: count)
                if buffer[..<count].contains(0x0a) { break }
            } else if count == 0 {
                break
            } else if errno == EINTR {
                continue
            } else {
                throw HelperError("read failed: errno \(errno)")
            }
        }
        if let newline = data.firstIndex(of: 0x0a) {
            data = data[..<newline]
        }
        guard !data.isEmpty else { throw HelperError("empty request") }
        return try JSONDecoder().decode(PrivilegedHelperRequest.self, from: data)
    }

    private func write(_ response: PrivilegedHelperResponse, to clientFD: Int32) throws {
        var data = try JSONEncoder().encode(response)
        data.append(0x0a)
        try data.withUnsafeBytes { rawBuffer in
            guard let baseAddress = rawBuffer.baseAddress else { return }
            var sent = 0
            while sent < data.count {
                let written = Darwin.send(clientFD, baseAddress.advanced(by: sent), data.count - sent, 0)
                guard written > 0 else {
                    throw HelperError("write failed: errno \(errno)")
                }
                sent += written
            }
        }
    }

    private func handle(_ request: PrivilegedHelperRequest) throws -> PrivilegedHelperResponse {
        switch request.command {
        case "ping":
            return PrivilegedHelperResponse(ok: true, message: "ready")
        case "start":
            let pid = try start(request)
            return PrivilegedHelperResponse(ok: true, message: "started", pid: pid)
        case "stop":
            try stop(request: request)
            return PrivilegedHelperResponse(ok: true, message: "stopped")
        case "status":
            if let process = currentProcess, process.isRunning {
                return PrivilegedHelperResponse(ok: true, message: "running", pid: process.processIdentifier)
            }
            return PrivilegedHelperResponse(ok: true, message: "stopped")
        default:
            throw HelperError("unknown command: \(request.command)")
        }
    }

    private func start(_ request: PrivilegedHelperRequest) throws -> Int32 {
        let corePath = try required(request.corePath, "corePath")
        let appHome = try required(request.appHome, "appHome")
        let runtimeConfigPath = try required(request.runtimeConfigPath, "runtimeConfigPath")
        let controllerSocketPath = try required(request.controllerSocketPath, "controllerSocketPath")
        let logPath = try required(request.logPath, "logPath")
        let pidPath = try required(request.pidPath, "pidPath")

        try stop(runtimeConfigPath: runtimeConfigPath, appHome: appHome, pidPath: pidPath)
        try FileManager.default.createDirectory(
            at: URL(fileURLWithPath: logPath).deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try FileManager.default.createDirectory(
            at: URL(fileURLWithPath: controllerSocketPath).deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        unlink(controllerSocketPath)

        let logHandle = try openAppendLogHandle(path: logPath)
        try logHandle.write(contentsOf: Data("[helper privileged core start]\n".utf8))

        let process = Process()
        process.executableURL = URL(fileURLWithPath: corePath)
        process.currentDirectoryURL = URL(fileURLWithPath: appHome, isDirectory: true)
        process.arguments = [
            "-d", appHome,
            "-f", runtimeConfigPath,
            "-ext-ctl-unix", controllerSocketPath
        ]
        process.environment = coreEnvironment(ageSecretKey: request.ageSecretKey)
        process.standardOutput = logHandle
        process.standardError = logHandle
        process.terminationHandler = { [weak self, weak process] terminated in
            guard let server = self else {
                try? logHandle.close()
                return
            }
            let terminatedProcess = process
            let terminationStatus = terminated.terminationStatus
            server.queue.async { [server, terminatedProcess, logHandle, terminationStatus] in
                if let terminatedProcess, server.currentProcess === terminatedProcess {
                    server.currentProcess = nil
                    server.currentLogHandle?.closeFile()
                    server.currentLogHandle = nil
                    if let pidPath = server.currentPIDPath {
                        try? FileManager.default.removeItem(atPath: pidPath)
                    }
                }
                if let data = "\n[helper core exited with status \(terminationStatus)]\n".data(using: .utf8) {
                    try? logHandle.write(contentsOf: data)
                }
                try? logHandle.close()
            }
        }

        try process.run()
        try "\(process.processIdentifier)\n".write(toFile: pidPath, atomically: true, encoding: .utf8)
        chmod(pidPath, 0o644)

        currentProcess = process
        currentRuntimeConfigPath = runtimeConfigPath
        currentAppHome = appHome
        currentPIDPath = pidPath
        currentLogHandle = logHandle
        return process.processIdentifier
    }

    private func stop(request: PrivilegedHelperRequest) throws {
        try stop(
            runtimeConfigPath: request.runtimeConfigPath ?? currentRuntimeConfigPath,
            appHome: request.appHome ?? currentAppHome,
            pidPath: request.pidPath ?? currentPIDPath
        )
    }

    private func stop(runtimeConfigPath: String?, appHome: String?, pidPath: String?) throws {
        if let process = currentProcess, process.isRunning {
            process.terminate()
            waitUntilExit(process)
        }
        currentProcess = nil
        currentLogHandle?.closeFile()
        currentLogHandle = nil

        var pids = Set<Int32>()
        if let pidPath,
           let text = try? String(contentsOfFile: pidPath, encoding: .utf8),
           let pid = Int32(text.trimmingCharacters(in: .whitespacesAndNewlines)) {
            pids.insert(pid)
        }
        if let runtimeConfigPath, let appHome {
            pids.formUnion(managedPIDs(runtimeConfigPath: runtimeConfigPath, appHome: appHome))
        }
        for pid in pids {
            kill(pid, SIGTERM)
        }
        Thread.sleep(forTimeInterval: 0.3)
        for pid in pids where processExists(pid: pid) {
            kill(pid, SIGKILL)
        }
        if let pidPath {
            try? FileManager.default.removeItem(atPath: pidPath)
        }
    }

    private func managedPIDs(runtimeConfigPath: String, appHome: String) -> [Int32] {
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
        let ownPID = Int32(ProcessInfo.processInfo.processIdentifier)
        return output.split(separator: "\n").compactMap { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard let firstSpace = trimmed.firstIndex(where: { $0 == " " || $0 == "\t" }) else { return nil }
            let pidText = trimmed[..<firstSpace]
            let command = trimmed[firstSpace...]
            guard let pid = Int32(pidText), pid != ownPID else { return nil }
            guard command.contains(runtimeConfigPath),
                  command.contains(appHome),
                  command.contains("-ext-ctl-unix") else { return nil }
            return pid
        }
    }

    private func required(_ value: String?, _ name: String) throws -> String {
        guard let value, !value.isEmpty else {
            throw HelperError("missing \(name)")
        }
        return value
    }

    private func prepareFile(path: String) throws {
        if !FileManager.default.fileExists(atPath: path) {
            FileManager.default.createFile(atPath: path, contents: nil)
        }
    }

    private func openAppendLogHandle(path: String) throws -> FileHandle {
        try prepareFile(path: path)
        let descriptor = Darwin.open(path, O_WRONLY | O_CREAT | O_APPEND, S_IRUSR | S_IWUSR | S_IRGRP | S_IROTH)
        guard descriptor >= 0 else {
            throw HelperError("failed to open log file \(path): errno \(errno)")
        }
        return FileHandle(fileDescriptor: descriptor, closeOnDealloc: true)
    }

    private func waitUntilExit(_ process: Process) {
        for _ in 0..<20 {
            if !process.isRunning { return }
            Thread.sleep(forTimeInterval: 0.1)
        }
        if process.isRunning {
            process.interrupt()
        }
    }

    private func processExists(pid: Int32) -> Bool {
        kill(pid, 0) == 0
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
}

private struct HelperError: LocalizedError {
    let message: String

    init(_ message: String) {
        self.message = message
    }

    var errorDescription: String? { message }
}

private func parseArguments() throws -> (socketPath: String, allowedUID: uid_t, allowedGID: gid_t) {
    var socketPath = ""
    var allowedUID: uid_t?
    var allowedGID: gid_t?
    var index = 1
    let args = CommandLine.arguments
    while index < args.count {
        switch args[index] {
        case "--socket":
            index += 1
            if index < args.count { socketPath = args[index] }
        case "--allowed-uid":
            index += 1
            if index < args.count, let value = uid_t(args[index]) { allowedUID = value }
        case "--allowed-gid":
            index += 1
            if index < args.count, let value = gid_t(args[index]) { allowedGID = value }
        default:
            break
        }
        index += 1
    }
    guard !socketPath.isEmpty else { throw HelperError("missing --socket") }
    guard let allowedUID else { throw HelperError("missing --allowed-uid") }
    guard let allowedGID else { throw HelperError("missing --allowed-gid") }
    return (socketPath, allowedUID, allowedGID)
}

do {
    let arguments = try parseArguments()
    try HelperServer(
        socketPath: arguments.socketPath,
        allowedUID: arguments.allowedUID,
        allowedGID: arguments.allowedGID
    ).run()
} catch {
    FileHandle.standardError.write(Data("ChumenHelper: \(error.localizedDescription)\n".utf8))
    exit(1)
}
