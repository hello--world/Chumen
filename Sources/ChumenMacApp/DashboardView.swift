import ChumenCore
import SwiftUI

struct DashboardView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                commandPanel
                metricsGrid
            }
            .padding(20)
            .frame(maxWidth: 1280, alignment: .topLeading)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .background(ChumenStyle.pageBackground)
    }

    private var commandPanel: some View {
        HStack(alignment: .center, spacing: 12) {
            commandSummary
                .frame(width: 330, alignment: .leading)

            Spacer(minLength: 12)

            VStack(alignment: .trailing, spacing: 9) {
                commandActions
                modeControl
            }
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: ChumenStyle.radius, style: .continuous)
                .fill(ChumenStyle.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: ChumenStyle.radius, style: .continuous)
                .strokeBorder(ChumenStyle.border)
        )
        .shadow(color: ChumenStyle.softShadow, radius: 6, x: 0, y: 2)
    }

    private var commandSummary: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: ChumenStyle.radius, style: .continuous)
                    .fill(commandAccent.opacity(0.10))
                Image(systemName: commandIcon)
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(commandAccent)
            }
            .frame(width: 38, height: 38)

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 8) {
                    Text(commandTitle)
                        .font(.headline.weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)

                    Text(commandBadge)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(commandAccent)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(
                            Capsule(style: .continuous)
                                .fill(commandAccent.opacity(0.10))
                        )
                }

                Text(commandSubtitle)
                    .font(.caption)
                    .foregroundStyle(ChumenStyle.mutedText)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var modeControl: some View {
        HStack(spacing: 8) {
            Text(model.t(.mode))
                .font(.callout.weight(.medium))
                .foregroundStyle(ChumenStyle.mutedText)
            modePicker
                .frame(width: 270)
        }
        .frame(maxWidth: 340, alignment: .leading)
    }

    private var commandActions: some View {
        HStack(spacing: 8) {
            Button {
                model.start()
            } label: {
                Label(model.t(.start), systemImage: "play.fill")
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .frame(width: 82)
            }
            .buttonStyle(.borderedProminent)
            .labelStyle(.titleAndIcon)
            .help(model.t(.start))
            .disabled(model.isRunning || model.isCoreTransitioning)

            Button {
                model.stop()
            } label: {
                Label(model.t(.stop), systemImage: "stop.fill")
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .frame(width: 82)
            }
            .buttonStyle(.bordered)
            .labelStyle(.titleAndIcon)
            .help(model.t(.stop))
            .disabled(!model.isRunning || model.isCoreTransitioning)

            Button {
                model.restart()
            } label: {
                Label(model.t(.restart), systemImage: "arrow.clockwise")
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .frame(width: 82)
            }
            .buttonStyle(.bordered)
            .labelStyle(.titleAndIcon)
            .help(model.t(.restart))
            .disabled(model.isCoreTransitioning)

            Button {
                Task { await model.refreshAll() }
            } label: {
                Label(model.t(.refresh), systemImage: "arrow.triangle.2.circlepath")
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .frame(width: 82)
            }
            .buttonStyle(.bordered)
            .labelStyle(.titleAndIcon)
            .help(model.t(.refresh))

            Button {
                model.toggleSystemProxy()
            } label: {
                Label(model.systemProxyEnabled ? model.t(.disableProxy) : model.t(.enableProxy), systemImage: "network")
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .frame(width: 112)
            }
            .buttonStyle(.bordered)
            .labelStyle(.titleAndIcon)
            .help(model.systemProxyEnabled ? model.t(.disableProxy) : model.t(.enableProxy))

            Button {
                model.setTunEnabled(!model.settings.enableTun)
            } label: {
                Label(model.settings.enableTun ? model.t(.disableTun) : model.t(.enableTun), systemImage: "shield.lefthalf.filled")
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .frame(width: 112)
            }
            .buttonStyle(.bordered)
            .labelStyle(.titleAndIcon)
            .help(tunHelpText)
            .tint(tunAccent)
            .disabled(model.isCoreTransitioning)
        }
        .controlSize(.regular)
    }

    private var commandTitle: String {
        if !model.isRunning {
            return model.t(.coreNotRunning)
        }
        if isAPIUnavailable {
            return model.t(.apiUnavailable)
        }
        if isAPINotTested {
            return model.t(.running)
        }
        return model.t(.apiConnected)
    }

    private var commandSubtitle: String {
        if !model.isRunning {
            let failure = commandFailureText
            if !failure.isEmpty {
                return failure
            }
            return "\(model.t(.coreNotRunningHint)) \(model.t(.activeProfile)): \(model.activeProfile?.name ?? "-")"
        }
        if isAPIUnavailable {
            return "\(model.t(.apiUnavailableHint)) \(controllerAddress)"
        }
        if isAPINotTested {
            return model.t(.apiNotTestedHint)
        }

        let status = model.statusText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !status.isEmpty else { return model.t(.apiConnectedHint) }
        let lowercased = status.lowercased()
        let suppressedStatuses = [
            model.t(.running),
            model.t(.stopped),
            model.t(.controllerUnavailable),
            model.t(.tunEnabled),
            model.t(.tunDisabled),
            L10n.text(.controllerUnavailable, language: .en)
        ]
        return suppressedStatuses.contains(status)
            || lowercased.contains("could not connect")
            || lowercased.contains("cannot connect")
            ? model.t(.apiConnectedHint)
            : status
    }

    private var commandFailureText: String {
        let status = model.statusText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !status.isEmpty else { return "" }
        let suppressed = [
            model.t(.running),
            model.t(.stopped),
            model.t(.coreNotRunning),
            model.t(.controllerUnavailable),
            L10n.text(.controllerUnavailable, language: .en)
        ]
        if suppressed.contains(status) {
            return ""
        }
        return status
    }

    private var commandBadge: String {
        if !model.isRunning {
            return model.t(.actionStartCore)
        }
        if isAPIUnavailable {
            return model.t(.actionCheckAPI)
        }
        if isAPINotTested {
            return model.t(.pending)
        }
        return model.t(.ready)
    }

    private var commandIcon: String {
        if !model.isRunning {
            return "power"
        }
        if isAPIUnavailable {
            return "exclamationmark.triangle.fill"
        }
        if isAPINotTested {
            return "clock"
        }
        return "checkmark.circle.fill"
    }

    private var commandAccent: Color {
        if !model.isRunning {
            return ChumenStyle.mutedText
        }
        if isAPIUnavailable {
            return .orange
        }
        if isAPINotTested {
            return .blue
        }
        return .green
    }

    private var controllerAddress: String {
        "\(model.settings.externalControllerHost):\(model.settings.externalControllerPort)"
    }

    private var isAPINotTested: Bool {
        let status = normalizedAPIText
        return status.isEmpty
            || status == model.t(.apiNotTested)
            || status == L10n.text(.apiNotTested, language: .en)
    }

    private var isAPIUnavailable: Bool {
        let status = normalizedAPIText
        let lowercased = status.lowercased()
        return status == model.t(.controllerUnavailable)
            || status == L10n.text(.controllerUnavailable, language: .en)
            || lowercased.contains("could not connect")
            || lowercased.contains("cannot connect")
            || lowercased.contains("connection refused")
    }

    private var normalizedAPIText: String {
        model.apiText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var modePicker: some View {
        Picker(model.t(.mode), selection: Binding(
            get: { model.settings.mode },
            set: { model.applyMode($0) }
        )) {
            ForEach(ProxyMode.allCases) { mode in
                Text(mode.rawValue).tag(mode)
            }
        }
        .labelsHidden()
        .pickerStyle(.segmented)
    }

    private var metricsGrid: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 230, maximum: 320), spacing: 12)], spacing: 12) {
            metric(
                model.t(.runtime),
                value: model.isRunning ? model.t(.running) : model.t(.stopped),
                icon: "bolt.horizontal",
                accent: model.isRunning ? .green : ChumenStyle.mutedText
            )
            metric(
                model.t(.activeProfile),
                value: model.activeProfile?.name ?? "-",
                icon: "doc.text",
                accent: .blue
            )
            metric(
                model.t(.mode),
                value: model.settings.mode.rawValue,
                icon: "arrow.triangle.branch",
                accent: .purple
            )
            metric(
                model.t(.cumulativeTraffic),
                value: model.dashboardTrafficText,
                icon: "arrow.up.arrow.down",
                accent: .teal
            )
            metric(
                model.t(.currentSpeed),
                value: model.speedText,
                icon: "speedometer",
                accent: .cyan
            )
            metric(
                model.t(.routedTraffic),
                value: model.routedTrafficText,
                icon: "point.3.connected.trianglepath.dotted",
                accent: .mint
            )
            metric(
                model.t(.memory),
                value: model.memoryText,
                icon: "memorychip",
                accent: .indigo
            )
            metric(
                model.t(.systemProxy),
                value: model.systemProxyEnabled ? model.t(.on) : model.t(.off),
                icon: model.systemProxyEnabled ? "checkmark.shield" : "shield",
                accent: model.systemProxyEnabled ? .green : ChumenStyle.mutedText
            )
            metric(
                model.t(.tunMode),
                value: tunStateText,
                icon: "shield.lefthalf.filled",
                accent: tunAccent
            )
        }
    }

    private func metric(_ title: String, value: String, icon: String, accent: Color) -> some View {
        HStack(alignment: .center, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(ChumenStyle.groupedSurface)
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(accent)
            }
            .frame(width: 36, height: 36)

            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(ChumenStyle.mutedText)
                Text(value)
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(Color.primary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.72)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(minHeight: 88, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: ChumenStyle.radius, style: .continuous)
                .fill(ChumenStyle.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: ChumenStyle.radius, style: .continuous)
                .strokeBorder(ChumenStyle.border)
        )
        .shadow(color: ChumenStyle.softShadow, radius: 5, x: 0, y: 1)
    }

    private var tunStateText: String {
        if !model.settings.enableTun {
            return model.t(.off)
        }
        if model.tunRuntimeFailed {
            return model.tunRuntimeFailureTitle
        }
        if model.isCoreTransitioning {
            return model.t(.pending)
        }
        return model.t(.on)
    }

    private var tunAccent: Color {
        if model.settings.enableTun && model.tunRuntimeFailed {
            return .orange
        }
        return model.settings.enableTun ? .green : ChumenStyle.mutedText
    }

    private var tunHelpText: String {
        if model.settings.enableTun && model.tunRuntimeFailed {
            let detail = model.tunRuntimeFailureDetail.trimmingCharacters(in: .whitespacesAndNewlines)
            return detail.isEmpty ? model.t(.tunFailed) : "\(model.t(.tunFailed)): \(detail)"
        }
        return model.settings.enableTun ? model.t(.disableTun) : model.t(.enableTun)
    }
}
