import AppKit
import Charts
import ChumenCore
import SwiftUI
import UniformTypeIdentifiers

private enum AppTab: Hashable, Sendable {
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

private enum GlobalSearchScope: String, CaseIterable, Identifiable, Sendable {
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

private struct GlobalSearchResult: Identifiable, Sendable {
    let id: String
    let tab: AppTab
    let scope: GlobalSearchScope
    let icon: String
    let title: String
    let subtitle: String
    let detail: String
    let priority: Int
}

private struct GlobalSearchLabels: Sendable {
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

private struct GlobalSearchSnapshot: Sendable {
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

struct ContentView: View {
    @EnvironmentObject private var model: AppModel
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
    @FocusState private var globalSearchFocused: Bool
    @FocusState private var aiInputFocused: Bool

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
                    header
                    Divider()
                    TabView(selection: $selectedTab) {
                        DashboardView()
                            .tabItem { Label(model.t(.dashboard), systemImage: "gauge.with.dots.needle.50percent") }
                            .tag(AppTab.dashboard)
                        ProfilesView(choosingProfile: $choosingProfile)
                            .tabItem { Label(model.t(.profiles), systemImage: "doc.text") }
                            .tag(AppTab.profiles)
                        ProxiesView()
                            .tabItem { Label(model.t(.proxies), systemImage: "point.3.connected.trianglepath.dotted") }
                            .tag(AppTab.proxies)
                        ProvidersView()
                            .tabItem { Label(model.t(.providers), systemImage: "tray.full") }
                            .tag(AppTab.providers)
                        ConnectionsView()
                            .tabItem { Label(model.t(.connections), systemImage: "link") }
                            .tag(AppTab.connections)
                        RulesView()
                            .tabItem { Label(model.t(.rules), systemImage: "list.bullet.rectangle") }
                            .tag(AppTab.rules)
                        CoreSettingsView(choosingCore: $choosingCore)
                            .tabItem { Label(model.t(.coreSettings), systemImage: "gearshape.2") }
                            .tag(AppTab.core)
                        CoreToolsView()
                            .tabItem { Label(model.t(.coreTools), systemImage: "terminal") }
                            .tag(AppTab.coreTools)
                        LogsView()
                            .tabItem { Label(model.t(.logs), systemImage: "text.alignleft") }
                            .tag(AppTab.logs)
                        AppSettingsView()
                            .tabItem { Label(model.t(.appSettings), systemImage: "gearshape") }
                            .tag(AppTab.settings)
                    }
                    .padding(.top, 8)
                }

                aiAssistantLayer
                    .zIndex(700)

                if globalSearchPresented {
                    globalSearchDismissLayer
                        .zIndex(900)
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
        Button {
            presentGlobalSearch()
        } label: {
            HStack(spacing: 9) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(ChumenStyle.mutedText)

                Text(model.t(.globalSearchPlaceholder))
                    .font(.callout)
                    .foregroundStyle(ChumenStyle.mutedText)
                    .lineLimit(1)

                Spacer(minLength: 8)
            }
            .padding(.horizontal, 11)
            .frame(height: 34)
            .background(
                RoundedRectangle(cornerRadius: ChumenStyle.radius, style: .continuous)
                    .fill(ChumenStyle.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: ChumenStyle.radius, style: .continuous)
                    .strokeBorder(ChumenStyle.border)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .opacity(globalSearchPresented ? 0 : 1)
        .frame(height: 34)
    }

    private var aiAssistantLayer: some View {
        GeometryReader { proxy in
            VStack {
                Spacer(minLength: 0)
                HStack {
                    Spacer(minLength: 0)
                    if aiAssistantPresented {
                        aiAssistantPanel
                            .transition(.opacity.combined(with: .scale(scale: 0.98, anchor: .bottomTrailing)))
                    } else {
                        aiFloatingButton
                    }
                }
                .padding(.trailing, proxy.size.width < 760 ? 14 : 20)
                .padding(.bottom, 18)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
    }

    private var aiFloatingButton: some View {
        Button {
            withAnimation(.easeOut(duration: 0.16)) {
                aiAssistantPresented = true
            }
            DispatchQueue.main.async {
                aiInputFocused = true
                if !model.aiReady {
                    scheduleAISearch(delay: .zero)
                }
            }
        } label: {
            Label(model.t(.aiAssistant), systemImage: "sparkles")
                .font(.callout.weight(.semibold))
                .labelStyle(.titleAndIcon)
                .padding(.horizontal, 14)
                .frame(height: 38)
                .background(
                    RoundedRectangle(cornerRadius: ChumenStyle.radius, style: .continuous)
                        .fill(Color.accentColor)
                )
                .foregroundStyle(.white)
                .shadow(color: ChumenStyle.softShadow.opacity(5), radius: 14, y: 8)
        }
        .buttonStyle(.plain)
        .help(model.t(.aiOpenAssistant))
    }

    private var aiAssistantPanel: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Label(model.t(.aiAssistant), systemImage: "sparkles")
                    .font(.headline.weight(.semibold))
                Spacer()
                Button {
                    model.clearAIMessages()
                    aiSearchResults = []
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
                .help(model.t(.aiClearChat))

                Button {
                    withAnimation(.easeOut(duration: 0.14)) {
                        aiAssistantPresented = false
                    }
                } label: {
                    Image(systemName: "xmark")
                }
                .buttonStyle(.borderless)
                .help(model.t(.aiCloseAssistant))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            Divider()

            aiConfigurationSection
                .padding(.horizontal, 14)
                .padding(.vertical, 10)

            Divider()

            Group {
                if model.aiReady {
                    aiMessagesList
                } else {
                    aiSearchResultsList
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            if !model.aiPendingChanges.isEmpty {
                Divider()
                aiPendingChangesView
                    .frame(maxHeight: 184)
            }

            Divider()
            aiInputBar
                .padding(12)
        }
        .frame(width: 420, height: 590)
        .background(
            RoundedRectangle(cornerRadius: ChumenStyle.radius, style: .continuous)
                .fill(ChumenStyle.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: ChumenStyle.radius, style: .continuous)
                .strokeBorder(ChumenStyle.border)
        )
        .shadow(color: ChumenStyle.softShadow.opacity(6), radius: 24, y: 12)
        .onChange(of: model.aiInputText) {
            if !model.aiReady {
                scheduleAISearch()
            }
        }
        .onChange(of: model.aiReady) {
            if !model.aiReady {
                scheduleAISearch(delay: .zero)
            }
        }
    }

    private var aiConfigurationSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Toggle(model.t(.aiAssistant), isOn: $model.settings.ai.isEnabled)
                    .toggleStyle(.switch)
                    .onChange(of: model.settings.ai.isEnabled) {
                        model.scheduleSettingsAutosave()
                    }
                Spacer()
                Text(aiAssistantStatusText)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(model.aiReady ? Color.green : ChumenStyle.mutedText)
                    .lineLimit(1)
            }

            HStack(spacing: 8) {
                Button {
                    model.useLocalOllamaAI()
                } label: {
                    Label(model.t(.aiUseLocalOllama), systemImage: "desktopcomputer")
                        .lineLimit(1)
                }
                .buttonStyle(.bordered)

                Text(model.settings.ai.usesLocalOllama ? model.t(.aiOllamaNoKeyRequired) : model.t(.aiRemoteAPI))
                    .font(.caption)
                    .foregroundStyle(ChumenStyle.mutedText)
                    .lineLimit(1)

                Spacer(minLength: 0)
            }

            HStack(spacing: 8) {
                TextField(model.t(.aiBaseURL), text: $model.settings.ai.baseURL)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: model.settings.ai.baseURL) {
                        model.scheduleSettingsAutosave()
                    }
                TextField(model.t(.aiModel), text: $model.settings.ai.model)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 132)
                    .onChange(of: model.settings.ai.model) {
                        model.scheduleSettingsAutosave()
                    }
            }

            if model.settings.ai.requiresAPIKey {
                HStack(spacing: 8) {
                    SecureField(model.t(.aiAPIKey), text: $model.aiAPIKeyInput)
                        .textFieldStyle(.roundedBorder)
                    Button(model.t(.aiSaveKey)) {
                        model.saveAIAPIKey()
                    }
                    .buttonStyle(.bordered)
                    Button(model.t(.aiClearKey)) {
                        model.clearAIAPIKey()
                    }
                    .buttonStyle(.bordered)
                    .disabled(!model.aiAPIKeyStored)
                }
            }

            Text(model.t(.aiReviewBeforeApply))
                .font(.caption)
                .foregroundStyle(ChumenStyle.mutedText)
        }
    }

    private var aiAssistantStatusText: String {
        if model.aiReady {
            return model.settings.ai.usesLocalOllama ? model.t(.aiOllamaReady) : model.t(.aiKeyStored)
        }
        return model.settings.ai.requiresAPIKey ? model.t(.aiSearchOnly) : model.t(.aiOllamaReady)
    }

    private var aiMessagesList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 9) {
                if model.aiMessages.isEmpty {
                    Text(model.t(.aiNoMessages))
                        .font(.callout)
                        .foregroundStyle(ChumenStyle.mutedText)
                        .frame(maxWidth: .infinity, minHeight: 120)
                } else {
                    ForEach(model.aiMessages) { message in
                        aiMessageBubble(message)
                    }
                }

                if !model.aiStatusText.isEmpty {
                    Text(model.aiStatusText)
                        .font(.caption)
                        .foregroundStyle(ChumenStyle.mutedText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(14)
        }
    }

    private func aiMessageBubble(_ message: ChumenAIChatMessage) -> some View {
        let isUser = message.role == .user
        return HStack {
            if isUser {
                Spacer(minLength: 36)
            }
            Text(message.content)
                .font(.callout)
                .textSelection(.enabled)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: ChumenStyle.radius, style: .continuous)
                        .fill(isUser ? Color.accentColor.opacity(0.14) : ChumenStyle.groupedSurface)
                )
                .frame(maxWidth: 330, alignment: isUser ? .trailing : .leading)
            if !isUser {
                Spacer(minLength: 36)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var aiSearchResultsList: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(model.t(.searchResults))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(ChumenStyle.mutedText)
                Spacer()
                Text("\(aiSearchResults.count)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(ChumenStyle.mutedText)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)

            Divider()

            if !Self.isSearchableGlobalQuery(aiSearchQuery) {
                Text(model.t(.aiSearchOnly))
                    .font(.callout)
                    .foregroundStyle(ChumenStyle.mutedText)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if aiSearchResults.isEmpty {
                Label(model.t(.noSearchResults), systemImage: "magnifyingglass")
                    .font(.callout.weight(.medium))
                    .foregroundStyle(ChumenStyle.mutedText)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(aiSearchResults) { result in
                            Button {
                                selectAISearchResult(result)
                            } label: {
                                HStack(alignment: .top, spacing: 10) {
                                    Image(systemName: result.icon)
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(Color.accentColor)
                                        .frame(width: 20, height: 20)
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(result.title)
                                            .font(.callout.weight(.semibold))
                                            .lineLimit(1)
                                            .truncationMode(.middle)
                                        Text(result.detail.isEmpty ? result.subtitle : result.detail)
                                            .font(.caption)
                                            .foregroundStyle(ChumenStyle.mutedText)
                                            .lineLimit(2)
                                            .truncationMode(.middle)
                                    }
                                    Spacer(minLength: 0)
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 9)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            if result.id != aiSearchResults.last?.id {
                                Divider()
                                    .padding(.leading, 44)
                            }
                        }
                    }
                }
            }
        }
    }

    private var aiPendingChangesView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(model.t(.aiPendingChanges))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(ChumenStyle.mutedText)
                Spacer()
                Text("\(model.aiPendingChanges.count)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(ChumenStyle.mutedText)
            }
            .padding(.horizontal, 14)
            .padding(.top, 8)

            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(model.aiPendingChanges) { change in
                        aiProposedChangeRow(change)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 10)
            }
        }
        .background(ChumenStyle.groupedSurface.opacity(0.45))
    }

    private func aiProposedChangeRow(_ change: ChumenAIProposedChange) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "doc.text.magnifyingglass")
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 18)
                VStack(alignment: .leading, spacing: 2) {
                    Text(change.title)
                        .font(.callout.weight(.semibold))
                        .lineLimit(1)
                    if !change.detail.isEmpty {
                        Text(change.detail)
                            .font(.caption)
                            .foregroundStyle(ChumenStyle.mutedText)
                            .lineLimit(2)
                    }
                }
                Spacer(minLength: 0)
            }

            if !change.diff.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text(model.t(.aiDiff))
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(ChumenStyle.mutedText)
                    ScrollView(.horizontal, showsIndicators: true) {
                        Text(change.diff)
                            .font(.system(.caption, design: .monospaced))
                            .textSelection(.enabled)
                            .foregroundStyle(Color.primary)
                            .padding(8)
                    }
                    .frame(maxHeight: 86)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(ChumenStyle.surface)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .strokeBorder(ChumenStyle.border.opacity(0.75))
                    )
                }
            }

            HStack(spacing: 8) {
                Spacer()
                Button(model.t(.aiDismissChange)) {
                    model.dismissAIProposedChange(change)
                }
                .buttonStyle(.bordered)
                Button(model.t(.aiApplyChange)) {
                    model.applyAIProposedChange(change)
                }
                .buttonStyle(.borderedProminent)
            }
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

    private var aiInputBar: some View {
        HStack(spacing: 8) {
            TextField(model.t(.aiAskPlaceholder), text: $model.aiInputText)
                .textFieldStyle(.plain)
                .font(.callout)
                .focused($aiInputFocused)
                .autocorrectionDisabled(true)
                .onSubmit {
                    submitAIInput()
                }
                .padding(.horizontal, 10)
                .frame(height: 34)
                .background(
                    RoundedRectangle(cornerRadius: ChumenStyle.radius, style: .continuous)
                        .fill(ChumenStyle.groupedSurface)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: ChumenStyle.radius, style: .continuous)
                        .strokeBorder(ChumenStyle.border)
                )

            Button {
                submitAIInput()
            } label: {
                Image(systemName: model.aiReady ? "paperplane.fill" : "magnifyingglass")
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.borderedProminent)
            .disabled(model.aiInputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || model.aiIsSending)
            .help(model.aiReady ? model.t(.aiSend) : model.t(.aiUseAsSearch))
        }
    }

    private var globalSearchDismissLayer: some View {
        Color.black.opacity(0.001)
            .ignoresSafeArea()
            .contentShape(Rectangle())
            .onTapGesture {
                dismissGlobalSearch()
            }
    }

    private var globalSearchOverlay: some View {
        GeometryReader { proxy in
            let horizontalPadding: CGFloat = proxy.size.width < 760 ? 16 : 24
            let panelWidth = max(320, proxy.size.width - horizontalPadding * 2)

            ZStack(alignment: .top) {
                VStack(spacing: 0) {
                    Rectangle()
                        .fill(ChumenStyle.pageBackground)
                        .frame(height: 96)
                        .overlay(alignment: .bottom) {
                            Rectangle()
                                .fill(ChumenStyle.border)
                                .frame(height: 1)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            dismissGlobalSearch()
                        }
                    Spacer(minLength: 0)
                }

                VStack(alignment: .leading, spacing: 8) {
                    globalSearchOverlayInput

                    if shouldShowGlobalSearchResults {
                        globalSearchResultsPanel
                    }
                }
                .frame(width: panelWidth)
                .padding(.top, 10)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .onAppear {
            DispatchQueue.main.async {
                globalSearchFocused = true
                if Self.isSearchableGlobalQuery(globalSearchQuery) {
                    scheduleGlobalSearch(delay: .zero)
                }
            }
        }
        .onExitCommand {
            dismissGlobalSearch()
        }
    }

    private var globalSearchOverlayInput: some View {
        HStack(spacing: 14) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(ChumenStyle.mutedText)

            TextField(model.t(.globalSearchPlaceholder), text: $globalSearchText)
                .textFieldStyle(.plain)
                .font(.title3.weight(.medium))
                .focused($globalSearchFocused)
                .autocorrectionDisabled(true)
                .onChange(of: globalSearchText) {
                    scheduleGlobalSearch()
                }
                .onSubmit {
                    if let firstResult = globalSearchResults.first {
                        selectGlobalSearchResult(firstResult)
                    } else {
                        scheduleGlobalSearch(delay: .zero)
                    }
                }

            if !globalSearchText.isEmpty {
                Button {
                    clearGlobalSearch()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18, weight: .semibold))
                }
                .buttonStyle(.plain)
                .foregroundStyle(ChumenStyle.mutedText)
                .help(model.t(.clear))
            }
        }
        .padding(.horizontal, 18)
        .frame(height: 56)
        .background(
            RoundedRectangle(cornerRadius: ChumenStyle.radius, style: .continuous)
                .fill(ChumenStyle.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: ChumenStyle.radius, style: .continuous)
                .strokeBorder(Color.accentColor.opacity(0.55))
        )
        .shadow(color: ChumenStyle.softShadow.opacity(3), radius: 20, y: 12)
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
        globalSearchPresented && Self.isSearchableGlobalQuery(globalSearchQuery)
    }

    private var globalSearchResultsPanel: some View {
        let results = globalSearchResults
        let resultListHeight = results.isEmpty ? 92 : min(360, max(160, CGFloat(results.count) * 58))

        return VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(model.t(.searchResults))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(ChumenStyle.mutedText)
                Spacer()
                Text("\(globalSearchScopeTitle(globalSearchScope)) · \(results.count)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(ChumenStyle.mutedText)
            }
            .padding(.horizontal, 12)
            .padding(.top, 10)
            .padding(.bottom, 6)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(GlobalSearchScope.allCases) { scope in
                        globalSearchScopeButton(scope)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 9)
            }

            Divider()

            if results.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                    Text(model.t(.noSearchResults))
                }
                .font(.callout.weight(.medium))
                .foregroundStyle(ChumenStyle.mutedText)
                .frame(maxWidth: .infinity, minHeight: resultListHeight)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(results) { result in
                            globalSearchResultRow(result)
                            if result.id != results.last?.id {
                                Divider()
                                    .padding(.leading, 42)
                            }
                        }
                    }
                }
                .frame(height: resultListHeight)
            }
        }
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: ChumenStyle.radius, style: .continuous)
                .fill(ChumenStyle.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: ChumenStyle.radius, style: .continuous)
                .strokeBorder(ChumenStyle.border)
        )
        .shadow(color: ChumenStyle.softShadow.opacity(2.5), radius: 18, y: 10)
    }

    private func globalSearchScopeButton(_ scope: GlobalSearchScope) -> some View {
        let isSelected = globalSearchScope == scope

        return Button {
            globalSearchScope = scope
            globalSearchPresented = true
            globalSearchFocused = true
            scheduleGlobalSearch(delay: .zero, scope: scope)
        } label: {
            Label(globalSearchScopeTitle(scope), systemImage: scope.systemImage)
                .font(.caption.weight(isSelected ? .semibold : .medium))
                .labelStyle(.titleAndIcon)
                .foregroundStyle(isSelected ? Color.accentColor : Color.primary)
                .padding(.horizontal, 9)
                .frame(height: 24)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(isSelected ? Color.accentColor.opacity(0.12) : ChumenStyle.controlFill)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .strokeBorder(isSelected ? Color.accentColor.opacity(0.28) : ChumenStyle.border.opacity(0.55))
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(globalSearchScopeTitle(scope))
    }

    private func globalSearchScopeTitle(_ scope: GlobalSearchScope) -> String {
        switch scope {
        case .all: model.t(.all)
        case .settings: model.t(.appSettings)
        case .core: model.t(.coreSettings)
        case .dashboard: model.t(.dashboard)
        case .profiles: model.t(.profiles)
        case .proxies: model.t(.proxies)
        case .providers: model.t(.providers)
        case .rules: model.t(.rules)
        case .connections: model.t(.connections)
        case .logs: model.t(.logs)
        }
    }

    private func globalSearchResultRow(_ result: GlobalSearchResult) -> some View {
        Button {
            selectGlobalSearchResult(result)
        } label: {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: result.icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 20, height: 20)

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(result.title)
                            .font(.callout.weight(.semibold))
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Text(result.subtitle)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(ChumenStyle.mutedText)
                            .lineLimit(1)
                        Spacer(minLength: 8)
                        Text(globalSearchScopeTitle(result.scope))
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(ChumenStyle.mutedText)
                            .padding(.horizontal, 6)
                            .frame(height: 18)
                            .background(
                                RoundedRectangle(cornerRadius: 5, style: .continuous)
                                    .fill(ChumenStyle.controlFill)
                            )
                    }

                    if !result.detail.isEmpty {
                        Text(result.detail)
                            .font(.caption)
                            .foregroundStyle(ChumenStyle.mutedText)
                            .lineLimit(2)
                            .truncationMode(.middle)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Spacer(minLength: 8)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func selectGlobalSearchResult(_ result: GlobalSearchResult) {
        globalSearchTask?.cancel()
        selectedTab = result.tab
        dismissGlobalSearch()
    }

    private func presentGlobalSearch() {
        globalSearchPresented = true
        DispatchQueue.main.async {
            globalSearchFocused = true
        }
        if Self.isSearchableGlobalQuery(globalSearchQuery) {
            scheduleGlobalSearch(delay: .zero)
        }
    }

    private func dismissGlobalSearch() {
        globalSearchTask?.cancel()
        globalSearchText = ""
        globalSearchResults = []
        globalSearchPresented = false
        globalSearchFocused = false
        globalSearchScope = .all
    }

    private func clearGlobalSearch() {
        globalSearchTask?.cancel()
        globalSearchText = ""
        globalSearchResults = []
        globalSearchFocused = true
    }

    // Native macOS text fields can draw focus rings above SwiftUI z-indexed overlays. Blocking
    // first-run sheets clear transient search focus so the setup UI owns the visual stack.
    private func clearBlockingOverlayFocus() {
        dismissGlobalSearch()
        aiInputFocused = false
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

    private func scheduleAISearch(delay: Duration = .milliseconds(160)) {
        aiSearchTask?.cancel()

        let query = aiSearchQuery
        guard Self.isSearchableGlobalQuery(query) else {
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
                Self.buildGlobalSearchResults(for: query, scope: .all, snapshot: snapshot)
            }.value
            guard !Task.isCancelled, query == aiSearchQuery, !model.aiReady else { return }
            aiSearchResults = results
        }
    }

    private func scheduleGlobalSearch(delay: Duration = .milliseconds(180), scope requestedScope: GlobalSearchScope? = nil) {
        globalSearchTask?.cancel()

        let query = globalSearchQuery
        let scope = requestedScope ?? globalSearchScope
        guard Self.isSearchableGlobalQuery(query) else {
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
                Self.buildGlobalSearchResults(for: query, scope: scope, snapshot: snapshot)
            }.value
            guard !Task.isCancelled, query == globalSearchQuery, scope == globalSearchScope else { return }
            globalSearchResults = results
        }
    }

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

    nonisolated private static func isSearchableGlobalQuery(_ query: String) -> Bool {
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

    nonisolated private static func buildGlobalSearchResults(
        for query: String,
        scope selectedScope: GlobalSearchScope,
        snapshot: GlobalSearchSnapshot
    ) -> [GlobalSearchResult] {
        guard isSearchableGlobalQuery(query) else { return [] }

        var results: [GlobalSearchResult] = []
        let displayLimit = 48
        let candidateLimit = 240
        let labels = snapshot.labels

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

    nonisolated private static func addProviderResult(
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

    nonisolated private static func addSettingsSearchResults(
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

    nonisolated private static func addLogSearchResults(
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

    nonisolated private static func addDirectSearchResult(
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

    nonisolated private static func connectionSearchTitle(_ connection: MihomoConnection) -> String {
        firstNonEmptySearchValue([
            connection.metadata?.host,
            connection.metadata?.destinationIP,
            connection.rulePayload,
            connection.chains?.last,
            connection.id
        ])
    }

    nonisolated private static func connectionSearchDetail(_ connection: MihomoConnection) -> String {
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

    nonisolated private static func connectionSearchText(_ connection: MihomoConnection) -> String {
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

    nonisolated private static func firstNonEmptySearchValue(_ values: [String?]) -> String {
        values
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty } ?? "-"
    }

    nonisolated private static func matchesGlobalSearch(_ value: String, query: String) -> Bool {
        value.range(of: query, options: [.caseInsensitive, .diacriticInsensitive]) != nil
    }

    nonisolated private static func clippedSearchDetail(_ value: String, limit: Int = 160) -> String {
        let normalized = value
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalized.count > limit else { return normalized }
        return String(normalized.prefix(limit)) + "..."
    }
}
