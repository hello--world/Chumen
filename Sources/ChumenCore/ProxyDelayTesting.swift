import Foundation

// Batch delay tests are core behavior rather than a view concern. The stream keeps scheduling
// and transport off the UI layer while allowing clients to render testing results as they arrive.
public struct ProxyDelayTestKey: Hashable, Sendable {
    public let groupName: String
    public let proxyName: String

    public init(groupName: String, proxyName: String) {
        self.groupName = groupName
        self.proxyName = proxyName
    }
}

public enum ProxyDelayTestResult: Hashable, Sendable {
    case value(Int)
    case timedOut
    case failed
}

public enum ProxyDelayTestEvent: Hashable, Sendable {
    case started(ProxyDelayTestKey)
    case completed(ProxyDelayTestKey, ProxyDelayTestResult)
}

public enum ProxyDelayTestState: Equatable, Sendable {
    case idle
    case testing
    case completed(ProxyDelayTestResult)
}

public enum ProxyDelayTesting {
    public static let defaultURL = "https://www.gstatic.com/generate_204"
    public static let defaultTimeout = 5_000
    public static let defaultMaximumConcurrency = 6

    public static func testableProxyNames(from names: [String]) -> [String] {
        let builtInNames: Set<String> = ["DIRECT", "REJECT", "REJECT-DROP", "PASS", "COMPATIBLE"]
        return Array(Set(names.filter { !builtInNames.contains($0) && !$0.isEmpty })).sorted()
    }

    public static func events(
        proxyNames: [String],
        groupName: String,
        client: MihomoClient,
        url: String = defaultURL,
        timeout: Int = defaultTimeout,
        maximumConcurrency: Int = defaultMaximumConcurrency
    ) -> AsyncStream<ProxyDelayTestEvent> {
        let names = testableProxyNames(from: proxyNames)

        return AsyncStream { continuation in
            let task = Task {
                for name in names {
                    continuation.yield(.started(ProxyDelayTestKey(groupName: groupName, proxyName: name)))
                }

                await withTaskGroup(of: ProxyDelayTestEvent?.self) { group in
                    let workerCount = min(maximumConcurrency, names.count)
                    var nextIndex = workerCount

                    for name in names.prefix(workerCount) {
                        group.addTask {
                            await test(name: name, groupName: groupName, client: client, url: url, timeout: timeout)
                        }
                    }

                    while let event = await group.next() {
                        if let event {
                            continuation.yield(event)
                        }

                        guard nextIndex < names.count else { continue }
                        let name = names[nextIndex]
                        nextIndex += 1
                        group.addTask {
                            await test(name: name, groupName: groupName, client: client, url: url, timeout: timeout)
                        }
                    }
                }

                continuation.finish()
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    private static func test(
        name: String,
        groupName: String,
        client: MihomoClient,
        url: String,
        timeout: Int
    ) async -> ProxyDelayTestEvent? {
        let key = ProxyDelayTestKey(groupName: groupName, proxyName: name)

        do {
            try Task.checkCancellation()
            let response = try await client.delayProxy(name: name, url: url, timeout: timeout)
            let result: ProxyDelayTestResult = response.delay > 0 ? .value(response.delay) : .timedOut
            return .completed(key, result)
        } catch is CancellationError {
            return nil
        } catch {
            return .completed(key, .failed)
        }
    }
}
