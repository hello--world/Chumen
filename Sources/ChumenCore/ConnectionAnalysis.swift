import Foundation

public struct ConnectionAnalysisBucket: Identifiable, Equatable, Sendable {
    public let id: String
    public let label: String
    public let count: Int
    public let uploadBytes: Int64
    public let downloadBytes: Int64

    public var totalBytes: Int64 {
        uploadBytes + downloadBytes
    }
}

public struct ConnectionAnalysisSnapshot: Equatable, Sendable {
    public let activeCount: Int
    public let uploadBytes: Int64
    public let downloadBytes: Int64
    public let routeBuckets: [ConnectionAnalysisBucket]
    public let topHosts: [ConnectionAnalysisBucket]
    public let topProcesses: [ConnectionAnalysisBucket]
    public let topRules: [ConnectionAnalysisBucket]
    public let topChains: [ConnectionAnalysisBucket]

    public var totalBytes: Int64 {
        uploadBytes + downloadBytes
    }

    public var aiContext: String {
        let routes = routeBuckets.map { "\($0.label)=\($0.count)" }.joined(separator: ", ")
        let hosts = topHosts.map { "\($0.label)=\($0.count)" }.joined(separator: ", ")
        let processes = topProcesses.map { "\($0.label)=\($0.count)" }.joined(separator: ", ")
        let rules = topRules.map { "\($0.label)=\($0.count)" }.joined(separator: ", ")
        return """
        Connection analysis:
        - active: \(activeCount)
        - upload bytes: \(uploadBytes)
        - download bytes: \(downloadBytes)
        - routes: \(routes.isEmpty ? "-" : routes)
        - top hosts: \(hosts.isEmpty ? "-" : hosts)
        - top processes: \(processes.isEmpty ? "-" : processes)
        - top rules: \(rules.isEmpty ? "-" : rules)
        """
    }
}

public enum ConnectionAnalyzer {
    public static func analyze(
        _ connections: [MihomoConnection],
        limit: Int = 6
    ) -> ConnectionAnalysisSnapshot {
        let uploadBytes = connections.reduce(Int64(0)) { $0 + max(0, $1.upload ?? 0) }
        let downloadBytes = connections.reduce(Int64(0)) { $0 + max(0, $1.download ?? 0) }

        return ConnectionAnalysisSnapshot(
            activeCount: connections.count,
            uploadBytes: uploadBytes,
            downloadBytes: downloadBytes,
            routeBuckets: grouped(connections, limit: 3) { connection in
                switch ConnectionTrafficAccumulator.routeKind(for: connection) {
                case .proxy: "proxy"
                case .direct: "direct"
                case .unknown: "unknown"
                }
            },
            topHosts: grouped(connections, limit: limit) { connection in
                firstNonEmpty([
                    connection.metadata?.host,
                    connection.metadata?.destinationIP,
                    connection.rulePayload
                ])
            },
            topProcesses: grouped(connections, limit: limit) { connection in
                firstNonEmpty([
                    connection.metadata?.process,
                    processName(from: connection.metadata?.processPath)
                ])
            },
            topRules: grouped(connections, limit: limit) { connection in
                [connection.rule, connection.rulePayload]
                    .compactMap { normalizedLabel($0) }
                    .joined(separator: " ")
            },
            topChains: grouped(connections, limit: limit) { connection in
                guard let chains = connection.chains, !chains.isEmpty else { return nil }
                return chains.joined(separator: " > ")
            }
        )
    }

    private static func grouped(
        _ connections: [MihomoConnection],
        limit: Int,
        key: (MihomoConnection) -> String?
    ) -> [ConnectionAnalysisBucket] {
        struct MutableBucket {
            var count = 0
            var uploadBytes: Int64 = 0
            var downloadBytes: Int64 = 0
        }

        var buckets: [String: MutableBucket] = [:]
        for connection in connections {
            guard let label = normalizedLabel(key(connection)) else { continue }
            var bucket = buckets[label] ?? MutableBucket()
            bucket.count += 1
            bucket.uploadBytes += max(0, connection.upload ?? 0)
            bucket.downloadBytes += max(0, connection.download ?? 0)
            buckets[label] = bucket
        }

        return buckets.map { label, bucket in
            ConnectionAnalysisBucket(
                id: label,
                label: label,
                count: bucket.count,
                uploadBytes: bucket.uploadBytes,
                downloadBytes: bucket.downloadBytes
            )
        }
        .sorted {
            if $0.count != $1.count {
                return $0.count > $1.count
            }
            if $0.totalBytes != $1.totalBytes {
                return $0.totalBytes > $1.totalBytes
            }
            return $0.label < $1.label
        }
        .prefix(max(0, limit))
        .map { $0 }
    }

    private static func firstNonEmpty(_ values: [String?]) -> String? {
        values.compactMap(normalizedLabel).first
    }

    private static func normalizedLabel(_ value: String?) -> String? {
        let normalized = value?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let normalized, !normalized.isEmpty, normalized != "-" else { return nil }
        return normalized
    }

    private static func processName(from path: String?) -> String? {
        guard let path = normalizedLabel(path) else { return nil }
        let name = URL(fileURLWithPath: path).lastPathComponent
        return name.isEmpty ? path : name
    }
}
