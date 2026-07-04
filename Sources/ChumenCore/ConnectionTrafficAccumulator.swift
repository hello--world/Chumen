import Foundation

public enum ConnectionRouteKind: Sendable, Equatable {
    case direct
    case proxy
    case unknown
}

public struct ConnectionTrafficAccumulator: Sendable, Equatable {
    public private(set) var proxyUploadTotal: Int64 = 0
    public private(set) var proxyDownloadTotal: Int64 = 0
    public private(set) var directUploadTotal: Int64 = 0
    public private(set) var directDownloadTotal: Int64 = 0
    public private(set) var unknownUploadTotal: Int64 = 0
    public private(set) var unknownDownloadTotal: Int64 = 0

    private var samples: [String: ConnectionTrafficSample] = [:]

    public init() {}

    public mutating func reset() {
        proxyUploadTotal = 0
        proxyDownloadTotal = 0
        directUploadTotal = 0
        directDownloadTotal = 0
        unknownUploadTotal = 0
        unknownDownloadTotal = 0
        samples.removeAll()
    }

    public mutating func apply(connections: [MihomoConnection], includeInitialSamples: Bool = false) {
        var activeIDs = Set<String>()
        for connection in connections {
            activeIDs.insert(connection.id)
            let currentUpload = max(0, connection.upload ?? 0)
            let currentDownload = max(0, connection.download ?? 0)
            let routeKind = Self.routeKind(for: connection)

            if let previous = samples[connection.id] {
                add(
                    upload: max(0, currentUpload - previous.upload),
                    download: max(0, currentDownload - previous.download),
                    routeKind: routeKind
                )
            } else if includeInitialSamples {
                add(upload: currentUpload, download: currentDownload, routeKind: routeKind)
            }

            samples[connection.id] = ConnectionTrafficSample(
                upload: currentUpload,
                download: currentDownload,
                routeKind: routeKind
            )
        }
        samples = samples.filter { activeIDs.contains($0.key) }
    }

    public static func routeKind(for connection: MihomoConnection) -> ConnectionRouteKind {
        guard let terminal = connection.chains?
            .map({ $0.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() })
            .last(where: { !$0.isEmpty }) else {
            return .unknown
        }

        if ["DIRECT", "REJECT", "REJECT-DROP", "REJECT-TINYGIF"].contains(terminal) {
            return .direct
        }
        return .proxy
    }

    private mutating func add(upload: Int64, download: Int64, routeKind: ConnectionRouteKind) {
        guard upload > 0 || download > 0 else { return }
        switch routeKind {
        case .direct:
            directUploadTotal += upload
            directDownloadTotal += download
        case .proxy:
            proxyUploadTotal += upload
            proxyDownloadTotal += download
        case .unknown:
            unknownUploadTotal += upload
            unknownDownloadTotal += download
        }
    }
}

private struct ConnectionTrafficSample: Sendable, Equatable {
    let upload: Int64
    let download: Int64
    let routeKind: ConnectionRouteKind
}
