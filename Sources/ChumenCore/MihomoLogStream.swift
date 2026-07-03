import Foundation

public final class MihomoLogStream: @unchecked Sendable {
    private var task: URLSessionWebSocketTask?
    private var isActive = false

    public init() {}

    public func start(
        baseURL: URL,
        secret: String,
        level: String = "info",
        structured: Bool = false,
        onMessage: @escaping @Sendable (String) -> Void
    ) {
        stop()

        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)
        components?.scheme = baseURL.scheme == "https" ? "wss" : "ws"
        components?.path = "/logs"
        var queryItems = [URLQueryItem(name: "level", value: level)]
        if structured {
            queryItems.append(URLQueryItem(name: "format", value: "structured"))
        }
        components?.queryItems = queryItems
        guard let url = components?.url else { return }

        var request = URLRequest(url: url)
        if !secret.isEmpty {
            request.setValue("Bearer \(secret)", forHTTPHeaderField: "Authorization")
        }

        let task = URLSession.shared.webSocketTask(with: request)
        self.task = task
        isActive = true
        task.resume()
        receiveLoop(task: task, onMessage: onMessage)
    }

    public func stop() {
        isActive = false
        task?.cancel(with: .goingAway, reason: nil)
        task = nil
    }

    private func receiveLoop(task: URLSessionWebSocketTask, onMessage: @escaping @Sendable (String) -> Void) {
        task.receive { [weak self] result in
            guard let self, self.isActive else { return }

            switch result {
            case let .success(message):
                switch message {
                case let .string(text):
                    onMessage(text + "\n")
                case let .data(data):
                    onMessage((String(data: data, encoding: .utf8) ?? "<binary log>") + "\n")
                @unknown default:
                    break
                }
                self.receiveLoop(task: task, onMessage: onMessage)
            case let .failure(error):
                onMessage("[log stream ended] \(error.localizedDescription)\n")
            }
        }
    }
}
