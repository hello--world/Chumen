import Charts
import ChumenCore
import SwiftUI

struct RulesView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Button {
                    Task { await model.refreshRules() }
                } label: {
                    Label(model.t(.refreshRules), systemImage: "arrow.triangle.2.circlepath")
                }
                Spacer()
                Text("\(model.rules.count) \(model.t(.rules))")
                    .foregroundStyle(.secondary)
            }

            List {
                ForEach(Array(model.rules.enumerated()), id: \.offset) { index, rule in
                    HStack {
                        Text(rule.type ?? "unknown")
                            .font(.caption.weight(.semibold))
                            .frame(width: 90, alignment: .leading)
                        Text(rule.payload ?? "")
                            .lineLimit(1)
                        Spacer()
                        Text(rule.proxy ?? "")
                            .foregroundStyle(.secondary)
                        Button(rule.disabled == true ? model.t(.activate) : model.t(.disableProxy)) {
                            model.setRuleDisabled(index: index, disabled: !(rule.disabled ?? false))
                        }
                    }
                    .padding(.vertical, 3)
                }
            }
        }
        .padding(18)
    }
}

struct LogsView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(model.t(.logs), systemImage: "text.alignleft")
                    .font(.headline)
                Spacer()
                Button {
                    model.clearLogs()
                } label: {
                    Label(model.t(.clearLogs), systemImage: "trash")
                }
            }

            HSplitView {
                logReportPanel
                    .frame(minWidth: 360, idealWidth: 420, maxWidth: 500)

                HSplitView {
                    logPane(title: model.t(.processLog), text: model.logs)
                    logPane(title: model.t(.runtimeLog), text: model.runtimeLogs)
                }
            }
        }
        .padding(18)
    }

    private var logReportPanel: some View {
        let analysis = model.logAnalysisSnapshot

        return ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label(model.t(.logReport), systemImage: "chart.bar.doc.horizontal")
                        .font(.headline)
                    Spacer()
                    Text(model.t(.aiAnalysisReady))
                        .font(.caption.weight(.medium))
                        .foregroundStyle(ChumenStyle.mutedText)
                }

                HStack(spacing: 8) {
                    reportMetricTile(
                        title: model.t(.totalLines),
                        value: "\(analysis.totalLines)",
                        detail: "\(model.t(.processLog)) / \(model.t(.runtimeLog))",
                        systemImage: "text.alignleft",
                        color: .blue
                    )
                    reportMetricTile(
                        title: model.t(.errorLogs),
                        value: "\(analysis.errorCount)",
                        detail: "\(model.t(.warningLogs)) \(analysis.warningCount)",
                        systemImage: "exclamationmark.triangle",
                        color: analysis.errorCount > 0 ? .red : .green
                    )
                }

                reportPanel(title: model.t(.historyTrend), systemImage: "waveform.path.ecg") {
                    logTrendChart
                }

                reportPanel(title: model.t(.logLevels), systemImage: "chart.bar.xaxis") {
                    logLevelChart(analysis.levelBuckets)
                }

                reportPanel(title: model.t(.frequentMessages), systemImage: "repeat") {
                    if analysis.frequentMessages.isEmpty {
                        emptyReportText
                    } else {
                        VStack(alignment: .leading, spacing: 7) {
                            ForEach(analysis.frequentMessages) { bucket in
                                HStack(spacing: 8) {
                                    Text("\(bucket.count)")
                                        .font(.caption.monospacedDigit().weight(.semibold))
                                        .frame(width: 34, alignment: .trailing)
                                        .foregroundStyle(.orange)
                                    Text(bucket.label)
                                        .font(.caption)
                                        .lineLimit(2)
                                        .truncationMode(.middle)
                                }
                            }
                        }
                    }
                }

                reportPanel(title: model.t(.recentIssues), systemImage: "exclamationmark.bubble") {
                    if analysis.recentIssues.isEmpty {
                        emptyReportText
                    } else {
                        VStack(alignment: .leading, spacing: 7) {
                            ForEach(analysis.recentIssues) { issue in
                                VStack(alignment: .leading, spacing: 3) {
                                    HStack(spacing: 6) {
                                        Circle()
                                            .fill(logLevelColor(issue.level.rawValue))
                                            .frame(width: 7, height: 7)
                                        Text(logLevelLabel(issue.level.rawValue))
                                            .font(.caption2.weight(.semibold))
                                            .foregroundStyle(logLevelColor(issue.level.rawValue))
                                        Text(issue.source)
                                            .font(.caption2)
                                            .foregroundStyle(ChumenStyle.mutedText)
                                    }
                                    Text(issue.message)
                                        .font(.caption)
                                        .lineLimit(2)
                                        .truncationMode(.middle)
                                }
                            }
                        }
                    }
                }
            }
            .padding(12)
        }
        .background(
            RoundedRectangle(cornerRadius: ChumenStyle.radius, style: .continuous)
                .fill(ChumenStyle.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: ChumenStyle.radius, style: .continuous)
                .strokeBorder(ChumenStyle.border)
        )
    }

    private var logTrendChart: some View {
        VStack(alignment: .leading, spacing: 6) {
            if model.logReportSamples.isEmpty {
                emptyReportText
                    .frame(height: 138)
            } else {
                Chart(model.logReportSamples) { sample in
                    LineMark(
                        x: .value(model.t(.lastRefresh), sample.timestamp),
                        y: .value(model.t(.errorLogs), sample.errorCount)
                    )
                    .foregroundStyle(.red)

                    LineMark(
                        x: .value(model.t(.lastRefresh), sample.timestamp),
                        y: .value(model.t(.warningLogs), sample.warningCount)
                    )
                    .foregroundStyle(.orange)
                }
                .chartXAxis(.hidden)
                .chartYAxis {
                    AxisMarks(position: .leading)
                }
                .frame(height: 138)
            }

            reportLegend([
                (color: .red, label: model.t(.errorLogs)),
                (color: .orange, label: model.t(.warningLogs))
            ])
        }
    }

    private func logLevelChart(_ buckets: [LogAnalysisBucket]) -> some View {
        Chart(buckets) { bucket in
            BarMark(
                x: .value(model.t(.totalLines), bucket.count),
                y: .value(model.t(.logLevels), logLevelLabel(bucket.id))
            )
            .foregroundStyle(logLevelColor(bucket.id).gradient)
            .annotation(position: .trailing) {
                Text("\(bucket.count)")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(ChumenStyle.mutedText)
            }
        }
        .chartXAxis(.hidden)
        .frame(height: 132)
    }

    private var emptyReportText: some View {
        Text("-")
            .font(.caption)
            .foregroundStyle(ChumenStyle.mutedText)
            .frame(maxWidth: .infinity, alignment: .leading)
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

    private func reportMetricTile(
        title: String,
        value: String,
        detail: String,
        systemImage: String,
        color: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                    .foregroundStyle(color)
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(ChumenStyle.mutedText)
            }
            Text(value)
                .font(.title2.weight(.bold))
                .lineLimit(1)
            Text(detail)
                .font(.caption)
                .foregroundStyle(ChumenStyle.mutedText)
                .lineLimit(1)
        }
        .padding(10)
        .frame(maxWidth: .infinity, minHeight: 76, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(ChumenStyle.groupedSurface.opacity(0.50))
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

    private func logLevelLabel(_ id: String) -> String {
        switch id {
        case LogAnalysisLevel.error.rawValue: model.t(.errorLogs)
        case LogAnalysisLevel.warning.rawValue: model.t(.warningLogs)
        case LogAnalysisLevel.debug.rawValue: model.t(.debugLogs)
        default: model.t(.infoLogs)
        }
    }

    private func logLevelColor(_ id: String) -> Color {
        switch id {
        case LogAnalysisLevel.error.rawValue: .red
        case LogAnalysisLevel.warning.rawValue: .orange
        case LogAnalysisLevel.debug.rawValue: .purple
        default: .blue
        }
    }

    private func logPane(title: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            ScrollView {
                Text(text.isEmpty ? model.t(.noLogs) : text)
                    .font(.system(.caption, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
                    .padding(12)
            }
            .background(Color(nsColor: .textBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .frame(minWidth: 320)
    }
}
