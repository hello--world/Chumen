import ChumenCore
import SwiftUI

// Dashboard providers are the extension point for high-signal homepage content. Feature areas
// should publish concise state, diagnostics, and navigation links here instead of hardcoding module
// cards inside DashboardView.
@MainActor
protocol DashboardSectionProvider: Sendable {
    var priority: Int { get }
    var placement: DashboardSectionPlacement { get }
    func dashboardSection(for model: AppModel) -> DashboardSection?
}

extension DashboardSectionProvider {
    var placement: DashboardSectionPlacement { .mainGrid }
}

enum DashboardItemStyle {
    case summary
    case command
    case state
    case metric
    case diagnostic
    case link
}

enum DashboardItemAction {
    case none
    case openTab(AppTab)
    case refreshAll
    case startCore
    case stopCore
    case restartCore
    case toggleSystemProxy
    case toggleTun
    case toggleAutoStartCoreOnLaunch
    case toggleSetSystemProxyOnStart
    case toggleEnableTunOnStart
    case toggleClearSystemProxyOnStop
    case toggleDisableTunOnQuit
    case toggleAllowLAN
    case toggleIPv6
    case toggleUnifiedDelay
    case toggleDNS
    case openDashboardURL
}

struct DashboardItem: Identifiable {
    let id: String
    let title: String
    let value: String
    let detail: String
    let systemImage: String
    let tint: Color
    let style: DashboardItemStyle
    let priority: Int
    let action: DashboardItemAction
    let isEnabled: Bool

    init(
        id: String,
        title: String,
        value: String,
        detail: String = "",
        systemImage: String,
        tint: Color,
        style: DashboardItemStyle = .metric,
        priority: Int,
        action: DashboardItemAction = .none,
        isEnabled: Bool = true
    ) {
        self.id = id
        self.title = title
        self.value = value
        self.detail = detail
        self.systemImage = systemImage
        self.tint = tint
        self.style = style
        self.priority = priority
        self.action = action
        self.isEnabled = isEnabled
    }
}

enum DashboardSectionPlacement {
    case commandBar
    case mainGrid
}

struct DashboardSectionConfiguration {
    let placement: DashboardSectionPlacement
    let maxVisibleItems: Int?
    let isVisible: Bool
    let isUserConfigurable: Bool

    static let mainGrid = DashboardSectionConfiguration(placement: .mainGrid)
    static let commandBar = DashboardSectionConfiguration(placement: .commandBar)

    init(
        placement: DashboardSectionPlacement,
        maxVisibleItems: Int? = nil,
        isVisible: Bool = true,
        isUserConfigurable: Bool = true
    ) {
        self.placement = placement
        self.maxVisibleItems = maxVisibleItems
        self.isVisible = isVisible
        self.isUserConfigurable = isUserConfigurable
    }
}

struct DashboardSection: Identifiable {
    let id: String
    let title: String
    let detail: String
    let priority: Int
    let configuration: DashboardSectionConfiguration
    var items: [DashboardItem]

    init(
        id: String,
        title: String,
        detail: String,
        priority: Int,
        configuration: DashboardSectionConfiguration = .mainGrid,
        items: [DashboardItem]
    ) {
        self.id = id
        self.title = title
        self.detail = detail
        self.priority = priority
        self.configuration = configuration
        self.items = items
    }
}

enum DashboardSectionRegistry {
    @MainActor
    private static let providers: [any DashboardSectionProvider] = [
        CommandStatusDashboardProvider(),
        QuickActionsDashboardProvider(),
        RuntimeDashboardProvider(),
        TrafficDashboardProvider(),
        DiagnosticsDashboardProvider()
    ]

    @MainActor
    static func sections(for model: AppModel) -> [DashboardSection] {
        sections(for: model, placement: .mainGrid)
    }

    @MainActor
    static func sections(for model: AppModel, placement: DashboardSectionPlacement) -> [DashboardSection] {
        let hiddenSectionIDs = Set(model.settings.dashboardHiddenSectionIDs)
        return allSections(for: model, placement: placement)
            .filter { section in
                section.configuration.isVisible &&
                    section.configuration.placement == placement &&
                    !hiddenSectionIDs.contains(section.id)
            }
    }

    @MainActor
    static func configurableSections(for model: AppModel) -> [DashboardSection] {
        allSections(for: model)
            .filter { section in
                section.configuration.isVisible && section.configuration.isUserConfigurable
            }
    }

    @MainActor
    static func configurableQuickActions(for model: AppModel) -> [DashboardItem] {
        QuickActionsDashboardProvider.items(for: model)
            .sorted { lhs, rhs in
                lhs.priority == rhs.priority ? lhs.id < rhs.id : lhs.priority < rhs.priority
            }
    }

    @MainActor
    private static func allSections(
        for model: AppModel,
        placement: DashboardSectionPlacement? = nil
    ) -> [DashboardSection] {
        providers
            .filter { provider in
                guard let placement else { return true }
                return provider.placement == placement
            }
            .compactMap { provider in
                provider.dashboardSection(for: model)
            }
            .map { section in
                DashboardSection(
                    id: section.id,
                    title: section.title,
                    detail: section.detail,
                    priority: section.priority,
                    configuration: section.configuration,
                    items: section.items.sorted { lhs, rhs in
                        lhs.priority == rhs.priority ? lhs.id < rhs.id : lhs.priority < rhs.priority
                    }.limited(to: section.configuration.maxVisibleItems)
                )
            }
            .sorted { lhs, rhs in
                lhs.priority == rhs.priority ? lhs.id < rhs.id : lhs.priority < rhs.priority
            }
    }
}

enum DashboardStateFormatting {
    @MainActor
    static func tunStateText(for model: AppModel) -> String {
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

    @MainActor
    static func tunTint(for model: AppModel) -> Color {
        if model.settings.enableTun && model.tunRuntimeFailed {
            return .orange
        }
        return model.settings.enableTun ? .green : ChumenStyle.mutedText
    }

    @MainActor
    static func commandStatus(for model: AppModel) -> DashboardItem {
        DashboardItem(
            id: "command.status",
            title: commandTitle(for: model),
            value: commandBadge(for: model),
            detail: commandSubtitle(for: model),
            systemImage: commandIcon(for: model),
            tint: commandTint(for: model),
            style: .summary,
            priority: 0,
            action: commandAction(for: model),
            isEnabled: !model.isCoreTransitioning
        )
    }

    @MainActor
    static func apiStateText(for model: AppModel) -> String {
        if isAPIUnavailable(for: model) {
            return model.t(.controllerUnavailable)
        }
        if isAPINotTested(for: model) {
            return model.t(.pending)
        }

        let text = normalizedAPIText(for: model)
        let primary = text.components(separatedBy: " / ").first ?? text
        if primary.hasPrefix("mihomo ") {
            return String(primary.dropFirst("mihomo ".count))
        }
        return primary.isEmpty ? "-" : primary
    }

    @MainActor
    static func apiStateDetail(for model: AppModel) -> String {
        if isAPIUnavailable(for: model) {
            return "\(model.t(.apiUnavailableHint)) \(controllerAddress(for: model))"
        }
        if isAPINotTested(for: model) {
            return model.t(.apiNotTestedHint)
        }
        return normalizedAPIText(for: model)
    }

    @MainActor
    static func apiStateTint(for model: AppModel) -> Color {
        if isAPIUnavailable(for: model) {
            return .orange
        }
        if isAPINotTested(for: model) {
            return .blue
        }
        return .blue
    }

    @MainActor
    private static func commandTitle(for model: AppModel) -> String {
        if !model.isRunning {
            return model.t(.coreNotRunning)
        }
        if isAPIUnavailable(for: model) {
            return model.t(.apiUnavailable)
        }
        if isAPINotTested(for: model) {
            return model.t(.running)
        }
        return model.t(.apiConnected)
    }

    @MainActor
    private static func commandSubtitle(for model: AppModel) -> String {
        if !model.isRunning {
            let failure = commandFailureText(for: model)
            if !failure.isEmpty {
                return failure
            }
            return "\(model.t(.coreNotRunningHint)) \(model.t(.activeProfile)): \(model.activeProfile?.name ?? "-")"
        }
        if isAPIUnavailable(for: model) {
            return "\(model.t(.apiUnavailableHint)) \(controllerAddress(for: model))"
        }
        if isAPINotTested(for: model) {
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

    @MainActor
    private static func commandFailureText(for model: AppModel) -> String {
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

    @MainActor
    private static func commandBadge(for model: AppModel) -> String {
        if !model.isRunning {
            return model.t(.actionStartCore)
        }
        if isAPIUnavailable(for: model) {
            return model.t(.actionCheckAPI)
        }
        if isAPINotTested(for: model) {
            return model.t(.pending)
        }
        return model.t(.ready)
    }

    @MainActor
    private static func commandIcon(for model: AppModel) -> String {
        if !model.isRunning {
            return "power"
        }
        if isAPIUnavailable(for: model) {
            return "exclamationmark.triangle.fill"
        }
        if isAPINotTested(for: model) {
            return "clock"
        }
        return "checkmark.circle.fill"
    }

    @MainActor
    private static func commandTint(for model: AppModel) -> Color {
        if !model.isRunning {
            return ChumenStyle.mutedText
        }
        if isAPIUnavailable(for: model) {
            return .orange
        }
        if isAPINotTested(for: model) {
            return .blue
        }
        return .green
    }

    @MainActor
    private static func commandAction(for model: AppModel) -> DashboardItemAction {
        if !model.isRunning {
            return .startCore
        }
        if isAPIUnavailable(for: model) {
            return .refreshAll
        }
        return .none
    }

    @MainActor
    private static func isAPINotTested(for model: AppModel) -> Bool {
        let status = normalizedAPIText(for: model)
        return status.isEmpty
            || status == model.t(.apiNotTested)
            || status == L10n.text(.apiNotTested, language: .en)
    }

    @MainActor
    private static func isAPIUnavailable(for model: AppModel) -> Bool {
        let status = normalizedAPIText(for: model)
        let lowercased = status.lowercased()
        return status == model.t(.controllerUnavailable)
            || status == L10n.text(.controllerUnavailable, language: .en)
            || lowercased.contains("could not connect")
            || lowercased.contains("cannot connect")
            || lowercased.contains("connection refused")
    }

    @MainActor
    private static func normalizedAPIText(for model: AppModel) -> String {
        model.apiText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    @MainActor
    private static func controllerAddress(for model: AppModel) -> String {
        "\(model.settings.externalControllerHost):\(model.settings.externalControllerPort)"
    }
}

private extension Array {
    func limited(to maxCount: Int?) -> [Element] {
        guard let maxCount else { return self }
        return Array(prefix(Swift.max(0, maxCount)))
    }
}

private struct CommandStatusDashboardProvider: DashboardSectionProvider {
    let priority = 0
    let placement: DashboardSectionPlacement = .commandBar

    func dashboardSection(for model: AppModel) -> DashboardSection? {
        DashboardSection(
            id: "command-status",
            title: model.t(.dashboardCommandStatus),
            detail: model.t(.apiConnectedHint),
            priority: priority,
            configuration: .commandBar,
            items: [DashboardStateFormatting.commandStatus(for: model)]
        )
    }
}

private struct QuickActionsDashboardProvider: DashboardSectionProvider {
    let priority = 5
    let placement: DashboardSectionPlacement = .commandBar

    func dashboardSection(for model: AppModel) -> DashboardSection? {
        DashboardSection(
            id: "quick-actions",
            title: model.t(.dashboardQuickActions),
            detail: model.t(.dashboard),
            priority: priority,
            configuration: .commandBar,
            items: Self.visibleItems(for: model)
        )
    }

    @MainActor
    static func visibleItems(for model: AppModel) -> [DashboardItem] {
        let hiddenIDs = Set(model.settings.dashboardHiddenQuickActionIDs)
        return items(for: model).filter { item in
            !hiddenIDs.contains(item.id)
        }
    }

    @MainActor
    static func items(for model: AppModel) -> [DashboardItem] {
        [
                DashboardItem(
                    id: "actions.start",
                    title: model.t(.start),
                    value: model.t(.start),
                    systemImage: "play.fill",
                    tint: .blue,
                    style: .command,
                    priority: 10,
                    action: .startCore,
                    isEnabled: !model.isRunning && !model.isCoreTransitioning
                ),
                DashboardItem(
                    id: "actions.stop",
                    title: model.t(.stop),
                    value: model.t(.stop),
                    systemImage: "stop.fill",
                    tint: .red,
                    style: .command,
                    priority: 20,
                    action: .stopCore,
                    isEnabled: model.isRunning && !model.isCoreTransitioning
                ),
                DashboardItem(
                    id: "actions.restart",
                    title: model.t(.restart),
                    value: model.t(.restart),
                    systemImage: "arrow.clockwise",
                    tint: .orange,
                    style: .command,
                    priority: 30,
                    action: .restartCore,
                    isEnabled: !model.isCoreTransitioning
                ),
                DashboardItem(
                    id: "actions.refresh",
                    title: model.t(.refresh),
                    value: model.t(.refresh),
                    systemImage: "arrow.triangle.2.circlepath",
                    tint: .blue,
                    style: .command,
                    priority: 40,
                    action: .refreshAll
                ),
                DashboardItem(
                    id: "actions.system-proxy",
                    title: model.t(.systemProxy),
                    value: model.systemProxyEnabled ? model.t(.on) : model.t(.off),
                    systemImage: "network",
                    tint: model.systemProxyEnabled ? .green : .teal,
                    style: .command,
                    priority: 50,
                    action: .toggleSystemProxy,
                    isEnabled: !model.isCoreTransitioning
                ),
                DashboardItem(
                    id: "actions.tun",
                    title: "TUN",
                    value: DashboardStateFormatting.tunStateText(for: model),
                    detail: model.tunRuntimeFailed ? model.tunRuntimeFailureDetail : "",
                    systemImage: "shield.lefthalf.filled",
                    tint: model.settings.enableTun || model.tunRuntimeFailed
                        ? DashboardStateFormatting.tunTint(for: model)
                        : .indigo,
                    style: .command,
                    priority: 60,
                    action: .toggleTun,
                    isEnabled: !model.isCoreTransitioning
                ),
                DashboardItem(
                    id: "actions.auto-start",
                    title: model.t(.autoStartCoreOnLaunch),
                    value: model.settings.autoStartCoreOnLaunch ? model.t(.on) : model.t(.off),
                    systemImage: "power.circle",
                    tint: model.settings.autoStartCoreOnLaunch ? .green : ChumenStyle.mutedText,
                    style: .command,
                    priority: 70,
                    action: .toggleAutoStartCoreOnLaunch
                ),
                DashboardItem(
                    id: "actions.proxy-on-start",
                    title: model.t(.setProxyOnStart),
                    value: model.settings.setSystemProxyOnStart ? model.t(.on) : model.t(.off),
                    systemImage: "checkmark.shield",
                    tint: model.settings.setSystemProxyOnStart ? .green : ChumenStyle.mutedText,
                    style: .command,
                    priority: 80,
                    action: .toggleSetSystemProxyOnStart
                ),
                DashboardItem(
                    id: "actions.tun-on-start",
                    title: model.t(.enableTunOnStart),
                    value: model.settings.enableTunOnStart ? model.t(.on) : model.t(.off),
                    systemImage: "shield",
                    tint: model.settings.enableTunOnStart ? .green : ChumenStyle.mutedText,
                    style: .command,
                    priority: 90,
                    action: .toggleEnableTunOnStart
                ),
                DashboardItem(
                    id: "actions.clear-proxy-on-stop",
                    title: model.t(.clearProxyOnStop),
                    value: model.settings.clearSystemProxyOnStop ? model.t(.on) : model.t(.off),
                    systemImage: "shield.slash",
                    tint: model.settings.clearSystemProxyOnStop ? .green : ChumenStyle.mutedText,
                    style: .command,
                    priority: 100,
                    action: .toggleClearSystemProxyOnStop
                ),
                DashboardItem(
                    id: "actions.disable-tun-on-quit",
                    title: model.t(.disableTunOnQuit),
                    value: model.settings.disableTunOnQuit ? model.t(.on) : model.t(.off),
                    systemImage: "rectangle.portrait.and.arrow.right",
                    tint: model.settings.disableTunOnQuit ? .green : ChumenStyle.mutedText,
                    style: .command,
                    priority: 110,
                    action: .toggleDisableTunOnQuit
                ),
                DashboardItem(
                    id: "actions.allow-lan",
                    title: model.t(.allowLAN),
                    value: model.settings.allowLAN ? model.t(.on) : model.t(.off),
                    systemImage: "network.badge.shield.half.filled",
                    tint: model.settings.allowLAN ? .green : ChumenStyle.mutedText,
                    style: .command,
                    priority: 120,
                    action: .toggleAllowLAN
                ),
                DashboardItem(
                    id: "actions.ipv6",
                    title: model.t(.ipv6),
                    value: model.settings.ipv6 ? model.t(.on) : model.t(.off),
                    systemImage: "6.circle",
                    tint: model.settings.ipv6 ? .green : ChumenStyle.mutedText,
                    style: .command,
                    priority: 130,
                    action: .toggleIPv6
                ),
                DashboardItem(
                    id: "actions.unified-delay",
                    title: model.t(.unifiedDelay),
                    value: model.settings.unifiedDelay ? model.t(.on) : model.t(.off),
                    systemImage: "timer",
                    tint: model.settings.unifiedDelay ? .green : ChumenStyle.mutedText,
                    style: .command,
                    priority: 140,
                    action: .toggleUnifiedDelay
                ),
                DashboardItem(
                    id: "actions.dns",
                    title: model.t(.enableDNS),
                    value: model.settings.enableDNS ? model.t(.on) : model.t(.off),
                    systemImage: "server.rack",
                    tint: model.settings.enableDNS ? .green : ChumenStyle.mutedText,
                    style: .command,
                    priority: 150,
                    action: .toggleDNS
                ),
                DashboardItem(
                    id: "actions.profiles",
                    title: model.t(.profiles),
                    value: model.t(.profiles),
                    systemImage: "doc.text",
                    tint: .blue,
                    style: .command,
                    priority: 200,
                    action: .openTab(.profiles)
                ),
                DashboardItem(
                    id: "actions.logs",
                    title: model.t(.logs),
                    value: model.t(.logs),
                    systemImage: "text.alignleft",
                    tint: .blue,
                    style: .command,
                    priority: 210,
                    action: .openTab(.logs)
                ),
                DashboardItem(
                    id: "actions.core-settings",
                    title: model.t(.coreSettings),
                    value: model.t(.coreSettings),
                    systemImage: "gearshape.2",
                    tint: .indigo,
                    style: .command,
                    priority: 220,
                    action: .openTab(.core)
                ),
                DashboardItem(
                    id: "actions.app-settings",
                    title: model.t(.appSettings),
                    value: model.t(.appSettings),
                    systemImage: "gearshape",
                    tint: .purple,
                    style: .command,
                    priority: 230,
                    action: .openTab(.settings)
                )
            ]
    }
}

private struct RuntimeDashboardProvider: DashboardSectionProvider {
    let priority = 10

    func dashboardSection(for model: AppModel) -> DashboardSection? {
        DashboardSection(
            id: "runtime",
            title: model.t(.runtime),
            detail: model.t(.apiConnectedHint),
            priority: priority,
            items: [
                DashboardItem(
                    id: "runtime.api",
                    title: "API",
                    value: DashboardStateFormatting.apiStateText(for: model),
                    detail: DashboardStateFormatting.apiStateDetail(for: model),
                    systemImage: "globe",
                    tint: DashboardStateFormatting.apiStateTint(for: model),
                    style: .state,
                    priority: 5,
                    action: .refreshAll
                ),
                DashboardItem(
                    id: "runtime.state",
                    title: model.t(.runtime),
                    value: model.isRunning ? model.t(.running) : model.t(.stopped),
                    detail: model.activeProfile?.name ?? "-",
                    systemImage: model.isRunning ? "bolt.horizontal.fill" : "power",
                    tint: model.isRunning ? .green : ChumenStyle.mutedText,
                    style: .state,
                    priority: 10
                ),
                DashboardItem(
                    id: "runtime.profile",
                    title: model.t(.configUpdated),
                    value: model.activeProfileConfigUpdateText,
                    detail: model.activeProfile?.name ?? "-",
                    systemImage: "doc.text",
                    tint: .blue,
                    style: .link,
                    priority: 20,
                    action: .openTab(.profiles)
                ),
                DashboardItem(
                    id: "runtime.mode",
                    title: model.t(.mode),
                    value: model.settings.mode.rawValue,
                    systemImage: "arrow.triangle.branch",
                    tint: .purple,
                    style: .state,
                    priority: 30
                ),
                DashboardItem(
                    id: "runtime.system-proxy",
                    title: model.t(.systemProxy),
                    value: model.systemProxyEnabled ? model.t(.on) : model.t(.off),
                    detail: model.systemProxyStateText,
                    systemImage: model.systemProxyEnabled ? "checkmark.shield" : "shield",
                    tint: model.systemProxyEnabled ? .green : ChumenStyle.mutedText,
                    style: .state,
                    priority: 40,
                    action: .toggleSystemProxy,
                    isEnabled: !model.isCoreTransitioning
                ),
                DashboardItem(
                    id: "runtime.tun",
                    title: model.t(.tunMode),
                    value: DashboardStateFormatting.tunStateText(for: model),
                    detail: model.tunRuntimeFailed ? model.tunRuntimeFailureDetail : "",
                    systemImage: "shield.lefthalf.filled",
                    tint: DashboardStateFormatting.tunTint(for: model),
                    style: .state,
                    priority: 50,
                    action: .toggleTun,
                    isEnabled: !model.isCoreTransitioning
                ),
                DashboardItem(
                    id: "runtime.app-memory",
                    title: model.t(.appMemory),
                    value: model.appMemoryText,
                    detail: "Chumen",
                    systemImage: "memorychip",
                    tint: .indigo,
                    style: .metric,
                    priority: 60
                )
            ]
        )
    }
}

private struct TrafficDashboardProvider: DashboardSectionProvider {
    let priority = 20

    func dashboardSection(for model: AppModel) -> DashboardSection? {
        DashboardSection(
            id: "traffic",
            title: model.t(.traffic),
            detail: model.t(.lastRefresh),
            priority: priority,
            items: [
                DashboardItem(
                    id: "traffic.total",
                    title: model.t(.cumulativeTraffic),
                    value: model.dashboardTrafficText,
                    systemImage: "arrow.up.arrow.down",
                    tint: .teal,
                    priority: 10
                ),
                DashboardItem(
                    id: "traffic.speed",
                    title: model.t(.currentSpeed),
                    value: model.speedText,
                    systemImage: "speedometer",
                    tint: .cyan,
                    priority: 20
                ),
                DashboardItem(
                    id: "traffic.routes",
                    title: model.t(.routedTraffic),
                    value: model.routedTrafficText,
                    systemImage: "point.3.connected.trianglepath.dotted",
                    tint: .mint,
                    priority: 30,
                    action: .openTab(.connections)
                ),
                DashboardItem(
                    id: "traffic.connections",
                    title: model.t(.connections),
                    value: "\(model.connections.count)",
                    detail: model.t(.activeConnections),
                    systemImage: "link",
                    tint: .orange,
                    priority: 40,
                    action: .openTab(.connections)
                ),
                DashboardItem(
                    id: "traffic.memory",
                    title: model.t(.memory),
                    value: model.memoryText,
                    systemImage: "memorychip",
                    tint: .indigo,
                    priority: 50
                )
            ]
        )
    }
}

private struct DiagnosticsDashboardProvider: DashboardSectionProvider {
    let priority = 30

    func dashboardSection(for model: AppModel) -> DashboardSection? {
        let analysis = model.logAnalysisSnapshot
        let logTint: Color = analysis.errorCount > 0 ? .red : (analysis.warningCount > 0 ? .orange : .green)
        let recentIssue = analysis.recentIssues.first
        let logValue = analysis.totalLines == 0
            ? model.t(.noLogs)
            : "\(model.t(.errorLogs)) \(analysis.errorCount) / \(model.t(.warningLogs)) \(analysis.warningCount)"
        let issueDetail = recentIssue?.message ?? "\(model.t(.totalLines)) \(analysis.totalLines)"

        var items = [
            DashboardItem(
                id: "diagnostics.logs",
                title: model.t(.logReport),
                value: logValue,
                detail: issueDetail,
                systemImage: "text.alignleft",
                tint: logTint,
                style: .diagnostic,
                priority: 10,
                action: .openTab(.logs)
            )
        ]

        if let recentIssue {
            items.append(
                DashboardItem(
                    id: "diagnostics.recent-issue",
                    title: model.t(.recentIssues),
                    value: recentIssue.level.rawValue,
                    detail: recentIssue.message,
                    systemImage: "exclamationmark.bubble",
                    tint: recentIssue.level == .error ? .red : .orange,
                    style: .diagnostic,
                    priority: 20,
                    action: .openTab(.logs)
                )
            )
        }

        return DashboardSection(
            id: "diagnostics",
            title: model.t(.logReport),
            detail: model.t(.aiAnalysisReady),
            priority: priority,
            items: items
        )
    }
}
