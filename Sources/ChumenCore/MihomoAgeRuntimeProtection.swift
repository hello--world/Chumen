import Foundation

public protocol MihomoAgeRuntimeProtecting: Sendable {
    func encryptRuntimeConfig(_ plainData: Data, corePath: String) throws -> Data
    func secretKey(corePath: String) throws -> String
}

public struct MihomoAgeKeyPair: Codable, Equatable, Sendable {
    public var secretKey: String
    public var publicKey: String

    public init(secretKey: String, publicKey: String) {
        self.secretKey = secretKey
        self.publicKey = publicKey
    }
}

public final class MihomoAgeRuntimeProtection: MihomoAgeRuntimeProtecting, @unchecked Sendable {
    public static let shared = MihomoAgeRuntimeProtection()

    private let lock = NSLock()
    private var keyPair: MihomoAgeKeyPair?

    // Intent: runtime YAML must be readable by mihomo without leaving Chumen-owned
    // plaintext on disk. The key is deliberately process-local: Chumen generates
    // the age identity, encrypts the runtime file with mihomo's own subcommand,
    // and passes only the secret through the child process environment.

    public init() {}

    public func encryptRuntimeConfig(_ plainData: Data, corePath: String) throws -> Data {
        let pair = try loadOrCreateKeyPair(corePath: corePath)
        return try Self.encrypt(plainData, publicKey: pair.publicKey, corePath: corePath)
    }

    public func secretKey(corePath: String) throws -> String {
        try loadOrCreateKeyPair(corePath: corePath).secretKey
    }

    private func loadOrCreateKeyPair(corePath: String) throws -> MihomoAgeKeyPair {
        lock.lock()
        if let keyPair {
            lock.unlock()
            return keyPair
        }
        lock.unlock()

        let created = try Self.generateKeyPair(corePath: corePath)

        lock.lock()
        if let keyPair {
            lock.unlock()
            return keyPair
        }
        keyPair = created
        lock.unlock()
        return created
    }

    public static func generateKeyPair(corePath: String) throws -> MihomoAgeKeyPair {
        let output = try runAgeCommand(corePath: corePath, arguments: ["age", "keygen"])
        guard let text = String(data: output, encoding: .utf8) else {
            throw ChumenError.commandFailed("mihomo age keygen returned non-UTF-8 output.")
        }

        var publicKey = ""
        var secretKey = ""
        for line in text.components(separatedBy: .newlines) {
            if line.hasPrefix("# public key: ") {
                publicKey = String(line.dropFirst("# public key: ".count))
            } else if line.hasPrefix("AGE-SECRET-KEY-") || line.hasPrefix("AGE-PLUGIN-") {
                secretKey = line
            }
        }

        guard !publicKey.isEmpty, !secretKey.isEmpty else {
            throw ChumenError.commandFailed("mihomo age keygen did not return a usable key pair.")
        }
        return MihomoAgeKeyPair(secretKey: secretKey, publicKey: publicKey)
    }

    public static func encrypt(_ plainData: Data, publicKey: String, corePath: String) throws -> Data {
        try runAgeCommand(
            corePath: corePath,
            arguments: ["age", "encrypt", publicKey, "-", "-"],
            stdin: plainData
        )
    }

    public static func decrypt(_ encryptedData: Data, secretKey: String, corePath: String) throws -> Data {
        try runAgeCommand(
            corePath: corePath,
            arguments: ["age", "decrypt", secretKey, "-", "-"],
            stdin: encryptedData
        )
    }

    private static func runAgeCommand(corePath: String, arguments: [String], stdin: Data? = nil) throws -> Data {
        guard !corePath.isEmpty else {
            throw ChumenError.missingCorePath
        }
        guard FileManager.default.isExecutableFile(atPath: corePath) else {
            throw ChumenError.coreNotExecutable(corePath)
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: corePath)
        process.arguments = arguments

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        let inputPipe: Pipe?
        if stdin != nil {
            let pipe = Pipe()
            process.standardInput = pipe
            inputPipe = pipe
        } else {
            inputPipe = nil
        }

        try process.run()

        let writerGroup = DispatchGroup()
        let writerError = LockedError()
        if let stdin, let inputPipe {
            writerGroup.enter()
            DispatchQueue.global(qos: .utility).async {
                defer { writerGroup.leave() }
                do {
                    try inputPipe.fileHandleForWriting.write(contentsOf: stdin)
                    try inputPipe.fileHandleForWriting.close()
                } catch {
                    writerError.set(error)
                }
            }
        }

        let output = outputPipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        writerGroup.wait()
        let errorOutput = errorPipe.fileHandleForReading.readDataToEndOfFile()

        if let error = writerError.get() {
            throw error
        }

        guard process.terminationStatus == 0 else {
            let message = String(data: errorOutput, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            throw ChumenError.commandFailed(
                ageCommandErrorMessage(
                    rawMessage: message,
                    operation: arguments.dropFirst().first ?? arguments.first ?? "age"
                )
            )
        }
        return output
    }

    private static func ageCommandErrorMessage(rawMessage: String?, operation: String) -> String {
        let message = rawMessage?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if message.contains("identity did not match any of the recipients") ||
            message.contains("incorrect identity for recipient block") {
            return "mihomo age \(operation) failed: stored age identity cannot decrypt this encrypted config."
        }
        if message.isEmpty {
            return "mihomo age \(operation) failed."
        }
        // Keep the first panic line but drop Go stack frames; the stack is noisy and usually hides
        // the actionable age/config error from the GUI notification and process log.
        if let firstLine = message.components(separatedBy: .newlines).first,
           firstLine.hasPrefix("panic: ") {
            return "mihomo age \(operation) failed: \(String(firstLine.dropFirst("panic: ".count)))"
        }
        return message
    }

    private final class LockedError: @unchecked Sendable {
        private let lock = NSLock()
        private var stored: Error?

        func set(_ error: Error) {
            lock.lock()
            stored = error
            lock.unlock()
        }

        func get() -> Error? {
            lock.lock()
            defer { lock.unlock() }
            return stored
        }
    }
}
