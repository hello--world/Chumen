import ChumenCore
import SwiftUI

struct DashboardView: View {
    @EnvironmentObject private var model: AppModel
    @Binding var selectedTab: AppTab
    @Binding var aiAssistantPresented: Bool
    let aiSearchResults: [GlobalSearchResult]
    let aiMarkdownCache: AIAssistantMarkdownCache
    let onAISearchChanged: () -> Void
    let onAISearchImmediately: () -> Void
    let onAIClearSearchResults: () -> Void
    let onAISubmit: () -> Void
    let onAISelectSearchResult: (GlobalSearchResult) -> Void

    @State private var quickActionConfigurationPresented = false

    var body: some View {
        GeometryReader { proxy in
            VStack(alignment: .leading, spacing: 12) {
                commandPanel
                dashboardAssistantWorkspace
                    .layoutPriority(1)
            }
            .padding(.horizontal, 18)
            .padding(.top, 14)
            .padding(.bottom, 14)
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .topLeading)
        }
        .background(ChumenStyle.pageBackground)
    }

    // The overview is now agent-first: quick controls stay on top, while the lower half is a single
    // assistant workspace. Runtime, traffic, and log facts are already injected into the AI prompt by
    // AppModel, so repeating them as large dashboard cards just creates noise and competes with chat.
    private var dashboardAssistantWorkspace: some View {
        assistantWorkbench
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var assistantWorkbench: some View {
        Group {
            if aiAssistantPresented {
                AIAssistantOverlayView(
                    isPresented: $aiAssistantPresented,
                    searchResults: aiSearchResults,
                    markdownCache: aiMarkdownCache,
                    onSearchChanged: onAISearchChanged,
                    onSearchImmediately: onAISearchImmediately,
                    onClearSearchResults: onAIClearSearchResults,
                    onSubmit: onAISubmit,
                    onSelectSearchResult: onAISelectSearchResult
                )
            } else {
                assistantClosedPlaceholder
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ChumenStyle.surface)
        .clipShape(RoundedRectangle(cornerRadius: ChumenStyle.radius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: ChumenStyle.radius, style: .continuous)
                .strokeBorder(ChumenStyle.border)
        )
    }

    private var assistantClosedPlaceholder: some View {
        VStack(spacing: 14) {
            Image(systemName: "sparkles")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(Color.accentColor)
                .frame(width: 54, height: 54)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.accentColor.opacity(0.10))
                )

            Text(model.t(.aiAssistant))
                .font(.title3.weight(.semibold))
            Text(model.t(.aiNoMessages))
                .font(.callout)
                .foregroundStyle(ChumenStyle.mutedText)
                .multilineTextAlignment(.center)

            Button {
                aiAssistantPresented = true
                if !model.aiReady {
                    onAISearchImmediately()
                }
            } label: {
                Label(model.t(.aiOpenAssistant), systemImage: "sparkles")
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var commandPanel: some View {
        let items = commandBarItems

        return commandPanelBody(items: items)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 6)
        .padding(.vertical, 10)
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

    // Keep the command header as one left-anchored row. Widths are intentionally bounded so the
    // overview does not split the mode switch and quick actions into separate rows.
    private func commandPanelBody(items: [DashboardItem]) -> some View {
        let statusItems = commandStatusItems(in: items)
        let actionItems = commandActionItems(in: items)
        let pinnedActionItems = commandPinnedActionItems(in: actionItems)

        return HStack(alignment: .center, spacing: 5) {
            commandPanelStatusForToolbar(item: statusItems.first)

            if !pinnedActionItems.isEmpty {
                Color.clear
                    .frame(width: commandStatusActionGap)
                    .accessibilityHidden(true)

                commandPinnedActionRow(items: pinnedActionItems)
                    .layoutPriority(5)
            }

            Color.clear
                .frame(width: commandActionsModeGap)
                .accessibilityHidden(true)

            modeControl
                .layoutPriority(1)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var commandToolbarStatusWidth: CGFloat {
        252
    }

    private var commandStatusActionGap: CGFloat {
        8
    }

    private var commandActionsModeGap: CGFloat {
        8
    }

    @ViewBuilder
    private func commandPanelStatusForToolbar(item: DashboardItem?) -> some View {
        if let item {
            commandToolbarStatusContent(item)
                .layoutPriority(10)
                .help(quickActionHelp(item))
        }
    }

    // The command panel header needs a compact but informative status summary. Keep it as a passive
    // view instead of a Button: macOS button labels can reserve extra hit-test/layout space even with
    // a plain style, which was the hidden source of the large gap before the Start button.
    private func commandToolbarStatusContent(_ item: DashboardItem) -> some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: ChumenStyle.radius, style: .continuous)
                    .fill(item.tint.opacity(0.10))
                Image(systemName: item.systemImage)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(item.tint)
            }
            .frame(width: 34, height: 34)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Text(item.title)
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)

                    Text(item.value)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(item.tint)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(
                            Capsule(style: .continuous)
                                .fill(item.tint.opacity(0.10))
                        )
                        .lineLimit(1)
                }

                Text(item.detail)
                    .font(.caption)
                    .foregroundStyle(ChumenStyle.mutedText)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
        }
        .frame(
            width: commandToolbarStatusWidth,
            alignment: .leading
        )
        .clipped()
        .contentShape(Rectangle())
    }

    private var commandBarItems: [DashboardItem] {
        DashboardSectionRegistry.sections(for: model, placement: .commandBar)
            .flatMap(\.items)
    }

    private func commandStatusItems(in items: [DashboardItem]) -> [DashboardItem] {
        items.filter { item in
            if case .summary = item.style {
                return true
            }
            return false
        }
    }

    private func commandActionItems(in items: [DashboardItem]) -> [DashboardItem] {
        items.filter { item in
            if case .command = item.style {
                return true
            }
            return false
        }
    }

    private var modeControl: some View {
        HStack(spacing: 5) {
            Text(model.t(.mode))
                .font(.caption.weight(.semibold))
                .foregroundStyle(ChumenStyle.mutedText)
            dashboardModePicker
                .frame(width: 112)
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
                        .font(.caption.weight(.semibold))
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
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.64)
                .padding(.horizontal, 6)
                .frame(width: 88, height: 30)
                .background(
                    RoundedRectangle(cornerRadius: ChumenStyle.radius, style: .continuous)
                        .fill(ChumenStyle.controlFill)
                )
        }
        .buttonStyle(.plain)
        .help(model.t(.quickControlsConfiguration))
    }

    private func commandPinnedActionRow(items: [DashboardItem]) -> some View {
        HStack(spacing: 5) {
            ForEach(items) { item in
                quickActionButton(item)
            }
            dashboardEditButton
        }
        .fixedSize(horizontal: true, vertical: false)
        .controlSize(.regular)
    }

    // The command bar has a fixed core row and an extension row. Start/stop/restart/refresh,
    // system proxy, TUN, and quick-control editing are muscle-memory operations and should stay
    // together; optional startup/network preferences belong below so enabling more shortcuts does
    // not disrupt the primary controls.
    private func commandExtensionActionFlow(items: [DashboardItem]) -> some View {
        CommandActionFlowLayout(horizontalSpacing: 8, verticalSpacing: 8) {
            ForEach(items) { item in
                quickActionButton(item)
            }
        }
        .controlSize(.regular)
    }

    private func commandPinnedActionItems(in items: [DashboardItem]) -> [DashboardItem] {
        items.filter { item in
            pinnedCommandActionIDs.contains(item.id)
        }
    }

    private func commandExtensionActionItems(in items: [DashboardItem]) -> [DashboardItem] {
        items.filter { item in
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
            .font(.caption.weight(.semibold))
            .foregroundStyle(quickActionForeground(for: item))
            .lineLimit(1)
            .minimumScaleFactor(0.64)
            .padding(.horizontal, 6)
            .frame(width: quickActionWidth(for: item), height: 30)
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
        HStack(spacing: 5) {
            Image(systemName: item.systemImage)
                .font(.caption.weight(.semibold))
                .frame(width: 14)
            Text(item.title)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.64)
            switchGlyph(isOn: isOn, tint: item.tint)
        }
        .foregroundStyle(quickActionForeground(for: item))
        .padding(.horizontal, 6)
        .frame(width: quickActionWidth(for: item), height: 30)
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
            .frame(width: 22, height: 12)
            .overlay(alignment: isOn ? .trailing : .leading) {
                Circle()
                    .fill(Color.white)
                    .frame(width: 8, height: 8)
                    .padding(2)
            }
    }

    private func quickActionWidth(for item: DashboardItem) -> CGFloat {
        switch item.id {
        case "actions.start":
            return 56
        case "actions.stop":
            return 60
        case "actions.restart":
            return 66
        case "actions.refresh":
            return 70
        case "actions.system-proxy":
            return 98
        case "actions.tun":
            return 90
        default:
            return 88
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
