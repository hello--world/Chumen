import Foundation

public final class MihomoEventStream<Event: Decodable & Sendable>: @unchecked Sendable {
    private var task: URLSessionWebSocketTask?
    private var isActive = false
    private let decoder = JSONDecoder()

    public init() {}

    public func start(
        baseURL: URL,
        secret: String,
        path: String,
        queryItems: [URLQueryItem] = [],
        onEvent: @escaping @Sendable (Event) -> Void,
        onError: (@Sendable (String) -> Void)? = nil
    ) {
        stop()

        // mihomo 的事件流走 WebSocket：HTTP controller 的 scheme 需要映射为 ws/wss。
        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)
        components?.scheme = baseURL.scheme == "https" ? "wss" : "ws"
        components?.path = path
        if !queryItems.isEmpty {
            components?.queryItems = queryItems
        }
        guard let url = components?.url else { return }

        var request = URLRequest(url: url)
        if !secret.isEmpty {
            request.setValue("Bearer \(secret)", forHTTPHeaderField: "Authorization")
        }

        let task = URLSession.shared.webSocketTask(with: request)
        self.task = task
        isActive = true
        task.resume()
        receiveLoop(task: task, onEvent: onEvent, onError: onError)
    }

    public func stop() {
        isActive = false
        task?.cancel(with: .goingAway, reason: nil)
        task = nil
    }

    private func receiveLoop(
        task: URLSessionWebSocketTask,
        onEvent: @escaping @Sendable (Event) -> Void,
        onError: (@Sendable (String) -> Void)?
    ) {
        task.receive { [weak self] result in
            guard let self, self.isActive else { return }

            switch result {
            case let .success(message):
                do {
                    let data: Data
                    switch message {
                    case let .string(text):
                        data = Data(text.utf8)
                    case let .data(payload):
                        data = payload
                    @unknown default:
                        data = Data()
                    }
                    if !data.isEmpty {
                        onEvent(try self.decoder.decode(Event.self, from: data))
                    }
                } catch {
                    onError?("[event stream decode failed] \(error.localizedDescription)")
                }
                // URLSessionWebSocketTask 是一次 receive 一条消息，需要递归续订下一条。
                self.receiveLoop(task: task, onEvent: onEvent, onError: onError)
            case let .failure(error):
                onError?("[event stream ended] \(error.localizedDescription)")
            }
        }
    }
}
