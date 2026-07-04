import Foundation
import ChumenCore

// Global search is intentionally pure and detached from SwiftUI rendering.
// ContentView owns focus and navigation state; this file owns indexing, ranking, and clipping so
// typing in the overlay can run off the main actor without dragging the whole app shell with it.

// AppTab is the single navigation contract shared by the tab view, global search, and AI fallback
// search. Keeping it near the search models makes "search result opens tab" explicit.
enum AppTab: Hashable, Sendable {
    case dashboard
    case profiles
    case proxies
    case providers
    case connections
    case rules
    case core
    case coreTools
    case logs
    case settings
}

// Scope order doubles as ranking policy. Settings and core are intentionally first because search
// is often used to find configuration controls; data-heavy tabs come after direct app actions.
enum GlobalSearchScope: String, CaseIterable, Identifiable, Sendable {
    case all
    case settings
    case core
    case dashboard
    case profiles
    case proxies
    case providers
    case rules
    case connections
    case logs

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .all: "sparkle.magnifyingglass"
        case .settings: "gearshape"
        case .core: "gearshape.2"
        case .dashboard: "gauge.with.dots.needle.50percent"
        case .profiles: "doc.text"
        case .proxies: "point.3.connected.trianglepath.dotted"
        case .providers: "tray.full"
        case .rules: "list.bullet.rectangle"
        case .connections: "link"
        case .logs: "text.alignleft"
        }
    }

    var sortPriority: Int {
        switch self {
        case .settings: 0
        case .core: 5
        case .dashboard: 20
        case .profiles: 30
        case .proxies: 40
        case .providers: 45
        case .rules: 50
        case .connections: 60
        case .logs: 70
        case .all: 100
        }
    }
}

// Search results carry enough metadata for rendering and navigation, but no AppModel references.
// That keeps results cheap to build on a detached task and safe to hand back to the main actor.
struct GlobalSearchResult: Identifiable, Sendable {
    let id: String
    let tab: AppTab
    let scope: GlobalSearchScope
    let icon: String
    let title: String
    let subtitle: String
    let detail: String
    let priority: Int
}

// Labels are captured before leaving the main actor. The search engine should not call localization
// helpers directly because it is designed to run outside SwiftUI/AppModel lifecycles.
struct GlobalSearchLabels: Sendable {
    let dashboard: String
    let running: String
    let stopped: String
    let traffic: String
    let profiles: String
    let activeProfile: String
    let proxies: String
    let groups: String
    let providers: String
    let connections: String
    let activeConnections: String
    let rules: String
    let coreSettings: String
    let runtime: String
    let coreTools: String
    let logs: String
    let processLog: String
    let runtimeLog: String
    let appSettings: String
    let statusBar: String
    let language: String
    let systemProxy: String
    let files: String
    let executable: String
    let secret: String
    let ports: String
    let controllerHost: String
    let networkOptions: String
    let allowLAN: String
    let tunMode: String
    let dns: String
    let externalUI: String
    let configAppendix: String
    let proxyProviders: String
    let ruleProviders: String
}

// Snapshot is the read-only boundary between mutable app state and pure search indexing. Add fields
// here when a new page should be searchable; do not let GlobalSearchEngine reach back into AppModel.
struct GlobalSearchSnapshot: Sendable {
    let labels: GlobalSearchLabels
    let settings: ChumenRuntimeSettings
    let activeProfileName: String
    let statusText: String
    let speedText: String
    let coreToolResult: String
    let logs: String
    let runtimeLogs: String
    let appHomePath: String
    let statusBarTemplatePreview: String
    let languageTitle: String
    let profiles: [ProxyProfile]
    let externalProfileCandidates: [ExternalProfileCandidate]
    let proxyGroups: [ProxyGroupSnapshot]
    let proxyProviders: [MihomoProvider]
    let ruleProviders: [MihomoProvider]
    let connections: [MihomoConnection]
    let rules: [MihomoRule]
}

enum GlobalSearchEngine {
    // Single-character Latin searches are noisy and expensive on large rule lists, but one Chinese
    // character can be a complete search intent. This keeps Chinese input responsive without making
    // every English keystroke scan the full dataset.
    static func isSearchableQuery(_ query: String) -> Bool {
        guard !query.isEmpty else { return false }
        if query.count >= 2 {
            return true
        }
        return query.unicodeScalars.contains { scalar in
            (0x4E00...0x9FFF).contains(Int(scalar.value))
                || (0x3400...0x4DBF).contains(Int(scalar.value))
                || (0x20000...0x2A6DF).contains(Int(scalar.value))
        }
    }

    // Ranking is deliberately deterministic: direct settings and tab targets are inserted first,
    // then data rows are capped before log scanning. The caps prevent long rule/log sets from
    // blocking UI updates while still giving the user representative results.
    static func buildResults(
        for query: String,
        scope selectedScope: GlobalSearchScope,
        snapshot: GlobalSearchSnapshot
    ) -> [GlobalSearchResult] {
        guard isSearchableQuery(query) else { return [] }

        var results: [GlobalSearchResult] = []
        let displayLimit = 48
        let candidateLimit = 240
        let labels = snapshot.labels

        // Local helper keeps each source section declarative while applying the same scope, cap,
        // fuzzy-match, clipping, and priority rules to every result.
        func add(
            id: String,
            tab: AppTab,
            scope resultScope: GlobalSearchScope,
            icon: String,
            title: String,
            subtitle: String,
            detail: String = "",
            priority: Int? = nil,
            tokens: [String?] = []
        ) {
            guard selectedScope == .all || selectedScope == resultScope else { return }
            guard results.count < candidateLimit else { return }
            let searchable = [title, subtitle, detail] + tokens.compactMap { $0 }
            guard searchable.contains(where: { matchesGlobalSearch($0, query: query) }) else { return }
            results.append(GlobalSearchResult(
                id: id,
                tab: tab,
                scope: resultScope,
                icon: icon,
                title: title,
                subtitle: subtitle,
                detail: clippedSearchDetail(detail),
                priority: priority ?? resultScope.sortPriority
            ))
        }

        addSettingsSearchResults(results: &results, query: query, scope: selectedScope, snapshot: snapshot)

        add(
            id: "tab-dashboard",
            tab: .dashboard,
            scope: .dashboard,
            icon: "gauge.with.dots.needle.50percent",
            title: labels.dashboard,
            subtitle: "Chumen",
            detail: "\(snapshot.statusText) \(snapshot.speedText.replacingOccurrences(of: "\n", with: " "))",
            priority: GlobalSearchScope.dashboard.sortPriority + 5,
            tokens: [labels.running, labels.stopped, labels.traffic]
        )
        add(
            id: "tab-profiles",
            tab: .profiles,
            scope: .profiles,
            icon: "doc.text",
            title: labels.profiles,
            subtitle: labels.activeProfile,
            detail: snapshot.activeProfileName,
            priority: GlobalSearchScope.profiles.sortPriority + 5
        )
        add(id: "tab-proxies", tab: .proxies, scope: .proxies, icon: "point.3.connected.trianglepath.dotted", title: labels.proxies, subtitle: "\(snapshot.proxyGroups.count) \(labels.groups)", priority: GlobalSearchScope.proxies.sortPriority + 5)
        add(id: "tab-providers", tab: .providers, scope: .providers, icon: "tray.full", title: labels.providers, subtitle: "\(snapshot.proxyProviders.count + snapshot.ruleProviders.count) Provider", priority: GlobalSearchScope.providers.sortPriority + 5)
        add(id: "tab-connections", tab: .connections, scope: .connections, icon: "link", title: labels.connections, subtitle: "\(snapshot.connections.count) \(labels.activeConnections)", priority: GlobalSearchScope.connections.sortPriority + 5)
        add(id: "tab-rules", tab: .rules, scope: .rules, icon: "list.bullet.rectangle", title: labels.rules, subtitle: "\(snapshot.rules.count)", priority: GlobalSearchScope.rules.sortPriority + 5)
        add(id: "tab-core", tab: .core, scope: .core, icon: "gearshape.2", title: labels.coreSettings, subtitle: labels.runtime, detail: snapshot.settings.corePath, priority: GlobalSearchScope.core.sortPriority + 8)
        add(id: "tab-core-tools", tab: .coreTools, scope: .core, icon: "terminal", title: labels.coreTools, subtitle: "API", detail: snapshot.coreToolResult, priority: GlobalSearchScope.core.sortPriority + 10)
        add(id: "tab-logs", tab: .logs, scope: .logs, icon: "text.alignleft", title: labels.logs, subtitle: "\(labels.processLog) / \(labels.runtimeLog)", priority: GlobalSearchScope.logs.sortPriority + 5)
        add(id: "tab-settings", tab: .settings, scope: .settings, icon: "gearshape", title: labels.appSettings, subtitle: "\(labels.statusBar) / \(labels.language) / \(labels.systemProxy)", priority: GlobalSearchScope.settings.sortPriority + 8)

        for profile in snapshot.profiles {
            add(
                id: "profile-\(profile.id)",
                tab: .profiles,
                scope: .profiles,
                icon: "doc.text",
                title: profile.name,
                subtitle: labels.profiles,
                detail: profile.remoteURL ?? profile.filePath,
                priority: GlobalSearchScope.profiles.sortPriority + 10,
                tokens: [profile.filePath, profile.remoteURL]
            )
        }

        for candidate in snapshot.externalProfileCandidates {
            add(
                id: "external-profile-\(candidate.id)",
                tab: .profiles,
                scope: .profiles,
                icon: "tray.and.arrow.down",
                title: candidate.name,
                subtitle: candidate.sourceName,
                detail: candidate.remoteURL ?? candidate.filePath,
                priority: GlobalSearchScope.profiles.sortPriority + 12,
                tokens: [candidate.filePath, candidate.remoteURL]
            )
        }

        for group in snapshot.proxyGroups {
            if results.count >= candidateLimit { break }
            add(
                id: "proxy-group-\(group.id)",
                tab: .proxies,
                scope: .proxies,
                icon: "point.3.connected.trianglepath.dotted",
                title: group.name,
                subtitle: group.type,
                detail: group.selected,
                priority: GlobalSearchScope.proxies.sortPriority + 10,
                tokens: [group.options.joined(separator: " ")]
            )

            for option in group.options.prefix(40) {
                if results.count >= candidateLimit { break }
                add(
                    id: "proxy-option-\(group.id)-\(option)",
                    tab: .proxies,
                    scope: .proxies,
                    icon: option == group.selected ? "checkmark.circle" : "circle",
                    title: option,
                    subtitle: group.name,
                    detail: group.type,
                    priority: GlobalSearchScope.proxies.sortPriority + 20
                )
            }
        }

        for provider in snapshot.proxyProviders {
            if results.count >= candidateLimit { break }
            addProviderResult(provider, tab: .providers, scope: .providers, subtitle: labels.proxyProviders, results: &results, query: query, selectedScope: selectedScope, candidateLimit: candidateLimit)
        }
        for provider in snapshot.ruleProviders {
            if results.count >= candidateLimit { break }
            addProviderResult(provider, tab: .providers, scope: .providers, subtitle: labels.ruleProviders, results: &results, query: query, selectedScope: selectedScope, candidateLimit: candidateLimit)
        }

        for connection in snapshot.connections {
            if results.count >= candidateLimit { break }
            add(
                id: "connection-\(connection.id)",
                tab: .connections,
                scope: .connections,
                icon: "link",
                title: connectionSearchTitle(connection),
                subtitle: connection.chains?.joined(separator: " > ") ?? labels.connections,
                detail: connectionSearchDetail(connection),
                priority: GlobalSearchScope.connections.sortPriority + 10,
                tokens: [connectionSearchText(connection)]
            )
        }

        for (index, rule) in snapshot.rules.enumerated() {
            if results.count >= candidateLimit { break }
            add(
                id: "rule-\(index)",
                tab: .rules,
                scope: .rules,
                icon: "list.bullet.rectangle",
                title: rule.payload ?? rule.type ?? labels.rules,
                subtitle: rule.type ?? labels.rules,
                detail: rule.proxy ?? "",
                priority: GlobalSearchScope.rules.sortPriority + 10,
                tokens: [rule.payload, rule.proxy, rule.type]
            )
        }

        if results.count < candidateLimit {
            addLogSearchResults(results: &results, query: query, scope: selectedScope, snapshot: snapshot, candidateLimit: candidateLimit)
        }

        return Array(results.sorted { lhs, rhs in
            if lhs.priority != rhs.priority {
                return lhs.priority < rhs.priority
            }
            if lhs.scope.sortPriority != rhs.scope.sortPriority {
                return lhs.scope.sortPriority < rhs.scope.sortPriority
            }
            return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
        }.prefix(displayLimit))
    }

    private static func addProviderResult(
        _ provider: MihomoProvider,
        tab: AppTab,
        scope resultScope: GlobalSearchScope,
        subtitle: String,
        results: inout [GlobalSearchResult],
        query: String,
        selectedScope: GlobalSearchScope,
        candidateLimit: Int
    ) {
        guard selectedScope == .all || selectedScope == resultScope else { return }
        guard results.count < candidateLimit else { return }
        let detail = [provider.type, provider.vehicleType, provider.behavior]
            .compactMap { $0 }
            .joined(separator: " / ")
        let searchable = [provider.name, subtitle, detail]
        guard searchable.contains(where: { matchesGlobalSearch($0, query: query) }) else { return }
        results.append(GlobalSearchResult(
            id: "provider-\(subtitle)-\(provider.id)",
            tab: tab,
            scope: resultScope,
            icon: "tray.full",
            title: provider.name,
            subtitle: subtitle,
            detail: clippedSearchDetail(detail),
            priority: resultScope.sortPriority + 10
        ))
    }

    private static func addSettingsSearchResults(
        results: inout [GlobalSearchResult],
        query: String,
        scope selectedScope: GlobalSearchScope,
        snapshot: GlobalSearchSnapshot
    ) {
        let labels = snapshot.labels
        let settings = snapshot.settings
        let coreItems: [(String, String, String, String)] = [
            ("core-path", labels.executable, settings.corePath, "terminal"),
            ("secret", labels.secret, settings.secret, "key"),
            ("ports", labels.ports, "Mixed \(settings.mixedPort), SOCKS \(settings.socksPort), HTTP \(settings.httpPort)", "point.3.connected.trianglepath.dotted"),
            ("controller", labels.controllerHost, "\(settings.externalControllerHost):\(settings.externalControllerPort)", "slider.horizontal.3"),
            ("network", labels.networkOptions, "\(labels.allowLAN) \(settings.allowLAN), IPv6 \(settings.ipv6)", "network"),
            ("tun", labels.tunMode, "\(settings.enableTun) / \(settings.tunStack.rawValue)", "shield.lefthalf.filled"),
            ("dns", labels.dns, "\(settings.enableDNS) / \(settings.dnsListen) / \(settings.dnsMode.rawValue)", "server.rack"),
            ("external-ui", labels.externalUI, settings.externalUI, "rectangle.connected.to.line.below"),
            ("appendix", labels.configAppendix, settings.configAppendixYAML, "doc.text")
        ]

        for item in coreItems {
            addDirectSearchResult(
                id: "setting-core-\(item.0)",
                tab: .core,
                icon: item.3,
                title: item.1,
                subtitle: labels.coreSettings,
                detail: item.2,
                scope: .core,
                priority: GlobalSearchScope.core.sortPriority,
                selectedScope: selectedScope,
                results: &results,
                query: query
            )
        }

        let appItems: [(String, String, String, String)] = [
            ("status-bar", labels.statusBar, snapshot.statusBarTemplatePreview, "menubar.rectangle"),
            ("language", labels.language, snapshot.languageTitle, "character.bubble"),
            ("system-proxy", labels.systemProxy, "\(settings.systemProxyHost):\(settings.mixedPort)", "globe"),
            ("files", labels.files, snapshot.appHomePath, "folder")
        ]

        for item in appItems {
            addDirectSearchResult(
                id: "setting-app-\(item.0)",
                tab: .settings,
                icon: item.3,
                title: item.1,
                subtitle: labels.appSettings,
                detail: item.2,
                scope: .settings,
                priority: GlobalSearchScope.settings.sortPriority,
                selectedScope: selectedScope,
                results: &results,
                query: query
            )
        }
    }

    private static func addLogSearchResults(
        results: inout [GlobalSearchResult],
        query: String,
        scope selectedScope: GlobalSearchScope,
        snapshot: GlobalSearchSnapshot,
        candidateLimit: Int
    ) {
        guard selectedScope == .all || selectedScope == .logs else { return }
        let sources = [
            (id: "process", title: snapshot.labels.processLog, text: snapshot.logs),
            (id: "runtime", title: snapshot.labels.runtimeLog, text: snapshot.runtimeLogs)
        ]

        for source in sources {
            guard results.count < candidateLimit else { break }
            let matchingLines = source.text
                .split(separator: "\n", omittingEmptySubsequences: true)
                .suffix(300)
                .filter { matchesGlobalSearch(String($0), query: query) }
                .suffix(5)

            for (index, line) in matchingLines.enumerated() {
                guard results.count < candidateLimit else { break }
                results.append(GlobalSearchResult(
                    id: "log-\(source.id)-\(index)-\(line.hashValue)",
                    tab: .logs,
                    scope: .logs,
                    icon: "text.alignleft",
                    title: source.title,
                    subtitle: snapshot.labels.logs,
                    detail: clippedSearchDetail(String(line)),
                    priority: GlobalSearchScope.logs.sortPriority + 10
                ))
            }
        }
    }

    private static func addDirectSearchResult(
        id: String,
        tab: AppTab,
        icon: String,
        title: String,
        subtitle: String,
        detail: String,
        scope resultScope: GlobalSearchScope,
        priority: Int,
        selectedScope: GlobalSearchScope,
        results: inout [GlobalSearchResult],
        query: String
    ) {
        guard selectedScope == .all || selectedScope == resultScope else { return }
        guard [title, subtitle, detail].contains(where: { matchesGlobalSearch($0, query: query) }) else { return }
        results.append(GlobalSearchResult(
            id: id,
            tab: tab,
            scope: resultScope,
            icon: icon,
            title: title,
            subtitle: subtitle,
            detail: clippedSearchDetail(detail),
            priority: priority
        ))
    }

    private static func connectionSearchTitle(_ connection: MihomoConnection) -> String {
        firstNonEmptySearchValue([
            connection.metadata?.host,
            connection.metadata?.destinationIP,
            connection.rulePayload,
            connection.chains?.last,
            connection.id
        ])
    }

    private static func connectionSearchDetail(_ connection: MihomoConnection) -> String {
        firstNonEmptySearchValue([
            connection.metadata?.process,
            connection.metadata?.processPath,
            connection.metadata?.destinationIP,
            connection.rulePayload,
            connection.rule,
            connection.metadata?.network,
            connection.id
        ])
    }

    private static func connectionSearchText(_ connection: MihomoConnection) -> String {
        let parts: [String?] = [
            connection.id,
            connection.start,
            connection.rule,
            connection.rulePayload,
            connection.chains?.joined(separator: " "),
            connection.metadata?.network,
            connection.metadata?.type,
            connection.metadata?.sourceIP,
            connection.metadata?.destinationIP,
            connection.metadata?.sourcePort,
            connection.metadata?.destinationPort,
            connection.metadata?.host,
            connection.metadata?.dnsMode,
            connection.metadata?.process,
            connection.metadata?.processPath,
            connection.metadata?.specialProxy
        ]

        return parts
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
    }

    private static func firstNonEmptySearchValue(_ values: [String?]) -> String {
        values
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty } ?? "-"
    }

    private static func matchesGlobalSearch(_ value: String, query: String) -> Bool {
        value.range(of: query, options: [.caseInsensitive, .diacriticInsensitive]) != nil
    }

    private static func clippedSearchDetail(_ value: String, limit: Int = 160) -> String {
        let normalized = value
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalized.count > limit else { return normalized }
        return String(normalized.prefix(limit)) + "..."
    }
}
