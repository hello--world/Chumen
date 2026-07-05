import ChumenCore
import SwiftUI

struct DashboardView: View {
    @EnvironmentObject private var model: AppModel
    @Binding var selectedTab: AppTab
    @State private var quickActionConfigurationPresented = false

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
            commandPanelHeader
            if !commandActionItems.isEmpty {
                commandActionFlow
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: ChumenStyle.radius, style: .continuous)
                .fill(ChumenStyle.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: ChumenStyle.radius, style: .continuous)
                .strokeBorder(ChumenStyle.border)
        )
        .sheet(isPresented: $quickActionConfigurationPresented) {
            QuickActionConfigurationSheet()
                .environmentObject(model)
        }
    }

    private var commandPanelHeader: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .center, spacing: 18) {
                commandStatusStrip
                Spacer(minLength: 16)
                modeControl
            }
            commandPanelHeaderStacked
        }
    }

    private var commandPanelHeaderStacked: some View {
        VStack(alignment: .leading, spacing: 10) {
            if !commandStatusItems.isEmpty {
                commandStatusStrip
            }
            modeControl
        }
    }

    private var commandBarItems: [DashboardItem] {
        DashboardSectionRegistry.sections(for: model, placement: .commandBar)
            .flatMap(\.items)
    }

    private var commandStatusItems: [DashboardItem] {
        commandBarItems.filter { item in
            if case .summary = item.style {
                return true
            }
            return false
        }
    }

    private var commandActionItems: [DashboardItem] {
        commandBarItems.filter { item in
            if case .command = item.style {
                return true
            }
            return false
        }
    }

    private var commandStatusStrip: some View {
        HStack(spacing: 10) {
            ForEach(commandStatusItems) { item in
                commandStatusItem(item)
            }
        }
        .fixedSize(horizontal: true, vertical: false)
    }

    @ViewBuilder
    private func commandStatusItem(_ item: DashboardItem) -> some View {
        if isActionable(item.action) {
            Button {
                perform(item.action)
            } label: {
                commandStatusContent(item)
            }
            .buttonStyle(.plain)
            .disabled(!item.isEnabled)
            .help(quickActionHelp(item))
        } else {
            commandStatusContent(item)
        }
    }

    private func commandStatusContent(_ item: DashboardItem) -> some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: ChumenStyle.radius, style: .continuous)
                    .fill(item.tint.opacity(0.10))
                Image(systemName: item.systemImage)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(item.tint)
            }
            .frame(width: 34, height: 34)

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 8) {
                    Text(item.title)
                        .font(.headline.weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)

                    Text(item.value)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(item.tint)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(
                            Capsule(style: .continuous)
                                .fill(item.tint.opacity(0.10))
                        )
                }

                Text(item.detail)
                    .font(.caption)
                    .foregroundStyle(ChumenStyle.mutedText)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        }
        .opacity(item.isEnabled ? 1 : 0.52)
        .contentShape(Rectangle())
    }

    private var modeControl: some View {
        HStack(spacing: 8) {
            Text(model.t(.mode))
                .font(.callout.weight(.medium))
                .foregroundStyle(ChumenStyle.mutedText)
            dashboardModePicker
                .frame(width: 180)
        }
        .fixedSize(horizontal: true, vertical: false)
    }

    private var dashboardModePicker: some View {
        HStack(spacing: 2) {
            ForEach(ProxyMode.allCases) { mode in
                Button {
                    if model.settings.mode != mode {
                        model.applyMode(mode)
                    }
                } label: {
                    Text(mode.rawValue)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(model.settings.mode == mode ? Color.white : Color.primary)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .fill(model.settings.mode == mode ? Color.blue : Color.clear)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(2)
        .background(
            RoundedRectangle(cornerRadius: ChumenStyle.radius, style: .continuous)
                .fill(ChumenStyle.controlFill)
        )
    }

    private var dashboardEditButton: some View {
        Button {
            quickActionConfigurationPresented = true
        } label: {
            Label(model.t(.editQuickControls), systemImage: "slider.horizontal.3")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
                .padding(.horizontal, 10)
                .frame(height: 32)
                .background(
                    RoundedRectangle(cornerRadius: ChumenStyle.radius, style: .continuous)
                        .fill(ChumenStyle.controlFill)
                )
        }
        .buttonStyle(.plain)
        .help(model.t(.quickControlsConfiguration))
    }

    private var commandActionFlow: some View {
        VStack(alignment: .leading, spacing: 8) {
            CommandActionFlowLayout(horizontalSpacing: 8, verticalSpacing: 8) {
                ForEach(commandPinnedActionItems) { item in
                    quickActionButton(item)
                }
                dashboardEditButton
            }

            if !commandExtensionActionItems.isEmpty {
                commandActionRow(commandExtensionActionItems)
            }
        }
        .controlSize(.regular)
    }

    // The command bar has a fixed core row and an extension row. Start/stop/restart/refresh,
    // system proxy, TUN, and quick-control editing are muscle-memory operations and should stay
    // together; optional startup/network preferences belong below so enabling more shortcuts does
    // not disrupt the primary controls.
    private func commandActionRow(_ items: [DashboardItem]) -> some View {
        CommandActionFlowLayout(horizontalSpacing: 8, verticalSpacing: 8) {
            ForEach(items) { item in
                quickActionButton(item)
            }
        }
    }

    private var commandPinnedActionItems: [DashboardItem] {
        commandActionItems.filter { item in
            pinnedCommandActionIDs.contains(item.id)
        }
    }

    private var commandExtensionActionItems: [DashboardItem] {
        commandActionItems.filter { item in
            !pinnedCommandActionIDs.contains(item.id)
        }
    }

    private var pinnedCommandActionIDs: Set<String> {
        [
            "actions.start",
            "actions.stop",
            "actions.restart",
            "actions.refresh",
            "actions.system-proxy",
            "actions.tun"
        ]
    }

    @ViewBuilder
    private func quickActionButton(_ item: DashboardItem) -> some View {
        if let isOn = toggleValue(for: item.action) {
            Button {
                setToggleValue(!isOn, for: item.action)
            } label: {
                quickToggleLabel(item, isOn: isOn)
            }
            .buttonStyle(.plain)
            .disabled(!item.isEnabled)
            .help(quickActionHelp(item))
        } else {
            Button {
                perform(item.action)
            } label: {
                quickActionLabel(item)
            }
            .buttonStyle(.plain)
            .disabled(!item.isEnabled)
            .help(quickActionHelp(item))
        }
    }

    private func quickActionLabel(_ item: DashboardItem) -> some View {
        Label(item.title, systemImage: item.systemImage)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(quickActionForeground(for: item))
            .lineLimit(1)
            .minimumScaleFactor(0.72)
            .padding(.horizontal, 10)
            .frame(height: 32)
            .background(
                RoundedRectangle(cornerRadius: ChumenStyle.radius, style: .continuous)
                    .fill(quickActionBackground(for: item))
            )
            .overlay(
                RoundedRectangle(cornerRadius: ChumenStyle.radius, style: .continuous)
                    .strokeBorder(quickActionBorder(for: item))
            )
            .opacity(item.isEnabled ? 1 : 0.42)
    }

    private func quickToggleLabel(_ item: DashboardItem, isOn: Bool) -> some View {
        HStack(spacing: 7) {
            Image(systemName: item.systemImage)
                .font(.subheadline.weight(.semibold))
                .frame(width: 16)
            Text(item.title)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.68)
            switchGlyph(isOn: isOn, tint: item.tint)
        }
        .foregroundStyle(quickActionForeground(for: item))
        .padding(.horizontal, 10)
        .frame(height: 32)
        .background(
            RoundedRectangle(cornerRadius: ChumenStyle.radius, style: .continuous)
                .fill(quickActionBackground(for: item))
        )
        .overlay(
            RoundedRectangle(cornerRadius: ChumenStyle.radius, style: .continuous)
                .strokeBorder(quickActionBorder(for: item))
        )
        .opacity(item.isEnabled ? 1 : 0.42)
    }

    private func switchGlyph(isOn: Bool, tint: Color) -> some View {
        RoundedRectangle(cornerRadius: 7, style: .continuous)
            .fill(isOn ? tint.opacity(0.92) : ChumenStyle.mutedText.opacity(0.22))
            .frame(width: 24, height: 13)
            .overlay(alignment: isOn ? .trailing : .leading) {
                Circle()
                    .fill(Color.white)
                    .frame(width: 9, height: 9)
                    .padding(2)
            }
    }

    private func quickActionHelp(_ item: DashboardItem) -> String {
        item.detail.isEmpty ? item.title : "\(item.title): \(item.detail)"
    }

    private func quickActionForeground(for item: DashboardItem) -> Color {
        guard item.isEnabled else { return ChumenStyle.mutedText }
        return isPrimaryCommand(item.action) ? .white : item.tint
    }

    private func quickActionBackground(for item: DashboardItem) -> Color {
        guard item.isEnabled else { return ChumenStyle.controlFill }
        return isPrimaryCommand(item.action) ? item.tint : item.tint.opacity(0.10)
    }

    private func quickActionBorder(for item: DashboardItem) -> Color {
        guard item.isEnabled else { return ChumenStyle.border }
        return isPrimaryCommand(item.action) ? item.tint.opacity(0.18) : item.tint.opacity(0.16)
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
        case .toggleAutoStartCoreOnLaunch:
            setToggleValue(!model.settings.autoStartCoreOnLaunch, for: action)
        case .toggleSetSystemProxyOnStart:
            setToggleValue(!model.settings.setSystemProxyOnStart, for: action)
        case .toggleEnableTunOnStart:
            setToggleValue(!model.settings.enableTunOnStart, for: action)
        case .toggleClearSystemProxyOnStop:
            setToggleValue(!model.settings.clearSystemProxyOnStop, for: action)
        case .toggleDisableTunOnQuit:
            setToggleValue(!model.settings.disableTunOnQuit, for: action)
        case .toggleAllowLAN:
            setToggleValue(!model.settings.allowLAN, for: action)
        case .toggleIPv6:
            setToggleValue(!model.settings.ipv6, for: action)
        case .toggleUnifiedDelay:
            setToggleValue(!model.settings.unifiedDelay, for: action)
        case .toggleDNS:
            setToggleValue(!model.settings.enableDNS, for: action)
        case .openDashboardURL:
            model.openDashboardURL()
        }
    }

    private func toggleValue(for action: DashboardItemAction) -> Bool? {
        switch action {
        case .toggleSystemProxy:
            return model.systemProxyEnabled
        case .toggleTun:
            return model.settings.enableTun
        case .toggleAutoStartCoreOnLaunch:
            return model.settings.autoStartCoreOnLaunch
        case .toggleSetSystemProxyOnStart:
            return model.settings.setSystemProxyOnStart
        case .toggleEnableTunOnStart:
            return model.settings.enableTunOnStart
        case .toggleClearSystemProxyOnStop:
            return model.settings.clearSystemProxyOnStop
        case .toggleDisableTunOnQuit:
            return model.settings.disableTunOnQuit
        case .toggleAllowLAN:
            return model.settings.allowLAN
        case .toggleIPv6:
            return model.settings.ipv6
        case .toggleUnifiedDelay:
            return model.settings.unifiedDelay
        case .toggleDNS:
            return model.settings.enableDNS
        default:
            return nil
        }
    }

    private func setToggleValue(_ isOn: Bool, for action: DashboardItemAction) {
        switch action {
        case .toggleSystemProxy:
            if model.systemProxyEnabled != isOn {
                model.toggleSystemProxy()
            }
        case .toggleTun:
            model.setTunEnabled(isOn)
        case .toggleAutoStartCoreOnLaunch:
            model.settings.autoStartCoreOnLaunch = isOn
            model.scheduleSettingsAutosave()
        case .toggleSetSystemProxyOnStart:
            model.settings.setSystemProxyOnStart = isOn
            model.scheduleSettingsAutosave()
        case .toggleEnableTunOnStart:
            model.settings.enableTunOnStart = isOn
            model.scheduleSettingsAutosave()
        case .toggleClearSystemProxyOnStop:
            model.settings.clearSystemProxyOnStop = isOn
            model.scheduleSettingsAutosave()
        case .toggleDisableTunOnQuit:
            model.settings.disableTunOnQuit = isOn
            model.scheduleSettingsAutosave()
        case .toggleAllowLAN:
            model.settings.allowLAN = isOn
            model.scheduleSettingsAutosave()
        case .toggleIPv6:
            model.settings.ipv6 = isOn
            model.scheduleSettingsAutosave()
        case .toggleUnifiedDelay:
            model.settings.unifiedDelay = isOn
            model.scheduleSettingsAutosave()
        case .toggleDNS:
            model.settings.enableDNS = isOn
            model.scheduleSettingsAutosave()
        default:
            break
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
        case .toggleAutoStartCoreOnLaunch:
            return "power.circle"
        case .toggleSetSystemProxyOnStart:
            return "checkmark.shield"
        case .toggleEnableTunOnStart:
            return "shield"
        case .toggleClearSystemProxyOnStop:
            return "shield.slash"
        case .toggleDisableTunOnQuit:
            return "rectangle.portrait.and.arrow.right"
        case .toggleAllowLAN:
            return "network.badge.shield.half.filled"
        case .toggleIPv6:
            return "6.circle"
        case .toggleUnifiedDelay:
            return "timer"
        case .toggleDNS:
            return "server.rack"
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
        case .summary:
            return .system(size: 18, weight: .semibold)
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
        case .summary:
            return 19
        case .diagnostic:
            return 17
        default:
            return 18
        }
    }

    private func iconFillOpacity(for style: DashboardItemStyle) -> Double {
        switch style {
        case .summary:
            return 0.10
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
        case .summary:
            return 64
        case .diagnostic:
            return 96
        case .command:
            return 54
        default:
            return 82
        }
    }
}

private struct CommandActionFlowLayout: Layout {
    var horizontalSpacing: CGFloat
    var verticalSpacing: CGFloat

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        let maxWidth = proposal.width ?? .greatestFiniteMagnitude
        let rows = rows(for: subviews, maxWidth: maxWidth)
        let width = rows.map(\.width).max() ?? 0
        let height = rows.enumerated().reduce(CGFloat.zero) { total, item in
            total + item.element.height + (item.offset == rows.count - 1 ? 0 : verticalSpacing)
        }
        return CGSize(width: width, height: height)
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            let needsWrap = x > bounds.minX && x + size.width > bounds.maxX
            if needsWrap {
                x = bounds.minX
                y += rowHeight + verticalSpacing
                rowHeight = 0
            }

            subview.place(
                at: CGPoint(x: x, y: y),
                proposal: ProposedViewSize(size)
            )
            x += size.width + horizontalSpacing
            rowHeight = max(rowHeight, size.height)
        }
    }

    private func rows(for subviews: Subviews, maxWidth: CGFloat) -> [(width: CGFloat, height: CGFloat)] {
        var rows: [(width: CGFloat, height: CGFloat)] = []
        var currentWidth: CGFloat = 0
        var currentHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            let nextWidth = currentWidth == 0
                ? size.width
                : currentWidth + horizontalSpacing + size.width
            if currentWidth > 0 && nextWidth > maxWidth {
                rows.append((currentWidth, currentHeight))
                currentWidth = size.width
                currentHeight = size.height
            } else {
                currentWidth = nextWidth
                currentHeight = max(currentHeight, size.height)
            }
        }

        if currentWidth > 0 {
            rows.append((currentWidth, currentHeight))
        }
        return rows
    }
}

private struct QuickActionConfigurationSheet: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss

    private var quickActions: [DashboardItem] {
        DashboardSectionRegistry.configurableQuickActions(for: model)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.blue)
                    .frame(width: 34, height: 34)
                    .background(
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .fill(Color.blue.opacity(0.10))
                    )

                VStack(alignment: .leading, spacing: 3) {
                    Text(model.t(.quickControlsConfiguration))
                        .font(.headline.weight(.semibold))
                    Text(model.t(.dashboardQuickActions))
                        .font(.caption)
                        .foregroundStyle(ChumenStyle.mutedText)
                }

                Spacer(minLength: 0)
            }
            .padding(16)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(quickActions) { item in
                        quickActionVisibilityToggle(item)
                    }
                }
                .padding(16)
            }

            Divider()

            HStack {
                Button {
                    model.settings.dashboardHiddenQuickActionIDs = ChumenRuntimeSettings.defaultDashboardHiddenQuickActionIDs
                    model.scheduleSettingsAutosave()
                } label: {
                    Label(model.t(.resetQuickControls), systemImage: "arrow.counterclockwise")
                }

                Spacer(minLength: 0)

                Button {
                    dismiss()
                } label: {
                    Label(model.t(.close), systemImage: "xmark")
                }
                .keyboardShortcut(.cancelAction)
            }
            .padding(16)
        }
        .frame(width: 500)
        .frame(minHeight: 420)
        .background(ChumenStyle.pageBackground)
    }

    private func quickActionVisibilityToggle(_ item: DashboardItem) -> some View {
        Toggle(isOn: quickActionVisibleBinding(item.id)) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(item.tint.opacity(0.10))
                    Image(systemName: item.systemImage)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(item.tint)
                }
                .frame(width: 34, height: 34)

                VStack(alignment: .leading, spacing: 4) {
                    Text(item.title)
                        .font(.callout.weight(.medium))
                    HStack(spacing: 6) {
                        Text(item.value)
                        if !item.detail.isEmpty {
                            Text("·")
                            Text(item.detail)
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(ChumenStyle.mutedText)
                    .lineLimit(1)
                    .truncationMode(.tail)
                }

                Spacer(minLength: 0)
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: ChumenStyle.radius, style: .continuous)
                    .fill(ChumenStyle.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: ChumenStyle.radius, style: .continuous)
                    .strokeBorder(ChumenStyle.border)
            )
        }
        .toggleStyle(.switch)
    }

    private func quickActionVisibleBinding(_ itemID: String) -> Binding<Bool> {
        Binding(
            get: {
                !model.settings.dashboardHiddenQuickActionIDs.contains(itemID)
            },
            set: { isVisible in
                var hiddenActionIDs = Set(model.settings.dashboardHiddenQuickActionIDs)
                if isVisible {
                    hiddenActionIDs.remove(itemID)
                } else {
                    hiddenActionIDs.insert(itemID)
                }
                model.settings.dashboardHiddenQuickActionIDs = hiddenActionIDs.sorted()
                model.scheduleSettingsAutosave()
            }
        )
    }
}
