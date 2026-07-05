import ChumenCore
import SwiftUI

// Dashboard providers are the extension point for high-signal homepage content. Feature areas
// should publish concise state, diagnostics, and navigation links here instead of hardcoding module
// cards inside DashboardView.
@MainActor
protocol DashboardSectionProvider: Sendable {
    var priority: Int { get }
    func dashboardSection(for model: AppModel) -> DashboardSection?
}

enum DashboardItemStyle {
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

struct DashboardSection: Identifiable {
    let id: String
    let title: String
    let detail: String
    let priority: Int
    var items: [DashboardItem]
}

enum DashboardSectionRegistry {
    static let quickActionsID = "quick-actions"

    @MainActor
    private static let providers: [any DashboardSectionProvider] = [
        QuickActionsDashboardProvider(),
        RuntimeDashboardProvider(),
        TrafficDashboardProvider(),
        DiagnosticsDashboardProvider(),
        NavigationDashboardProvider()
    ]

    @MainActor
    static func sections(for model: AppModel) -> [DashboardSection] {
        allSections(for: model)
            .filter { $0.id != quickActionsID }
    }

    @MainActor
    static func quickActions(for model: AppModel) -> DashboardSection? {
        allSections(for: model).first { $0.id == quickActionsID }
    }

    @MainActor
    private static func allSections(for model: AppModel) -> [DashboardSection] {
        providers
            .compactMap { provider in
                provider.dashboardSection(for: model)
            }
            .map { section in
                DashboardSection(
                    id: section.id,
                    title: section.title,
                    detail: section.detail,
                    priority: section.priority,
                    items: section.items.sorted { lhs, rhs in
                        lhs.priority == rhs.priority ? lhs.id < rhs.id : lhs.priority < rhs.priority
                    }
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
    static func controllerState(for model: AppModel) -> (value: String, detail: String, tint: Color) {
        let status = model.apiText.trimmingCharacters(in: .whitespacesAndNewlines)
        let lowercased = status.lowercased()
        let address = "\(model.settings.externalControllerHost):\(model.settings.externalControllerPort)"
        if status.isEmpty ||
            status == model.t(.apiNotTested) ||
            status == L10n.text(.apiNotTested, language: .en) {
            return (model.t(.pending), address, .blue)
        }
        if status == model.t(.controllerUnavailable) ||
            status == L10n.text(.controllerUnavailable, language: .en) ||
            lowercased.contains("could not connect") ||
            lowercased.contains("cannot connect") ||
            lowercased.contains("connection refused") {
            return (model.t(.controllerUnavailable), address, .orange)
        }
        return (model.t(.apiConnected), status, .green)
    }
}

private struct QuickActionsDashboardProvider: DashboardSectionProvider {
    let priority = 0

    func dashboardSection(for model: AppModel) -> DashboardSection? {
        DashboardSection(
            id: DashboardSectionRegistry.quickActionsID,
            title: model.t(.quickSettings),
            detail: model.t(.dashboard),
            priority: priority,
            items: [
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
                    tint: ChumenStyle.mutedText,
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
                    tint: ChumenStyle.mutedText,
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
                    tint: ChumenStyle.mutedText,
                    style: .command,
                    priority: 40,
                    action: .refreshAll
                ),
                DashboardItem(
                    id: "actions.system-proxy",
                    title: model.systemProxyEnabled ? model.t(.disableProxy) : model.t(.enableProxy),
                    value: model.systemProxyEnabled ? model.t(.disableProxy) : model.t(.enableProxy),
                    systemImage: "network",
                    tint: model.systemProxyEnabled ? .green : ChumenStyle.mutedText,
                    style: .command,
                    priority: 50,
                    action: .toggleSystemProxy,
                    isEnabled: !model.isCoreTransitioning
                ),
                DashboardItem(
                    id: "actions.tun",
                    title: model.settings.enableTun ? model.t(.disableTun) : model.t(.enableTun),
                    value: model.settings.enableTun ? model.t(.disableTun) : model.t(.enableTun),
                    detail: model.tunRuntimeFailed ? model.tunRuntimeFailureDetail : "",
                    systemImage: "shield.lefthalf.filled",
                    tint: DashboardStateFormatting.tunTint(for: model),
                    style: .command,
                    priority: 60,
                    action: .toggleTun,
                    isEnabled: !model.isCoreTransitioning
                ),
                DashboardItem(
                    id: "actions.profiles",
                    title: model.t(.profiles),
                    value: model.t(.profiles),
                    systemImage: "doc.text",
                    tint: .blue,
                    style: .command,
                    priority: 70,
                    action: .openTab(.profiles)
                ),
                DashboardItem(
                    id: "actions.logs",
                    title: model.t(.logs),
                    value: model.t(.logs),
                    systemImage: "text.alignleft",
                    tint: .blue,
                    style: .command,
                    priority: 80,
                    action: .openTab(.logs)
                ),
                DashboardItem(
                    id: "actions.core-settings",
                    title: model.t(.coreSettings),
                    value: model.t(.coreSettings),
                    systemImage: "gearshape.2",
                    tint: .indigo,
                    style: .command,
                    priority: 90,
                    action: .openTab(.core)
                ),
                DashboardItem(
                    id: "actions.app-settings",
                    title: model.t(.appSettings),
                    value: model.t(.appSettings),
                    systemImage: "gearshape",
                    tint: .purple,
                    style: .command,
                    priority: 100,
                    action: .openTab(.settings)
                )
            ]
        )
    }
}

private struct RuntimeDashboardProvider: DashboardSectionProvider {
    let priority = 10

    func dashboardSection(for model: AppModel) -> DashboardSection? {
        let controller = DashboardStateFormatting.controllerState(for: model)
        return DashboardSection(
            id: "runtime",
            title: model.t(.runtime),
            detail: model.t(.apiConnectedHint),
            priority: priority,
            items: [
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
                    id: "runtime.api",
                    title: model.t(.apiConnected),
                    value: controller.value,
                    detail: controller.detail,
                    systemImage: "network",
                    tint: controller.tint,
                    style: .state,
                    priority: 20
                ),
                DashboardItem(
                    id: "runtime.profile",
                    title: model.t(.activeProfile),
                    value: model.activeProfile?.name ?? "-",
                    detail: model.activeProfileConfigUpdateText,
                    systemImage: "doc.text",
                    tint: .blue,
                    style: .link,
                    priority: 30,
                    action: .openTab(.profiles)
                ),
                DashboardItem(
                    id: "runtime.mode",
                    title: model.t(.mode),
                    value: model.settings.mode.rawValue,
                    systemImage: "arrow.triangle.branch",
                    tint: .purple,
                    style: .state,
                    priority: 40
                ),
                DashboardItem(
                    id: "runtime.system-proxy",
                    title: model.t(.systemProxy),
                    value: model.systemProxyEnabled ? model.t(.on) : model.t(.off),
                    detail: model.systemProxyStateText,
                    systemImage: model.systemProxyEnabled ? "checkmark.shield" : "shield",
                    tint: model.systemProxyEnabled ? .green : ChumenStyle.mutedText,
                    style: .state,
                    priority: 50,
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
                    priority: 60,
                    action: .toggleTun,
                    isEnabled: !model.isCoreTransitioning
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

private struct NavigationDashboardProvider: DashboardSectionProvider {
    let priority = 40

    func dashboardSection(for model: AppModel) -> DashboardSection? {
        var items = [
            DashboardItem(
                id: "links.logs",
                title: model.t(.logs),
                value: model.t(.logReport),
                detail: "\(model.t(.processLog)) / \(model.t(.runtimeLog))",
                systemImage: "text.alignleft",
                tint: .blue,
                style: .link,
                priority: 10,
                action: .openTab(.logs)
            ),
            DashboardItem(
                id: "links.connections",
                title: model.t(.connections),
                value: "\(model.connections.count)",
                detail: model.t(.activeConnections),
                systemImage: "link",
                tint: .orange,
                style: .link,
                priority: 20,
                action: .openTab(.connections)
            ),
            DashboardItem(
                id: "links.core-settings",
                title: model.t(.coreSettings),
                value: model.t(.runtime),
                detail: "\(model.t(.tunMode)) / \(model.t(.dns)) / \(model.t(.ports))",
                systemImage: "gearshape.2",
                tint: .indigo,
                style: .link,
                priority: 30,
                action: .openTab(.core)
            ),
            DashboardItem(
                id: "links.core-tools",
                title: model.t(.coreTools),
                value: model.t(.openDashboard),
                detail: model.t(.controllerHost),
                systemImage: "terminal",
                tint: .purple,
                style: .link,
                priority: 40,
                action: .openTab(.coreTools)
            )
        ]

        if model.settings.dashboardLaunchURL(paths: model.paths, language: model.language) != nil {
            items.append(
                DashboardItem(
                    id: "links.external-dashboard",
                    title: model.t(.openDashboard),
                    value: model.settings.externalUIName.isEmpty ? model.t(.externalUI) : model.settings.externalUIName,
                    detail: model.t(.controllerHost),
                    systemImage: "safari",
                    tint: .teal,
                    style: .link,
                    priority: 50,
                    action: .openDashboardURL
                )
            )
        }

        return DashboardSection(
            id: "links",
            title: model.t(.quickSettings),
            detail: model.t(.globalSearch),
            priority: priority,
            items: items
        )
    }
}
