import AppKit
import ChumenCore
import SwiftUI

struct ProxiesView: View {
    @EnvironmentObject private var model: AppModel
    let isVisible: Bool
    @State private var proxySelectionHelpGroupID: String?
    @State private var expandedProxyOptionsGroupID: String?

    private enum Layout {
        static let rowSpacing: CGFloat = 12
        static let minNameColumnWidth: CGFloat = 180
        static let selectionColumnWidth: CGFloat = 320
        static let controlHeight: CGFloat = 34
        static let actionButtonWidth: CGFloat = 92
        static let helpButtonWidth: CGFloat = 30
        static let identityHeight: CGFloat = 44
        static let rowMinHeight: CGFloat = 54
    }

    var body: some View {
        Group {
            if isVisible {
                content
            } else {
                ChumenStyle.pageBackground
            }
        }
        .background(ChumenStyle.pageBackground)
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Button {
                    Task { await model.refreshProxies() }
                } label: {
                    Label(model.t(.refreshProxies), systemImage: "arrow.triangle.2.circlepath")
                }
                .buttonStyle(.bordered)
                .tint(ChumenActionTone.refresh.color)
                Spacer()
                Text("\(model.proxyGroups.count) \(model.t(.groups))")
                    .foregroundStyle(.secondary)
            }

            proxyGroupList
        }
        .padding(18)
        .task {
            if model.proxyGroups.isEmpty {
                await model.refreshProxies()
            }
        }
    }

    @ViewBuilder
    private var proxyGroupList: some View {
        if model.proxyGroups.isEmpty {
            VStack(spacing: 8) {
                Image(systemName: "point.3.connected.trianglepath.dotted")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(ChumenStyle.mutedText)
                Text(model.t(.proxies))
                    .font(.headline)
                Text(model.t(.refreshProxies))
                    .font(.caption)
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
        } else {
            let lastGroupID = model.proxyGroups.last?.id
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(model.proxyGroups) { group in
                        proxyGroupRow(for: group)
                        if group.id != lastGroupID {
                            Divider()
                                .padding(.leading, 12)
                        }
                    }
                }
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
    }

    private func proxyGroupRow(for group: ProxyGroupSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center, spacing: Layout.rowSpacing) {
                Button {
                    let isOpening = expandedProxyOptionsGroupID != group.id
                    expandedProxyOptionsGroupID = isOpening ? group.id : nil
                    if isOpening {
                        model.testDelays(in: group)
                    }
                } label: {
                    proxyGroupIdentity(for: group)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(group.name)

                proxySelectionMenu(for: group)

                proxyActions(for: group)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .frame(maxWidth: .infinity, minHeight: Layout.rowMinHeight, alignment: .leading)

            if expandedProxyOptionsGroupID == group.id {
                Divider()
                    .padding(.horizontal, 12)

                proxyOptionGrid(for: group)
            }
        }
    }

    // This is additive to the existing group controls: node selection and delay testing stay
    // independent so testing a node never changes the active proxy accidentally.
    private func proxyOptionGrid(for group: ProxyGroupSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "chevron.down.circle.fill")
                    .foregroundStyle(ChumenActionTone.refresh.color)
                Text(model.t(.node))
                    .font(.caption.weight(.semibold))
                Text("\(group.options.count)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(ChumenStyle.mutedText)
                Spacer()
            }

            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(minimum: 0), spacing: 10), count: 3),
                spacing: 10
            ) {
                ForEach(group.options, id: \.self) { option in
                    proxyOptionCard(option, in: group)
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: ChumenStyle.radius, style: .continuous)
                .fill(ChumenActionTone.refresh.color.opacity(0.045))
        )
        .overlay(
            RoundedRectangle(cornerRadius: ChumenStyle.radius, style: .continuous)
                .strokeBorder(ChumenActionTone.refresh.color.opacity(0.20))
        )
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private func proxyOptionCard(_ option: String, in group: ProxyGroupSnapshot) -> some View {
        let isSelected = group.selected == option

        return HStack(spacing: 0) {
            proxyOptionSelectionButton(option, in: group, isSelected: isSelected)
            proxyOptionDelayButton(option, in: group)
        }
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(isSelected ? ChumenActionTone.refresh.color.opacity(0.10) : ChumenStyle.identityFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .strokeBorder(isSelected ? ChumenActionTone.refresh.color.opacity(0.28) : ChumenStyle.border.opacity(0.40))
        )
    }

    private func proxyOptionSelectionButton(
        _ option: String,
        in group: ProxyGroupSnapshot,
        isSelected: Bool
    ) -> some View {
        Button {
            model.selectProxy(group: group, name: option)
        } label: {
            HStack(spacing: 8) {
                Text(option)
                    .font(.callout.weight(.medium))
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer(minLength: 0)
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(ChumenActionTone.refresh.color)
                }
            }
            .padding(.leading, 12)
            .padding(.trailing, 8)
            .frame(maxWidth: .infinity, minHeight: 54, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(option)
    }

    private func proxyOptionDelayButton(_ option: String, in group: ProxyGroupSnapshot) -> some View {
        let state = model.proxyDelayState(for: option, in: group)
        let help = delayTitle(for: option, in: group)

        return Button {
            model.testDelay(name: option, in: group)
        } label: {
            proxyDelayLabel(for: state)
                .frame(width: 62, height: 54)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(help)
        .accessibilityLabel(help)
        .disabled(state == .testing)
    }

    private func proxyGroupIdentity(for group: ProxyGroupSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(group.name)
                .font(.headline)
                .lineLimit(1)
                .truncationMode(.middle)
            Text(group.type)
                .font(.caption)
                .foregroundStyle(ChumenStyle.mutedText)
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .frame(
            minWidth: Layout.minNameColumnWidth,
            maxWidth: .infinity,
            minHeight: Layout.identityHeight,
            alignment: .leading
        )
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(ChumenStyle.identityFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .strokeBorder(ChumenStyle.border.opacity(0.40))
        )
    }

    private func proxySelectionMenu(for group: ProxyGroupSnapshot) -> some View {
        ProxySelectionPopUpButton(
            options: group.options,
            selected: group.selected
        ) { option in
            model.selectProxy(group: group, name: option)
        }
        .frame(width: Layout.selectionColumnWidth, height: Layout.controlHeight)
        .disabled(group.options.isEmpty)
    }

    private func proxyActions(for group: ProxyGroupSnapshot) -> some View {
        HStack(spacing: 8) {
            proxyActionButton(
                title: model.t(.delayTest),
                systemImage: "speedometer",
                tone: .test,
                help: delayTitle(for: group.selected, in: group),
                disabled: group.selected.isEmpty
            ) {
                model.testDelay(name: group.selected, in: group)
            }

            proxyActionButton(
                title: model.t(.groupDelayTest),
                systemImage: "gauge.with.dots.needle.50percent",
                tone: .test,
                help: model.t(.groupDelayTest)
            ) {
                model.testGroupDelay(group)
            }

            proxyActionButton(
                title: model.t(.clearProxySelectionAction),
                systemImage: "pin.slash",
                tone: .clear,
                help: model.t(.clearProxySelectionHelpTitle)
            ) {
                model.clearProxySelection(group)
            }

            proxySelectionHelpButton(for: group)
        }
        .fixedSize(horizontal: true, vertical: false)
    }

    private func proxySelectionHelpButton(for group: ProxyGroupSnapshot) -> some View {
        Button {
            proxySelectionHelpGroupID = group.id
        } label: {
                Image(systemName: "exclamationmark.circle")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(ChumenActionTone.help.color)
                    .frame(width: Layout.helpButtonWidth, height: Layout.controlHeight)
                    .chumenActionSurface(.help)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(model.t(.clearProxySelectionHelpTitle))
        .help(model.t(.clearProxySelectionHelpTitle))
        .popover(
            isPresented: Binding(
                get: { proxySelectionHelpGroupID == group.id },
                set: { isPresented in
                    if !isPresented {
                        proxySelectionHelpGroupID = nil
                    }
                }
            ),
            arrowEdge: .top
        ) {
            VStack(alignment: .leading, spacing: 8) {
                Text(model.t(.clearProxySelectionHelpTitle))
                    .font(.headline)
                Text(model.t(.clearProxySelectionHelpBody))
                    .font(.callout)
                    .foregroundStyle(ChumenStyle.mutedText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(width: 280, alignment: .leading)
            .padding(14)
        }
    }

    private func proxyActionButton(
        title: String,
        systemImage: String,
        tone: ChumenActionTone,
        help: String,
        disabled: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: systemImage)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(tone.color)
                Text(title)
                    .font(.callout.weight(.medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
            }
            .frame(width: Layout.actionButtonWidth, height: Layout.controlHeight)
            .chumenActionSurface(tone)
            .opacity(disabled ? 0.45 : 1)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(help)
        .help(help)
        .disabled(disabled)
    }

    @ViewBuilder
    private func proxyDelayLabel(for state: ProxyDelayTestState) -> some View {
        switch state {
        case .idle:
            Text(model.t(.delayTest))
                .font(.callout.weight(.medium))
                .foregroundStyle(ChumenActionTone.test.color)
        case .testing:
            ProgressView()
                .controlSize(.small)
        case let .completed(.value(delay)):
            Text("\(delay)")
                .font(.callout.weight(.medium))
                .foregroundStyle(delayColor(for: delay))
        case .completed(.timedOut):
            Text("—")
                .font(.callout.weight(.medium))
                .foregroundStyle(ChumenActionTone.clear.color)
        case .completed(.failed):
            Text(model.t(.failed))
                .font(.callout.weight(.medium))
                .foregroundStyle(ChumenActionTone.destructive.color)
        }
    }

    private func delayTitle(for name: String, in group: ProxyGroupSnapshot) -> String {
        switch model.proxyDelayState(for: name, in: group) {
        case .idle, .testing:
            model.t(.delayTest)
        case let .completed(.value(delay)):
            "\(delay) ms"
        case .completed(.timedOut):
            "—"
        case .completed(.failed):
            model.t(.failed)
        }
    }

    private func delayColor(for delay: Int) -> Color {
        switch delay {
        case ..<250:
            .green
        case ..<400:
            ChumenActionTone.refresh.color
        default:
            ChumenActionTone.clear.color
        }
    }
}
private struct ProxySelectionPopUpButton: NSViewRepresentable {
    let options: [String]
    let selected: String
    let onSelect: (String) -> Void

    func makeNSView(context: Context) -> NSPopUpButton {
        let button = NSPopUpButton(frame: .zero, pullsDown: false)
        button.bezelStyle = .rounded
        button.controlSize = .large
        button.font = NSFont.systemFont(ofSize: NSFont.systemFontSize, weight: .medium)
        button.target = context.coordinator
        button.action = #selector(Coordinator.selectionChanged(_:))
        button.setContentHuggingPriority(.defaultLow, for: .horizontal)
        button.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return button
    }

    func updateNSView(_ button: NSPopUpButton, context: Context) {
        context.coordinator.parent = self

        let displayOptions = normalizedOptions
        if context.coordinator.displayOptions != displayOptions {
            button.removeAllItems()
            button.addItems(withTitles: displayOptions)
            context.coordinator.displayOptions = displayOptions
        }

        button.isEnabled = !options.isEmpty
        if let selectedIndex = displayOptions.firstIndex(of: selected) {
            button.selectItem(at: selectedIndex)
        } else {
            button.selectItem(at: 0)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    private var normalizedOptions: [String] {
        if options.isEmpty {
            return [selected.isEmpty ? "-" : selected]
        }
        if selected.isEmpty || options.contains(selected) {
            return options
        }
        return [selected] + options
    }

    final class Coordinator: NSObject {
        var parent: ProxySelectionPopUpButton
        var displayOptions: [String] = []

        init(parent: ProxySelectionPopUpButton) {
            self.parent = parent
        }

        @MainActor @objc func selectionChanged(_ sender: NSPopUpButton) {
            guard let title = sender.selectedItem?.title, title != "-" else { return }
            parent.onSelect(title)
        }
    }
}

struct ProvidersView: View {
    @EnvironmentObject private var model: AppModel
    let isVisible: Bool

    var body: some View {
        Group {
            if isVisible {
                content
            } else {
                ChumenStyle.pageBackground
            }
        }
        .background(ChumenStyle.pageBackground)
    }

    private var content: some View {
        HStack(alignment: .top, spacing: 14) {
            providerPanel(
                title: model.t(.proxyProviders),
                providers: model.proxyProviders,
                showHealthcheck: true,
                showsRefreshControl: true,
                updateAction: model.updateProxyProvider,
                healthcheckAction: model.healthcheckProxyProvider
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            providerPanel(
                title: model.t(.ruleProviders),
                providers: model.ruleProviders,
                showHealthcheck: false,
                showsRefreshControl: false,
                updateAction: model.updateRuleProvider,
                healthcheckAction: { _ in }
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(18)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .task {
            if model.proxyProviders.isEmpty && model.ruleProviders.isEmpty {
                await model.refreshProviders()
            }
        }
    }

    private func providerPanel(
        title: String,
        providers: [MihomoProvider],
        showHealthcheck: Bool,
        showsRefreshControl: Bool,
        updateAction: @escaping (MihomoProvider) -> Void,
        healthcheckAction: @escaping (MihomoProvider) -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title)
                    .font(.headline)
                Spacer()
                if showsRefreshControl {
                    Button {
                        Task { await model.refreshProviders() }
                    } label: {
                        Label(model.t(.refresh), systemImage: "arrow.triangle.2.circlepath")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .tint(ChumenActionTone.refresh.color)
                    .help(model.t(.refreshProviders))
                }
                Text("\(providers.count)")
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.top, 12)

            if providers.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "tray")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(ChumenStyle.mutedText)
                    Text("0")
                        .font(.headline)
                        .foregroundStyle(ChumenStyle.mutedText)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(18)
            } else {
                let lastProviderID = providers.last?.id
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(providers) { provider in
                            providerRow(
                                provider,
                                showHealthcheck: showHealthcheck,
                                updateAction: updateAction,
                                healthcheckAction: healthcheckAction
                            )
                            if provider.id != lastProviderID {
                                Divider()
                                    .padding(.leading, 12)
                            }
                        }
                    }
                    .padding(.trailing, 18)
                }
                .padding(.bottom, 8)
            }
        }
        .frame(minWidth: 360, maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: ChumenStyle.radius, style: .continuous)
                .fill(ChumenStyle.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: ChumenStyle.radius, style: .continuous)
                .strokeBorder(ChumenStyle.border)
        )
    }

    private func providerRow(
        _ provider: MihomoProvider,
        showHealthcheck: Bool,
        updateAction: @escaping (MihomoProvider) -> Void,
        healthcheckAction: @escaping (MihomoProvider) -> Void
    ) -> some View {
        HStack(alignment: .center, spacing: 12) {
            providerIdentity(provider)
                .layoutPriority(0)

            providerTrailingControls(
                provider,
                showHealthcheck: showHealthcheck,
                updateAction: updateAction,
                healthcheckAction: healthcheckAction
            )
            .layoutPriority(1)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity, minHeight: 54, alignment: .leading)
    }

    private func providerIdentity(_ provider: MihomoProvider) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(provider.name)
                .font(.headline)
                .lineLimit(1)
                .truncationMode(.middle)
            Text([provider.type, provider.vehicleType, provider.behavior].compactMap { $0 }.joined(separator: " / "))
                .font(.caption)
                .foregroundStyle(ChumenStyle.mutedText)
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .frame(minWidth: 140, maxWidth: .infinity, minHeight: 44, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(ChumenStyle.identityFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .strokeBorder(ChumenStyle.border.opacity(0.40))
        )
    }

    private func providerTrailingControls(
        _ provider: MihomoProvider,
        showHealthcheck: Bool,
        updateAction: @escaping (MihomoProvider) -> Void,
        healthcheckAction: @escaping (MihomoProvider) -> Void
    ) -> some View {
        HStack(spacing: 12) {
            Text("\(provider.proxies?.count ?? 0) \(model.t(.providerItems))")
                .font(.caption.weight(.medium))
                .foregroundStyle(ChumenStyle.mutedText)
                .frame(width: 64, alignment: .trailing)

            HStack(spacing: 8) {
                providerActionButton(title: model.t(.update), systemImage: "arrow.down.circle", tone: .update) {
                    updateAction(provider)
                }

                if showHealthcheck {
                    providerActionButton(title: model.t(.delayTest), systemImage: "speedometer", tone: .test) {
                        healthcheckAction(provider)
                    }
                }
            }
            .fixedSize(horizontal: true, vertical: false)
        }
        .frame(width: showHealthcheck ? 248 : 158, alignment: .trailing)
    }

    private func providerActionButton(
        title: String,
        systemImage: String,
        tone: ChumenActionTone,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: systemImage)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(tone.color)
                Text(title)
                    .font(.callout.weight(.medium))
                    .lineLimit(1)
            }
            .frame(width: 82, height: 34)
            .chumenActionSurface(tone)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(title)
    }
}
