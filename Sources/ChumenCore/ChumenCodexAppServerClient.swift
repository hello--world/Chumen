import Foundation
import Darwin

/// Runs Chumen's assistant through Codex app-server instead of a one-shot CLI command.
///
/// Intent: Chumen needs an agent surface that can reuse the user's Codex/ChatGPT login,
/// but the app must keep its own review-before-apply boundary. The app-server protocol is
/// conversation-oriented, so Chumen can send local knowledge and current app state as prompt
/// context while forcing Codex into a read-only, no-approval thread. Any config mutation still
/// returns as `ChumenAIResponse.changes` and must be applied by the user in Chumen.
public struct ChumenCodexAppServerClient: Sendable {
    private let executableURL: URL?
    private let timeoutSeconds: TimeInterval

    public init(executableURL: URL? = nil, timeoutSeconds: TimeInterval = 60) {
        self.executableURL = executableURL
        self.timeoutSeconds = timeoutSeconds
    }

    public func complete(
        settings: ChumenAISettings,
        systemPrompt: String,
        messages: [ChumenAIChatMessage]
    ) async throws -> ChumenAIResponse {
        let processBox = CodexProcessBox()
        return try await withTaskCancellationHandler {
            try await withThrowingTaskGroup(of: ChumenAIResponse.self) { group in
                group.addTask {
                    try await runConversation(
                        settings: settings,
                        systemPrompt: systemPrompt,
                        messages: messages,
                        processBox: processBox
                    )
                }
                group.addTask {
                    try await Task.sleep(nanoseconds: UInt64(timeoutSeconds * 1_000_000_000))
                    throw ChumenError.commandFailed("Codex Agent timed out.")
                }
                do {
                    guard let result = try await group.next() else {
                        throw ChumenError.commandFailed("Codex Agent did not return a response.")
                    }
                    group.cancelAll()
                    processBox.terminate()
                    return result
                } catch {
                    group.cancelAll()
                    processBox.terminate()
                    throw error
                }
            }
        } onCancel: {
            processBox.terminate()
        }
    }

    private func runConversation(
        settings: ChumenAISettings,
        systemPrompt: String,
        messages: [ChumenAIChatMessage],
        processBox: CodexProcessBox
    ) async throws -> ChumenAIResponse {
        let process = try makeProcess()
        processBox.process = process

        let stdin = Pipe()
        let stdout = Pipe()
        let stderr = Pipe()
        process.standardInput = stdin
        process.standardOutput = stdout
        process.standardError = stderr

        try process.run()
        let stderrTask = Task { try await Self.collectLimitedText(from: stderr.fileHandleForReading) }

        do {
            var lines = stdout.fileHandleForReading.bytes.lines.makeAsyncIterator()
            try sendInitialize(to: stdin.fileHandleForWriting)
            _ = try await waitForResult(id: 1, lines: &lines, input: stdin.fileHandleForWriting)
            try send(["method": "initialized", "params": [:]], to: stdin.fileHandleForWriting)

            try sendThreadStart(settings: settings, systemPrompt: systemPrompt, to: stdin.fileHandleForWriting)
            let threadResult = try await waitForResult(id: 2, lines: &lines, input: stdin.fileHandleForWriting)
            guard let thread = threadResult["thread"] as? [String: Any],
                  let threadId = thread["id"] as? String,
                  !threadId.isEmpty else {
                throw ChumenError.commandFailed("Codex Agent did not return a thread id.")
            }

            try sendTurnStart(
                threadId: threadId,
                prompt: Self.codexTurnPrompt(messages: messages),
                settings: settings,
                to: stdin.fileHandleForWriting
            )
            let content = try await waitForTurnCompletion(
                lines: &lines,
                input: stdin.fileHandleForWriting
            )
            processBox.terminate()
            return ChumenAIClient.parseAssistantContent(content)
        } catch {
            processBox.terminate()
            let stderrText = (try? await stderrTask.value) ?? ""
            if !stderrText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                throw ChumenError.commandFailed("\(error.localizedDescription)\n\(stderrText)")
            }
            throw error
        }
    }

    private func makeProcess() throws -> Process {
        let process = Process()
        if let executableURL {
            process.executableURL = executableURL
            process.arguments = ["app-server", "--stdio"]
            return process
        }
        if let candidate = Self.firstExecutableCodexCandidate() {
            process.executableURL = candidate
            process.arguments = ["app-server", "--stdio"]
            return process
        }
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["codex", "app-server", "--stdio"]
        return process
    }

    public static func firstExecutableCodexCandidate() -> URL? {
        let manager = FileManager.default
        let home = manager.homeDirectoryForCurrentUser.path
        let envCandidate = ProcessInfo.processInfo.environment["CODEX_BIN"]
        let paths = [
            envCandidate,
            "\(home)/.local/bin/codex",
            "/opt/homebrew/bin/codex",
            "/usr/local/bin/codex",
            "/usr/bin/codex"
        ].compactMap { $0 }

        return paths
            .map { URL(fileURLWithPath: $0) }
            .first { manager.isExecutableFile(atPath: $0.path) }
    }

    private func sendInitialize(to input: FileHandle) throws {
        try send([
            "id": 1,
            "method": "initialize",
            "params": [
                "clientInfo": [
                    "name": "chumen",
                    "title": "Chumen",
                    "version": "0.1.0"
                ],
                "capabilities": [
                    "experimentalApi": true,
                    "requestAttestation": false,
                    "optOutNotificationMethods": [
                        "thread/tokenUsageUpdated",
                        "thread/statusChanged",
                        "turn/planUpdated",
                        "turn/diffUpdated"
                    ]
                ]
            ]
        ], to: input)
    }

    private func sendThreadStart(
        settings: ChumenAISettings,
        systemPrompt: String,
        to input: FileHandle
    ) throws {
        var params: [String: Any] = [
            "approvalPolicy": "never",
            "approvalsReviewer": "user",
            "baseInstructions": Self.codexBaseInstructions,
            "developerInstructions": systemPrompt,
            "cwd": FileManager.default.temporaryDirectory.path,
            "ephemeral": true,
            "sandbox": "read-only",
            "threadSource": "user",
            "sessionStartSource": "new"
        ]
        let model = settings.model.trimmingCharacters(in: .whitespacesAndNewlines)
        if !model.isEmpty {
            params["model"] = model
        }
        try send(["id": 2, "method": "thread/start", "params": params], to: input)
    }

    private func sendTurnStart(
        threadId: String,
        prompt: String,
        settings: ChumenAISettings,
        to input: FileHandle
    ) throws {
        var params: [String: Any] = [
            "threadId": threadId,
            "approvalPolicy": "never",
            "sandboxPolicy": [
                "type": "readOnly",
                "networkAccess": false
            ],
            "input": [
                [
                    "type": "text",
                    "text": prompt,
                    "text_elements": []
                ]
            ],
            "outputSchema": Self.chumenResponseJSONSchema()
        ]
        let model = settings.model.trimmingCharacters(in: .whitespacesAndNewlines)
        if !model.isEmpty {
            params["model"] = model
        }
        try send(["id": 3, "method": "turn/start", "params": params], to: input)
    }

    private func waitForResult(
        id: Int,
        lines: inout AsyncLineSequence<FileHandle.AsyncBytes>.AsyncIterator,
        input: FileHandle
    ) async throws -> [String: Any] {
        while let line = try await lines.next() {
            let message = try Self.decodeJSONObject(line)
            try handleServerRequestIfNeeded(message, input: input)
            guard Self.intID(message["id"]) == id else { continue }
            if let error = message["error"] as? [String: Any] {
                throw ChumenError.commandFailed(Self.errorMessage(error))
            }
            return message["result"] as? [String: Any] ?? [:]
        }
        throw ChumenError.commandFailed("Codex Agent stopped before request \(id) completed.")
    }

    private func waitForTurnCompletion(
        lines: inout AsyncLineSequence<FileHandle.AsyncBytes>.AsyncIterator,
        input: FileHandle
    ) async throws -> String {
        var streamedMessage = ""
        var completedMessage = ""
        var lastError = ""

        while let line = try await lines.next() {
            let message = try Self.decodeJSONObject(line)
            try handleServerRequestIfNeeded(message, input: input)
            guard let method = message["method"] as? String else {
                if Self.intID(message["id"]) == 3, let error = message["error"] as? [String: Any] {
                    throw ChumenError.commandFailed(Self.errorMessage(error))
                }
                continue
            }

            switch method {
            case "item/agentMessage/delta":
                if let params = message["params"] as? [String: Any],
                   let delta = params["delta"] as? String {
                    streamedMessage += delta
                }
            case "item/completed":
                if let params = message["params"] as? [String: Any],
                   let text = Self.agentMessageText(from: params) {
                    completedMessage = text
                }
            case "error":
                if let params = message["params"] as? [String: Any] {
                    lastError = Self.errorMessage(params)
                }
            case "turn/completed":
                guard let params = message["params"] as? [String: Any],
                      let turn = params["turn"] as? [String: Any] else {
                    break
                }
                if let text = Self.agentMessageText(fromTurn: turn) {
                    completedMessage = text
                }
                let status = turn["status"] as? String ?? "completed"
                if status != "completed" {
                    let error = (turn["error"] as? [String: Any]).map(Self.errorMessage)
                    throw ChumenError.commandFailed(error ?? lastError.ifEmpty("Codex Agent turn failed."))
                }
                let content = completedMessage.ifEmpty(streamedMessage)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                guard !content.isEmpty else {
                    throw ChumenError.commandFailed(lastError.ifEmpty("Codex Agent returned an empty response."))
                }
                return content
            default:
                break
            }
        }

        throw ChumenError.commandFailed(lastError.ifEmpty("Codex Agent stopped before finishing the turn."))
    }

    private func handleServerRequestIfNeeded(_ message: [String: Any], input: FileHandle) throws {
        guard let method = message["method"] as? String, let id = message["id"] else { return }

        // Chumen allows Codex-managed MCP tools to run through app-server, but it does not provide
        // its own client-side dynamic tools yet and must never silently grant shell/file/system
        // permissions. Respond with protocol-shaped denials or explicit JSON-RPC errors so a turn
        // fails visibly instead of leaving the UI stuck in "generating" state.
        switch method {
        case "item/commandExecution/requestApproval",
             "item/fileChange/requestApproval",
             "applyPatchApproval":
            try send(["id": id, "result": ["decision": "decline"]], to: input)
        case "execCommandApproval":
            try send(["id": id, "result": ["decision": "denied"]], to: input)
        case "mcpServer/elicitation/request":
            try send(["id": id, "result": ["action": "decline"]], to: input)
        case "item/tool/requestUserInput":
            try send(["id": id, "result": ["answers": [:]]], to: input)
        case "item/tool/call":
            try send([
                "id": id,
                "result": [
                    "success": false,
                    "contentItems": [
                        [
                            "type": "inputText",
                            "text": "Chumen has not exposed client-side dynamic tools yet."
                        ]
                    ]
                ]
            ], to: input)
        case "item/permissions/requestApproval":
            try sendError(
                id: id,
                code: -32010,
                message: "Chumen does not grant additional Codex permissions from the assistant panel.",
                to: input
            )
        case "account/chatgptAuthTokens/refresh", "attestation/generate":
            try sendError(
                id: id,
                code: -32601,
                message: "Chumen does not handle \(method); use Codex CLI login state.",
                to: input
            )
        default:
            try sendError(
                id: id,
                code: -32601,
                message: "Unsupported Codex app-server request: \(method)",
                to: input
            )
        }
    }

    private func send(_ object: [String: Any], to input: FileHandle) throws {
        var data = try JSONSerialization.data(withJSONObject: object)
        data.append(0x0A)
        try input.write(contentsOf: data)
    }

    private func sendError(id: Any, code: Int, message: String, to input: FileHandle) throws {
        try send([
            "id": id,
            "error": [
                "code": code,
                "message": message
            ]
        ], to: input)
    }

    static func codexTurnPrompt(messages: [ChumenAIChatMessage]) -> String {
        let transcript = messages.map { message in
            "\(message.role.rawValue.uppercased()):\n\(message.content.trimmingCharacters(in: .whitespacesAndNewlines))"
        }.joined(separator: "\n\n")

        return """
        Continue this Chumen in-app assistant conversation.

        Conversation transcript:
        \(transcript)

        Return only the JSON object requested by the Chumen developer instructions. You may use configured
        Codex MCP tools for read-only context when they are available, but do not request extra permissions,
        do not run shell commands, do not edit files, do not claim that changes were applied, and do not include
        Markdown fences.
        """
    }

    private static let codexBaseInstructions = """
    You are Chumen's in-app network configuration agent. You answer product questions and draft safe,
    reviewable Chumen configuration changes. Use configured Codex MCP tools only for context gathering
    when useful. You must not modify files, run shell commands, request extra permissions, or apply
    changes yourself. Return only the Chumen JSON response shape.
    """

    private static func chumenResponseJSONSchema() -> [String: Any] {
        [
            "type": "object",
            "additionalProperties": false,
            "required": ["reply", "changes"],
            "properties": [
                "reply": [
                    "type": "string"
                ],
                "changes": [
                    "type": "array",
                    "items": [
                        "type": "object",
                        "additionalProperties": false,
                        "required": ["kind", "title", "detail"],
                        "properties": [
                            "kind": [
                                "type": "string",
                                "enum": [
                                    "importSubscription",
                                    "setMode",
                                    "setTun",
                                    "setSystemProxy",
                                    "setConfigAppendix",
                                    "reloadRuntimeConfig"
                                ]
                            ],
                            "title": ["type": "string"],
                            "detail": ["type": "string"],
                            "diff": ["type": "string"],
                            "subscriptionURL": ["type": ["string", "null"]],
                            "profileName": ["type": ["string", "null"]],
                            "mode": [
                                "type": ["string", "null"],
                                "enum": ["rule", "global", "direct", NSNull()]
                            ],
                            "enabled": ["type": ["boolean", "null"]],
                            "configAppendixYAML": ["type": ["string", "null"]]
                        ]
                    ]
                ]
            ]
        ]
    }

    private static func decodeJSONObject(_ line: String) throws -> [String: Any] {
        guard let data = line.data(using: .utf8),
              let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ChumenError.commandFailed("Codex Agent returned invalid JSON-RPC.")
        }
        return object
    }

    private static func intID(_ value: Any?) -> Int? {
        if let value = value as? Int { return value }
        if let number = value as? NSNumber { return number.intValue }
        return nil
    }

    private static func errorMessage(_ object: [String: Any]) -> String {
        if let message = object["message"] as? String {
            return message
        }
        if let error = object["error"] as? [String: Any] {
            return errorMessage(error)
        }
        return "Codex Agent request failed."
    }

    private static func agentMessageText(from params: [String: Any]) -> String? {
        guard let item = params["item"] as? [String: Any],
              item["type"] as? String == "agentMessage",
              let text = item["text"] as? String else {
            return nil
        }
        return text
    }

    private static func agentMessageText(fromTurn turn: [String: Any]) -> String? {
        guard let items = turn["items"] as? [[String: Any]] else { return nil }
        return items.reversed().compactMap { item -> String? in
            guard item["type"] as? String == "agentMessage" else { return nil }
            return item["text"] as? String
        }.first
    }

    private static func collectLimitedText(from handle: FileHandle) async throws -> String {
        var text = ""
        for try await line in handle.bytes.lines {
            text += line + "\n"
            if text.count > 8_000 {
                text.removeFirst(text.count - 8_000)
            }
        }
        return text
    }
}

private final class CodexProcessBox: @unchecked Sendable {
    private let lock = NSLock()
    private var storedProcess: Process?

    var process: Process? {
        get {
            lock.lock()
            defer { lock.unlock() }
            return storedProcess
        }
        set {
            lock.lock()
            storedProcess = newValue
            lock.unlock()
        }
    }

    func terminate() {
        guard let process, process.isRunning else { return }
        process.terminate()
        let pid = process.processIdentifier
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 2) {
            if process.isRunning {
                kill(pid, SIGKILL)
            }
        }
    }
}

private extension String {
    func ifEmpty(_ fallback: String) -> String {
        isEmpty ? fallback : self
    }
}
