import AppKit
import Combine
import Foundation
import ChumenCore

@MainActor
final class AppModel: ObservableObject {
    // AppModel 是 GUI 的单一状态源：窗口、状态栏菜单和异步内核任务都从这里读写状态。
    @Published var settings: ChumenRuntimeSettings
    @Published var profileLibrary: ProfileLibrary
    @Published var isRunning = false
    @Published var isCoreTransitioning = false
    @Published var systemProxyEnabled = false
    @Published var statusText = ""
    @Published var apiText = ""
    @Published var logs = ""
    @Published var runtimeLogs = ""
    @Published var remoteProfileURL = ""
    @Published var remoteProfileName = ""
    @Published var editingProfile: ProxyProfile?
    @Published var profileEditorName = ""
    @Published var profileEditorRemoteURL = ""
    @Published var profileEditorText = ""
    @Published var profileEditorIsLoading = false
    @Published var externalProfileCandidates: [ExternalProfileCandidate] = []
    @Published var externalProfileScanCompleted = false
    @Published var proxyGroups: [ProxyGroupSnapshot] = []
    @Published var proxyProviders: [MihomoProvider] = []
    @Published var ruleProviders: [MihomoProvider] = []
    @Published var proxyDelays: [String: Int] = [:]
    @Published var connections: [MihomoConnection] = []
    @Published var rules: [MihomoRule] = []
    @Published var uploadTotal: Int64 = 0
    @Published var downloadTotal: Int64 = 0
    @Published var uploadSpeed: Int64 = 0
    @Published var downloadSpeed: Int64 = 0
    @Published var proxyRoutedUploadTotal: Int64 = 0
    @Published var proxyRoutedDownloadTotal: Int64 = 0
    @Published var directRoutedUploadTotal: Int64 = 0
    @Published var directRoutedDownloadTotal: Int64 = 0
    @Published var unknownRoutedUploadTotal: Int64 = 0
    @Published var unknownRoutedDownloadTotal: Int64 = 0
    @Published var memoryInUse: Int64 = 0
    @Published var memoryLimit: Int64 = 0
    @Published var memoryUnavailable = false
    @Published var systemProxyStateText = ""
    @Published var tunRuntimeFailed = false
    @Published var tunRuntimeFailureMessage = ""
    @Published var lastRefreshText = "-"
    @Published var coreToolResult = ""
    @Published var dnsQueryName = "example.com"
    @Published var dnsQueryType = "A"
    @Published var storageKey = ""
    @Published var storageValue = "{}"
    @Published var rawAPIMethod = "GET"
    @Published var rawAPIPath = "/version"
    @Published var rawAPIBody = ""

    let paths: ChumenPaths

    private let manager: CoreProcessManager
    private let profileRepository: ProfileRepository
    private let settingsStore: ChumenSettingsStore
    private let logStream = MihomoLogStream()
    private let trafficStream = MihomoEventStream<MihomoTraffic>()
    private let memoryStream = MihomoEventStream<MihomoMemory>()
    private let connectionsStream = MihomoEventStream<MihomoConnectionsResponse>()
    private var connectionTrafficAccumulator = ConnectionTrafficAccumulator()
    private var autoRefreshTask: Task<Void, Never>?
    private var profileEditorLoadTask: Task<Void, Never>?
    private var profileEditorOriginalText = ""
    private var coreTransitionTask: Task<Void, Never>?
    private var isPreparingForQuit = false

    init() {
        let paths = (try? ChumenPaths.defaultPaths()) ?? ChumenPaths(appHome: URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("chumen"))
        let settingsStore = ChumenSettingsStore(paths: paths)
        self.paths = paths
        self.settingsStore = settingsStore
        let loadedSettings = settingsStore.load()
        self.settings = loadedSettings
        self.profileRepository = ProfileRepository(paths: paths)
        var library = profileRepository.load()
        if library.activeProfileID == nil {
            library.activeProfileID = loadedSettings.activeProfileID
        }
        self.profileLibrary = library
        self.manager = CoreProcessManager(paths: paths)

        manager.onLog = { [weak self] text in
            Task { @MainActor in
                self?.handleCoreLog(text)
            }
        }
        manager.onExit = { [weak self] status in
            Task { @MainActor in
                guard let self else { return }
                self.stopControllerStreams()
                self.autoRefreshTask?.cancel()
                self.autoRefreshTask = nil
                self.isRunning = false
                self.statusText = status == 0 ? self.t(.stopped) : "\(self.t(.coreExited)): \(status)"
            }
        }

        try? paths.ensureDirectories()
        statusText = t(.stopped)
        apiText = t(.apiNotTested)
        refreshSystemProxyState()
        Task {
            // 启动 GUI 时先探测已有 controller，避免误把其他客户端启动的内核当成自己管理的进程。
            await detectRunningCore()
            if settings.autoStartCoreOnLaunch, !isRunning {
                start()
            }
        }
    }

    var language: AppLanguage {
        let configured = settings.language ?? .system
        return configured == .system ? AppLanguage.defaultLanguage() : configured
    }

    func t(_ key: L10n.Key) -> String {
        L10n.text(key, language: language)
    }

    private func displayError(_ error: Error) -> String {
        if let chumenError = error as? ChumenError {
            switch chumenError {
            case .missingCorePath:
                return t(.coreNotFound)
            case let .coreNotExecutable(path):
                return "\(t(.coreNotFound)): \(path)"
            default:
                break
            }
        }

        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain {
            switch nsError.code {
            case NSURLErrorCannotConnectToHost,
                 NSURLErrorCannotFindHost,
                 NSURLErrorNetworkConnectionLost,
                 NSURLErrorNotConnectedToInternet,
                 NSURLErrorTimedOut:
                return t(.controllerUnavailable)
            default:
                break
            }
        }

        let message = error.localizedDescription
        if language == .zhHans {
            let lowercased = message.lowercased()
            if lowercased.contains("could not connect") || lowercased.contains("cannot connect") {
                return t(.controllerUnavailable)
            }
        }
        return message
    }

    func setLanguage(_ language: AppLanguage) {
        settings.language = language
        saveSettings()
        statusText = isRunning ? t(.running) : t(.stopped)
        if apiText == L10n.text(.apiNotTested, language: .en) || apiText == L10n.text(.apiNotTested, language: .zhHans) {
            apiText = t(.apiNotTested)
        }
        refreshSystemProxyState()
    }

    func languageTitle(_ language: AppLanguage) -> String {
        switch language {
        case .system:
            "System / 系统"
        case .zhHans:
            "简体中文"
        case .en:
            "English"
        }
    }

    func statusBarDisplayModeTitle(_ mode: StatusBarDisplayMode) -> String {
        switch mode {
        case .iconOnly:
            t(.statusBarModeIconOnly)
        case .appName:
            t(.statusBarModeAppName)
        case .status:
            t(.statusBarModeStatus)
        case .speed:
            t(.statusBarModeSpeed)
        case .stackedSpeed:
            t(.statusBarModeStackedSpeed)
        case .traffic:
            t(.statusBarModeTraffic)
        case .statusAndSpeed:
            t(.statusBarModeStatusAndSpeed)
        case .custom:
            t(.statusBarModeCustom)
        }
    }

    var statusBarTitleText: String {
        statusBarTitle(for: settings.statusBarDisplayMode)
    }

    var statusBarTooltipText: String {
        [
            "Chumen - \(statusLine)",
            speedLine,
            totalTrafficText
        ].joined(separator: "\n")
    }

    var statusBarTemplatePreview: String {
        renderStatusBarTemplate(settings.statusBarCustomTemplate)
    }

    func setStatusBarItemVisible(_ visible: Bool) {
        guard settings.showStatusBarItem != visible else { return }
        settings.showStatusBarItem = visible
        saveSettings()
    }

    func setStatusBarDisplayMode(_ mode: StatusBarDisplayMode) {
        guard settings.statusBarDisplayMode != mode else { return }
        settings.statusBarDisplayMode = mode
        saveSettings()
    }

    func setStatusBarCustomTemplate(_ template: String) {
        guard settings.statusBarCustomTemplate != template else { return }
        settings.statusBarCustomTemplate = template
        saveSettings()
    }

    var activeProfile: ProxyProfile? {
        profileLibrary.activeProfile
    }

    var totalTrafficText: String {
        "\(t(.upload)) \(Self.formatBytes(uploadTotal)) / \(t(.download)) \(Self.formatBytes(downloadTotal))"
    }

    var dashboardTrafficText: String {
        "\(t(.upload)) \(Self.formatBytes(uploadTotal))\n\(t(.download)) \(Self.formatBytes(downloadTotal))"
    }

    var speedText: String {
        "\(t(.upload)) \(Self.formatBytes(uploadSpeed))/s\n\(t(.download)) \(Self.formatBytes(downloadSpeed))/s"
    }

    var routedTrafficText: String {
        let proxyLine = "\(t(.proxiedTraffic)) \(Self.formatDirectionalBytes(up: proxyRoutedUploadTotal, down: proxyRoutedDownloadTotal, rate: false))"
        let directLine = "\(t(.directTraffic)) \(Self.formatDirectionalBytes(up: directRoutedUploadTotal, down: directRoutedDownloadTotal, rate: false))"
        if unknownRoutedUploadTotal > 0 || unknownRoutedDownloadTotal > 0 {
            let unknownTotal = unknownRoutedUploadTotal + unknownRoutedDownloadTotal
            return "\(proxyLine)\n\(directLine) · \(t(.unknown)) \(Self.formatBytes(unknownTotal))"
        }
        return "\(proxyLine)\n\(directLine)"
    }

    private var statusLine: String {
        "\(isRunning ? t(.running) : t(.stopped)) · \(settings.mode.rawValue)"
    }

    private var speedLine: String {
        Self.formatDirectionalBytes(up: uploadSpeed, down: downloadSpeed, rate: true)
    }

    private var trafficLine: String {
        Self.formatDirectionalBytes(up: uploadTotal, down: downloadTotal, rate: false)
    }

    private var statusBarSpeedLine: String {
        Self.formatFixedDirectionalBytes(up: uploadSpeed, down: downloadSpeed, rate: true)
    }

    var statusBarStackedSpeedText: String {
        "\(Self.formatFixedRateText(uploadSpeed))\n\(Self.formatFixedRateText(downloadSpeed))"
    }

    private var statusBarTrafficLine: String {
        Self.formatFixedDirectionalBytes(up: uploadTotal, down: downloadTotal, rate: false)
    }

    private func statusBarTitle(for mode: StatusBarDisplayMode) -> String {
        switch mode {
        case .iconOnly:
            ""
        case .appName:
            "Chumen"
        case .status:
            statusLine
        case .speed:
            statusBarSpeedLine
        case .stackedSpeed:
            statusBarStackedSpeedText
        case .traffic:
            statusBarTrafficLine
        case .statusAndSpeed:
            "\(statusLine) · \(statusBarSpeedLine)"
        case .custom:
            renderStatusBarTemplate(settings.statusBarCustomTemplate)
        }
    }

    private func renderStatusBarTemplate(_ template: String) -> String {
        let source = template.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? ChumenRuntimeSettings.defaultStatusBarCustomTemplate
            : template
        let values = [
            "{app}": "Chumen",
            "{state}": isRunning ? t(.running) : t(.stopped),
            "{mode}": settings.mode.rawValue,
            "{profile}": activeProfile?.name ?? "-",
            "{up}": Self.formatBytes(uploadSpeed),
            "{down}": Self.formatBytes(downloadSpeed),
            "{totalUp}": Self.formatBytes(uploadTotal),
            "{totalDown}": Self.formatBytes(downloadTotal)
        ]
        return values.reduce(source) { text, pair in
            text.replacingOccurrences(of: pair.key, with: pair.value)
        }
        .components(separatedBy: .newlines)
        .joined(separator: " ")
    }

    var memoryText: String {
        guard memoryInUse > 0 || memoryLimit > 0 else {
            return memoryUnavailable ? t(.memoryUnavailable) : "-"
        }
        if memoryLimit > 0 {
            return "\(Self.formatBytes(memoryInUse)) / \(Self.formatBytes(memoryLimit))"
        }
        return Self.formatBytes(memoryInUse)
    }

    var tunRuntimeFailureTitle: String {
        guard tunRuntimeFailed else { return "" }
        return tunFailureTitle(for: tunRuntimeFailureMessage)
    }

    var tunRuntimeFailureDetail: String {
        guard tunRuntimeFailed else { return "" }
        let title = tunRuntimeFailureTitle
        let message = tunRuntimeFailureMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !message.isEmpty, message != title else { return title }
        return "\(title): \(message)"
    }

    func chooseCore(_ url: URL) {
        settings.corePath = url.path
        saveSettings()
    }

    func importLocalProfile(_ url: URL) {
        let scoped = url.startAccessingSecurityScopedResource()
        defer {
            if scoped {
                url.stopAccessingSecurityScopedResource()
            }
        }

        do {
            var library = profileLibrary
            let profile = try profileRepository.importLocalProfile(from: url, into: &library)
            profileLibrary = library
            activateProfile(profile)
            statusText = "\(t(.imported)) \(profile.name)"
        } catch {
            statusText = displayError(error)
        }
    }

    func importRemoteProfile() {
        let url = remoteProfileURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !url.isEmpty else {
            statusText = t(.subscriptionURLEmpty)
            return
        }

        Task {
            do {
                var library = profileLibrary
                let profile = try await profileRepository.importRemoteProfile(
                    urlString: url,
                    name: remoteProfileName.isEmpty ? nil : remoteProfileName,
                    into: &library
                )
                profileLibrary = library
                activateProfile(profile)
                remoteProfileURL = ""
                remoteProfileName = ""
                statusText = "\(t(.imported)) \(profile.name)"
            } catch {
                statusText = displayError(error)
            }
        }
    }

    func scanExternalProfiles() {
        externalProfileCandidates = profileRepository.discoverExternalProfiles()
        externalProfileScanCompleted = true
        if externalProfileCandidates.isEmpty {
            statusText = t(.noExternalProfilesFound)
        } else {
            statusText = "\(t(.externalProfilesFound)) \(externalProfileCandidates.count)"
        }
    }

    func importExternalProfiles() {
        guard !externalProfileCandidates.isEmpty else {
            scanExternalProfiles()
            return
        }
        importExternalProfiles(externalProfileCandidates)
    }

    func importExternalProfile(_ candidate: ExternalProfileCandidate) {
        importExternalProfiles([candidate])
    }

    func updateProfile(_ profile: ProxyProfile) {
        Task {
            do {
                var library = profileLibrary
                _ = try await profileRepository.update(profile, in: &library)
                profileLibrary = library
                statusText = "\(t(.updated)) \(profile.name)"
                if isRunning, profile.id == settings.activeProfileID {
                    restart()
                }
            } catch {
                statusText = displayError(error)
            }
        }
    }

    func updateActiveProfile() {
        guard let activeProfile else { return }
        updateProfile(activeProfile)
    }

    func beginEditProfile(_ profile: ProxyProfile) {
        profileEditorLoadTask?.cancel()
        profileEditorName = profile.name
        profileEditorRemoteURL = profile.remoteURL ?? ""
        profileEditorText = ""
        profileEditorOriginalText = ""
        profileEditorIsLoading = true
        editingProfile = profile

        let filePath = profile.filePath
        profileEditorLoadTask = Task { [weak self] in
            do {
                let text = try await Task.detached(priority: .userInitiated) {
                    try String(contentsOfFile: filePath, encoding: .utf8)
                }.value
                guard !Task.isCancelled else { return }
                self?.profileEditorText = text
                self?.profileEditorOriginalText = text
                self?.profileEditorIsLoading = false
            } catch {
                guard !Task.isCancelled else { return }
                self?.profileEditorIsLoading = false
                self?.editingProfile = nil
                self?.statusText = self?.displayError(error) ?? error.localizedDescription
            }
        }
    }

    func saveProfileEditor() {
        guard let editingProfile else { return }
        guard !profileEditorIsLoading else { return }
        do {
            let contentChanged = profileEditorText != profileEditorOriginalText
            var library = profileLibrary
            let updated = try profileRepository.saveContentAndMetadata(
                editingProfile,
                content: profileEditorText,
                name: profileEditorName,
                remoteURL: profileEditorRemoteURL,
                in: &library
            )
            profileLibrary = library
            self.editingProfile = nil
            statusText = "\(t(.saved)) \(updated.name)"
            if contentChanged, isRunning, updated.id == settings.activeProfileID {
                restart()
            }
        } catch {
            statusText = displayError(error)
        }
    }

    func cancelProfileEditor() {
        profileEditorLoadTask?.cancel()
        profileEditorLoadTask = nil
        editingProfile = nil
        profileEditorName = ""
        profileEditorRemoteURL = ""
        profileEditorText = ""
        profileEditorOriginalText = ""
        profileEditorIsLoading = false
    }

    func openProfileFile(_ profile: ProxyProfile) {
        NSWorkspace.shared.open(URL(fileURLWithPath: profile.filePath))
    }

    func deleteProfile(_ profile: ProxyProfile) {
        do {
            let wasActive = profile.id == settings.activeProfileID
            var library = profileLibrary
            try profileRepository.delete(profile, from: &library)
            profileLibrary = library
            settings.activeProfileID = library.activeProfileID
            settings.profilePath = library.activeProfile?.filePath
            saveSettings()
            statusText = "\(t(.deleted)) \(profile.name)"
            if wasActive {
                reloadRunningCoreAfterProfileChange()
            }
        } catch {
            statusText = displayError(error)
        }
    }

    func activateProfile(_ profile: ProxyProfile) {
        profileLibrary.activeProfileID = profile.id
        settings.activeProfileID = profile.id
        settings.profilePath = profile.filePath
        do {
            try profileRepository.save(profileLibrary)
            saveSettings()
            statusText = "\(t(.activeProfile)): \(profile.name)"
            reloadRunningCoreAfterProfileChange()
        } catch {
            statusText = displayError(error)
        }
    }

    private func importExternalProfiles(_ candidates: [ExternalProfileCandidate]) {
        do {
            var library = profileLibrary
            let summary = try profileRepository.importExternalProfiles(candidates, into: &library)
            profileLibrary = library
            if let firstImported = summary.imported.first {
                activateProfile(firstImported)
            } else {
                settings.activeProfileID = library.activeProfileID
                settings.profilePath = library.activeProfile?.filePath
                saveSettings()
            }
            externalProfileCandidates = profileRepository.discoverExternalProfiles()
            externalProfileScanCompleted = true
            statusText = externalImportStatus(summary)
        } catch {
            statusText = displayError(error)
        }
    }

    private func reloadRunningCoreAfterProfileChange() {
        guard isRunning else { return }
        Task {
            do {
                let launch = launchSettings()
                // profile 改动后不重启内核，优先通过 controller 热重载生成后的 runtime YAML。
                try ChumenConfigurationBuilder.writeRuntimeConfig(settings: launch, paths: paths)
                settings = launch
                saveSettings()
                try await mihomoClient().reloadConfig(path: paths.runtimeConfigURL.path, force: true)
                statusText = t(.runtimeConfigReloaded)
                await refreshAll()
            } catch {
                statusText = displayError(error)
            }
        }
    }

    private func externalImportStatus(_ summary: ExternalProfileImportSummary) -> String {
        [
            "\(t(.imported)) \(summary.imported.count)",
            "\(t(.skipped)) \(summary.skipped.count)",
            "\(t(.failed)) \(summary.failed.count)"
        ].joined(separator: " / ")
    }

    func useDetectedCore() {
        if let candidate = ChumenRuntimeSettings.firstExecutableCoreCandidate() {
            settings.corePath = candidate
            saveSettings()
            statusText = t(.coreDetected)
        } else {
            statusText = t(.coreNotFound)
        }
    }

    func start() {
        guard !isCoreTransitioning else { return }
        let launch = launchSettings()
        resetTunRuntimeState(for: launch)
        resetConnectionTrafficBreakdown()
        resetMemoryTelemetry()
        isCoreTransitioning = true
        statusText = t(.pending)

        coreTransitionTask = Task { [weak self, manager] in
            do {
                // Process.run / helper 安装可能阻塞，放到 detached task，避免 SwiftUI 主线程卡住。
                try await Task.detached(priority: .userInitiated) {
                    try manager.start(settings: launch)
                }.value

                guard let self, !Task.isCancelled else { return }
                self.settings = launch
                self.isRunning = true
                self.statusText = self.t(.running)
                self.saveSettings()
                self.startControllerStreams()

                if launch.setSystemProxyOnStart {
                    do {
                        try await self.setSystemProxy(true, using: launch)
                        self.systemProxyEnabled = true
                        self.statusText = self.t(.systemProxyEnabled)
                    } catch {
                        self.statusText = self.displayError(error)
                    }
                    await self.refreshSystemProxyStateAsync()
                }

                self.isCoreTransitioning = false
                self.coreTransitionTask = nil
                try? await Task.sleep(for: .milliseconds(600))
                await self.refreshAll()
            } catch {
                guard let self, !Task.isCancelled else { return }
                self.isRunning = manager.isRunning
                self.isCoreTransitioning = false
                self.statusText = self.displayError(error)
                self.coreTransitionTask = nil
            }
        }
    }

    func stop() {
        guard !isCoreTransitioning else { return }
        stopControllerStreams()
        autoRefreshTask?.cancel()
        autoRefreshTask = nil
        isCoreTransitioning = true
        statusText = t(.pending)
        let shouldClearProxy = settings.clearSystemProxyOnStop && systemProxyEnabled
        let stopSettings = settings

        coreTransitionTask = Task { [weak self, manager] in
            await Task.detached(priority: .userInitiated) {
                manager.stop()
            }.value

            guard let self, !Task.isCancelled else { return }
            self.isRunning = false
            self.statusText = self.t(.stopped)

            if shouldClearProxy {
                do {
                    try await self.setSystemProxy(false, using: stopSettings)
                    self.systemProxyEnabled = false
                    self.statusText = self.t(.systemProxyDisabled)
                } catch {
                    self.statusText = self.displayError(error)
                }
                await self.refreshSystemProxyStateAsync()
            }

            self.isCoreTransitioning = false
            self.coreTransitionTask = nil
        }
    }

    func restart() {
        guard !isCoreTransitioning else { return }
        let launch = launchSettings()
        resetTunRuntimeState(for: launch)
        resetConnectionTrafficBreakdown()
        resetMemoryTelemetry()
        stopControllerStreams()
        autoRefreshTask?.cancel()
        autoRefreshTask = nil
        isCoreTransitioning = true
        statusText = t(.coreRestartRequested)

        coreTransitionTask = Task { [weak self, manager] in
            do {
                try await Task.detached(priority: .userInitiated) {
                    try manager.restart(settings: launch)
                }.value
                guard let self, !Task.isCancelled else { return }
                self.settings = launch
                self.isRunning = true
                self.isCoreTransitioning = false
                self.statusText = self.t(.running)
                self.saveSettings()
                self.startControllerStreams()
                try? await Task.sleep(for: .milliseconds(600))
                await self.refreshAll()
                self.coreTransitionTask = nil
            } catch {
                guard let self, !Task.isCancelled else { return }
                self.isRunning = manager.isRunning
                self.isCoreTransitioning = false
                self.statusText = self.displayError(error)
                self.coreTransitionTask = nil
            }
        }
    }

    func testAPI() {
        Task {
            await refreshVersionAndConfig()
        }
    }

    func refreshAll() async {
        await refreshVersionAndConfig()
        await refreshTrafficAndMemory()
        await refreshProxies()
        await refreshProviders()
        await refreshConnections()
        await refreshRules()
        lastRefreshText = Date().formatted(date: .omitted, time: .standard)
    }

    func detectRunningCore() async {
        let manager = manager
        let ownsCore = await Task.detached(priority: .utility) {
            manager.isRunning || manager.hasManagedSidecar
        }.value
        do {
            _ = try await mihomoClient().version()
            if ownsCore {
                isRunning = true
                statusText = t(.running)
                startControllerStreams()
                await refreshAll()
            } else {
                // API 可用但不是本应用启动的内核，只读取状态，不接管 stop/restart 语义。
                isRunning = false
                statusText = t(.externalCoreDetected)
                apiText = t(.externalCoreDetectedHint)
            }
        } catch {
            isRunning = ownsCore
            statusText = ownsCore ? t(.controllerUnavailable) : t(.stopped)
        }
    }

    func refreshProxies() async {
        do {
            let response = try await mihomoClient().proxies()
            proxyGroups = response.proxies.values
                .filter(\.isGroup)
                .map(ProxyGroupSnapshot.init(proxy:))
                .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        } catch {
            statusText = displayError(error)
        }
    }

    func selectProxy(group: ProxyGroupSnapshot, name: String) {
        Task {
            do {
                try await mihomoClient().selectProxy(group: group.name, name: name)
                await refreshProxies()
                statusText = "\(group.name) -> \(name)"
            } catch {
                statusText = displayError(error)
            }
        }
    }

    func testDelay(name: String) {
        Task {
            do {
                let result = try await mihomoClient().delayProxy(name: name)
                proxyDelays[name] = result.delay
                statusText = "\(name): \(result.delay) ms"
                await refreshProxies()
            } catch {
                statusText = displayError(error)
            }
        }
    }

    func testGroupDelay(_ group: ProxyGroupSnapshot) {
        Task {
            do {
                let response = try await mihomoClient().delayGroup(name: group.name)
                coreToolResult = Self.jsonString(response)
                statusText = "\(t(.delayTest)) \(group.name)"
                await refreshProxies()
            } catch {
                statusText = displayError(error)
                coreToolResult = displayError(error)
            }
        }
    }

    func clearProxySelection(_ group: ProxyGroupSnapshot) {
        Task {
            do {
                try await mihomoClient().clearProxySelection(group: group.name)
                statusText = "\(group.name) \(t(.clearedSelection))"
                await refreshProxies()
            } catch {
                statusText = displayError(error)
            }
        }
    }

    func refreshProviders() async {
        do {
            proxyProviders = try await mihomoClient().proxyProviders().providers.values
                .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        } catch {
            proxyProviders = []
        }

        do {
            ruleProviders = try await mihomoClient().ruleProviders().providers.values
                .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        } catch {
            ruleProviders = []
        }
    }

    func updateProxyProvider(_ provider: MihomoProvider) {
        Task {
            do {
                try await mihomoClient().updateProxyProvider(name: provider.name)
                statusText = "\(t(.updated)) \(provider.name)"
                await refreshProviders()
                await refreshProxies()
            } catch {
                statusText = displayError(error)
            }
        }
    }

    func healthcheckProxyProvider(_ provider: MihomoProvider) {
        Task {
            do {
                try await mihomoClient().healthcheckProxyProvider(name: provider.name)
                statusText = "\(t(.healthchecked)) \(provider.name)"
                await refreshProviders()
                await refreshProxies()
            } catch {
                statusText = displayError(error)
            }
        }
    }

    func updateRuleProvider(_ provider: MihomoProvider) {
        Task {
            do {
                try await mihomoClient().updateRuleProvider(name: provider.name)
                statusText = "\(t(.updated)) \(provider.name)"
                await refreshProviders()
                await refreshRules()
            } catch {
                statusText = displayError(error)
            }
        }
    }

    func refreshConnections() async {
        do {
            let response = try await mihomoClient().connections()
            applyConnectionTelemetry(response)
        } catch {
            statusText = displayError(error)
        }
    }

    func closeConnection(_ connection: MihomoConnection) {
        Task {
            do {
                try await mihomoClient().closeConnection(id: connection.id)
                await refreshConnections()
            } catch {
                statusText = displayError(error)
            }
        }
    }

    func closeAllConnections() {
        Task {
            do {
                try await mihomoClient().closeAllConnections()
                await refreshConnections()
                statusText = t(.connectionsClosed)
            } catch {
                statusText = displayError(error)
            }
        }
    }

    func refreshRules() async {
        do {
            rules = try await mihomoClient().rules().rules
        } catch {
            statusText = displayError(error)
        }
    }

    func setRuleDisabled(index: Int, disabled: Bool) {
        Task {
            do {
                try await mihomoClient().disableRules([String(index): disabled])
                statusText = disabled ? t(.ruleDisabled) : t(.ruleEnabled)
                await refreshRules()
            } catch {
                statusText = displayError(error)
            }
        }
    }

    func applyMode(_ mode: ProxyMode) {
        settings.mode = mode
        saveSettings()

        guard isRunning else { return }
        Task {
            do {
                try await mihomoClient().setMode(mode)
                apiText = "\(t(.mode)) -> \(mode.rawValue)"
                await refreshVersionAndConfig()
            } catch {
                apiText = displayError(error)
            }
        }
    }

    func setTunEnabled(_ enabled: Bool) {
        guard settings.enableTun != enabled else { return }
        manager.appendEventLog("TUN requested \(enabled ? "on" : "off"); coreRunning=\(isRunning)")
        settings.enableTun = enabled
        resetTunRuntimeState(for: settings)
        saveSettings()
        statusText = enabled ? t(.tunEnabled) : t(.tunDisabled)
        if isRunning {
            // TUN 是启动级配置，不能只 patch controller；运行中切换必须重启内核。
            restart()
        }
    }

    func setTunStack(_ stack: TunStack) {
        guard settings.tunStack != stack else { return }
        settings.tunStack = stack
        saveSettings()
        if isRunning {
            restart()
        }
    }

    func toggleSystemProxy() {
        guard !isCoreTransitioning else { return }
        let shouldEnable = !systemProxyEnabled
        let proxySettings = settings
        statusText = t(.pending)

        Task {
            do {
                try await setSystemProxy(shouldEnable, using: proxySettings)
                systemProxyEnabled = shouldEnable
                statusText = shouldEnable ? t(.systemProxyEnabled) : t(.systemProxyDisabled)
                await refreshSystemProxyStateAsync()
            } catch {
                statusText = displayError(error)
            }
        }
    }

    func refreshSystemProxyState() {
        Task {
            await refreshSystemProxyStateAsync()
        }
    }

    private func refreshSystemProxyStateAsync() async {
        let proxySettings = settings
        let proxyManager = systemProxyManager(for: proxySettings)
        do {
            let state = try await Task.detached(priority: .utility) {
                try proxyManager.currentState()
            }.value
            let currentSettings = settings
            let ownedByChumen = state.matches(host: currentSettings.systemProxyHost, port: currentSettings.mixedPort)
            systemProxyEnabled = ownedByChumen
            systemProxyStateText = systemProxyText(for: state, ownedByChumen: ownedByChumen, settings: currentSettings)
        } catch {
            systemProxyStateText = displayError(error)
        }
    }

    func openDataDirectory() {
        NSWorkspace.shared.open(paths.appHome)
    }

    func showMainWindow() {
        // 平时作为状态栏应用隐藏 Dock；用户主动打开窗口时恢复 regular 以显示 Dock 图标。
        NSApplication.shared.setActivationPolicy(.regular)
        NSApplication.shared.activate(ignoringOtherApps: true)
        Task { @MainActor in
            self.orderSingleMainWindowFront()
        }
    }

    func quit() {
        prepareForQuit()
        NSApplication.shared.terminate(nil)
    }

    func prepareForQuit() {
        guard !isPreparingForQuit else { return }
        isPreparingForQuit = true
        coreTransitionTask?.cancel()
        coreTransitionTask = nil
        stopControllerStreams()
        autoRefreshTask?.cancel()
        autoRefreshTask = nil
        if settings.clearSystemProxyOnStop, systemProxyEnabled {
            disableSystemProxySynchronously()
        }
        // 状态栏退出必须同步停掉本应用启动的内核，避免代理/TUN 进程残留。
        manager.stop(waitForExit: true)
        isRunning = false
        statusText = t(.stopped)
    }

    private func handleCoreLog(_ text: String) {
        logs.append(text)
        guard settings.enableTun else { return }

        // TUN 初始化失败通常只出现在 mihomo 日志里，这里提取成 UI 可读状态。
        let lowercased = text.lowercased()
        guard lowercased.contains("tun"),
              lowercased.contains("error") || lowercased.contains("operation not permitted") else {
            return
        }

        let message = compactLogMessage(from: text)
        tunRuntimeFailed = true
        tunRuntimeFailureMessage = message
        statusText = "\(t(.tunFailed)): \(tunFailureTitle(for: message))"
    }

    private func resetTunRuntimeState(for settings: ChumenRuntimeSettings) {
        tunRuntimeFailed = false
        tunRuntimeFailureMessage = ""
    }

    func clearLogs() {
        logs.removeAll()
        runtimeLogs.removeAll()
    }

    private func orderSingleMainWindowFront() {
        let windows = NSApplication.shared.windows.filter { window in
            window.canBecomeMain && window.title == "Chumen"
        }
        for duplicate in windows.dropFirst() {
            duplicate.close()
        }
        guard let window = windows.first else { return }
        if window.isMiniaturized {
            window.deminiaturize(nil)
        }
        window.makeKeyAndOrderFront(nil)
    }

    func reloadRuntimeConfigViaAPI() {
        Task {
            do {
                let launch = launchSettings()
                try ChumenConfigurationBuilder.writeRuntimeConfig(settings: launch, paths: paths)
                try await mihomoClient().reloadConfig(path: paths.runtimeConfigURL.path, force: true)
                settings = launch
                saveSettings()
                statusText = t(.runtimeConfigReloaded)
                await refreshAll()
            } catch {
                statusText = displayError(error)
                coreToolResult = displayError(error)
            }
        }
    }

    func restartKernelViaAPI() {
        runCoreTool(success: t(.coreRestartRequested)) { client in
            try await client.restartKernel()
        }
    }

    func flushFakeIPCache() {
        runCoreTool(success: t(.fakeIPFlushed)) { client in
            try await client.flushFakeIPCache()
        }
    }

    func flushDNSCache() {
        runCoreTool(success: t(.dnsCacheFlushed)) { client in
            try await client.flushDNSCache()
        }
    }

    func updateConfigGeo() {
        runCoreTool(success: t(.geoUpdated)) { client in
            try await client.updateConfigGeo()
        }
    }

    func upgradeGeo() {
        runCoreTool(success: t(.geoUpdated)) { client in
            try await client.upgradeGeo()
        }
    }

    func upgradeUI() {
        runCoreTool(success: t(.webUIUpdated)) { client in
            try await client.upgradeUI()
        }
    }

    func debugGC() {
        runCoreTool(success: t(.debugGCDone)) { client in
            try await client.debugGC()
        }
    }

    func queryDNS() {
        Task {
            do {
                let response = try await mihomoClient().dnsQuery(
                    name: dnsQueryName.trimmingCharacters(in: .whitespacesAndNewlines),
                    type: dnsQueryType.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "A" : dnsQueryType
                )
                coreToolResult = Self.jsonString(response)
                statusText = t(.dnsQueryDone)
            } catch {
                statusText = displayError(error)
                coreToolResult = displayError(error)
            }
        }
    }

    func getStorageValue() {
        Task {
            do {
                let response = try await mihomoClient().storage(key: storageKey)
                storageValue = Self.jsonString(response)
                coreToolResult = storageValue
                statusText = t(.storageRead)
            } catch {
                statusText = displayError(error)
                coreToolResult = displayError(error)
            }
        }
    }

    func putStorageValue() {
        Task {
            do {
                let value = try Self.parseJSON(storageValue)
                try await mihomoClient().putStorage(key: storageKey, value: value)
                statusText = t(.storageWritten)
            } catch {
                statusText = displayError(error)
                coreToolResult = displayError(error)
            }
        }
    }

    func deleteStorageValue() {
        Task {
            do {
                try await mihomoClient().deleteStorage(key: storageKey)
                statusText = t(.storageDeleted)
            } catch {
                statusText = displayError(error)
                coreToolResult = displayError(error)
            }
        }
    }

    func callRawAPI() {
        Task {
            do {
                let body = rawAPIBody.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : Data(rawAPIBody.utf8)
                let response = try await mihomoClient().raw(path: rawAPIPath, method: rawAPIMethod.uppercased(), body: body)
                coreToolResult = response.body.isEmpty ? "HTTP \(response.statusCode)" : response.body
                statusText = "HTTP \(response.statusCode)"
            } catch {
                statusText = displayError(error)
                coreToolResult = displayError(error)
            }
        }
    }

    func openDashboardURL() {
        guard let url = URL(string: "http://\(settings.externalControllerHost):\(settings.externalControllerPort)/ui") else { return }
        NSWorkspace.shared.open(url)
    }

    func saveSettings() {
        do {
            try paths.ensureDirectories()
            try settingsStore.save(settings)
        } catch {
            statusText = displayError(error)
        }
    }

    private func refreshVersionAndConfig() async {
        do {
            let client = try mihomoClient()
            let version = try await client.version()
            let configs = try await client.configs()
            apiText = "mihomo \(version.version ?? t(.unknown)) / \(t(.mode)) \(configs.mode ?? t(.unknown))"
            if let rawMode = configs.mode, let mode = ProxyMode(rawValue: rawMode) {
                settings.mode = mode
            }
        } catch {
            apiText = displayError(error)
        }
    }

    private func refreshTrafficAndMemory() async {
        // /traffic 和 /memory 是流式端点，普通 URLSession 请求会等到超时；后台轮询只做本地内存兜底。
        await refreshManagedMemoryFallback()
    }

    private func setSystemProxy(_ enabled: Bool, using settings: ChumenRuntimeSettings) async throws {
        let proxyManager = systemProxyManager(for: settings)
        try await Task.detached(priority: .userInitiated) {
            if enabled {
                try proxyManager.enable()
            } else {
                try proxyManager.disable()
            }
        }.value
    }

    private func disableSystemProxySynchronously() {
        do {
            try systemProxyManager(for: settings).disable()
            systemProxyEnabled = false
            statusText = t(.systemProxyDisabled)
        } catch {
            statusText = displayError(error)
        }
    }

    private func startControllerStreams() {
        startLogStream()
        startTelemetryStreams()
        startAutoRefresh()
    }

    private func stopControllerStreams() {
        logStream.stop()
        trafficStream.stop()
        memoryStream.stop()
        connectionsStream.stop()
    }

    private func startLogStream() {
        guard let url = settings.controllerBaseURL else { return }
        logStream.start(baseURL: url, secret: settings.secret) { [weak self] text in
            Task { @MainActor in
                self?.runtimeLogs.append(text)
            }
        }
    }

    private func startTelemetryStreams() {
        guard let url = settings.controllerBaseURL else { return }
        trafficStream.start(baseURL: url, secret: settings.secret, path: "/traffic") { [weak self] event in
            Task { @MainActor in
                self?.uploadSpeed = event.up ?? self?.uploadSpeed ?? 0
                self?.downloadSpeed = event.down ?? self?.downloadSpeed ?? 0
                self?.uploadTotal = event.upTotal ?? self?.uploadTotal ?? 0
                self?.downloadTotal = event.downTotal ?? self?.downloadTotal ?? 0
            }
        } onError: { [weak self] text in
            Task { @MainActor in self?.runtimeLogs.append(text + "\n") }
        }

        memoryStream.start(baseURL: url, secret: settings.secret, path: "/memory") { [weak self] event in
            Task { @MainActor in
                guard let self else { return }
                if let inuse = event.inuse, inuse > 0 {
                    self.memoryInUse = inuse
                    self.memoryLimit = event.oslimit ?? self.memoryLimit
                    self.memoryUnavailable = false
                }
            }
        } onError: { [weak self] text in
            Task { @MainActor in self?.runtimeLogs.append(text + "\n") }
        }

        connectionsStream.start(
            baseURL: url,
            secret: settings.secret,
            path: "/connections",
            queryItems: [URLQueryItem(name: "interval", value: "1000")]
        ) { [weak self] event in
            Task { @MainActor in
                self?.applyConnectionTelemetry(event)
            }
        } onError: { [weak self] text in
            Task { @MainActor in self?.runtimeLogs.append(text + "\n") }
        }
    }

    private func applyConnectionTelemetry(_ response: MihomoConnectionsResponse) {
        connections = response.connections
        uploadTotal = response.uploadTotal ?? uploadTotal
        downloadTotal = response.downloadTotal ?? downloadTotal
        connectionTrafficAccumulator.apply(connections: response.connections)
        proxyRoutedUploadTotal = connectionTrafficAccumulator.proxyUploadTotal
        proxyRoutedDownloadTotal = connectionTrafficAccumulator.proxyDownloadTotal
        directRoutedUploadTotal = connectionTrafficAccumulator.directUploadTotal
        directRoutedDownloadTotal = connectionTrafficAccumulator.directDownloadTotal
        unknownRoutedUploadTotal = connectionTrafficAccumulator.unknownUploadTotal
        unknownRoutedDownloadTotal = connectionTrafficAccumulator.unknownDownloadTotal
    }

    private func resetConnectionTrafficBreakdown() {
        connectionTrafficAccumulator.reset()
        proxyRoutedUploadTotal = 0
        proxyRoutedDownloadTotal = 0
        directRoutedUploadTotal = 0
        directRoutedDownloadTotal = 0
        unknownRoutedUploadTotal = 0
        unknownRoutedDownloadTotal = 0
    }

    private func refreshManagedMemoryFallback() async {
        let manager = manager
        let rss = await Task.detached(priority: .utility) {
            manager.managedRSSBytes()
        }.value
        if let rss, rss > 0 {
            memoryInUse = rss
            memoryLimit = 0
            memoryUnavailable = false
        } else if isRunning, memoryInUse == 0, memoryLimit == 0 {
            memoryUnavailable = true
        }
    }

    private func resetMemoryTelemetry() {
        memoryInUse = 0
        memoryLimit = 0
        memoryUnavailable = false
    }

    private func startAutoRefresh() {
        autoRefreshTask?.cancel()
        autoRefreshTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(5))
                guard let self, !Task.isCancelled else { return }
                await self.refreshConnections()
                await self.refreshTrafficAndMemory()
            }
        }
    }

    private func launchSettings() -> ChumenRuntimeSettings {
        var launch = settings
        if (launch.corePath.isEmpty || !FileManager.default.isExecutableFile(atPath: launch.corePath)),
           let candidate = ChumenRuntimeSettings.firstExecutableCoreCandidate() {
            launch.corePath = candidate
        }
        if let activeProfile {
            launch.profilePath = activeProfile.filePath
            launch.activeProfileID = activeProfile.id
        }
        return launch
    }

    private func mihomoClient() throws -> MihomoClient {
        guard let url = settings.controllerBaseURL else {
            throw ChumenError.invalidControllerURL
        }
        return MihomoClient(baseURL: url, secret: settings.secret)
    }

    private func systemProxyManager(for settings: ChumenRuntimeSettings) -> SystemProxyManager {
        SystemProxyManager(host: settings.systemProxyHost, port: settings.mixedPort)
    }

    private func systemProxyText(for state: SystemProxyState, ownedByChumen: Bool, settings: ChumenRuntimeSettings) -> String {
        guard let service = state.service else { return t(.noService) }
        if ownedByChumen {
            return "\(service): \(t(.on)) \(settings.systemProxyHost):\(settings.mixedPort)"
        }
        if state.isEnabled {
            let address = state.summaryAddress.map { " \($0)" } ?? ""
            return "\(service): \(t(.externalProxy))\(address)"
        }
        return "\(service): \(t(.off))"
    }

    static func formatBytes(_ bytes: Int64) -> String {
        if bytes == 0 {
            return "0 KB"
        }
        return ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }

    private static func formatDirectionalBytes(up: Int64, down: Int64, rate: Bool) -> String {
        let upParts = byteParts(up)
        let downParts = byteParts(down)
        let suffix = rate ? "/s" : ""
        if upParts.unit == downParts.unit, !upParts.unit.isEmpty {
            return "↑\(upParts.value) ↓\(downParts.value) \(upParts.unit)\(suffix)"
        }
        return "↑\(byteText(upParts))\(suffix) ↓\(byteText(downParts))\(suffix)"
    }

    private static func formatFixedDirectionalBytes(up: Int64, down: Int64, rate: Bool) -> String {
        let upParts = byteParts(up)
        let downParts = byteParts(down)
        let suffix = rate ? "/s" : ""
        if upParts.unit == downParts.unit, !upParts.unit.isEmpty {
            return "↑\(fixedByteValue(upParts.value)) ↓\(fixedByteValue(downParts.value)) \(upParts.unit)\(suffix)"
        }
        return "↑\(fixedByteText(upParts))\(suffix) ↓\(fixedByteText(downParts))\(suffix)"
    }

    private static func fixedByteValue(_ value: String) -> String {
        let maxWidth = 4
        guard value.count < maxWidth else { return value }
        return String(repeating: " ", count: maxWidth - value.count) + value
    }

    private static func fixedByteText(_ parts: (value: String, unit: String)) -> String {
        fixedByteValue(byteText(parts))
    }

    private static func formatFixedRateText(_ bytes: Int64) -> String {
        "\(fixedByteText(byteParts(bytes)))/s"
    }

    private static func byteParts(_ bytes: Int64) -> (value: String, unit: String) {
        let text = formatBytes(bytes)
        guard let split = text.lastIndex(of: " ") else {
            return (text, "")
        }
        return (String(text[..<split]), String(text[text.index(after: split)...]))
    }

    private static func byteText(_ parts: (value: String, unit: String)) -> String {
        parts.unit.isEmpty ? parts.value : "\(parts.value) \(parts.unit)"
    }

    private func runCoreTool(success: String, operation: @escaping @Sendable (MihomoClient) async throws -> Void) {
        Task {
            do {
                try await operation(mihomoClient())
                statusText = success
                coreToolResult = success
            } catch {
                statusText = displayError(error)
                coreToolResult = displayError(error)
            }
        }
    }

    private static func jsonString<T: Encodable>(_ value: T) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(value), let text = String(data: data, encoding: .utf8) else {
            return "\(value)"
        }
        return text
    }

    private static func parseJSON(_ text: String) throws -> MihomoJSONValue {
        guard let data = text.data(using: .utf8) else {
            throw ChumenError.commandFailed("Invalid UTF-8 JSON.")
        }
        return try JSONDecoder().decode(MihomoJSONValue.self, from: data)
    }

    private func compactLogMessage(from text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let range = trimmed.range(of: "msg=\"") else {
            return trimmed
        }

        let messageStart = range.upperBound
        guard let end = trimmed[messageStart...].lastIndex(of: "\"") else {
            return String(trimmed[messageStart...])
        }
        return String(trimmed[messageStart..<end])
    }

    private func tunFailureTitle(for message: String) -> String {
        let lowercased = message.lowercased()
        if lowercased.contains("add route") || lowercased.contains("file exists") || lowercased.contains("route exists") {
            return t(.tunRouteConflict)
        }
        if lowercased.contains("operation not permitted") || lowercased.contains("permission") || lowercased.contains("administrator") {
            return t(.tunPermissionRequired)
        }
        return t(.ineffective)
    }
}
