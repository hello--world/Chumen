import AppKit
import ChumenCore
import SwiftUI

struct ProxiesView: View {
    @EnvironmentObject private var model: AppModel

    private enum Layout {
        static let rowSpacing: CGFloat = 12
        static let minNameColumnWidth: CGFloat = 180
        static let selectionColumnWidth: CGFloat = 320
        static let controlHeight: CGFloat = 34
        static let actionButtonWidth: CGFloat = 92
        static let identityHeight: CGFloat = 44
        static let rowMinHeight: CGFloat = 54
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Button {
                    Task { await model.refreshProxies() }
                } label: {
                    Label(model.t(.refreshProxies), systemImage: "arrow.triangle.2.circlepath")
                }
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
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(model.proxyGroups) { group in
                        proxyGroupRow(for: group)
                        if group.id != model.proxyGroups.last?.id {
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
        HStack(alignment: .center, spacing: Layout.rowSpacing) {
            proxyGroupIdentity(for: group)

            proxySelectionMenu(for: group)

            proxyActions(for: group)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity, minHeight: Layout.rowMinHeight, alignment: .leading)
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
                help: delayTitle(for: group.selected),
                disabled: group.selected.isEmpty
            ) {
                model.testDelay(name: group.selected)
            }

            proxyActionButton(
                title: model.t(.groupDelayTest),
                systemImage: "gauge.with.dots.needle.50percent",
                help: model.t(.groupDelayTest)
            ) {
                model.testGroupDelay(group)
            }

            proxyActionButton(
                title: model.t(.clear),
                systemImage: "pin.slash",
                help: model.t(.clear)
            ) {
                model.clearProxySelection(group)
            }
        }
        .fixedSize(horizontal: true, vertical: false)
    }

    private func proxyActionButton(
        title: String,
        systemImage: String,
        help: String,
        disabled: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: systemImage)
                    .font(.system(size: 14, weight: .semibold))
                Text(title)
                    .font(.callout.weight(.medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
            }
            .foregroundStyle(Color.primary)
            .frame(width: Layout.actionButtonWidth, height: Layout.controlHeight)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(ChumenStyle.controlFill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(ChumenStyle.border.opacity(0.55))
            )
            .opacity(disabled ? 0.45 : 1)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(help)
        .help(help)
        .disabled(disabled)
    }

    private func delayTitle(for name: String) -> String {
        guard let delay = model.proxyDelays[name] else {
            return model.t(.delayTest)
        }
        return "\(delay) ms"
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
        if button.itemArray.map(\.title) != displayOptions {
            button.removeAllItems()
            button.addItems(withTitles: displayOptions)
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

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            providerPanel(
                title: model.t(.proxyProviders),
                providers: model.proxyProviders,
                showHealthcheck: true,
                updateAction: model.updateProxyProvider,
                healthcheckAction: model.healthcheckProxyProvider
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            providerPanel(
                title: model.t(.ruleProviders),
                providers: model.ruleProviders,
                showHealthcheck: false,
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
        .toolbar {
            Button {
                Task { await model.refreshProviders() }
            } label: {
                Label(model.t(.refreshProviders), systemImage: "arrow.triangle.2.circlepath")
            }
        }
    }

    private func providerPanel(
        title: String,
        providers: [MihomoProvider],
        showHealthcheck: Bool,
        updateAction: @escaping (MihomoProvider) -> Void,
        healthcheckAction: @escaping (MihomoProvider) -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title)
                    .font(.headline)
                Spacer()
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
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(providers) { provider in
                            providerRow(
                                provider,
                                showHealthcheck: showHealthcheck,
                                updateAction: updateAction,
                                healthcheckAction: healthcheckAction
                            )
                            if provider.id != providers.last?.id {
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
                providerActionButton(title: model.t(.update), systemImage: "arrow.down.circle") {
                    updateAction(provider)
                }

                if showHealthcheck {
                    providerActionButton(title: model.t(.delayTest), systemImage: "speedometer") {
                        healthcheckAction(provider)
                    }
                }
            }
            .fixedSize(horizontal: true, vertical: false)
        }
        .frame(width: showHealthcheck ? 248 : 158, alignment: .trailing)
    }

    private func providerActionButton(title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: systemImage)
                    .font(.system(size: 14, weight: .semibold))
                Text(title)
                    .font(.callout.weight(.medium))
                    .lineLimit(1)
            }
            .foregroundStyle(Color.primary)
            .frame(width: 82, height: 34)
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
        .help(title)
    }
}
