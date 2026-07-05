import ChumenCore
import SwiftUI

struct DashboardView: View {
    @EnvironmentObject private var model: AppModel
    @Binding var selectedTab: AppTab

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                commandPanel
                dashboardSections
            }
            .padding(.horizontal, 18)
            .padding(.top, 18)
            .padding(.bottom, 28)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .background(ChumenStyle.pageBackground)
    }

    private var dashboardSections: some View {
        VStack(alignment: .leading, spacing: 18) {
            ForEach(DashboardSectionRegistry.sections(for: model)) { section in
                dashboardSection(section)
            }
        }
    }

    private func dashboardSection(_ section: DashboardSection) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(section.title)
                    .font(.headline.weight(.semibold))
                if !section.detail.isEmpty {
                    Text(section.detail)
                        .font(.caption)
                        .foregroundStyle(ChumenStyle.mutedText)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                Spacer(minLength: 0)
            }

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 260, maximum: 420), spacing: 12)],
                alignment: .leading,
                spacing: 12
            ) {
                ForEach(section.items) { item in
                    dashboardItem(item)
                }
            }
        }
    }

    private func dashboardItem(_ item: DashboardItem) -> some View {
        Group {
            if isActionable(item.action) {
                Button {
                    perform(item.action)
                } label: {
                    dashboardItemContent(item)
                }
                .buttonStyle(.plain)
                .disabled(!item.isEnabled)
            } else {
                dashboardItemContent(item)
            }
        }
        .opacity(item.isEnabled ? 1 : 0.52)
    }

    private func dashboardItemContent(_ item: DashboardItem) -> some View {
        HStack(alignment: .center, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(item.tint.opacity(iconFillOpacity(for: item.style)))
                Image(systemName: item.systemImage)
                    .font(.system(size: iconSize(for: item.style), weight: .semibold))
                    .foregroundStyle(item.tint)
            }
            .frame(width: 38, height: 38)

            VStack(alignment: .leading, spacing: 6) {
                Text(item.title)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(ChumenStyle.mutedText)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Text(item.value)
                    .font(valueFont(for: item.style))
                    .foregroundStyle(Color.primary)
                    .lineLimit(valueLineLimit(for: item.style))
                    .minimumScaleFactor(0.74)
                    .fixedSize(horizontal: false, vertical: true)
                if !item.detail.isEmpty {
                    Text(item.detail)
                        .font(.caption)
                        .foregroundStyle(ChumenStyle.mutedText)
                        .lineLimit(detailLineLimit(for: item.style))
                        .truncationMode(.middle)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer(minLength: 0)

            if isActionable(item.action) {
                Image(systemName: actionIcon(for: item.action))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(ChumenStyle.mutedText)
                    .frame(width: 16)
            }
        }
        .padding(12)
        .frame(minHeight: minHeight(for: item.style), alignment: .leading)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: ChumenStyle.radius, style: .continuous)
                .fill(ChumenStyle.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: ChumenStyle.radius, style: .continuous)
                .strokeBorder(ChumenStyle.border)
        )
        .contentShape(RoundedRectangle(cornerRadius: ChumenStyle.radius, style: .continuous))
    }

    private var commandPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .center, spacing: 14) {
                    commandSummary
                    Spacer(minLength: 12)
                    modeControl
                }

                VStack(alignment: .leading, spacing: 10) {
                    commandSummary
                    modeControl
                }
            }

            Divider()

            ViewThatFits(in: .horizontal) {
                quickActionStrip
                ScrollView(.horizontal, showsIndicators: false) {
                    quickActionStrip
                }
            }
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

    private var quickActionStrip: some View {
        HStack(spacing: 8) {
            ForEach(DashboardSectionRegistry.quickActions(for: model)?.items ?? []) { item in
                quickActionButton(item)
            }
        }
        .controlSize(.regular)
    }

    @ViewBuilder
    private func quickActionButton(_ item: DashboardItem) -> some View {
        if isPrimaryCommand(item.action) {
            Button {
                perform(item.action)
            } label: {
                quickActionLabel(item)
            }
            .buttonStyle(.borderedProminent)
            .labelStyle(.titleAndIcon)
            .disabled(!item.isEnabled)
            .tint(item.tint)
            .help(quickActionHelp(item))
        } else {
            Button {
                perform(item.action)
            } label: {
                quickActionLabel(item)
            }
            .buttonStyle(.bordered)
            .labelStyle(.titleAndIcon)
            .disabled(!item.isEnabled)
            .tint(item.tint)
            .help(quickActionHelp(item))
        }
    }

    private func quickActionLabel(_ item: DashboardItem) -> some View {
        Label(item.title, systemImage: item.systemImage)
            .lineLimit(1)
            .minimumScaleFactor(0.78)
            .padding(.horizontal, 2)
            .frame(minWidth: 76)
    }

    private func quickActionHelp(_ item: DashboardItem) -> String {
        item.detail.isEmpty ? item.title : "\(item.title): \(item.detail)"
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

    private func perform(_ action: DashboardItemAction) {
        switch action {
        case .none:
            break
        case .openTab(let tab):
            selectedTab = tab
        case .refreshAll:
            Task { await model.refreshAll() }
        case .startCore:
            model.start()
        case .stopCore:
            model.stop()
        case .restartCore:
            model.restart()
        case .toggleSystemProxy:
            model.toggleSystemProxy()
        case .toggleTun:
            model.setTunEnabled(!model.settings.enableTun)
        case .openDashboardURL:
            model.openDashboardURL()
        }
    }

    private func isActionable(_ action: DashboardItemAction) -> Bool {
        switch action {
        case .none:
            return false
        default:
            return true
        }
    }

    private func actionIcon(for action: DashboardItemAction) -> String {
        switch action {
        case .refreshAll:
            return "arrow.triangle.2.circlepath"
        case .startCore:
            return "play.fill"
        case .stopCore:
            return "stop.fill"
        case .restartCore:
            return "arrow.clockwise"
        case .toggleSystemProxy, .toggleTun:
            return "switch.2"
        case .openDashboardURL:
            return "arrow.up.forward.app"
        case .openTab:
            return "chevron.right"
        case .none:
            return ""
        }
    }

    private func isPrimaryCommand(_ action: DashboardItemAction) -> Bool {
        switch action {
        case .startCore:
            return true
        default:
            return false
        }
    }

    private func valueFont(for style: DashboardItemStyle) -> Font {
        switch style {
        case .command:
            return .system(size: 16, weight: .semibold)
        case .state:
            return .system(size: 19, weight: .semibold)
        case .metric:
            return .system(size: 18, weight: .semibold)
        case .diagnostic:
            return .system(size: 16, weight: .semibold)
        case .link:
            return .system(size: 16, weight: .semibold)
        }
    }

    private func iconSize(for style: DashboardItemStyle) -> CGFloat {
        switch style {
        case .diagnostic:
            return 17
        default:
            return 18
        }
    }

    private func iconFillOpacity(for style: DashboardItemStyle) -> Double {
        switch style {
        case .link:
            return 0.08
        case .diagnostic:
            return 0.10
        default:
            return 0.09
        }
    }

    private func valueLineLimit(for style: DashboardItemStyle) -> Int {
        switch style {
        case .metric, .diagnostic:
            return 2
        default:
            return 1
        }
    }

    private func detailLineLimit(for style: DashboardItemStyle) -> Int {
        switch style {
        case .diagnostic:
            return 2
        default:
            return 1
        }
    }

    private func minHeight(for style: DashboardItemStyle) -> CGFloat {
        switch style {
        case .diagnostic:
            return 96
        case .command:
            return 54
        default:
            return 82
        }
    }
}
