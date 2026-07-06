import Charts
import ChumenCore
import SwiftUI

struct ConnectionsView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.openWindow) private var openWindow
    @State private var searchText = ""

    var body: some View {
        GeometryReader { proxy in
            if proxy.size.width < 1_080 {
                compactLayout
            } else {
                splitLayout(availableWidth: proxy.size.width)
            }
        }
        .background(ChumenStyle.pageBackground)
    }

    private func splitLayout(availableWidth: CGFloat) -> some View {
        let rightWidth = max(430, min(620, availableWidth * 0.38))

        return HStack(alignment: .top, spacing: 14) {
            ScrollView {
                connectionReport
                    .padding(.vertical, 18)
                    .padding(.leading, 18)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

            connectionsPane
                .frame(width: rightWidth)
                .padding(.vertical, 18)
                .padding(.trailing, 18)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var compactLayout: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                connectionReport
                connectionsPane
                    .frame(minHeight: 440)
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
    }

    private var connectionsPane: some View {
        VStack(alignment: .leading, spacing: 0) {
            connectionsPaneHeader
            Divider()
            controlsBar
            Divider()
            connectionsList
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: ChumenStyle.radius, style: .continuous)
                .fill(ChumenStyle.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: ChumenStyle.radius, style: .continuous)
                .strokeBorder(ChumenStyle.border)
        )
    }

    private var connectionsPaneHeader: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Label(model.t(.connections), systemImage: "link")
                .font(.headline)
            Spacer(minLength: 8)
            Text(connectionsSummary)
                .font(.caption.weight(.medium))
                .foregroundStyle(ChumenStyle.mutedText)
                .lineLimit(1)
                .truncationMode(.middle)
            Button {
                openWindow(id: ChumenWindowID.connectionsDetail)
            } label: {
                Label(model.t(.viewMore), systemImage: "rectangle.on.rectangle")
            }
            .controlSize(.small)
            .help(model.t(.connectionHistory))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private var controlsBar: some View {
        HStack(spacing: 8) {
            Button {
                Task { await model.refreshConnections() }
            } label: {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .frame(width: 24, height: 24)
            }
            .help(model.t(.refreshConnections))
            .accessibilityLabel(model.t(.refreshConnections))

            Button(role: .destructive) {
                model.closeAllConnections()
            } label: {
                Image(systemName: "xmark.circle")
                    .frame(width: 24, height: 24)
            }
            .disabled(model.connections.isEmpty)
            .help(model.t(.closeAll))
            .accessibilityLabel(model.t(.closeAll))

            TextField(model.t(.searchConnections), text: $searchText)
                .textFieldStyle(.roundedBorder)
                .frame(minWidth: 140)

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                }
                .buttonStyle(.plain)
                .foregroundStyle(ChumenStyle.mutedText)
                .help(model.t(.clear))
            }

        }
        .padding(10)
        .controlSize(.regular)
    }

    private var filteredConnections: [MihomoConnection] {
        filterConnections(model.connections, searchText: searchText)
    }

    private var connectionsSummary: String {
        let countPrefix = searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "\(model.connections.count)"
            : "\(filteredConnections.count)/\(model.connections.count)"
        return "\(countPrefix) \(model.t(.activeConnections)) / \(model.totalTrafficText)"
    }

    private var connectionReport: some View {
        let analysis = model.connectionAnalysisSnapshot

        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Label(model.t(.networkReport), systemImage: "chart.xyaxis.line")
                    .font(.headline)
                Spacer()
                Text(model.t(.aiAnalysisReady))
                    .font(.caption.weight(.medium))
                    .foregroundStyle(ChumenStyle.mutedText)
            }

            HStack(spacing: 10) {
                reportMetricTile(
                    title: model.t(.activeConnections),
                    value: "\(analysis.activeCount)",
                    detail: "\(model.t(.upload)) \(AppModel.formatBytes(analysis.uploadBytes)) / " +
                        "\(model.t(.download)) \(AppModel.formatBytes(analysis.downloadBytes))",
                    systemImage: "link",
                    color: .blue
                )
                reportMetricTile(
                    title: model.t(.proxyRoute),
                    value: "\(routeCount("proxy", in: analysis))",
                    detail: "\(model.t(.directRoute)) \(routeCount("direct", in: analysis)) / " +
                        "\(model.t(.unknownRoute)) \(routeCount("unknown", in: analysis))",
                    systemImage: "point.3.connected.trianglepath.dotted",
                    color: .orange
                )
                reportMetricTile(
                    title: model.t(.activeTraffic),
                    value: AppModel.formatBytes(analysis.totalBytes),
                    detail: "\(model.t(.currentSpeed)) \(model.speedText)",
                    systemImage: "speedometer",
                    color: .green
                )
            }

            HStack(alignment: .top, spacing: 10) {
                reportPanel(title: model.t(.historyTrend), systemImage: "waveform.path.ecg") {
                    connectionCountTrendChart
                }
                reportPanel(title: model.t(.currentSpeed), systemImage: "arrow.up.arrow.down") {
                    connectionSpeedTrendChart
                }
            }

            HStack(alignment: .top, spacing: 10) {
                reportPanel(title: model.t(.routeDistribution), systemImage: "chart.bar.xaxis") {
                    bucketBarChart(
                        buckets: analysis.routeBuckets,
                        label: { routeLabel($0.label) },
                        value: { Double($0.count) }
                    )
                }
                reportPanel(title: model.t(.topHosts), systemImage: "server.rack") {
                    bucketBarChart(
                        buckets: analysis.topHosts,
                        label: { $0.label },
                        value: { Double($0.count) }
                    )
                }
                reportPanel(title: model.t(.topProcesses), systemImage: "app.connected.to.app.below.fill") {
                    bucketBarChart(
                        buckets: analysis.topProcesses,
                        label: { $0.label },
                        value: { Double($0.count) }
                    )
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: ChumenStyle.radius, style: .continuous)
                .fill(ChumenStyle.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: ChumenStyle.radius, style: .continuous)
                .strokeBorder(ChumenStyle.border)
        )
    }

    private var connectionCountTrendChart: some View {
        VStack(alignment: .leading, spacing: 6) {
            if model.connectionReportSamples.isEmpty {
                emptyReportText
                    .frame(height: 138)
            } else {
                Chart(model.connectionReportSamples) { sample in
                    LineMark(
                        x: .value(model.t(.lastRefresh), sample.timestamp),
                        y: .value(model.t(.activeConnections), sample.activeCount)
                    )
                    .foregroundStyle(.blue)

                    LineMark(
                        x: .value(model.t(.lastRefresh), sample.timestamp),
                        y: .value(model.t(.proxyRoute), sample.proxyCount)
                    )
                    .foregroundStyle(.orange)

                    LineMark(
                        x: .value(model.t(.lastRefresh), sample.timestamp),
                        y: .value(model.t(.directRoute), sample.directCount)
                    )
                    .foregroundStyle(.green)
                }
                .chartXAxis(.hidden)
                .chartYAxis {
                    AxisMarks(position: .leading)
                }
                .frame(height: 138)
            }

            reportLegend([
                (color: .blue, label: model.t(.activeConnections)),
                (color: .orange, label: model.t(.proxyRoute)),
                (color: .green, label: model.t(.directRoute))
            ])
        }
    }

    private var connectionSpeedTrendChart: some View {
        VStack(alignment: .leading, spacing: 6) {
            if model.connectionReportSamples.isEmpty {
                emptyReportText
                    .frame(height: 138)
            } else {
                Chart(model.connectionReportSamples) { sample in
                    LineMark(
                        x: .value(model.t(.lastRefresh), sample.timestamp),
                        y: .value(model.t(.upload), Double(sample.uploadSpeed))
                    )
                    .foregroundStyle(.orange)

                    LineMark(
                        x: .value(model.t(.lastRefresh), sample.timestamp),
                        y: .value(model.t(.download), Double(sample.downloadSpeed))
                    )
                    .foregroundStyle(.cyan)
                }
                .chartXAxis(.hidden)
                .chartYAxis {
                    AxisMarks(position: .leading)
                }
                .frame(height: 138)
            }

            reportLegend([
                (color: .orange, label: model.t(.upload)),
                (color: .cyan, label: model.t(.download))
            ])
        }
    }

    @ViewBuilder
    private var connectionsList: some View {
        ConnectionRowsPanel(
            connections: model.connections,
            searchText: searchText,
            emptyTitle: model.t(.noConnections),
            allowsClosing: true
        )
    }

    private func reportMetricTile(
        title: String,
        value: String,
        detail: String,
        systemImage: String,
        color: Color
    ) -> some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(ChumenStyle.mutedText)
                Text(value)
                    .font(.title2.weight(.bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(ChumenStyle.mutedText)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .frame(maxWidth: .infinity, minHeight: 78, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(ChumenStyle.groupedSurface.opacity(0.55))
        )
    }

    private func reportPanel<Content: View>(
        title: String,
        systemImage: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: systemImage)
                .font(.caption.weight(.semibold))
                .foregroundStyle(ChumenStyle.mutedText)
            content()
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(ChumenStyle.groupedSurface.opacity(0.40))
        )
    }

    @ViewBuilder
    private func bucketBarChart(
        buckets: [ConnectionAnalysisBucket],
        label: @escaping (ConnectionAnalysisBucket) -> String,
        value: @escaping (ConnectionAnalysisBucket) -> Double
    ) -> some View {
        if buckets.isEmpty {
            emptyReportText
                .frame(height: 136)
        } else {
            Chart(buckets) { bucket in
                BarMark(
                    x: .value(model.t(.activeConnections), value(bucket)),
                    y: .value(model.t(.node), label(bucket))
                )
                .foregroundStyle(.blue.gradient)
                .annotation(position: .trailing) {
                    Text("\(bucket.count)")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(ChumenStyle.mutedText)
                }
            }
            .chartXAxis(.hidden)
            .frame(height: 136)
        }
    }

    private var emptyReportText: some View {
        Text("-")
            .font(.caption)
            .foregroundStyle(ChumenStyle.mutedText)
            .frame(maxWidth: .infinity, alignment: .center)
    }

    private func reportLegend(_ items: [(color: Color, label: String)]) -> some View {
        HStack(spacing: 10) {
            ForEach(items, id: \.label) { item in
                HStack(spacing: 4) {
                    Circle()
                        .fill(item.color)
                        .frame(width: 7, height: 7)
                    Text(item.label)
                        .font(.caption2)
                        .foregroundStyle(ChumenStyle.mutedText)
                }
            }
        }
        .lineLimit(1)
    }

    private func routeCount(_ label: String, in analysis: ConnectionAnalysisSnapshot) -> Int {
        analysis.routeBuckets.first { $0.label == label }?.count ?? 0
    }

    private func routeLabel(_ label: String) -> String {
        switch label {
        case "proxy": model.t(.proxyRoute)
        case "direct": model.t(.directRoute)
        default: model.t(.unknownRoute)
        }
    }
}

private enum ConnectionDetailScope: String, CaseIterable, Identifiable {
    case active
    case closed

    var id: String { rawValue }
}

struct ConnectionsDetailWindow: View {
    @EnvironmentObject private var model: AppModel
    @State private var scope: ConnectionDetailScope = .active
    @State private var searchText = ""

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            ConnectionDetailTable(
                connections: scopedConnections,
                searchText: searchText,
                emptyTitle: scope == .active ? model.t(.noConnections) : model.t(.noClosedConnections),
                allowsClosing: scope == .active
            )
        }
        .background(ChumenStyle.pageBackground)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Label(model.t(.connectionHistory), systemImage: "link")
                    .font(.title3.weight(.semibold))
                Spacer()
                Text("\(model.connections.count) \(model.t(.activeConnections)) / \(model.closedConnections.count) \(model.t(.closedConnections))")
                    .font(.callout.weight(.medium))
                    .foregroundStyle(ChumenStyle.mutedText)
                    .lineLimit(1)
            }

            HStack(spacing: 8) {
                Picker("", selection: $scope) {
                    Text("\(model.t(.activeConnections)) \(model.connections.count)")
                        .tag(ConnectionDetailScope.active)
                    Text("\(model.t(.closedConnections)) \(model.closedConnections.count)")
                        .tag(ConnectionDetailScope.closed)
                }
                .pickerStyle(.segmented)
                .frame(width: 260)

                TextField(model.t(.searchConnections), text: $searchText)
                    .textFieldStyle(.roundedBorder)
                    .frame(minWidth: 220)

                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(ChumenStyle.mutedText)
                    .help(model.t(.clear))
                }

                Spacer(minLength: 0)

                Button {
                    Task { await model.refreshConnections() }
                } label: {
                    Image(systemName: "arrow.triangle.2.circlepath")
                }
                .help(model.t(.refreshConnections))

                if scope == .active {
                    Button(role: .destructive) {
                        model.closeAllConnections()
                    } label: {
                        Label(model.t(.closeAll), systemImage: "xmark.circle")
                    }
                    .disabled(model.connections.isEmpty)
                } else {
                    Button(role: .destructive) {
                        model.clearClosedConnections()
                    } label: {
                        Label(model.t(.clearHistory), systemImage: "trash")
                    }
                    .disabled(model.closedConnections.isEmpty)
                }
            }
        }
        .padding(14)
        .controlSize(.regular)
    }

    private var scopedConnections: [MihomoConnection] {
        switch scope {
        case .active:
            return model.connections
        case .closed:
            return Array(model.closedConnections.reversed())
        }
    }
}

private struct ConnectionDetailTable: View {
    @EnvironmentObject private var model: AppModel

    let connections: [MihomoConnection]
    let searchText: String
    let emptyTitle: String
    let allowsClosing: Bool

    private var filteredConnections: [MihomoConnection] {
        filterConnections(connections, searchText: searchText)
    }

    private let columns: [ConnectionTableColumn] = [
        .init(key: .connectionDownloadAmount, width: 86, alignment: .trailing),
        .init(key: .connectionUploadAmount, width: 86, alignment: .trailing),
        .init(key: .connectionDownloadSpeed, width: 92, alignment: .trailing),
        .init(key: .connectionUploadSpeed, width: 92, alignment: .trailing),
        .init(key: .connectionChain, width: 220, alignment: .leading),
        .init(key: .connectionRule, width: 220, alignment: .leading),
        .init(key: .connectionProcess, width: 150, alignment: .leading),
        .init(key: .connectionStartTime, width: 168, alignment: .leading),
        .init(key: .connectionSourceAddress, width: 180, alignment: .leading),
        .init(key: .connectionDestinationAddress, width: 220, alignment: .leading),
        .init(key: .connectionType, width: 110, alignment: .leading)
    ]

    var body: some View {
        if connections.isEmpty {
            connectionEmptyState(title: emptyTitle)
        } else if filteredConnections.isEmpty {
            connectionEmptyState(title: model.t(.noMatchingConnections))
        } else {
            ScrollView([.horizontal, .vertical]) {
                LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
                    Section {
                        ForEach(filteredConnections) { connection in
                            tableRow(connection)
                            if connection.id != filteredConnections.last?.id {
                                Divider()
                            }
                        }
                    } header: {
                        tableHeader
                    }
                }
                .frame(minWidth: tableWidth, alignment: .topLeading)
                .background(ChumenStyle.surface)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    private var tableWidth: CGFloat {
        columns.reduce(CGFloat(0)) { $0 + $1.width } + (allowsClosing ? 54 : 0)
    }

    private var tableHeader: some View {
        HStack(spacing: 0) {
            ForEach(columns) { column in
                tableHeaderCell(model.t(column.key), column: column)
            }
            if allowsClosing {
                tableHeaderCell("", width: 54, alignment: .center)
            }
        }
        .padding(.vertical, 8)
        .background(ChumenStyle.groupedSurface)
        .overlay(alignment: .bottom) {
            Divider()
        }
    }

    private func tableRow(_ connection: MihomoConnection) -> some View {
        HStack(spacing: 0) {
            tableValueCell(AppModel.formatBytes(connection.download ?? 0), column: columns[0], monospaced: true)
            tableValueCell(AppModel.formatBytes(connection.upload ?? 0), column: columns[1], monospaced: true)
            tableValueCell("-", column: columns[2], monospaced: true)
            tableValueCell("-", column: columns[3], monospaced: true)
            tableValueCell(connectionChainText(for: connection), column: columns[4])
            tableValueCell(connectionRuleText(for: connection), column: columns[5])
            tableValueCell(connectionProcessText(for: connection), column: columns[6])
            tableValueCell(firstNonEmpty([connection.start]), column: columns[7])
            tableValueCell(connectionSourceText(for: connection), column: columns[8])
            tableValueCell(connectionDestinationText(for: connection), column: columns[9])
            tableValueCell(connectionTypeText(for: connection), column: columns[10])

            if allowsClosing {
                Button {
                    model.closeConnection(connection)
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .bold))
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.plain)
                .foregroundStyle(ChumenStyle.mutedText)
                .frame(width: 54, height: 38, alignment: .center)
                .help(model.t(.close))
            }
        }
        .frame(minHeight: 38, alignment: .leading)
        .background(ChumenStyle.surface)
    }

    private func tableHeaderCell(
        _ text: String,
        column: ConnectionTableColumn
    ) -> some View {
        tableHeaderCell(text, width: column.width, alignment: column.alignment)
    }

    private func tableHeaderCell(
        _ text: String,
        width: CGFloat,
        alignment: Alignment
    ) -> some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(ChumenStyle.mutedText)
            .lineLimit(1)
            .truncationMode(.tail)
            .frame(width: width, alignment: alignment)
            .padding(.horizontal, 8)
    }

    private func tableValueCell(
        _ text: String,
        column: ConnectionTableColumn,
        monospaced: Bool = false
    ) -> some View {
        Text(text)
            .font(monospaced ? .caption.monospacedDigit() : .caption)
            .foregroundStyle(Color.primary)
            .lineLimit(1)
            .truncationMode(.middle)
            .frame(width: column.width, alignment: column.alignment)
            .padding(.horizontal, 8)
            .textSelection(.enabled)
    }

    private func connectionEmptyState(title: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: "link")
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(ChumenStyle.mutedText)
            Text(title)
                .font(.headline)
                .foregroundStyle(ChumenStyle.mutedText)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
    }
}

private struct ConnectionTableColumn: Identifiable {
    var id: String { key.rawValue }
    let key: L10n.Key
    let width: CGFloat
    let alignment: Alignment
}

private struct ConnectionRowsPanel: View {
    @EnvironmentObject private var model: AppModel

    let connections: [MihomoConnection]
    let searchText: String
    let emptyTitle: String
    let allowsClosing: Bool

    private var filteredConnections: [MihomoConnection] {
        filterConnections(connections, searchText: searchText)
    }

    var body: some View {
        if connections.isEmpty {
            connectionEmptyState(title: emptyTitle)
        } else if filteredConnections.isEmpty {
            connectionEmptyState(title: model.t(.noMatchingConnections))
        } else {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(filteredConnections) { connection in
                        connectionRow(connection)
                        if connection.id != filteredConnections.last?.id {
                            Divider()
                                .padding(.leading, 12)
                        }
                    }
                }
                .padding(.bottom, 8)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
    }

    private func connectionEmptyState(title: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: "link")
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(ChumenStyle.mutedText)
            Text(title)
                .font(.headline)
                .foregroundStyle(ChumenStyle.mutedText)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
    }

    private func connectionRow(_ connection: MihomoConnection) -> some View {
        HStack(alignment: .top, spacing: 10) {
            connectionIdentity(connection)
                .layoutPriority(1)

            connectionTrafficControls(connection)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
        .contentShape(Rectangle())
    }

    private func connectionIdentity(_ connection: MihomoConnection) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(connectionHostText(for: connection))
                .font(.callout.weight(.semibold))
                .lineLimit(1)
                .truncationMode(.middle)

            connectionTags(for: connection)

            Text(connectionEndpointText(for: connection))
                .font(.caption2)
                .foregroundStyle(ChumenStyle.mutedText)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
    }

    private func connectionTags(for connection: MihomoConnection) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 4) {
                connectionTag(connection.metadata?.network, maxWidth: 74)
                connectionTag(connection.metadata?.type, maxWidth: 82)
                connectionTag(connection.metadata?.process, maxWidth: 118)
                connectionTag(connectionRuleText(for: connection), maxWidth: 130)
                connectionTag(connectionChainText(for: connection), maxWidth: 180)
            }

            HStack(spacing: 4) {
                connectionTag(connection.metadata?.network, maxWidth: 74)
                connectionTag(connection.metadata?.type, maxWidth: 82)
                connectionTag(connection.metadata?.process, maxWidth: 118)
                connectionTag(connectionRuleText(for: connection), maxWidth: 130)
            }

            HStack(spacing: 4) {
                connectionTag(connection.metadata?.network, maxWidth: 74)
                connectionTag(connection.metadata?.type, maxWidth: 82)
                connectionTag(connection.metadata?.process, maxWidth: 118)
            }
        }
    }

    @ViewBuilder
    private func connectionTag(_ value: String?, maxWidth: CGFloat) -> some View {
        let text = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !text.isEmpty, text != "-" {
            Text(text)
                .font(.caption2.weight(.medium))
                .foregroundStyle(ChumenStyle.mutedText)
                .lineLimit(1)
                .truncationMode(.middle)
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .frame(maxWidth: maxWidth, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(ChumenStyle.groupedSurface.opacity(0.55))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .strokeBorder(ChumenStyle.border.opacity(0.45))
                )
        }
    }

    private func connectionTrafficControls(_ connection: MihomoConnection) -> some View {
        HStack(alignment: .center, spacing: 8) {
            VStack(alignment: .trailing, spacing: 3) {
                Text("\(model.t(.upload)) \(AppModel.formatBytes(connection.upload ?? 0))")
                Text("\(model.t(.download)) \(AppModel.formatBytes(connection.download ?? 0))")
            }
            .font(.caption2.weight(.medium))
            .foregroundStyle(ChumenStyle.mutedText)
            .lineLimit(1)
            .frame(width: 82, alignment: .trailing)

            if allowsClosing {
                Button {
                    model.closeConnection(connection)
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color.primary)
                        .frame(width: 28, height: 28)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(ChumenStyle.controlFill)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .strokeBorder(ChumenStyle.border.opacity(0.55))
                        )
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help(model.t(.close))
            }
        }
        .frame(width: allowsClosing ? 122 : 82, alignment: .trailing)
    }
}

private func filterConnections(_ connections: [MihomoConnection], searchText: String) -> [MihomoConnection] {
    let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !query.isEmpty else { return connections }
    return connections.filter { connectionSearchableText(for: $0).localizedCaseInsensitiveContains(query) }
}

private func connectionHostText(for connection: MihomoConnection) -> String {
    let host = firstNonEmpty([
        connection.metadata?.host,
        connection.metadata?.destinationIP,
        connection.rulePayload,
        connection.chains?.last,
        connection.id
    ])

    guard let port = connection.metadata?.destinationPort?.trimmingCharacters(in: .whitespacesAndNewlines),
          !port.isEmpty,
          host != "-"
    else {
        return host
    }
    return "\(host):\(port)"
}

private func connectionChainText(for connection: MihomoConnection) -> String {
    guard let chains = connection.chains, !chains.isEmpty else { return "-" }
    return chains.reversed().joined(separator: " / ")
}

private func connectionRuleText(for connection: MihomoConnection) -> String {
    let rule = firstNonEmpty([connection.rule])
    let payload = firstNonEmpty([connection.rulePayload])
    if rule == "-" { return payload }
    if payload == "-" { return rule }
    return "\(rule)(\(payload))"
}

private func connectionProcessText(for connection: MihomoConnection) -> String {
    let process = firstNonEmpty([connection.metadata?.process])
    if process != "-" {
        return process
    }
    let processPath = firstNonEmpty([connection.metadata?.processPath])
    if processPath == "-" {
        return "-"
    }
    return URL(fileURLWithPath: processPath).lastPathComponent
}

private func connectionTypeText(for connection: MihomoConnection) -> String {
    let network = firstNonEmpty([connection.metadata?.network])
    let type = firstNonEmpty([connection.metadata?.type])
    if network == "-" { return type }
    if type == "-" { return network }
    return "\(network) / \(type)"
}

private func connectionEndpointText(for connection: MihomoConnection) -> String {
    let source = connectionSourceText(for: connection)
    let destination = connectionDestinationText(for: connection)
    let start = connection.start?.trimmingCharacters(in: .whitespacesAndNewlines)

    var parts = ["\(source) -> \(destination)"]
    if let start, !start.isEmpty {
        parts.append(start)
    }
    return parts.joined(separator: "  ")
}

private func connectionSourceText(for connection: MihomoConnection) -> String {
    endpointText(
        host: connection.metadata?.sourceIP,
        port: connection.metadata?.sourcePort
    )
}

private func connectionDestinationText(for connection: MihomoConnection) -> String {
    endpointText(
        host: firstNonEmpty([
            connection.metadata?.destinationIP,
            connection.metadata?.host,
            connection.rulePayload
        ]),
        port: connection.metadata?.destinationPort
    )
}

private func endpointText(host: String?, port: String?) -> String {
    let cleanedHost = host?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    let cleanedPort = port?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

    guard !cleanedHost.isEmpty, cleanedHost != "-" else { return "-" }
    guard !cleanedPort.isEmpty else { return cleanedHost }
    return "\(cleanedHost):\(cleanedPort)"
}

private func connectionSearchableText(for connection: MihomoConnection) -> String {
    var parts: [String] = []
    func append(_ value: String?) {
        guard let text = value?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else { return }
        parts.append(text)
    }

    append(connection.id)
    append(connection.start)
    append(connection.rule)
    append(connection.rulePayload)
    append(connection.chains?.joined(separator: " "))
    append(connection.metadata?.network)
    append(connection.metadata?.type)
    append(connection.metadata?.sourceIP)
    append(connection.metadata?.destinationIP)
    append(connection.metadata?.sourcePort)
    append(connection.metadata?.destinationPort)
    append(connection.metadata?.host)
    append(connection.metadata?.dnsMode)
    append(connection.metadata?.process)
    append(connection.metadata?.processPath)
    append(connection.metadata?.specialProxy)

    return parts.joined(separator: "\n")
}

private func firstNonEmpty(_ values: [String?]) -> String {
    values
        .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
        .first { !$0.isEmpty } ?? "-"
}
