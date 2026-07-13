import AppKit
import ChumenCore
import SwiftUI
import UniformTypeIdentifiers

// ContentView is the app shell: it owns top-level navigation, first-run overlays, and the
// scheduling glue that connects search/AI overlays back to AppModel. Feature-heavy rendering is
// intentionally extracted into sibling views so this file stays a readable routing map.
struct ContentView: View {
    @EnvironmentObject private var model: AppModel

    // Shell state only. Individual pages own their local controls; this view keeps the cross-page
    // state needed for tab routing, file import sheets, global search, and the floating assistant.
    @State private var selectedTab: AppTab = .dashboard
    @State private var choosingCore = false
    @State private var choosingProfile = false
    @State private var globalSearchText = ""
    @State private var globalSearchScope: GlobalSearchScope = .all
    @State private var globalSearchPresented = false
    @State private var globalSearchResults: [GlobalSearchResult] = []
    @State private var globalSearchTask: Task<Void, Never>?
    @State private var aiAssistantPresented = false
    @State private var aiSearchResults: [GlobalSearchResult] = []
    @State private var aiSearchTask: Task<Void, Never>?
    @StateObject private var aiMarkdownCache = AIAssistantMarkdownCache()

    // First-run setup is modal in practice. Rendering only the blocking background prevents the
    // normal tab surface from accepting focus while PIN/import decisions are incomplete.
    private var blockingSetupOverlayPresented: Bool {
        model.pinOverlayPresented || model.startupImportPromptPresented
    }

    var body: some View {
        ZStack(alignment: .top) {
            if blockingSetupOverlayPresented {
                ChumenStyle.pageBackground
                    .ignoresSafeArea()
            } else {
                VStack(spacing: 0) {
                    TabView(selection: $selectedTab) {
                        DashboardView(
                            aiAssistantPresented: $aiAssistantPresented,
                            aiSearchResults: aiSearchResults,
                            aiMarkdownCache: aiMarkdownCache,
                            onOpenTab: { selectedTab = $0 },
                            onAISearchChanged: { scheduleAISearch() },
                            onAISearchImmediately: { scheduleAISearch(delay: .zero) },
                            onAIClearSearchResults: { aiSearchResults = [] },
                            onAISubmit: submitAIInput,
                            onAISelectSearchResult: selectAISearchResult
                        )
                            .tabItem { Label(model.t(.dashboard), systemImage: "gauge.with.dots.needle.50percent") }
                            .tag(AppTab.dashboard)
                        ProfilesView(choosingProfile: $choosingProfile)
                            .tabItem { Label(model.t(.profiles), systemImage: "doc.text") }
                            .tag(AppTab.profiles)
                        ProxiesView(isVisible: selectedTab == .proxies)
                            .tabItem { Label(model.t(.proxies), systemImage: "point.3.connected.trianglepath.dotted") }
                            .tag(AppTab.proxies)
                        ProvidersView(isVisible: selectedTab == .providers)
                            .tabItem { Label(model.t(.providers), systemImage: "tray.full") }
                            .tag(AppTab.providers)
                        ConnectionsView(isVisible: selectedTab == .connections)
                            .tabItem { Label(model.t(.connections), systemImage: "link") }
                            .tag(AppTab.connections)
                        RulesView(isVisible: selectedTab == .rules)
                            .tabItem { Label(model.t(.rules), systemImage: "list.bullet.rectangle") }
                            .tag(AppTab.rules)
                        CoreSettingsView(choosingCore: $choosingCore)
                            .tabItem { Label(model.t(.coreSettings), systemImage: "gearshape.2") }
                            .tag(AppTab.core)
                        CoreToolsView()
                            .tabItem { Label(model.t(.coreTools), systemImage: "terminal") }
                            .tag(AppTab.coreTools)
                        LogsView(isVisible: selectedTab == .logs)
                            .tabItem { Label(model.t(.logs), systemImage: "text.alignleft") }
                            .tag(AppTab.logs)
                        AppSettingsView()
                            .tabItem { Label(model.t(.appSettings), systemImage: "gearshape") }
                            .tag(AppTab.settings)
                    }
                }

                if globalSearchPresented {
                    globalSearchOverlay
                        .zIndex(950)
                }
            }

            if model.startupImportPromptPresented && !model.pinOverlayPresented {
                StartupImportOverlay {
                    model.dismissStartupImportPrompt()
                    choosingProfile = true
                }
                .zIndex(1100)
            }

            if model.pinOverlayPresented {
                PINLockOverlay()
                    .zIndex(1200)
            }
        }
        .background(ChumenStyle.pageBackground)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                globalSearchBox
            }
        }
        .fileImporter(isPresented: $choosingCore, allowedContentTypes: [.item], allowsMultipleSelection: false) { result in
            if case let .success(urls) = result, let url = urls.first {
                model.chooseCore(url)
            }
        }
        .fileImporter(isPresented: $choosingProfile, allowedContentTypes: [.item], allowsMultipleSelection: false) { result in
            if case let .success(urls) = result, let url = urls.first {
                model.importLocalProfile(url)
            }
        }
        .onAppear {
            if model.pinOverlayPresented || model.startupImportPromptPresented {
                clearBlockingOverlayFocus()
            }
        }
        .onChange(of: selectedTab) {
            dismissGlobalSearch()
        }
        .onChange(of: model.pinOverlayPresented) { _, isPresented in
            if isPresented {
                clearBlockingOverlayFocus()
            }
        }
        .onChange(of: model.startupImportPromptPresented) { _, isPresented in
            if isPresented {
                clearBlockingOverlayFocus()
            }
        }
    }

    private var header: some View {
        GeometryReader { proxy in
            let width = max(proxy.size.width, 0)
            let horizontalPadding: CGFloat = width < 1000 ? 16 : 20
            let availableWidth = max(0, width - horizontalPadding * 2)
            let identityWidth = min(CGFloat(162), max(CGFloat(154), availableWidth * 0.17))
            let searchWidth = min(CGFloat(232), max(CGFloat(220), availableWidth * 0.22))

            ZStack(alignment: .topLeading) {
                ZStack {
                    HStack(alignment: .center, spacing: 8) {
                        headerIdentity
                            .frame(width: identityWidth, alignment: .leading)

                        headerLeftStatusPills

                        Spacer(minLength: 0)

                        headerRightStatusPills
                    }

                    globalSearchBox
                        .frame(width: searchWidth)
                        .zIndex(20)
                }
                .padding(.horizontal, horizontalPadding)
                .padding(.vertical, 10)
                .frame(width: proxy.size.width, height: proxy.size.height, alignment: .center)
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .center)
        }
        .frame(height: 64)
        .background(ChumenStyle.pageBackground)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(ChumenStyle.border)
                .frame(height: 1)
        }
        .zIndex(10)
    }

    private var headerIdentity: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: ChumenStyle.radius, style: .continuous)
                    .fill(ChumenStyle.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: ChumenStyle.radius, style: .continuous)
                            .fill((model.isRunning ? Color.green : ChumenStyle.accent).opacity(0.06))
                    )
                Image(systemName: model.isRunning ? "bolt.horizontal.fill" : "bolt.horizontal")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(model.isRunning ? .green : ChumenStyle.accent)
            }
            .frame(width: 38, height: 38)
            .overlay(
                RoundedRectangle(cornerRadius: ChumenStyle.radius, style: .continuous)
                    .strokeBorder(ChumenStyle.border)
            )

            VStack(alignment: .leading, spacing: 5) {
                Text("Chumen")
                    .font(.system(size: 22, weight: .semibold))
                    .lineLimit(1)
                HStack(spacing: 8) {
                    runtimeBadge
                    Text(model.activeProfile?.name ?? "-")
                        .font(.subheadline)
                        .foregroundStyle(ChumenStyle.mutedText)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var globalSearchBox: some View {
        Button(action: presentGlobalSearch) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(Color.primary)
                .frame(width: 42, height: 42)
                .background(Circle().fill(ChumenStyle.surface))
                .overlay(Circle().strokeBorder(ChumenStyle.border))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .help(model.t(.globalSearchPlaceholder))
        .opacity(globalSearchPresented ? 0 : 1)
    }

    private var globalSearchOverlay: some View {
        // The overlay owns focus and presentation. ContentView supplies only search state and
        // navigation callbacks, keeping search UI changes isolated from the main app shell.
        GlobalSearchOverlayView(
            text: $globalSearchText,
            scope: $globalSearchScope,
            results: globalSearchResults,
            shouldShowResults: shouldShowGlobalSearchResults,
            onAppear: {
                if GlobalSearchEngine.isSearchableQuery(globalSearchQuery) {
                    scheduleGlobalSearch(delay: .zero)
                }
            },
            onDismiss: dismissGlobalSearch,
            onClear: clearGlobalSearch,
            onTextChanged: {
                scheduleGlobalSearch()
            },
            onSubmit: {
                if let firstResult = globalSearchResults.first {
                    selectGlobalSearchResult(firstResult)
                } else {
                    scheduleGlobalSearch(delay: .zero)
                }
            },
            onScopeSelected: { selectedScope in
                globalSearchPresented = true
                scheduleGlobalSearch(delay: .zero, scope: selectedScope)
            },
            onSelectResult: selectGlobalSearchResult
        )
    }

    private var headerLeftStatusPills: some View {
        HStack(spacing: 6) {
            headerStatusPill(
                title: "API",
                value: headerAPIVersionText,
                icon: "globe",
                accent: model.apiText == model.t(.apiNotTested) ? ChumenStyle.mutedText : .blue,
                width: 88,
                help: "API: \(model.apiText)"
            )
            headerStatusPill(
                title: model.t(.configUpdated),
                value: model.activeProfileConfigUpdateText,
                icon: "clock",
                accent: .orange,
                width: 126,
                help: "\(model.t(.configUpdated)): \(model.activeProfileConfigUpdateText)"
            )
        }
    }

    private var headerRightStatusPills: some View {
        HStack(spacing: 6) {
            headerProxyChainPill
            headerStatusPill(
                title: model.t(.mode),
                value: model.settings.mode.rawValue,
                icon: "arrow.triangle.branch",
                accent: .purple,
                width: 82,
                help: "\(model.t(.mode)): \(model.settings.mode.rawValue)"
            )
            headerStatusPill(
                title: "TUN",
                value: headerTunStateText,
                icon: "shield.lefthalf.filled",
                accent: headerTunAccent,
                width: 70,
                help: "\(model.t(.tunMode)): \(headerTunStateText)"
            )
        }
    }

    private var runtimeBadge: some View {
        Label(model.isRunning ? model.t(.running) : model.t(.stopped), systemImage: model.isRunning ? "checkmark.circle.fill" : "pause.circle.fill")
            .font(.caption.weight(.semibold))
            .labelStyle(.titleAndIcon)
            .foregroundStyle(model.isRunning ? .green : ChumenStyle.mutedText)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: ChumenStyle.radius, style: .continuous)
                    .fill(ChumenStyle.groupedSurface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: ChumenStyle.radius, style: .continuous)
                    .strokeBorder((model.isRunning ? Color.green.opacity(0.35) : ChumenStyle.border))
            )
    }

    private func headerStatusPill(title: String, value: String, icon: String, accent: Color, width: CGFloat, help: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(accent.opacity(0.9))
                .frame(width: 13)
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(ChumenStyle.mutedText)
                .lineLimit(1)
            Text(value)
                .font(.caption.weight(.semibold))
                .foregroundStyle(accent)
                .lineLimit(1)
                .truncationMode(.middle)
                .minimumScaleFactor(0.58)
                .allowsTightening(true)
        }
        .padding(.horizontal, 7)
        .frame(width: width, height: 34, alignment: .leading)
        .clipped()
        .background(
            RoundedRectangle(cornerRadius: ChumenStyle.radius, style: .continuous)
                .fill(ChumenStyle.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: ChumenStyle.radius, style: .continuous)
                .strokeBorder(ChumenStyle.border.opacity(0.72))
        )
        .help(help)
    }

    private var headerProxyChainPill: some View {
        HStack(spacing: 4) {
            Image(systemName: model.systemProxyEnabled ? "checkmark.shield" : "shield")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(headerProxyAccent.opacity(0.9))
                .frame(width: 13)
            Text(model.t(.systemProxy))
                .font(.caption2.weight(.semibold))
                .foregroundStyle(ChumenStyle.mutedText)
                .lineLimit(1)
            Text(">")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(ChumenStyle.mutedText)
            Text(headerProxyStateValueText)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(headerProxyAccent)
                .lineLimit(1)
            if let address = headerProxyEndpointText {
                Text(">")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(ChumenStyle.mutedText)
                Text(address)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(headerProxyAccent)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .minimumScaleFactor(0.54)
                    .allowsTightening(true)
            }
        }
        .padding(.horizontal, 7)
        .frame(width: headerProxyEndpointText == nil ? 106 : 208, height: 34, alignment: .leading)
        .clipped()
        .background(
            RoundedRectangle(cornerRadius: ChumenStyle.radius, style: .continuous)
                .fill(ChumenStyle.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: ChumenStyle.radius, style: .continuous)
                .strokeBorder(ChumenStyle.border.opacity(0.72))
        )
        .help("\(model.t(.systemProxy)): \(model.systemProxyStateText)")
    }

    private var headerAPIVersionText: String {
        let text = model.apiText.trimmingCharacters(in: .whitespacesAndNewlines)
        let primary = text.components(separatedBy: " / ").first ?? text
        if primary.hasPrefix("mihomo ") {
            return String(primary.dropFirst("mihomo ".count))
        }
        return primary
    }

    private var headerProxyStateValueText: String {
        if model.systemProxyEnabled {
            return model.t(.on)
        }
        if model.systemProxyStateText.localizedCaseInsensitiveContains(model.t(.externalProxy)) ||
            model.systemProxyStateText.contains("其他代理") {
            return model.t(.externalProxy).localizedCaseInsensitiveContains("Other") ? "Other" : "其他"
        }
        return model.t(.externalProxy).localizedCaseInsensitiveContains("Other") ? "Off" : "未开"
    }

    private var headerProxyEndpointText: String? {
        let tokens = model.systemProxyStateText.split(whereSeparator: \.isWhitespace)
        for token in tokens.reversed() {
            let candidate = token.trimmingCharacters(in: CharacterSet(charactersIn: " ,;()[]"))
            guard let split = candidate.lastIndex(of: ":") else { continue }
            let host = candidate[..<split]
            let port = candidate[candidate.index(after: split)...]
            if !host.isEmpty, port.allSatisfy(\.isNumber) {
                return candidate
            }
        }
        if model.systemProxyEnabled {
            return "\(model.settings.systemProxyHost):\(model.settings.mixedPort)"
        }
        return nil
    }

    private var headerProxyAccent: Color {
        if model.systemProxyEnabled {
            return .green
        }
        if model.systemProxyStateText.localizedCaseInsensitiveContains(model.t(.externalProxy)) ||
            model.systemProxyStateText.contains("其他代理") {
            return .orange
        }
        return ChumenStyle.mutedText
    }

    private var headerTunStateText: String {
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

    private var headerTunAccent: Color {
        if model.settings.enableTun && model.tunRuntimeFailed {
            return .orange
        }
        return model.settings.enableTun ? .green : ChumenStyle.mutedText
    }

    private var globalSearchQuery: String {
        globalSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var shouldShowGlobalSearchResults: Bool {
        globalSearchPresented && GlobalSearchEngine.isSearchableQuery(globalSearchQuery)
    }

    private func selectGlobalSearchResult(_ result: GlobalSearchResult) {
        globalSearchTask?.cancel()
        selectedTab = result.tab
        dismissGlobalSearch()
    }

    private func presentGlobalSearch() {
        globalSearchPresented = true
        if GlobalSearchEngine.isSearchableQuery(globalSearchQuery) {
            scheduleGlobalSearch(delay: .zero)
        }
    }

    private func dismissGlobalSearch() {
        globalSearchTask?.cancel()
        globalSearchText = ""
        globalSearchResults = []
        globalSearchPresented = false
        globalSearchScope = .all
    }

    private func clearGlobalSearch() {
        globalSearchTask?.cancel()
        globalSearchText = ""
        globalSearchResults = []
    }

    // Native macOS text fields can draw focus rings above SwiftUI z-indexed overlays. Blocking
    // first-run sheets clear transient search focus so the setup UI owns the visual stack.
    private func clearBlockingOverlayFocus() {
        dismissGlobalSearch()
        DispatchQueue.main.async {
            NSApp.keyWindow?.makeFirstResponder(nil)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            NSApp.keyWindow?.makeFirstResponder(nil)
        }
    }

    private var aiSearchQuery: String {
        model.aiInputText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // Before a model provider is configured, the assistant input intentionally behaves as a quick
    // app search box. Once AI is ready, the same field becomes chat input.
    private func submitAIInput() {
        if model.aiReady {
            model.sendAIMessage()
        } else if let firstResult = aiSearchResults.first {
            selectAISearchResult(firstResult)
        } else {
            scheduleAISearch(delay: .zero)
        }
    }

    private func selectAISearchResult(_ result: GlobalSearchResult) {
        aiSearchTask?.cancel()
        selectedTab = result.tab
        model.aiInputText = ""
        aiSearchResults = []
        withAnimation(.easeOut(duration: 0.14)) {
            aiAssistantPresented = false
        }
    }

    // AI fallback search uses the same index as global search. Cancellation avoids stale results
    // winning the race when the user keeps typing or enables AI while a search is pending.
    private func scheduleAISearch(delay: Duration = .milliseconds(160)) {
        aiSearchTask?.cancel()

        let query = aiSearchQuery
        guard GlobalSearchEngine.isSearchableQuery(query) else {
            aiSearchResults = []
            return
        }

        aiSearchResults = []
        aiSearchTask = Task { @MainActor in
            do {
                try await Task.sleep(for: delay)
            } catch {
                return
            }
            guard !Task.isCancelled, query == aiSearchQuery, !model.aiReady else { return }
            let snapshot = makeGlobalSearchSnapshot()
            let results = await Task.detached(priority: .userInitiated) {
                GlobalSearchEngine.buildResults(for: query, scope: .all, snapshot: snapshot)
            }.value
            guard !Task.isCancelled, query == aiSearchQuery, !model.aiReady else { return }
            aiSearchResults = results
        }
    }

    // Debounce search work and build results off the main actor. The query/scope guards are the
    // race boundary: only the newest text and selected scope are allowed to update the UI.
    private func scheduleGlobalSearch(delay: Duration = .milliseconds(180), scope requestedScope: GlobalSearchScope? = nil) {
        globalSearchTask?.cancel()

        let query = globalSearchQuery
        let scope = requestedScope ?? globalSearchScope
        guard GlobalSearchEngine.isSearchableQuery(query) else {
            globalSearchResults = []
            return
        }

        globalSearchResults = []
        globalSearchTask = Task { @MainActor in
            do {
                try await Task.sleep(for: delay)
            } catch {
                return
            }
            guard !Task.isCancelled, query == globalSearchQuery, scope == globalSearchScope else { return }
            let snapshot = makeGlobalSearchSnapshot()
            let results = await Task.detached(priority: .userInitiated) {
                GlobalSearchEngine.buildResults(for: query, scope: scope, snapshot: snapshot)
            }.value
            guard !Task.isCancelled, query == globalSearchQuery, scope == globalSearchScope else { return }
            globalSearchResults = results
        }
    }

    // Snapshotting keeps GlobalSearchEngine pure and Sendable. The engine can rank and filter on a
    // detached task without touching AppModel or localized strings on the main actor.
    private func makeGlobalSearchSnapshot() -> GlobalSearchSnapshot {
        GlobalSearchSnapshot(
            labels: GlobalSearchLabels(
                dashboard: model.t(.dashboard),
                running: model.t(.running),
                stopped: model.t(.stopped),
                traffic: model.t(.traffic),
                profiles: model.t(.profiles),
                activeProfile: model.t(.activeProfile),
                proxies: model.t(.proxies),
                groups: model.t(.groups),
                providers: model.t(.providers),
                connections: model.t(.connections),
                activeConnections: model.t(.activeConnections),
                rules: model.t(.rules),
                coreSettings: model.t(.coreSettings),
                runtime: model.t(.runtime),
                coreTools: model.t(.coreTools),
                logs: model.t(.logs),
                processLog: model.t(.processLog),
                runtimeLog: model.t(.runtimeLog),
                appSettings: model.t(.appSettings),
                statusBar: model.t(.statusBar),
                language: model.t(.language),
                systemProxy: model.t(.systemProxy),
                files: model.t(.files),
                executable: model.t(.executable),
                secret: model.t(.secret),
                ports: model.t(.ports),
                controllerHost: model.t(.controllerHost),
                networkOptions: model.t(.networkOptions),
                allowLAN: model.t(.allowLAN),
                tunMode: model.t(.tunMode),
                dns: model.t(.dns),
                externalUI: model.t(.externalUI),
                configAppendix: model.t(.configAppendix),
                proxyProviders: model.t(.proxyProviders),
                ruleProviders: model.t(.ruleProviders)
            ),
            settings: model.settings,
            activeProfileName: model.activeProfile?.name ?? "",
            statusText: model.statusText,
            speedText: model.speedText,
            coreToolResult: model.coreToolResult,
            logs: model.logs,
            runtimeLogs: model.runtimeLogs,
            appHomePath: model.paths.appHome.path,
            statusBarTemplatePreview: model.statusBarTemplatePreview,
            languageTitle: model.languageTitle(model.settings.language ?? .system),
            profiles: model.profileLibrary.profiles,
            externalProfileCandidates: model.externalProfileCandidates,
            proxyGroups: model.proxyGroups,
            proxyProviders: model.proxyProviders,
            ruleProviders: model.ruleProviders,
            connections: model.connections,
            rules: model.rules
        )
    }
}
