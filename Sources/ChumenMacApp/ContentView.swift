import AppKit
import ChumenCore
import SwiftUI
import UniformTypeIdentifiers

private enum ChumenStyle {
    static let radius: CGFloat = 8
    static let accent = Color(red: 0.02, green: 0.48, blue: 0.38)
    static let pageBackground = Color(nsColor: .windowBackgroundColor)
    static let surface = Color(nsColor: .textBackgroundColor)
    static let groupedSurface = Color(nsColor: .controlBackgroundColor)
    static let controlFill = Color.primary.opacity(0.065)
    static let identityFill = Color.primary.opacity(0.035)
    static let border = Color(nsColor: .separatorColor).opacity(0.30)
    static let mutedText = Color(nsColor: .secondaryLabelColor)
    static let softShadow = Color.black.opacity(0.025)
}

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

    var body: some View {
        ZStack(alignment: .top) {
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

private struct DashboardView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                commandPanel
                metricsGrid
            }
            .padding(20)
            .frame(maxWidth: 1280, alignment: .topLeading)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .background(ChumenStyle.pageBackground)
    }

    private var commandPanel: some View {
        HStack(alignment: .center, spacing: 12) {
            commandSummary
                .frame(width: 330, alignment: .leading)

            Spacer(minLength: 12)

            VStack(alignment: .trailing, spacing: 9) {
                commandActions
                modeControl
            }
                .frame(maxWidth: .infinity, alignment: .trailing)
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
        .shadow(color: ChumenStyle.softShadow, radius: 6, x: 0, y: 2)
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

    private var commandActions: some View {
        HStack(spacing: 8) {
            Button {
                model.start()
            } label: {
                Label(model.t(.start), systemImage: "play.fill")
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .frame(width: 82)
            }
            .buttonStyle(.borderedProminent)
            .labelStyle(.titleAndIcon)
            .help(model.t(.start))
            .disabled(model.isRunning || model.isCoreTransitioning)

            Button {
                model.stop()
            } label: {
                Label(model.t(.stop), systemImage: "stop.fill")
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .frame(width: 82)
            }
            .buttonStyle(.bordered)
            .labelStyle(.titleAndIcon)
            .help(model.t(.stop))
            .disabled(!model.isRunning || model.isCoreTransitioning)

            Button {
                model.restart()
            } label: {
                Label(model.t(.restart), systemImage: "arrow.clockwise")
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .frame(width: 82)
            }
            .buttonStyle(.bordered)
            .labelStyle(.titleAndIcon)
            .help(model.t(.restart))
            .disabled(model.isCoreTransitioning)

            Button {
                Task { await model.refreshAll() }
            } label: {
                Label(model.t(.refresh), systemImage: "arrow.triangle.2.circlepath")
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .frame(width: 82)
            }
            .buttonStyle(.bordered)
            .labelStyle(.titleAndIcon)
            .help(model.t(.refresh))

            Button {
                model.toggleSystemProxy()
            } label: {
                Label(model.systemProxyEnabled ? model.t(.disableProxy) : model.t(.enableProxy), systemImage: "network")
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .frame(width: 112)
            }
            .buttonStyle(.bordered)
            .labelStyle(.titleAndIcon)
            .help(model.systemProxyEnabled ? model.t(.disableProxy) : model.t(.enableProxy))

            Button {
                model.setTunEnabled(!model.settings.enableTun)
            } label: {
                Label(model.settings.enableTun ? model.t(.disableTun) : model.t(.enableTun), systemImage: "shield.lefthalf.filled")
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .frame(width: 112)
            }
            .buttonStyle(.bordered)
            .labelStyle(.titleAndIcon)
            .help(tunHelpText)
            .tint(tunAccent)
            .disabled(model.isCoreTransitioning)
        }
        .controlSize(.regular)
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

    private var metricsGrid: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 230, maximum: 320), spacing: 12)], spacing: 12) {
            metric(
                model.t(.runtime),
                value: model.isRunning ? model.t(.running) : model.t(.stopped),
                icon: "bolt.horizontal",
                accent: model.isRunning ? .green : ChumenStyle.mutedText
            )
            metric(
                model.t(.activeProfile),
                value: model.activeProfile?.name ?? "-",
                icon: "doc.text",
                accent: .blue
            )
            metric(
                model.t(.mode),
                value: model.settings.mode.rawValue,
                icon: "arrow.triangle.branch",
                accent: .purple
            )
            metric(
                model.t(.cumulativeTraffic),
                value: model.dashboardTrafficText,
                icon: "arrow.up.arrow.down",
                accent: .teal
            )
            metric(
                model.t(.currentSpeed),
                value: model.speedText,
                icon: "speedometer",
                accent: .cyan
            )
            metric(
                model.t(.routedTraffic),
                value: model.routedTrafficText,
                icon: "point.3.connected.trianglepath.dotted",
                accent: .mint
            )
            metric(
                model.t(.memory),
                value: model.memoryText,
                icon: "memorychip",
                accent: .indigo
            )
            metric(
                model.t(.systemProxy),
                value: model.systemProxyEnabled ? model.t(.on) : model.t(.off),
                icon: model.systemProxyEnabled ? "checkmark.shield" : "shield",
                accent: model.systemProxyEnabled ? .green : ChumenStyle.mutedText
            )
            metric(
                model.t(.tunMode),
                value: tunStateText,
                icon: "shield.lefthalf.filled",
                accent: tunAccent
            )
        }
    }

    private func metric(_ title: String, value: String, icon: String, accent: Color) -> some View {
        HStack(alignment: .center, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(ChumenStyle.groupedSurface)
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(accent)
            }
            .frame(width: 36, height: 36)

            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(ChumenStyle.mutedText)
                Text(value)
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(Color.primary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.72)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(minHeight: 88, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: ChumenStyle.radius, style: .continuous)
                .fill(ChumenStyle.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: ChumenStyle.radius, style: .continuous)
                .strokeBorder(ChumenStyle.border)
        )
        .shadow(color: ChumenStyle.softShadow, radius: 5, x: 0, y: 1)
    }

    private var tunStateText: String {
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

    private var tunAccent: Color {
        if model.settings.enableTun && model.tunRuntimeFailed {
            return .orange
        }
        return model.settings.enableTun ? .green : ChumenStyle.mutedText
    }

    private var tunHelpText: String {
        if model.settings.enableTun && model.tunRuntimeFailed {
            let detail = model.tunRuntimeFailureDetail.trimmingCharacters(in: .whitespacesAndNewlines)
            return detail.isEmpty ? model.t(.tunFailed) : "\(model.t(.tunFailed)): \(detail)"
        }
        return model.settings.enableTun ? model.t(.disableTun) : model.t(.enableTun)
    }
}

private struct ProfilesView: View {
    @EnvironmentObject private var model: AppModel
    @Binding var choosingProfile: Bool

    var body: some View {
        HSplitView {
            VStack(alignment: .leading, spacing: 16) {
                Button {
                    choosingProfile = true
                } label: {
                    Label(model.t(.importLocal), systemImage: "square.and.arrow.down")
                }

                Divider()

                TextField(model.t(.subscriptionURL), text: $model.remoteProfileURL)
                    .textFieldStyle(.roundedBorder)
                TextField(model.t(.displayName), text: $model.remoteProfileName)
                    .textFieldStyle(.roundedBorder)
                Button {
                    model.importRemoteProfile()
                } label: {
                    Label(model.t(.importSubscription), systemImage: "arrow.down.doc")
                }

                Divider()

                GroupBox {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(model.t(.importFromClients))
                            .font(.headline)
                        Text(model.t(.externalImportHint))
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        HStack {
                            Button {
                                model.scanExternalProfiles()
                            } label: {
                                Label(model.t(.scanClients), systemImage: "magnifyingglass")
                            }

                            Button {
                                model.importExternalProfiles()
                            } label: {
                                Label(model.t(.importAllFound), systemImage: "tray.and.arrow.down")
                            }
                            .disabled(model.externalProfileCandidates.isEmpty)
                        }

                        if model.externalProfileCandidates.isEmpty && model.externalProfileScanCompleted {
                            Text(model.t(.noExternalProfilesFound))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else if !model.externalProfileCandidates.isEmpty {
                            ScrollView {
                                VStack(alignment: .leading, spacing: 8) {
                                    ForEach(model.externalProfileCandidates) { candidate in
                                        HStack(alignment: .top, spacing: 8) {
                                            VStack(alignment: .leading, spacing: 3) {
                                                Text(candidate.name)
                                                    .font(.subheadline.weight(.semibold))
                                                    .lineLimit(1)
                                                Text(candidate.sourceName)
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                                if candidate.remoteURL != nil {
                                                    Label(model.t(.subscriptionURLFound), systemImage: "link.badge.plus")
                                                        .font(.caption2)
                                                        .foregroundStyle(.secondary)
                                                }
                                                Text(candidate.filePath)
                                                    .font(.caption2)
                                                    .foregroundStyle(.tertiary)
                                                    .lineLimit(1)
                                            }
                                            Spacer(minLength: 8)
                                            Button(model.t(.importOne)) {
                                                model.importExternalProfile(candidate)
                                            }
                                            .controlSize(.small)
                                        }
                                        .padding(8)
                                        .background(ChumenStyle.groupedSurface.opacity(0.65))
                                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                    }
                                }
                            }
                            .frame(maxHeight: 210)
                        }
                    }
                }

                Divider()

                Button {
                    model.beginEditGlobalProfileAppendix()
                } label: {
                    Label(model.t(.globalExtendOverrideConfig), systemImage: "doc.badge.gearshape")
                }

                Spacer()
            }
            .padding(18)
            .frame(minWidth: 300, idealWidth: 340, maxWidth: 380)

            List {
                ForEach(model.profileLibrary.profiles) { profile in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(profile.name)
                                    .font(.headline)
                                Text(profile.filePath)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                if let remoteURL = profile.remoteURL, !remoteURL.isEmpty {
                                    Label(remoteURL, systemImage: "link")
                                        .font(.caption)
                                        .foregroundStyle(.tertiary)
                                        .lineLimit(1)
                                }
                            }
                            Spacer()
                            if profile.id == model.profileLibrary.activeProfileID {
                                Label(model.t(.active), systemImage: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                            }
                        }

                        HStack {
                            if profile.id == model.profileLibrary.activeProfileID {
                                Label(model.t(.currentActive), systemImage: "checkmark.circle.fill")
                                    .font(.callout.weight(.semibold))
                                    .foregroundStyle(.green)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(
                                        Capsule(style: .continuous)
                                            .fill(Color.green.opacity(0.10))
                                    )
                                    .overlay(
                                        Capsule(style: .continuous)
                                            .strokeBorder(Color.green.opacity(0.28))
                                    )
                            } else {
                                Button(model.t(.activate)) {
                                    model.activateProfile(profile)
                                }
                            }

                            Spacer()

                            Menu {
                                profileActionMenu(profile)
                            } label: {
                                Image(systemName: "ellipsis")
                                    .font(.system(size: 13, weight: .semibold))
                                    .frame(width: 28, height: 24)
                                    .contentShape(Rectangle())
                            }
                            .menuStyle(.borderlessButton)
                            .fixedSize()
                            .help(model.t(.more))
                        }
                    }
                    .padding(.vertical, 6)
                    .contextMenu {
                        profileActionMenu(profile)
                    }
                }
            }
        }
        .sheet(item: $model.editingProfileMetadata) { profile in
            ProfileMetadataEditorSheet(profile: profile)
                .environmentObject(model)
        }
        .sheet(item: $model.editingProfile) { profile in
            ProfileEditorSheet(profile: profile)
                .environmentObject(model)
        }
        .sheet(item: $model.editingProfileSection) { editor in
            ProfileSectionEditorSheet(editor: editor)
                .environmentObject(model)
        }
        .sheet(item: $model.editingProfileAppendix) { target in
            ProfileAppendixEditorSheet(target: target)
                .environmentObject(model)
        }
    }

    @ViewBuilder
    private func profileActionMenu(_ profile: ProxyProfile) -> some View {
        Button {
            model.activateProfile(profile)
        } label: {
            Label(model.t(.useProfile), systemImage: "checkmark.circle")
        }
        .disabled(profile.id == model.profileLibrary.activeProfileID)

        Button {
            model.beginEditProfileMetadata(profile)
        } label: {
            Label(model.t(.editInfo), systemImage: "info.circle")
        }

        Button {
            model.beginEditProfile(profile)
        } label: {
            Label(model.t(.editFile), systemImage: "doc.text")
        }

        Divider()

        Button {
            model.beginEditProfileSection(profile, kind: .rules)
        } label: {
            Label(model.t(.editRules), systemImage: ProfileSectionEditorKind.rules.systemImage)
        }

        Button {
            model.beginEditProfileSection(profile, kind: .proxies)
        } label: {
            Label(model.t(.editNodes), systemImage: ProfileSectionEditorKind.proxies.systemImage)
        }

        Button {
            model.beginEditProfileSection(profile, kind: .proxyGroups)
        } label: {
            Label(model.t(.editProxyGroups), systemImage: ProfileSectionEditorKind.proxyGroups.systemImage)
        }

        Button {
            model.beginEditProfileAppendix(profile)
        } label: {
            Label(model.t(.extendOverrideConfig), systemImage: "doc.badge.gearshape")
        }

        Button {
            model.noteProfileScriptUnsupported()
        } label: {
            Label(model.t(.extendScript), systemImage: "curlybraces")
        }

        Divider()

        Button {
            model.openProfileFile(profile)
        } label: {
            Label(model.t(.openFile), systemImage: "arrow.up.right.square")
        }

        Button {
            model.updateProfile(profile)
        } label: {
            Label(model.t(.update), systemImage: "arrow.clockwise")
        }
        .disabled(profile.remoteURL == nil)

        Button {
            model.updateProfileViaProxy(profile)
        } label: {
            Label(model.t(.updateViaProxy), systemImage: "point.3.connected.trianglepath.dotted")
        }
        .disabled(profile.remoteURL == nil)

        Divider()

        Button(role: .destructive) {
            model.deleteProfile(profile)
        } label: {
            Label(model.t(.delete), systemImage: "trash")
        }
    }
}

private struct ProfileMetadataEditorSheet: View {
    @EnvironmentObject private var model: AppModel
    let profile: ProxyProfile

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(model.t(.editInfo))
                        .font(.headline)
                    Text(profile.filePath)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                Button(model.t(.cancel)) {
                    model.cancelProfileMetadataEditor()
                }
                Button(model.t(.save)) {
                    model.saveProfileMetadataEditor()
                }
                .keyboardShortcut(.defaultAction)
            }

            TextField(model.t(.displayName), text: $model.profileMetadataEditorName)
                .textFieldStyle(.roundedBorder)
            TextField(model.t(.subscriptionURL), text: $model.profileMetadataEditorRemoteURL)
                .textFieldStyle(.roundedBorder)
            Text(model.t(.subscriptionEditHint))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(18)
        .frame(minWidth: 520)
    }
}

private struct ProfileEditorSheet: View {
    @EnvironmentObject private var model: AppModel
    let profile: ProxyProfile

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(model.t(.editFile))
                        .font(.headline)
                    Text(profile.filePath)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                Button(model.t(.cancel)) {
                    model.cancelProfileEditor()
                }
                Button(model.t(.save)) {
                    model.saveProfileEditor()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(model.profileEditorIsLoading)
            }

            ZStack {
                YAMLTextView(text: $model.profileEditorText)
                    .frame(minWidth: 720, minHeight: 520)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .opacity(model.profileEditorIsLoading ? 0.35 : 1)

                if model.profileEditorIsLoading {
                    ProgressView()
                        .controlSize(.large)
                        .padding(18)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
            }
        }
        .padding(18)
    }
}

private struct ProfileSectionEditorSheet: View {
    @EnvironmentObject private var model: AppModel
    let editor: ProfileSectionEditorState

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Label(model.t(editor.kind.titleKey), systemImage: editor.kind.systemImage)
                        .font(.headline)
                    Text(editor.profile.name)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                Button(model.t(.cancel)) {
                    model.cancelProfileSectionEditor()
                }
                Button(model.t(.save)) {
                    model.saveProfileSectionEditor()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(model.profileSectionEditorIsLoading)
            }

            ZStack {
                YAMLTextView(text: $model.profileSectionEditorText)
                    .frame(minWidth: 720, minHeight: 520)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .opacity(model.profileSectionEditorIsLoading ? 0.35 : 1)

                if model.profileSectionEditorIsLoading {
                    ProgressView()
                        .controlSize(.large)
                        .padding(18)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
            }
        }
        .padding(18)
    }
}

private struct ProfileAppendixEditorSheet: View {
    @EnvironmentObject private var model: AppModel
    let target: ProfileAppendixEditorTarget

    private var title: String {
        switch target {
        case .global:
            model.t(.globalExtendOverrideConfig)
        case .profile:
            model.t(.extendOverrideConfig)
        }
    }

    private var subtitle: String {
        switch target {
        case .global:
            model.t(.configAppendix)
        case let .profile(profile):
            profile.name
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Label(title, systemImage: "doc.badge.gearshape")
                        .font(.headline)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                Button(model.t(.cancel)) {
                    model.cancelProfileAppendixEditor()
                }
                Button(model.t(.save)) {
                    model.saveProfileAppendixEditor()
                }
                .keyboardShortcut(.defaultAction)
            }

            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    Label(model.t(.codeEditor), systemImage: "chevron.left.forwardslash.chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(ChumenStyle.mutedText)

                    YAMLTextView(text: $model.profileAppendixEditorText)
                        .frame(minWidth: 520, minHeight: 480)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }

                Divider()

                AppendixVisualEditor(text: $model.profileAppendixEditorText)
                    .frame(width: 360)
                    .frame(minHeight: 480)
            }
        }
        .padding(18)
        .frame(width: 960, height: 590)
    }
}

private struct AppendixVisualEditor: View {
    @EnvironmentObject private var model: AppModel
    @Binding var text: String
    @State private var selectedIndex: Int?
    @State private var draftKey = ""
    @State private var draftBody = ""
    @State private var isLoadingDraft = false
    @State private var isCommittingFromVisual = false

    var body: some View {
        let sections = AppendixYAMLSection.parse(text)

        VStack(alignment: .leading, spacing: 8) {
            Label(model.t(.visualEditor), systemImage: "slider.horizontal.3")
                .font(.caption.weight(.semibold))
                .foregroundStyle(ChumenStyle.mutedText)

            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Text(model.t(.topLevelKey))
                            .font(.caption.weight(.medium))
                            .foregroundStyle(ChumenStyle.mutedText)
                        Spacer()
                        Button {
                            addSection()
                        } label: {
                            Image(systemName: "plus")
                                .frame(width: 22, height: 22)
                        }
                        .buttonStyle(.borderless)
                        .help(model.t(.addSection))
                    }

                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 6) {
                            ForEach(sections.indices, id: \.self) { index in
                                sectionButton(sections[index], index: index)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(ChumenStyle.groupedSurface.opacity(0.35))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .frame(width: 130)

                VStack(alignment: .leading, spacing: 8) {
                    TextField(model.t(.topLevelKey), text: $draftKey)
                        .textFieldStyle(.roundedBorder)
                        .disabled(selectedIndex == nil)

                    Text(model.t(.content))
                        .font(.caption.weight(.medium))
                        .foregroundStyle(ChumenStyle.mutedText)

                    TextEditor(text: $draftBody)
                        .font(.system(.caption, design: .monospaced))
                        .scrollContentBackground(.hidden)
                        .background(ChumenStyle.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .strokeBorder(ChumenStyle.border)
                        )
                        .disabled(selectedIndex == nil)

                    HStack {
                        Spacer()
                        Button(role: .destructive) {
                            deleteSelectedSection()
                        } label: {
                            Label(model.t(.deleteSection), systemImage: "trash")
                        }
                        .disabled(selectedIndex == nil)
                    }
                }
            }
        }
        .onAppear {
            syncDraftWithText()
        }
        .onChange(of: text) {
            guard !isCommittingFromVisual else { return }
            syncDraftWithText()
        }
        .onChange(of: draftKey) {
            commitDraftToText()
        }
        .onChange(of: draftBody) {
            commitDraftToText()
        }
    }

    private func sectionButton(_ section: AppendixYAMLSection, index: Int) -> some View {
        Button {
            selectSection(at: index, from: AppendixYAMLSection.parse(text))
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "square.text.square")
                    .foregroundStyle(ChumenStyle.mutedText)
                Text(section.key)
                    .font(.caption.weight(.medium))
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 7)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(selectedIndex == index ? Color.accentColor.opacity(0.14) : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }

    private func addSection() {
        var sections = AppendixYAMLSection.parse(text)
        let key = uniqueKey(base: "profile", in: sections)
        sections.append(AppendixYAMLSection(key: key, body: ""))
        setTextFromVisual(AppendixYAMLSection.render(sections))
        selectSection(at: sections.count - 1, from: sections)
    }

    private func deleteSelectedSection() {
        guard let selectedIndex else { return }
        var sections = AppendixYAMLSection.parse(text)
        guard sections.indices.contains(selectedIndex) else { return }
        sections.remove(at: selectedIndex)
        setTextFromVisual(AppendixYAMLSection.render(sections))

        if sections.isEmpty {
            clearDraft()
        } else {
            selectSection(at: min(selectedIndex, sections.count - 1), from: sections)
        }
    }

    private func syncDraftWithText() {
        let sections = AppendixYAMLSection.parse(text)
        guard !sections.isEmpty else {
            clearDraft()
            return
        }

        let index = selectedIndex.flatMap { sections.indices.contains($0) ? $0 : nil } ?? 0
        selectSection(at: index, from: sections)
    }

    private func selectSection(at index: Int, from sections: [AppendixYAMLSection]) {
        guard sections.indices.contains(index) else {
            clearDraft()
            return
        }

        isLoadingDraft = true
        selectedIndex = index
        draftKey = sections[index].key
        draftBody = sections[index].body
        DispatchQueue.main.async {
            isLoadingDraft = false
        }
    }

    private func clearDraft() {
        isLoadingDraft = true
        selectedIndex = nil
        draftKey = ""
        draftBody = ""
        DispatchQueue.main.async {
            isLoadingDraft = false
        }
    }

    private func commitDraftToText() {
        guard !isLoadingDraft else { return }
        guard let selectedIndex else { return }
        var sections = AppendixYAMLSection.parse(text)
        guard sections.indices.contains(selectedIndex) else { return }

        let key = sanitizedKey(draftKey)
        guard !key.isEmpty else { return }

        sections[selectedIndex].key = key
        sections[selectedIndex].body = draftBody
        setTextFromVisual(AppendixYAMLSection.render(sections))
    }

    private func setTextFromVisual(_ yaml: String) {
        isCommittingFromVisual = true
        text = yaml
        DispatchQueue.main.async {
            isCommittingFromVisual = false
        }
    }

    private func sanitizedKey(_ key: String) -> String {
        key.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ":", with: "")
    }

    private func uniqueKey(base: String, in sections: [AppendixYAMLSection]) -> String {
        let keys = Set(sections.map(\.key))
        guard keys.contains(base) else { return base }

        var index = 2
        while keys.contains("\(base)-\(index)") {
            index += 1
        }
        return "\(base)-\(index)"
    }
}

private struct AppendixYAMLSection: Equatable {
    var key: String
    var body: String

    static func parse(_ yaml: String) -> [AppendixYAMLSection] {
        let lines = yaml.components(separatedBy: .newlines)
        var sections: [AppendixYAMLSection] = []
        var currentKey: String?
        var currentInlineValue = ""
        var currentBody: [String] = []

        func flush() {
            guard let currentKey else { return }
            let body = currentBody.isEmpty
                ? currentInlineValue
                : currentBody.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            sections.append(AppendixYAMLSection(key: currentKey, body: body))
        }

        for line in lines {
            if let key = ChumenConfigurationBuilder.topLevelKey(in: line) {
                flush()
                currentKey = key
                currentInlineValue = topLevelValue(in: line)
                currentBody = []
            } else if currentKey != nil {
                currentBody.append(line)
            }
        }

        flush()
        return sections
    }

    static func render(_ sections: [AppendixYAMLSection]) -> String {
        sections
            .map(renderSection)
            .filter { !$0.isEmpty }
            .joined(separator: "\n\n")
    }

    private static func renderSection(_ section: AppendixYAMLSection) -> String {
        let key = section.key.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ":", with: "")
        guard !key.isEmpty else { return "" }

        let body = section.body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !body.isEmpty else { return "\(key):" }

        if shouldRenderInline(body) {
            return "\(key): \(body)"
        }

        return "\(key):\n\(indented(body))"
    }

    private static func shouldRenderInline(_ body: String) -> Bool {
        guard !body.contains("\n") else { return false }

        let trimmed = body.trimmingCharacters(in: .whitespaces)
        guard !trimmed.hasPrefix("-") else { return false }
        if trimmed.hasPrefix("[") || trimmed.hasPrefix("{") {
            return true
        }
        return !trimmed.contains(":")
    }

    private static func indented(_ body: String) -> String {
        body.components(separatedBy: .newlines)
            .map { line in
                guard !line.isEmpty else { return line }
                if line.hasPrefix(" ") || line.hasPrefix("\t") {
                    return line
                }
                return "  \(line)"
            }
            .joined(separator: "\n")
    }

    private static func topLevelValue(in line: String) -> String {
        guard let colonIndex = line.firstIndex(of: ":") else { return "" }
        return line[line.index(after: colonIndex)...]
            .trimmingCharacters(in: .whitespaces)
    }
}

private struct ProxiesView: View {
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

private struct ProvidersView: View {
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

private struct ConnectionsView: View {
    @EnvironmentObject private var model: AppModel
    @State private var searchText = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Button {
                    Task { await model.refreshConnections() }
                } label: {
                    Label(model.t(.refreshConnections), systemImage: "arrow.triangle.2.circlepath")
                }
                Button(role: .destructive) {
                    model.closeAllConnections()
                } label: {
                    Label(model.t(.closeAll), systemImage: "xmark.circle")
                }
                .disabled(model.connections.isEmpty)

                TextField(model.t(.searchConnections), text: $searchText)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 320)

                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(ChumenStyle.mutedText)
                    .help(model.t(.clear))
                }

                Spacer()
                Text(connectionsSummary)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .controlSize(.large)

            connectionsList
        }
        .padding(18)
    }

    private var filteredConnections: [MihomoConnection] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return model.connections }
        return model.connections.filter { searchableText(for: $0).localizedCaseInsensitiveContains(query) }
    }

    private var connectionsSummary: String {
        let countPrefix = searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "\(model.connections.count)"
            : "\(filteredConnections.count)/\(model.connections.count)"
        return "\(countPrefix) \(model.t(.activeConnections)) / \(model.totalTrafficText)"
    }

    @ViewBuilder
    private var connectionsList: some View {
        if model.connections.isEmpty {
            connectionEmptyState(title: model.t(.noConnections))
        } else if filteredConnections.isEmpty {
            connectionEmptyState(title: model.t(.noMatchingConnections))
        } else {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(filteredConnections) { connection in
                        connectionRow(connection)
                        if connection.id != filteredConnections.last?.id {
                            Divider()
                                .padding(.leading, 12)
                        }
                    }
                }
                .padding(.trailing, 18)
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

    private func connectionEmptyState(title: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: "link")
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(ChumenStyle.mutedText)
            Text(title)
                .font(.headline)
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
    }

    private func connectionRow(_ connection: MihomoConnection) -> some View {
        HStack(alignment: .center, spacing: 12) {
            connectionIdentity(connection)
                .layoutPriority(0)

            connectionTrafficControls(connection)
                .layoutPriority(1)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity, minHeight: 76, alignment: .leading)
    }

    private func connectionIdentity(_ connection: MihomoConnection) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(connectionTitle(for: connection))
                .font(.headline)
                .lineLimit(1)
                .truncationMode(.middle)

            Text(connectionChainText(for: connection))
                .font(.caption.weight(.medium))
                .foregroundStyle(ChumenStyle.mutedText)
                .lineLimit(1)
                .truncationMode(.middle)

            Text(connectionDetailText(for: connection))
                .font(.caption)
                .foregroundStyle(ChumenStyle.mutedText)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(minWidth: 220, maxWidth: .infinity, minHeight: 58, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(ChumenStyle.identityFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .strokeBorder(ChumenStyle.border.opacity(0.40))
        )
    }

    private func connectionTrafficControls(_ connection: MihomoConnection) -> some View {
        VStack(alignment: .trailing, spacing: 6) {
            Text("\(model.t(.upload)) \(AppModel.formatBytes(connection.upload ?? 0))")
            Text("\(model.t(.download)) \(AppModel.formatBytes(connection.download ?? 0))")

            Button {
                model.closeConnection(connection)
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "xmark.circle")
                        .font(.system(size: 13, weight: .semibold))
                    Text(model.t(.close))
                        .font(.callout.weight(.medium))
                }
                .foregroundStyle(Color.primary)
                .frame(width: 86, height: 32)
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
            .help(model.t(.close))
        }
        .font(.caption.weight(.medium))
        .foregroundStyle(Color.primary)
        .frame(width: 118, alignment: .trailing)
    }

    private func connectionTitle(for connection: MihomoConnection) -> String {
        firstNonEmpty([
            connection.metadata?.host,
            connection.metadata?.destinationIP,
            connection.rulePayload,
            connection.chains?.last,
            connection.id
        ])
    }

    private func connectionChainText(for connection: MihomoConnection) -> String {
        guard let chains = connection.chains, !chains.isEmpty else { return "-" }
        return chains.joined(separator: " > ")
    }

    private func connectionDetailText(for connection: MihomoConnection) -> String {
        firstNonEmpty([
            connection.metadata?.process,
            connection.metadata?.destinationIP,
            connection.rulePayload,
            connection.rule,
            connection.metadata?.network,
            connection.id
        ])
    }

    private func searchableText(for connection: MihomoConnection) -> String {
        var parts: [String] = []
        func append(_ value: String?) {
            guard let text = value?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else { return }
            parts.append(text)
        }

        append(connection.id)
        append(connection.start)
        append(connection.rule)
        append(connection.rulePayload)
        append(connection.chains?.joined(separator: " "))
        append(connection.metadata?.network)
        append(connection.metadata?.type)
        append(connection.metadata?.sourceIP)
        append(connection.metadata?.destinationIP)
        append(connection.metadata?.sourcePort)
        append(connection.metadata?.destinationPort)
        append(connection.metadata?.host)
        append(connection.metadata?.dnsMode)
        append(connection.metadata?.process)
        append(connection.metadata?.processPath)
        append(connection.metadata?.specialProxy)

        return parts.joined(separator: "\n")
    }

    private func firstNonEmpty(_ values: [String?]) -> String {
        values
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty } ?? "-"
    }
}

private struct RulesView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Button {
                    Task { await model.refreshRules() }
                } label: {
                    Label(model.t(.refreshRules), systemImage: "arrow.triangle.2.circlepath")
                }
                Spacer()
                Text("\(model.rules.count) \(model.t(.rules))")
                    .foregroundStyle(.secondary)
            }

            List {
                ForEach(Array(model.rules.enumerated()), id: \.offset) { index, rule in
                    HStack {
                        Text(rule.type ?? "unknown")
                            .font(.caption.weight(.semibold))
                            .frame(width: 90, alignment: .leading)
                        Text(rule.payload ?? "")
                            .lineLimit(1)
                        Spacer()
                        Text(rule.proxy ?? "")
                            .foregroundStyle(.secondary)
                        Button(rule.disabled == true ? model.t(.activate) : model.t(.disableProxy)) {
                            model.setRuleDisabled(index: index, disabled: !(rule.disabled ?? false))
                        }
                    }
                    .padding(.vertical, 3)
                }
            }
        }
        .padding(18)
    }
}

private struct LogsView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(model.t(.logs), systemImage: "text.alignleft")
                    .font(.headline)
                Spacer()
                Button {
                    model.clearLogs()
                } label: {
                    Label(model.t(.clear), systemImage: "trash")
                }
            }

            HSplitView {
                logPane(title: model.t(.processLog), text: model.logs)
                logPane(title: model.t(.runtimeLog), text: model.runtimeLogs)
            }
        }
        .padding(18)
    }

    private func logPane(title: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            ScrollView {
                Text(text.isEmpty ? model.t(.noLogs) : text)
                    .font(.system(.caption, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
                    .padding(12)
            }
            .background(Color(nsColor: .textBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .frame(minWidth: 320)
    }
}

private struct CoreToolsView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                toolGroup(title: model.t(.runtime)) {
                    Button {
                        model.reloadRuntimeConfigViaAPI()
                    } label: {
                        Label(model.t(.reloadRuntimeConfig), systemImage: "arrow.clockwise.circle")
                    }
                    Button {
                        model.restartKernelViaAPI()
                    } label: {
                        Label(model.t(.restartKernelAPI), systemImage: "power")
                    }
                    ForEach(BundledDashboard.allCases) { dashboard in
                        Button {
                            model.openDashboardURL(dashboard)
                        } label: {
                            Label(dashboard.displayName, systemImage: "safari")
                        }
                    }
                }

                toolGroup(title: model.t(.cache)) {
                    Button {
                        model.flushFakeIPCache()
                    } label: {
                        Label(model.t(.flushFakeIP), systemImage: "trash")
                    }
                    Button {
                        model.flushDNSCache()
                    } label: {
                        Label(model.t(.flushDNS), systemImage: "trash.circle")
                    }
                    Button {
                        model.debugGC()
                    } label: {
                        Label(model.t(.debugGC), systemImage: "memorychip")
                    }
                }

                toolGroup(title: "Geo / UI") {
                    Button {
                        model.updateConfigGeo()
                    } label: {
                        Label(model.t(.updateGeo), systemImage: "globe.asia.australia")
                    }
                    Button {
                        model.upgradeGeo()
                    } label: {
                        Label(model.t(.upgradeGeo), systemImage: "arrow.down.circle")
                    }
                    Button {
                        model.upgradeUI()
                    } label: {
                        Label(model.t(.upgradeUI), systemImage: "rectangle.connected.to.line.below")
                    }
                }

                panel(title: model.t(.dnsQuery)) {
                    HStack {
                        TextField("example.com", text: $model.dnsQueryName)
                            .textFieldStyle(.roundedBorder)
                        TextField("A", text: $model.dnsQueryType)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 90)
                        Button(model.t(.request)) {
                            model.queryDNS()
                        }
                    }
                }

                panel(title: model.t(.storage)) {
                    TextField(model.t(.key), text: $model.storageKey)
                        .textFieldStyle(.roundedBorder)
                    TextEditor(text: $model.storageValue)
                        .font(.system(.caption, design: .monospaced))
                        .frame(minHeight: 90)
                    HStack {
                        Button(model.t(.read)) { model.getStorageValue() }
                        Button(model.t(.write)) { model.putStorageValue() }
                        Button(role: .destructive) { model.deleteStorageValue() } label: { Text(model.t(.delete)) }
                    }
                }

                panel(title: model.t(.rawAPI)) {
                    HStack {
                        Picker("", selection: $model.rawAPIMethod) {
                            ForEach(["GET", "POST", "PUT", "PATCH", "DELETE"], id: \.self) { method in
                                Text(method).tag(method)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 110)
                        TextField("/version", text: $model.rawAPIPath)
                            .textFieldStyle(.roundedBorder)
                        Button(model.t(.request)) {
                            model.callRawAPI()
                        }
                    }
                    Text(model.t(.body))
                        .font(.caption.weight(.medium))
                        .foregroundStyle(ChumenStyle.mutedText)
                    TextEditor(text: $model.rawAPIBody)
                        .font(.system(.caption, design: .monospaced))
                        .frame(minHeight: 90)
                }

                panel(title: model.t(.response)) {
                    ScrollView {
                        Text(model.coreToolResult.isEmpty ? "-" : model.coreToolResult)
                            .font(.system(.caption, design: .monospaced))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)
                            .padding(10)
                    }
                    .frame(minHeight: 160)
                    .background(Color(nsColor: .textBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: ChumenStyle.radius))
                }
            }
            .padding(18)
            .frame(maxWidth: 980, alignment: .topLeading)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
    }

    private func toolGroup<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        panel(title: title) {
            HStack(spacing: 8) {
                content()
                Spacer(minLength: 0)
            }
            .controlSize(.large)
        }
    }

    private func panel<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
            content()
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
}

private enum CoreSettingsSectionID: String, CaseIterable, Identifiable {
    case runtime
    case ports
    case networkOptions
    case tunMode
    case advancedTun
    case dns
    case advancedDNS
    case externalUI
    case configAppendix

    var id: String { rawValue }

    var titleKey: L10n.Key {
        switch self {
        case .runtime: .runtime
        case .ports: .ports
        case .networkOptions: .networkOptions
        case .tunMode: .tunMode
        case .advancedTun: .advancedTun
        case .dns: .dns
        case .advancedDNS: .advancedDNS
        case .externalUI: .externalUI
        case .configAppendix: .configAppendix
        }
    }

    var systemImage: String {
        switch self {
        case .runtime: "terminal"
        case .ports: "point.3.connected.trianglepath.dotted"
        case .networkOptions: "network"
        case .tunMode: "shield.lefthalf.filled"
        case .advancedTun: "slider.horizontal.3"
        case .dns: "server.rack"
        case .advancedDNS: "gearshape.2"
        case .externalUI: "rectangle.connected.to.line.below"
        case .configAppendix: "doc.text"
        }
    }
}

private struct CoreSettingsView: View {
    @EnvironmentObject private var model: AppModel
    @Binding var choosingCore: Bool
    @State private var selectedSettingsSection: CoreSettingsSectionID = .runtime

    var body: some View {
        ScrollViewReader { proxy in
            HStack(alignment: .top, spacing: 14) {
                settingsQuickBar(proxy: proxy)
                    .padding(.leading, 24)
                    .padding(.top, 18)

                Form {
                    Section(model.t(.runtime)) {
                        pathRow(
                            title: model.t(.executable),
                            value: $model.settings.corePath,
                            systemImage: "terminal",
                            chooseAction: { choosingCore = true }
                        )
                        Button {
                            model.useDetectedCore()
                        } label: {
                            Label(model.t(.useDetectedCore), systemImage: "magnifyingglass")
                        }

                        TextField(model.t(.secret), text: $model.settings.secret)
                            .textFieldStyle(.roundedBorder)
                        Toggle(model.t(.autoStartCoreOnLaunch), isOn: $model.settings.autoStartCoreOnLaunch)
                        settingsActionButton(title: model.t(.applySettingsToCore), systemImage: "arrow.clockwise.circle") {
                            model.reloadRuntimeConfigViaAPI()
                        }
                    }
                    .id(CoreSettingsSectionID.runtime)

            Section(model.t(.ports)) {
                Stepper(value: $model.settings.mixedPort, in: 1...65535) {
                    Label("Mixed \(model.settings.mixedPort)", systemImage: "point.3.connected.trianglepath.dotted")
                }
                Toggle("SOCKS", isOn: $model.settings.socksEnabled)
                Stepper(value: $model.settings.socksPort, in: 1...65535) {
                    Label("SOCKS \(model.settings.socksPort)", systemImage: "s.circle")
                }
                .disabled(!model.settings.socksEnabled)
                Toggle("HTTP", isOn: $model.settings.httpEnabled)
                Stepper(value: $model.settings.httpPort, in: 1...65535) {
                    Label("HTTP \(model.settings.httpPort)", systemImage: "h.circle")
                }
                .disabled(!model.settings.httpEnabled)
                Toggle("Redir", isOn: $model.settings.redirEnabled)
                Stepper(value: $model.settings.redirPort, in: 1...65535) {
                    Label("Redir \(model.settings.redirPort)", systemImage: "r.circle")
                }
                .disabled(!model.settings.redirEnabled)
                Toggle("TProxy", isOn: $model.settings.tproxyEnabled)
                Stepper(value: $model.settings.tproxyPort, in: 1...65535) {
                    Label("TProxy \(model.settings.tproxyPort)", systemImage: "t.circle")
                }
                .disabled(!model.settings.tproxyEnabled)
                Stepper(value: $model.settings.externalControllerPort, in: 1...65535) {
                    Label("Controller \(model.settings.externalControllerPort)", systemImage: "slider.horizontal.3")
                }
                TextField(model.t(.controllerHost), text: $model.settings.externalControllerHost)
                    .textFieldStyle(.roundedBorder)
            }
            .id(CoreSettingsSectionID.ports)

            Section(model.t(.networkOptions)) {
                Toggle(model.t(.allowLAN), isOn: $model.settings.allowLAN)
                Toggle(model.t(.ipv6), isOn: $model.settings.ipv6)
                Toggle(model.t(.unifiedDelay), isOn: $model.settings.unifiedDelay)
                Picker(model.t(.logLevel), selection: $model.settings.logLevel) {
                    ForEach(CoreLogLevel.allCases) { level in
                        Text(level.rawValue).tag(level)
                    }
                }
            }
            .id(CoreSettingsSectionID.networkOptions)

            Section(model.t(.tunMode)) {
                Toggle(model.t(.enableTun), isOn: Binding(
                    get: { model.settings.enableTun },
                    set: { model.setTunEnabled($0) }
                ))
                .disabled(model.isCoreTransitioning)
                Picker(model.t(.tunStack), selection: Binding(
                    get: { model.settings.tunStack },
                    set: { model.setTunStack($0) }
                )) {
                    ForEach(TunStack.allCases) { stack in
                        Text(stack.rawValue).tag(stack)
                    }
                }
                .disabled(model.isCoreTransitioning)
                .pickerStyle(.segmented)
            }
            .id(CoreSettingsSectionID.tunMode)

            Section(model.t(.advancedTun)) {
                TextField("Device", text: $model.settings.tunDevice)
                    .textFieldStyle(.roundedBorder)
                Toggle("Auto Route", isOn: $model.settings.tunAutoRoute)
                Toggle("Strict Route", isOn: $model.settings.tunStrictRoute)
                Toggle("Auto Detect Interface", isOn: $model.settings.tunAutoDetectInterface)
                Stepper(value: $model.settings.tunMTU, in: 576...9000) {
                    Label("MTU \(model.settings.tunMTU)", systemImage: "arrow.left.and.right")
                }
                Text("DNS Hijack")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(ChumenStyle.mutedText)
                TextEditor(text: tunDNSHijackText)
                    .font(.system(.caption, design: .monospaced))
                    .frame(minHeight: 58)
                Text("Route Exclude Address")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(ChumenStyle.mutedText)
                TextEditor(text: tunRouteExcludeText)
                    .font(.system(.caption, design: .monospaced))
                    .frame(minHeight: 58)
            }
            .id(CoreSettingsSectionID.advancedTun)

            Section(model.t(.dns)) {
                Toggle(model.t(.enableDNS), isOn: $model.settings.enableDNS)
                TextField(model.t(.dnsListen), text: $model.settings.dnsListen)
                    .textFieldStyle(.roundedBorder)
                Picker(model.t(.dnsMode), selection: $model.settings.dnsMode) {
                    ForEach(DNSMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                TextEditor(text: nameserverText)
                    .font(.system(.caption, design: .monospaced))
                    .frame(minHeight: 70)
                    .accessibilityLabel(model.t(.nameservers))
            }
            .id(CoreSettingsSectionID.dns)

            Section(model.t(.advancedDNS)) {
                Toggle("DNS IPv6", isOn: $model.settings.dnsIPv6)
                Toggle("Prefer HTTP/3", isOn: $model.settings.dnsPreferH3)
                Toggle("Respect Rules", isOn: $model.settings.dnsRespectRules)
                Toggle("Use Hosts", isOn: $model.settings.dnsUseHosts)
                Toggle("Use System Hosts", isOn: $model.settings.dnsUseSystemHosts)
                TextField("Fake-IP Range", text: $model.settings.dnsFakeIPRange)
                    .textFieldStyle(.roundedBorder)
                TextField("Fake-IP Range IPv6", text: $model.settings.dnsFakeIPRange6)
                    .textFieldStyle(.roundedBorder)
                Picker("Fake-IP Filter Mode", selection: $model.settings.dnsFakeIPFilterMode) {
                    ForEach(DNSFakeIPFilterMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                labeledEditor("Default Nameserver", text: defaultNameserverText)
                labeledEditor("Fallback", text: fallbackNameserverText)
                labeledEditor("Proxy Server Nameserver", text: proxyServerNameserverText)
                labeledEditor("Direct Nameserver", text: directNameserverText)
                labeledEditor("Fake-IP Filter", text: fakeIPFilterText)
                labeledEditor("Fallback IP CIDR", text: fallbackIPCIDRText)
                labeledEditor("Fallback Domain", text: fallbackDomainText)
                Toggle("Fallback GeoIP", isOn: $model.settings.fallbackFilterGeoIP)
                TextField("GeoIP Code", text: $model.settings.fallbackFilterGeoIPCode)
                    .textFieldStyle(.roundedBorder)
                labeledEditor("Nameserver Policy YAML", text: $model.settings.nameserverPolicyYAML)
                labeledEditor("Hosts YAML", text: $model.settings.hostsYAML)
            }
            .id(CoreSettingsSectionID.advancedDNS)

            Section(model.t(.externalUI)) {
                HStack {
                    Text(model.t(.dashboardPreset))
                    Spacer()
                    ForEach(BundledDashboard.allCases) { dashboard in
                        if model.isDashboardPresetActive(dashboard) {
                            Button(dashboard.displayName) {
                                model.useDashboardPreset(dashboard)
                            }
                            .buttonStyle(.borderedProminent)
                        } else {
                            Button(dashboard.displayName) {
                                model.useDashboardPreset(dashboard)
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }
                TextField("external-ui", text: $model.settings.externalUI)
                    .textFieldStyle(.roundedBorder)
                TextField("external-ui-name", text: $model.settings.externalUIName)
                    .textFieldStyle(.roundedBorder)
                TextField("external-ui-url", text: $model.settings.externalUIURL)
                    .textFieldStyle(.roundedBorder)
                Toggle("CORS allow-private-network", isOn: $model.settings.externalControllerCORSAllowPrivateNetwork)
                labeledEditor(model.t(.corsOrigins), text: corsOriginsText)
            }
            .id(CoreSettingsSectionID.externalUI)

            Section(model.t(.configAppendix)) {
                TextEditor(text: $model.settings.configAppendixYAML)
                    .font(.system(.caption, design: .monospaced))
                    .frame(minHeight: 100)
            }
            .id(CoreSettingsSectionID.configAppendix)

                }
                .formStyle(.grouped)
                .onChange(of: model.settings) {
                    model.scheduleSettingsAutosave()
                }
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    private func settingsQuickBar(proxy: ScrollViewProxy) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(model.t(.quickSettings))
                .font(.caption.weight(.semibold))
                .foregroundStyle(ChumenStyle.mutedText)
                .padding(.horizontal, 8)
                .padding(.bottom, 2)

            ForEach(CoreSettingsSectionID.allCases) { section in
                settingsQuickBarButton(section, proxy: proxy)
            }
        }
        .padding(8)
        .frame(width: 138, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: ChumenStyle.radius, style: .continuous)
                .fill(ChumenStyle.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: ChumenStyle.radius, style: .continuous)
                .strokeBorder(ChumenStyle.border)
        )
    }

    private func settingsQuickBarButton(_ section: CoreSettingsSectionID, proxy: ScrollViewProxy) -> some View {
        Button {
            selectedSettingsSection = section
            withAnimation(.easeInOut(duration: 0.18)) {
                proxy.scrollTo(section, anchor: .top)
            }
        } label: {
            HStack(spacing: 7) {
                Image(systemName: section.systemImage)
                    .font(.system(size: 12, weight: .semibold))
                    .frame(width: 15)
                Text(model.t(section.titleKey))
                    .font(.system(size: 12.5, weight: selectedSettingsSection == section ? .semibold : .medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            .foregroundStyle(selectedSettingsSection == section ? Color.accentColor : Color.primary)
            .padding(.horizontal, 8)
            .frame(height: 28)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(selectedSettingsSection == section ? Color.accentColor.opacity(0.13) : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(model.t(section.titleKey))
    }

    private func settingsActionButton(
        title: String,
        systemImage: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.system(size: 14, weight: .semibold))
                Text(title)
                    .font(.callout.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.86)
            }
            .foregroundStyle(Color.primary)
            .padding(.horizontal, 12)
            .frame(height: 38)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: ChumenStyle.radius, style: .continuous)
                    .fill(ChumenStyle.controlFill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: ChumenStyle.radius, style: .continuous)
                    .strokeBorder(ChumenStyle.border.opacity(0.65))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(title)
    }

    private func pathRow(
        title: String,
        value: Binding<String>,
        systemImage: String,
        chooseAction: @escaping () -> Void
    ) -> some View {
        HStack {
            Label(title, systemImage: systemImage)
                .frame(width: 110, alignment: .leading)
            TextField(title, text: value)
                .textFieldStyle(.roundedBorder)
            Button(action: chooseAction) {
                Image(systemName: "folder")
            }
            .help(title)
        }
    }

    private var nameserverText: Binding<String> {
        listText(\.nameservers)
    }

    private var defaultNameserverText: Binding<String> { listText(\.defaultNameservers) }
    private var fallbackNameserverText: Binding<String> { listText(\.fallbackNameservers) }
    private var proxyServerNameserverText: Binding<String> { listText(\.proxyServerNameservers) }
    private var directNameserverText: Binding<String> { listText(\.directNameservers) }
    private var fakeIPFilterText: Binding<String> { listText(\.fakeIPFilters) }
    private var fallbackIPCIDRText: Binding<String> { listText(\.fallbackFilterIPCIDRs) }
    private var fallbackDomainText: Binding<String> { listText(\.fallbackFilterDomains) }
    private var tunDNSHijackText: Binding<String> { listText(\.tunDNSHijack) }
    private var tunRouteExcludeText: Binding<String> { listText(\.tunRouteExcludeAddress) }
    private var corsOriginsText: Binding<String> { listText(\.externalControllerCORSAllowOrigins) }

    private func listText(_ keyPath: WritableKeyPath<ChumenRuntimeSettings, [String]>) -> Binding<String> {
        Binding(
            get: { model.settings[keyPath: keyPath].joined(separator: "\n") },
            set: { value in
                model.settings[keyPath: keyPath] = value
                    .components(separatedBy: .newlines)
                    .flatMap { $0.components(separatedBy: ",") }
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
            }
        )
    }

    @ViewBuilder
    private func labeledEditor(_ title: String, text: Binding<String>) -> some View {
        Text(title)
            .font(.caption.weight(.medium))
            .foregroundStyle(ChumenStyle.mutedText)
        TextEditor(text: text)
            .font(.system(.caption, design: .monospaced))
            .frame(minHeight: 62)
    }
}

private struct AppSettingsView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        Form {
            Section(model.t(.statusBar)) {
                Toggle(model.t(.showStatusBarItem), isOn: Binding(
                    get: { model.settings.showStatusBarItem },
                    set: { model.setStatusBarItemVisible($0) }
                ))

                Picker(model.t(.statusBarDisplayMode), selection: Binding(
                    get: { model.settings.statusBarDisplayMode },
                    set: { model.setStatusBarDisplayMode($0) }
                )) {
                    ForEach(StatusBarDisplayMode.allCases) { mode in
                        Text(model.statusBarDisplayModeTitle(mode)).tag(mode)
                    }
                }
                .disabled(!model.settings.showStatusBarItem)

                if model.settings.statusBarDisplayMode == .custom {
                    TextField(model.t(.statusBarCustomTemplate), text: Binding(
                        get: { model.settings.statusBarCustomTemplate },
                        set: { model.setStatusBarCustomTemplate($0) }
                    ))
                    .textFieldStyle(.roundedBorder)
                    .help("{app} {state} {mode} {profile} {up} {down} {totalUp} {totalDown}")

                    HStack {
                        Text(model.t(.statusBarTemplatePreview))
                            .foregroundStyle(ChumenStyle.mutedText)
                        Text(model.statusBarTemplatePreview)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    .font(.caption)
                }
            }

            Section(model.t(.language)) {
                Picker(model.t(.language), selection: Binding(
                    get: { model.settings.language ?? .system },
                    set: { model.setLanguage($0) }
                )) {
                    ForEach(AppLanguage.allCases) { language in
                        Text(model.languageTitle(language)).tag(language)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section(model.t(.systemProxy)) {
                TextField(model.t(.systemProxyHost), text: $model.settings.systemProxyHost)
                    .textFieldStyle(.roundedBorder)
                Toggle(model.t(.setProxyOnStart), isOn: $model.settings.setSystemProxyOnStart)
                Toggle(model.t(.clearProxyOnStop), isOn: $model.settings.clearSystemProxyOnStop)
                HStack {
                    Text(model.systemProxyStateText)
                    Spacer()
                    Button(model.t(.refresh)) {
                        model.refreshSystemProxyState()
                    }
                }
            }

            Section(model.t(.files)) {
                Text(model.paths.appHome.path)
                    .font(.caption)
                    .textSelection(.enabled)
                Button {
                    model.openDataDirectory()
                } label: {
                    Label(model.t(.openDataDirectory), systemImage: "folder")
                }
            }
        }
        .formStyle(.grouped)
        .onChange(of: model.settings) {
            model.scheduleSettingsAutosave()
        }
        .padding(.vertical, 8)
    }
}
