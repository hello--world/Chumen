import Darwin
import Foundation

public struct PrivilegedHelperRequest: Codable, Sendable {
    public var command: String
    public var corePath: String?
    public var appHome: String?
    public var runtimeConfigPath: String?
    public var controllerSocketPath: String?
    public var logPath: String?
    public var pidPath: String?

    public init(
        command: String,
        corePath: String? = nil,
        appHome: String? = nil,
        runtimeConfigPath: String? = nil,
        controllerSocketPath: String? = nil,
        logPath: String? = nil,
        pidPath: String? = nil
    ) {
        self.command = command
        self.corePath = corePath
        self.appHome = appHome
        self.runtimeConfigPath = runtimeConfigPath
        self.controllerSocketPath = controllerSocketPath
        self.logPath = logPath
        self.pidPath = pidPath
    }
}

public struct PrivilegedHelperResponse: Codable, Sendable {
    public var ok: Bool
    public var message: String
    public var pid: Int32?

    public init(ok: Bool, message: String, pid: Int32? = nil) {
        self.ok = ok
        self.message = message
        self.pid = pid
    }
}

public enum ChumenUnixSocket {
    public static func withAddress<T>(
        path: String,
        _ body: (UnsafePointer<sockaddr>, socklen_t) throws -> T
    ) rethrows -> T {
        var address = sockaddr_un()
        let maxPathLength = MemoryLayout.size(ofValue: address.sun_path)
        let pathBytes = Array(path.utf8)
        precondition(pathBytes.count < maxPathLength, "Unix socket path is too long: \(path)")

        let pathOffset = MemoryLayout<sockaddr_un>.offset(of: \.sun_path) ?? 2
        let length = socklen_t(pathOffset + pathBytes.count + 1)
        address.sun_len = UInt8(length)
        address.sun_family = sa_family_t(AF_UNIX)
        withUnsafeMutableBytes(of: &address.sun_path) { rawBuffer in
            rawBuffer.initializeMemory(as: UInt8.self, repeating: 0)
            pathBytes.withUnsafeBytes { sourceBuffer in
                guard let source = sourceBuffer.baseAddress else { return }
                rawBuffer.copyMemory(from: UnsafeRawBufferPointer(start: source, count: pathBytes.count))
            }
        }

        return try withUnsafePointer(to: &address) { pointer in
            try pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { socketAddress in
                try body(socketAddress, length)
            }
        }
    }
}

public struct PrivilegedHelperClient: Sendable {
    public let socketURL: URL
    public var timeout: TimeInterval

    public init(socketURL: URL, timeout: TimeInterval = 3) {
        self.socketURL = socketURL
        self.timeout = timeout
    }

    public func send(_ request: PrivilegedHelperRequest) throws -> PrivilegedHelperResponse {
        let socketFD = Darwin.socket(AF_UNIX, SOCK_STREAM, 0)
        guard socketFD >= 0 else {
            throw ChumenError.commandFailed("Failed to create helper socket: errno \(errno)")
        }
        defer { Darwin.close(socketFD) }

        var readTimeout = timeval(tv_sec: Int(timeout), tv_usec: 0)
        setsockopt(socketFD, SOL_SOCKET, SO_RCVTIMEO, &readTimeout, socklen_t(MemoryLayout<timeval>.size))
        var writeTimeout = timeval(tv_sec: Int(timeout), tv_usec: 0)
        setsockopt(socketFD, SOL_SOCKET, SO_SNDTIMEO, &writeTimeout, socklen_t(MemoryLayout<timeval>.size))

        try ChumenUnixSocket.withAddress(path: socketURL.path) { address, length in
            guard Darwin.connect(socketFD, address, length) == 0 else {
                throw ChumenError.commandFailed("Privileged helper is not available: errno \(errno)")
            }
        }

        var payload = try JSONEncoder().encode(request)
        payload.append(0x0a)
        try payload.withUnsafeBytes { rawBuffer in
            guard let baseAddress = rawBuffer.baseAddress else { return }
            var sent = 0
            while sent < payload.count {
                let written = Darwin.send(
                    socketFD,
                    baseAddress.advanced(by: sent),
                    payload.count - sent,
                    0
                )
                guard written > 0 else {
                    throw ChumenError.commandFailed("Failed to write helper request: errno \(errno)")
                }
                sent += written
            }
        }

        Darwin.shutdown(socketFD, SHUT_WR)

        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 4096)
        while true {
            let count = Darwin.recv(socketFD, &buffer, buffer.count, 0)
            if count > 0 {
                data.append(buffer, count: count)
            } else if count == 0 {
                break
            } else if errno == EINTR {
                continue
            } else {
                throw ChumenError.commandFailed("Failed to read helper response: errno \(errno)")
            }
        }

        let response = try JSONDecoder().decode(PrivilegedHelperResponse.self, from: data)
        guard response.ok else {
            throw ChumenError.commandFailed(response.message)
        }
        return response
    }
}
