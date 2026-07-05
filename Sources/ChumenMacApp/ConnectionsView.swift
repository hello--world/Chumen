import Charts
import ChumenCore
import SwiftUI

struct ConnectionsView: View {
    @EnvironmentObject private var model: AppModel
    @State private var searchText = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                controlsBar
                connectionReport
                connectionsList
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .background(ChumenStyle.pageBackground)
    }

    private var controlsBar: some View {
        HStack(spacing: 10) {
            Button {
                Task { await model.refreshConnections() }
            } label: {
                Label(model.t(.refreshConnections), systemImage: "arrow.triangle.2.circlepath")
            }
            Button(role: .destructive) {
                model.closeAllConnections()
            } label: {
                Label(model.t(.closeAll), systemImage: "xmark.circle")
            }
            .disabled(model.connections.isEmpty)

            TextField(model.t(.searchConnections), text: $searchText)
                .textFieldStyle(.roundedBorder)
                .frame(width: 320)

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

            Spacer()
            Text(connectionsSummary)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .controlSize(.large)
    }

    private var filteredConnections: [MihomoConnection] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return model.connections }
        return model.connections.filter { searchableText(for: $0).localizedCaseInsensitiveContains(query) }
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
        if model.connections.isEmpty {
            connectionEmptyState(title: model.t(.noConnections))
        } else if filteredConnections.isEmpty {
            connectionEmptyState(title: model.t(.noMatchingConnections))
        } else {
            LazyVStack(spacing: 0) {
                ForEach(filteredConnections) { connection in
                    connectionRow(connection)
                    if connection.id != filteredConnections.last?.id {
                        Divider()
                            .padding(.leading, 12)
                    }
                }
            }
            .padding(.trailing, 18)
            .background(
                RoundedRectangle(cornerRadius: ChumenStyle.radius, style: .continuous)
                    .fill(ChumenStyle.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: ChumenStyle.radius, style: .continuous)
                    .strokeBorder(ChumenStyle.border)
            )
            .frame(minHeight: 260, alignment: .top)
        }
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
        .background(
            RoundedRectangle(cornerRadius: ChumenStyle.radius, style: .continuous)
                .fill(ChumenStyle.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: ChumenStyle.radius, style: .continuous)
                .strokeBorder(ChumenStyle.border)
        )
    }

    private func connectionRow(_ connection: MihomoConnection) -> some View {
        HStack(alignment: .center, spacing: 12) {
            connectionIdentity(connection)
                .layoutPriority(0)

            connectionTrafficControls(connection)
                .layoutPriority(1)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity, minHeight: 76, alignment: .leading)
    }

    private func connectionIdentity(_ connection: MihomoConnection) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(connectionTitle(for: connection))
                .font(.headline)
                .lineLimit(1)
                .truncationMode(.middle)

            Text(connectionChainText(for: connection))
                .font(.caption.weight(.medium))
                .foregroundStyle(ChumenStyle.mutedText)
                .lineLimit(1)
                .truncationMode(.middle)

            Text(connectionDetailText(for: connection))
                .font(.caption)
                .foregroundStyle(ChumenStyle.mutedText)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(minWidth: 220, maxWidth: .infinity, minHeight: 58, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(ChumenStyle.identityFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .strokeBorder(ChumenStyle.border.opacity(0.40))
        )
    }

    private func connectionTrafficControls(_ connection: MihomoConnection) -> some View {
        VStack(alignment: .trailing, spacing: 6) {
            Text("\(model.t(.upload)) \(AppModel.formatBytes(connection.upload ?? 0))")
            Text("\(model.t(.download)) \(AppModel.formatBytes(connection.download ?? 0))")

            Button {
                model.closeConnection(connection)
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "xmark.circle")
                        .font(.system(size: 13, weight: .semibold))
                    Text(model.t(.close))
                        .font(.callout.weight(.medium))
                }
                .foregroundStyle(Color.primary)
                .frame(width: 86, height: 32)
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
        .font(.caption.weight(.medium))
        .foregroundStyle(Color.primary)
        .frame(width: 118, alignment: .trailing)
    }

    private func connectionTitle(for connection: MihomoConnection) -> String {
        firstNonEmpty([
            connection.metadata?.host,
            connection.metadata?.destinationIP,
            connection.rulePayload,
            connection.chains?.last,
            connection.id
        ])
    }

    private func connectionChainText(for connection: MihomoConnection) -> String {
        guard let chains = connection.chains, !chains.isEmpty else { return "-" }
        return chains.joined(separator: " > ")
    }

    private func connectionDetailText(for connection: MihomoConnection) -> String {
        firstNonEmpty([
            connection.metadata?.process,
            connection.metadata?.destinationIP,
            connection.rulePayload,
            connection.rule,
            connection.metadata?.network,
            connection.id
        ])
    }

    private func searchableText(for connection: MihomoConnection) -> String {
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
}
