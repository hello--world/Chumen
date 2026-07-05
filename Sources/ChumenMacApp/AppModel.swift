import AppKit
import Combine
import Foundation
import ChumenCore
import Security
import STTextView

enum ProfileSectionEditorKind: String, CaseIterable, Identifiable {
    case rules
    case proxies
    case proxyGroups

    var id: String { rawValue }

    var yamlKey: String {
        switch self {
        case .rules: "rules"
        case .proxies: "proxies"
        case .proxyGroups: "proxy-groups"
        }
    }

    var titleKey: L10n.Key {
        switch self {
        case .rules: .editRules
        case .proxies: .editNodes
        case .proxyGroups: .editProxyGroups
        }
    }

    var systemImage: String {
        switch self {
        case .rules: "list.bullet.rectangle"
        case .proxies: "point.3.connected.trianglepath.dotted"
        case .proxyGroups: "rectangle.3.group"
        }
    }
}

struct ProfileSectionEditorState: Identifiable, Equatable {
    let profile: ProxyProfile
    let kind: ProfileSectionEditorKind

    var id: String { "\(profile.id)-\(kind.rawValue)" }
}

enum ProfileAppendixEditorTarget: Identifiable, Equatable {
    case global
    case profile(ProxyProfile)

    var id: String {
        switch self {
        case .global: "global"
        case let .profile(profile): "profile-\(profile.id)"
        }
    }
}

struct ConnectionReportSample: Identifiable, Equatable, Sendable {
    let timestamp: Date
    let activeCount: Int
    let proxyCount: Int
    let directCount: Int
    let uploadSpeed: Int64
    let downloadSpeed: Int64

    var id: Date { timestamp }
}

struct LogReportSample: Identifiable, Equatable, Sendable {
    let timestamp: Date
    let errorCount: Int
    let warningCount: Int
    let totalLines: Int

    var id: Date { timestamp }
}

private struct ProfileContentCacheEntry: Sendable {
    var content: String
    var sections: [YAMLTopLevelSection]
    var topLevelBlocks: [String: String]
}

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
    @Published var editingProfileMetadata: ProxyProfile?
    @Published var profileMetadataEditorName = ""
    @Published var profileMetadataEditorRemoteURL = ""
    @Published var profileEditorName = ""
    @Published var profileEditorRemoteURL = ""
    @Published var profileEditorText = ""
    @Published var profileEditorVisualSections: [YAMLTopLevelSection] = []
    @Published var profileEditorIsLoading = false
    @Published var editingProfileSection: ProfileSectionEditorState?
    @Published var profileSectionEditorText = ""
    @Published var profileSectionEditorVisualSections: [YAMLTopLevelSection] = []
    @Published var profileSectionEditorIsLoading = false
    @Published var editingProfileAppendix: ProfileAppendixEditorTarget?
    @Published var profileAppendixEditorText = ""
    @Published var profileAppendixEditorVisualSections: [YAMLTopLevelSection] = []
    @Published var externalProfileCandidates: [ExternalProfileCandidate] = []
    @Published var externalProfileScanCompleted = false
    @Published var startupImportPromptPresented = false
    @Published var proxyGroups: [ProxyGroupSnapshot] = []
    @Published var proxyProviders: [MihomoProvider] = []
    @Published var ruleProviders: [MihomoProvider] = []
    @Published var proxyDelays: [String: Int] = [:]
    @Published var connections: [MihomoConnection] = []
    @Published var connectionReportSamples: [ConnectionReportSample] = []
    @Published var logReportSamples: [LogReportSample] = []
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
    @Published var systemProxyRuntimeFailed = false
    @Published var systemProxyRuntimeFailureMessage = ""
    @Published var tunRuntimeFailed = false
    @Published var tunRuntimeFailureMessage = ""
    @Published var coreToolResult = ""
    @Published var dnsQueryName = "example.com"
    @Published var dnsQueryType = "A"
    @Published var storageKey = ""
    @Published var storageValue = "{}"
    @Published var rawAPIMethod = "GET"
    @Published var rawAPIPath = "/version"
    @Published var rawAPIBody = ""
    @Published var aiMessages: [ChumenAIChatMessage] = []
    @Published var aiInputText = ""
    @Published var aiAPIKeyInput = ""
    @Published var aiAPIKeyStored = false
    @Published var aiIsSending = false
    @Published var aiPendingChanges: [ChumenAIProposedChange] = []
    @Published var aiStatusText = ""
    @Published var pinInput = ""
    @Published var pinSetupPIN = ""
    @Published var pinSetupConfirm = ""
    @Published var pinStatusText = ""
    @Published var pinVaultExists = false
    @Published var pinSetupRequired = false
    @Published var pinSetupProtectAgeKey = false
    @Published var pinStorageLocked = false
    @Published var pinAppLocked = false
    @Published var pinAppLockOnLaunch = false
    @Published var pinStorageKind: ChumenAgeKeyStorageKind = .local

    let paths: ChumenPaths
    let configSync: ChumenConfigSyncService

    private let manager: CoreProcessManager
    private var profileRepository: ProfileRepository
    private var settingsStore: ChumenSettingsStore
    private let pinVault: ChumenPINVault
    private var protectionKeyStore: ChumenConfigProtectionKeyStore
    private var unlockedAgeKeyPair: MihomoAgeKeyPair?
    private let logStream = MihomoLogStream()
    private let trafficStream = MihomoEventStream<MihomoTraffic>()
    private let memoryStream = MihomoEventStream<MihomoMemory>()
    private let connectionsStream = MihomoEventStream<MihomoConnectionsResponse>()
    private var connectionTrafficAccumulator = ConnectionTrafficAccumulator()
    private var shouldSeedConnectionTrafficSnapshot = true
    private var lastTrafficEventDate: Date?
    private var lastConnectionTelemetryDate: Date?
    private var lastConnectionUploadTotal: Int64?
    private var lastConnectionDownloadTotal: Int64?
    private var lastConnectionReportSampleDate: Date?
    private var lastLogReportSampleDate: Date?
    private var autoRefreshTask: Task<Void, Never>?
    private var profileEditorLoadTask: Task<Void, Never>?
    private var profileSectionEditorLoadTask: Task<Void, Never>?
    private var profileVisualPreloadTask: Task<Void, Never>?
    private var profileContentCache: [String: ProfileContentCacheEntry] = [:]
    private var profileEditorOriginalText = ""
    private var coreTransitionTask: Task<Void, Never>?
    private var settingsAutosaveTask: Task<Void, Never>?
    private var aiTask: Task<Void, Never>?
    private var pendingTunToggleTarget: Bool?
    private var lastSavedSettings: ChumenRuntimeSettings
    private var isPreparingForQuit = false
    private let aiKeychainStore = ChumenAIKeychainStore()
    private let aiClient = ChumenAIClient()
    private let notificationService: ChumenNotificationService

    init(notificationService: ChumenNotificationService = ChumenNotificationService()) {
        self.notificationService = notificationService
        let paths = (try? ChumenPaths.defaultPaths()) ?? ChumenPaths(appHome: URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("chumen"))
        let bootstrapKeyStore = Self.makeProtectionKeyStore(paths: paths, storage: .local)
        let settingsStore = ChumenSettingsStore(paths: paths, protectionKeyStore: bootstrapKeyStore)
        let pinVault = ChumenPINVault(paths: paths)
        self.paths = paths
        self.configSync = ChumenConfigSyncService(paths: paths)
        self.protectionKeyStore = bootstrapKeyStore
        self.pinVault = pinVault
        self.settingsStore = settingsStore
        try? paths.ensureDirectories()

        var loadedSettings: ChumenRuntimeSettings
        var library: ProfileLibrary
        let shouldDeferStartup: Bool
        if pinVault.exists {
            self.pinVaultExists = true
            let detectedPINStorage = pinVault.storageKind() ?? .local
            self.pinStorageKind = detectedPINStorage
            let storedVault = try? pinVault.load(preferredStorage: detectedPINStorage)
            let appLockOnLaunch = storedVault?.lockAppOnLaunch ?? false
            self.pinAppLockOnLaunch = appLockOnLaunch

            // PIN has two jobs: it can protect the age key, and it can optionally lock the app.
            // Default installs keep the app usable by auto-unlocking the PIN-protected age key with
            // Chumen's local wrapping key. Only the explicit app-lock flag should block startup.
            if !appLockOnLaunch,
               let keyPair = try? pinVault.autoUnlock(preferredStorage: detectedPINStorage),
               let protectedState = try? Self.loadProtectedConfiguration(
                    paths: paths,
                    storage: detectedPINStorage,
                    ageKeyPair: keyPair
               ) {
                self.protectionKeyStore = protectedState.keyStore
                self.settingsStore = protectedState.settingsStore
                self.profileRepository = protectedState.profileRepository
                self.unlockedAgeKeyPair = keyPair
                loadedSettings = protectedState.settings
                library = protectedState.library
                self.pinStorageLocked = false
                self.pinStatusText = ""
                shouldDeferStartup = false
            } else {
                // Existing vaults from older builds may not have an auto-unlock copy. In that case
                // ask once for the PIN, then loadUnlockedConfiguration will backfill auto-unlock
                // when app-lock is disabled.
                loadedSettings = ChumenSettingsStore.defaultSettings()
                library = ProfileLibrary()
                self.pinStorageLocked = true
                self.pinStatusText = L10n.text(.pinRequired, language: loadedSettings.language ?? .system)
                self.profileRepository = ProfileRepository(
                    paths: paths,
                    protectConfigFiles: loadedSettings.protectConfigFiles,
                    protectionKeyStore: bootstrapKeyStore,
                    corePath: loadedSettings.corePath
                )
                shouldDeferStartup = true
            }
        } else {
            // First pass is read-only: if the decoded/default settings require PIN protection, we
            // must not migrate plaintext settings or profiles yet because migration writes would
            // create an unwrapped age identity before the user chooses PIN/Keychain/local storage.
            loadedSettings = settingsStore.load(migrateOnLoad: false)
            let activeKeyStore = Self.makeProtectionKeyStore(paths: paths, storage: loadedSettings.ageKeyStorage)
            self.protectionKeyStore = activeKeyStore
            let activeSettingsStore = ChumenSettingsStore(paths: paths, protectionKeyStore: activeKeyStore)
            self.settingsStore = activeSettingsStore
            let repository = ProfileRepository(
                paths: paths,
                protectConfigFiles: loadedSettings.protectConfigFiles,
                protectionKeyStore: activeKeyStore,
                corePath: loadedSettings.corePath
            )
            self.profileRepository = repository
            if loadedSettings.protectAgeKeyWithPIN {
                library = ProfileLibrary()
            } else {
                loadedSettings = activeSettingsStore.load(migrateOnLoad: true)
                library = repository.load()
                if library.activeProfileID == nil {
                    library.activeProfileID = loadedSettings.activeProfileID
                }
                if let activeProfile = library.activeProfile,
                   loadedSettings.activeProfileID != activeProfile.id || loadedSettings.profilePath != activeProfile.filePath {
                    loadedSettings.activeProfileID = activeProfile.id
                    loadedSettings.profilePath = activeProfile.filePath
                    try? activeSettingsStore.save(loadedSettings)
                }
            }
            let needsSecuritySetup = !loadedSettings.securitySetupCompleted
            let needsPINSetup = loadedSettings.protectAgeKeyWithPIN || needsSecuritySetup
            self.pinSetupRequired = needsPINSetup
            self.pinVaultExists = false
            self.pinSetupProtectAgeKey = loadedSettings.protectAgeKeyWithPIN
            self.pinStorageKind = loadedSettings.ageKeyStorage
            self.pinAppLockOnLaunch = false
            self.pinStatusText = needsPINSetup
                ? L10n.text(.pinSetupRequired, language: loadedSettings.language ?? .system)
                : ""
            if needsPINSetup {
                let generatedPIN = Self.generateDefaultPIN()
                self.pinSetupPIN = generatedPIN
                self.pinSetupConfirm = generatedPIN
            }
            shouldDeferStartup = needsPINSetup
        }
        self.settings = loadedSettings
        self.profileLibrary = library
        self.manager = CoreProcessManager(paths: paths, protectionKeyStore: self.protectionKeyStore)
        self.lastSavedSettings = loadedSettings
        self.aiAPIKeyStored = aiKeychainStore.hasAPIKey()
        self.aiStatusText = loadedSettings.ai.usesLocalOllama
            ? L10n.text(.aiOllamaReady, language: loadedSettings.language ?? .system)
            : (self.aiAPIKeyStored ? L10n.text(.aiKeyStored, language: loadedSettings.language ?? .system) : L10n.text(.aiSearchOnly, language: loadedSettings.language ?? .system))

        notificationService.onLog = { [manager = self.manager] message in
            manager.appendEventLog(message)
        }

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
                if status != 0 {
                    self.notify(title: self.t(.notificationCoreExited), body: self.statusText, level: .warning)
                }
            }
        }

        statusText = t(.stopped)
        apiText = t(.apiNotTested)
        preloadProfileVisualData(for: library.profiles, force: false)
        refreshSystemProxyState()
        if shouldDeferStartup {
            statusText = pinStatusText.isEmpty ? t(.pending) : pinStatusText
        } else {
            presentStartupImportPromptIfNeeded()
            Task {
            // 启动 GUI 时先探测已有 controller，避免误把其他客户端启动的内核当成自己管理的进程。
                await detectRunningCore()
                if settings.autoStartCoreOnLaunch, !isRunning {
                    start()
                }
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

    func sendTestNotification() {
        notify(
            title: t(.notificationTestTitle),
            body: t(.notificationTestBody),
            level: .info
        )
    }

    func syncBackendTitle(_ backend: ChumenSyncBackendKind) -> String {
        configSync.backendTitle(backend, language: language)
    }

    func setConfigSyncBackend(_ backend: ChumenSyncBackendKind) {
        configSync.setBackend(backend)
    }

    func chooseConfigSyncDirectory(_ url: URL) {
        configSync.setDirectory(url)
        statusText = t(.syncDirectorySelected)
    }

    func setCloudKitContainerIdentifier(_ identifier: String) {
        configSync.setCloudKitContainerIdentifier(identifier)
    }

    func pushConfigSync() {
        saveSettings()
        Task {
            do {
                try await configSync.push(
                    appSettings: settings,
                    profileLibrary: profileLibrary,
                    readProfileContent: { [profileRepository] profile in
                        try profileRepository.profileContent(profile)
                    }
                )
                statusText = t(.syncUploaded)
                notify(title: t(.syncUploaded), body: t(.syncCompleted), level: .success)
            } catch {
                statusText = displayError(error)
                notify(title: t(.syncFailed), body: statusText, level: .failure)
            }
        }
    }

    func pullConfigSync() {
        guard !isCoreTransitioning else { return }
        Task {
            do {
                let imported = try await configSync.pull(
                    currentSettings: settings,
                    protectionKeyStore: protectionKeyStore
                )
                settings = imported.settings
                profileLibrary = imported.profileLibrary
                lastSavedSettings = imported.settings
                profileContentCache.removeAll()
                preloadProfileVisualData(for: imported.profileLibrary.profiles, force: true)
                statusText = t(.syncDownloaded)
                notify(title: t(.syncDownloaded), body: t(.syncCompleted), level: .success)
                if isRunning {
                    restart()
                }
            } catch {
                statusText = displayError(error)
                notify(title: t(.syncFailed), body: statusText, level: .failure)
            }
        }
    }

    func checkCloudKitSyncStatus() {
        Task {
            do {
                try await configSync.checkCloudKitStatus()
                statusText = configSync.statusText
            } catch {
                statusText = displayError(error)
            }
        }
    }

    private func notify(title: String, body: String, level: ChumenNotificationLevel = .info) {
        // Notifications are user-visible failures/successes, so mirror them into the process log.
        // This keeps transient macOS banners from becoming the only diagnostic record.
        manager.appendEventLog("notification[\(level.logName)] \(title): \(body)")
        notificationService.notify(title: title, body: body, level: level)
    }

    private struct ProfileLaunchRecovery {
        var launchSettings: ChumenRuntimeSettings
        var profileName: String
        var profilePath: String
    }

    private func recoverUnreadableActiveProfileForDefaultLaunch(after error: Error) -> ProfileLaunchRecovery? {
        guard isAgeIdentityMismatch(error), let failedProfile = activeProfile else {
            return nil
        }

        // Recovery is deliberately non-destructive: the encrypted profile remains in the library
        // and on disk, but it is no longer the active launch input. A mismatched age identity cannot
        // be repaired by retrying with a fresh key, so the app falls back to Chumen's default DIRECT
        // runtime to keep the UI/API usable for re-import or manual recovery.
        profileLibrary.activeProfileID = nil
        settings.activeProfileID = nil
        settings.profilePath = nil

        do {
            try profileRepository.save(profileLibrary)
            try settingsStore.save(settings)
            lastSavedSettings = settings
        } catch {
            manager.appendEventLog("profile-recovery save failed: \(error.localizedDescription)")
        }

        manager.appendEventLog(
            "profile-recovery disabled active profile \(failedProfile.id) \(failedProfile.filePath): \(error.localizedDescription)"
        )

        var fallback = launchSettings()
        fallback.activeProfileID = nil
        fallback.profilePath = nil
        return ProfileLaunchRecovery(
            launchSettings: fallback,
            profileName: failedProfile.name,
            profilePath: failedProfile.filePath
        )
    }

    private func startRecoveredDefaultRuntime(
        recovery: ProfileLaunchRecovery,
        manager: CoreProcessManager,
        notificationTitle: String
    ) async -> Bool {
        do {
            try await Task.detached(priority: .userInitiated) {
                try manager.start(settings: recovery.launchSettings, profileAppendixYAML: "")
            }.value

            settings = recovery.launchSettings
            isRunning = true
            isCoreTransitioning = false
            statusText = "\(t(.activeProfileDisabled)): \(recovery.profileName)"
            saveSettings()
            startControllerStreams()
            notify(
                title: notificationTitle,
                body: "\(t(.activeProfileDisabledBody)) \(recovery.profilePath)",
                level: .warning
            )

            if recovery.launchSettings.setSystemProxyOnStart {
                resetSystemProxyRuntimeState()
                systemProxyEnabled = true
                do {
                    try await setSystemProxy(true, using: recovery.launchSettings)
                    systemProxyEnabled = true
                    statusText = t(.systemProxyEnabled)
                    await refreshSystemProxyStateAsync()
                } catch {
                    systemProxyEnabled = false
                    recordSystemProxyFailure(error)
                }
            }

            coreTransitionTask = nil
            try? await Task.sleep(for: .milliseconds(600))
            await refreshAll()
            return true
        } catch {
            isRunning = manager.isRunning
            isCoreTransitioning = false
            statusText = recordCoreTransitionFailure(action: "recovery-start", error: error)
            notify(title: t(.notificationCoreFailed), body: statusText, level: .failure)
            coreTransitionTask = nil
            return true
        }
    }

    private static func profileEditorRecoveryTemplate(profile: ProxyProfile) -> String {
        """
        # Chumen could not decrypt the previous encrypted content for this profile.
        # Saving this editor will replace the unreadable file with a new config encrypted by the current age key.
        # Profile: \(profile.name)
        proxies: []
        proxy-groups:
          - name: PROXY
            type: select
            proxies:
              - DIRECT
        rules:
          - MATCH,DIRECT
        """
    }

    private static let blankProfileTemplate = """
    proxies: []
    proxy-groups:
      - name: PROXY
        type: select
        proxies:
          - DIRECT
    rules:
      - MATCH,DIRECT
    """

    private func isAgeIdentityMismatch(_ error: Error) -> Bool {
        let message = error.localizedDescription
        return message.contains("stored age identity cannot decrypt") ||
            message.contains("identity did not match any of the recipients") ||
            message.contains("incorrect identity for recipient block")
    }

    private func activeProfileNotificationBody() -> String {
        "\(t(.activeProfile)): \(activeProfile?.name ?? "-")"
    }

    private func recordCoreTransitionFailure(action: String, error: Error) -> String {
        let message = displayError(error)
        manager.appendEventLog("core \(action) failed: \(message)")
        if message != error.localizedDescription {
            manager.appendEventLog("core \(action) raw error: \(error.localizedDescription)")
        }
        return message
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

    var pinOverlayPresented: Bool {
        pinSetupRequired || pinStorageLocked || pinAppLocked
    }

    func unlockPIN() {
        do {
            try ChumenPINVault.validatePIN(pinInput)
            let keyPair = try pinVault.unlock(pin: pinInput, preferredStorage: pinStorageKind)
            if pinStorageLocked {
                try loadUnlockedConfiguration(ageKeyPair: keyPair)
            } else {
                unlockedAgeKeyPair = keyPair
                pinAppLocked = false
                pinStatusText = t(.pinUnlocked)
            }
            pinInput = ""
        } catch {
            pinStatusText = t(.pinIncorrect)
        }
    }

    func unlockAndDisablePINProtection() {
        do {
            try ChumenPINVault.validatePIN(pinInput)
            let keyPair = try pinVault.unlock(pin: pinInput, preferredStorage: pinStorageKind)
            if pinStorageLocked {
                try loadUnlockedConfiguration(ageKeyPair: keyPair)
            } else {
                unlockedAgeKeyPair = keyPair
                pinAppLocked = false
            }
            pinInput = ""
            disablePINProtection()
        } catch {
            pinStatusText = t(.pinIncorrect)
        }
    }

    func enablePINProtection() {
        guard pinSetupProtectAgeKey else {
            skipPINProtectionSetup()
            return
        }

        do {
            try ChumenPINVault.validatePIN(pinSetupPIN)
            guard pinSetupPIN == pinSetupConfirm else {
                pinStatusText = t(.pinMismatch)
                return
            }
            let corePath = try resolvedCorePathForPIN()
            let keyPair = try loadOrGenerateAgeKeyPair(corePath: corePath)
            try pinVault.create(
                pin: pinSetupPIN,
                keyPair: keyPair,
                lockAppOnLaunch: pinAppLockOnLaunch,
                storage: pinStorageKind
            )

            // The vault now owns the persistent age identity. Save settings through an in-memory
            // override, then remove any raw local/Keychain identity left by older builds.
            let unlockedStore = ChumenConfigProtectionKeyStore(ageKeyPair: keyPair)
            protectionKeyStore = unlockedStore
            settingsStore = ChumenSettingsStore(paths: paths, protectionKeyStore: unlockedStore)
            manager.updateProtectionKeyStore(unlockedStore)
            settings.protectAgeKeyWithPIN = true
            settings.securitySetupCompleted = true
            settings.ageKeyStorage = pinStorageKind
            try settingsStore.save(settings)
            try Self.makeProtectionKeyStore(paths: paths, storage: .local).deleteStoredAgeKeyPair()
            try loadUnlockedConfiguration(ageKeyPair: keyPair)

            pinSetupPIN = ""
            pinSetupConfirm = ""
            pinStatusText = t(.pinEnabled)
            statusText = t(.pinEnabled)
        } catch {
            pinStatusText = displayError(error)
        }
    }

    func skipPINProtectionSetup() {
        do {
            pinSetupProtectAgeKey = false
            let keyPair = try loadOrGenerateAgeKeyPair(corePath: resolvedCorePathForPIN())
            let rawStore = Self.makeProtectionKeyStore(paths: paths, storage: pinStorageKind)
            try rawStore.storeAgeKeyPair(keyPair)
            protectionKeyStore = rawStore
            settingsStore = ChumenSettingsStore(paths: paths, protectionKeyStore: rawStore)
            profileRepository = ProfileRepository(
                paths: paths,
                protectConfigFiles: settings.protectConfigFiles,
                protectionKeyStore: rawStore,
                corePath: settings.corePath
            )
            manager.updateProtectionKeyStore(rawStore)
            settings.protectAgeKeyWithPIN = false
            settings.securitySetupCompleted = true
            settings.ageKeyStorage = pinStorageKind
            pinSetupRequired = false
            pinSetupProtectAgeKey = false
            pinAppLockOnLaunch = false
            pinSetupPIN = ""
            pinSetupConfirm = ""
            try settingsStore.save(settings)
            lastSavedSettings = settings
            var library = profileRepository.load()
            if library.activeProfileID == nil {
                library.activeProfileID = settings.activeProfileID
            }
            if let activeProfile = library.activeProfile,
               settings.activeProfileID != activeProfile.id || settings.profilePath != activeProfile.filePath {
                settings.activeProfileID = activeProfile.id
                settings.profilePath = activeProfile.filePath
                try settingsStore.save(settings)
                lastSavedSettings = settings
            }
            profileLibrary = library
            profileContentCache.removeAll()
            preloadProfileVisualData(for: library.profiles, force: true)
            refreshSystemProxyState()
            pinStatusText = t(.pinDisabled)
            statusText = t(.pinDisabled)
            presentStartupImportPromptIfNeeded()
            Task {
                await detectRunningCore()
                if settings.autoStartCoreOnLaunch, !isRunning {
                    start()
                }
            }
        } catch {
            pinStatusText = displayError(error)
        }
    }

    func disablePINProtection() {
        guard let keyPair = unlockedAgeKeyPair else {
            pinStatusText = t(.pinRequired)
            pinAppLocked = true
            return
        }

        do {
            let rawStore = Self.makeProtectionKeyStore(paths: paths, storage: pinStorageKind)
            try rawStore.storeAgeKeyPair(keyPair)
            protectionKeyStore = rawStore
            settingsStore = ChumenSettingsStore(paths: paths, protectionKeyStore: rawStore)
            profileRepository = ProfileRepository(
                paths: paths,
                protectConfigFiles: settings.protectConfigFiles,
                protectionKeyStore: rawStore,
                corePath: settings.corePath
            )
            manager.updateProtectionKeyStore(rawStore)
            settings.protectAgeKeyWithPIN = false
            settings.securitySetupCompleted = true
            settings.ageKeyStorage = pinStorageKind
            try settingsStore.save(settings)
            try pinVault.delete()

            unlockedAgeKeyPair = nil
            pinVaultExists = false
            pinSetupRequired = false
            pinSetupProtectAgeKey = false
            pinStorageLocked = false
            pinAppLocked = false
            pinAppLockOnLaunch = false
            pinInput = ""
            lastSavedSettings = settings
            pinStatusText = t(.pinDisabled)
            statusText = t(.pinDisabled)
        } catch {
            pinStatusText = displayError(error)
        }
    }

    func lockAppWithPIN() {
        guard pinVaultExists else { return }
        pinInput = ""
        pinAppLocked = true
        pinStatusText = t(.pinLocked)
    }

    func regeneratePINSetupPIN() {
        let pin = Self.generateDefaultPIN()
        pinSetupPIN = pin
        pinSetupConfirm = pin
        pinStatusText = ""
    }

    func setPINAppLockOnLaunch(_ enabled: Bool) {
        pinAppLockOnLaunch = enabled
        guard pinVaultExists else { return }
        do {
            if !enabled, unlockedAgeKeyPair == nil {
                pinStatusText = t(.pinRequired)
                pinAppLocked = true
                return
            }
            let keyPair = enabled ? nil : unlockedAgeKeyPair
            try pinVault.updateLockAppOnLaunch(enabled, keyPair: keyPair, storage: pinStorageKind)
            pinStatusText = t(.saved)
        } catch {
            pinStatusText = displayError(error)
        }
    }

    func setPINStorageKind(_ storage: ChumenAgeKeyStorageKind) {
        guard storage != pinStorageKind else { return }
        do {
            if pinVaultExists {
                try pinVault.move(to: storage)
                pinStorageKind = storage
                settings.ageKeyStorage = storage
                if !pinStorageLocked {
                    try settingsStore.save(settings)
                    lastSavedSettings = settings
                }
            } else if !settings.protectAgeKeyWithPIN {
                let keyPair = try loadOrGenerateAgeKeyPair(corePath: resolvedCorePathForPIN())
                let rawStore = Self.makeProtectionKeyStore(paths: paths, storage: storage)
                try rawStore.storeAgeKeyPair(keyPair)
                protectionKeyStore = rawStore
                settingsStore = ChumenSettingsStore(paths: paths, protectionKeyStore: rawStore)
                profileRepository = ProfileRepository(
                    paths: paths,
                    protectConfigFiles: settings.protectConfigFiles,
                    protectionKeyStore: rawStore,
                    corePath: settings.corePath
                )
                manager.updateProtectionKeyStore(rawStore)
                pinStorageKind = storage
                settings.ageKeyStorage = storage
                try settingsStore.save(settings)
                lastSavedSettings = settings
            } else {
                pinStorageKind = storage
            }
            pinStatusText = t(.saved)
        } catch {
            pinStatusText = displayError(error)
        }
    }

    private struct ProtectedConfigurationState {
        let keyStore: ChumenConfigProtectionKeyStore
        let settingsStore: ChumenSettingsStore
        let profileRepository: ProfileRepository
        var settings: ChumenRuntimeSettings
        var library: ProfileLibrary
    }

    private static func loadProtectedConfiguration(
        paths: ChumenPaths,
        storage: ChumenAgeKeyStorageKind,
        ageKeyPair: MihomoAgeKeyPair
    ) throws -> ProtectedConfigurationState {
        let unlockedStore = ChumenConfigProtectionKeyStore(ageKeyPair: ageKeyPair)
        let settingsStore = ChumenSettingsStore(paths: paths, protectionKeyStore: unlockedStore)
        var loadedSettings = try settingsStore.loadOrThrow()
        let decodedProtectAgeKeyWithPIN = loadedSettings.protectAgeKeyWithPIN
        loadedSettings.protectAgeKeyWithPIN = true
        loadedSettings.ageKeyStorage = storage
        let profileRepository = ProfileRepository(
            paths: paths,
            protectConfigFiles: loadedSettings.protectConfigFiles,
            protectionKeyStore: unlockedStore,
            corePath: loadedSettings.corePath
        )
        var library = profileRepository.load()
        var needsSave = false
        if library.activeProfileID == nil {
            library.activeProfileID = loadedSettings.activeProfileID
        }
        if let activeProfile = library.activeProfile,
           loadedSettings.activeProfileID != activeProfile.id || loadedSettings.profilePath != activeProfile.filePath {
            loadedSettings.activeProfileID = activeProfile.id
            loadedSettings.profilePath = activeProfile.filePath
            needsSave = true
        }
        if !decodedProtectAgeKeyWithPIN {
            needsSave = true
        }
        if needsSave {
            try settingsStore.save(loadedSettings)
        }

        return ProtectedConfigurationState(
            keyStore: unlockedStore,
            settingsStore: settingsStore,
            profileRepository: profileRepository,
            settings: loadedSettings,
            library: library
        )
    }

    private func loadUnlockedConfiguration(ageKeyPair: MihomoAgeKeyPair) throws {
        let protectedState = try Self.loadProtectedConfiguration(
            paths: paths,
            storage: pinStorageKind,
            ageKeyPair: ageKeyPair
        )

        unlockedAgeKeyPair = ageKeyPair
        protectionKeyStore = protectedState.keyStore
        settingsStore = protectedState.settingsStore
        profileRepository = protectedState.profileRepository
        manager.updateProtectionKeyStore(protectedState.keyStore)
        settings = protectedState.settings
        profileLibrary = protectedState.library
        lastSavedSettings = protectedState.settings
        pinVaultExists = true
        pinSetupRequired = false
        pinStorageLocked = false
        pinAppLocked = false
        pinAppLockOnLaunch = (try? pinVault.load(preferredStorage: pinStorageKind)?.lockAppOnLaunch) ?? false
        if !pinAppLockOnLaunch {
            try? pinVault.updateLockAppOnLaunch(false, keyPair: ageKeyPair, storage: pinStorageKind)
        }
        pinStatusText = t(.pinUnlocked)
        statusText = t(.pinUnlocked)
        profileContentCache.removeAll()
        preloadProfileVisualData(for: protectedState.library.profiles, force: true)
        refreshSystemProxyState()
        presentStartupImportPromptIfNeeded()
        Task {
            await detectRunningCore()
            if settings.autoStartCoreOnLaunch, !isRunning {
                start()
            }
        }
    }

    private func resolvedCorePathForPIN() throws -> String {
        if !settings.corePath.isEmpty, FileManager.default.isExecutableFile(atPath: settings.corePath) {
            return settings.corePath
        }
        if let candidate = ChumenRuntimeSettings.firstExecutableCoreCandidate() {
            settings.corePath = candidate
            return candidate
        }
        throw ChumenError.missingCorePath
    }

    private nonisolated static func generateDefaultPIN() -> String {
        var bytes = [UInt8](repeating: 0, count: 4)
        let status = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        guard status == errSecSuccess else {
            return String(format: "%04d", Int.random(in: 0..<10_000))
        }
        let value = bytes.reduce(UInt32(0)) { ($0 << 8) | UInt32($1) }
        return String(format: "%04u", value % 10_000)
    }

    private func loadOrGenerateAgeKeyPair(corePath: String) throws -> MihomoAgeKeyPair {
        if let existing = try protectionKeyStore.loadAgeKeyPairIfPresent() {
            return existing
        }
        return try MihomoAgeRuntimeProtection.generateKeyPair(corePath: corePath)
    }

    private static func makeProtectionKeyStore(
        paths: ChumenPaths,
        storage: ChumenAgeKeyStorageKind
    ) -> ChumenConfigProtectionKeyStore {
        ChumenConfigProtectionKeyStore(
            ageIdentityURL: paths.ageIdentityURL,
            useKeychainForAgeKey: storage == .keychain
        )
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

    func importExternalDashboard(_ url: URL) {
        let dashboardURL = url.standardizedFileURL
        guard isUsableDashboardDirectory(dashboardURL) else {
            statusText = t(.dashboardImportInvalid)
            return
        }

        settings.useExternalDashboard(at: dashboardURL)
        saveSettings()
        statusText = t(.dashboardImported)
        reloadRuntimeConfigAfterDashboardChange()
    }

    func clearExternalDashboard() {
        guard !settings.externalUI.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }
        settings.clearExternalDashboard()
        saveSettings()
        statusText = t(.dashboardCleared)
        reloadRuntimeConfigAfterDashboardChange()
    }

    private func reloadRuntimeConfigAfterDashboardChange() {
        guard isRunning else { return }
        Task {
            do {
                let runtimeConfigURL = try ChumenConfigurationBuilder.writeRuntimeConfig(
                    settings: settings,
                    paths: paths,
                    profileAppendixYAML: activeProfileAppendixYAML,
                    protectionKeyStore: protectionKeyStore
                )
                defer {
                    ChumenConfigurationBuilder.cleanupRuntimePlaintextFile(runtimeConfigURL, paths: paths)
                }
                try await mihomoClient().reloadConfig(path: runtimeConfigURL.path, force: true)
                await refreshAll()
            } catch {
                statusText = displayError(error)
            }
        }
    }

    private func isUsableDashboardDirectory(_ url: URL) -> Bool {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            return false
        }
        return FileManager.default.fileExists(atPath: url.appendingPathComponent("index.html").path)
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

    var activeProfileAppendixYAML: String {
        activeProfile?.configAppendixYAML ?? ""
    }

    private func preloadProfileVisualData(for profiles: [ProxyProfile], force: Bool) {
        guard !profiles.isEmpty else { return }
        profileVisualPreloadTask?.cancel()
        let repository = profileRepository
        profileVisualPreloadTask = Task { [weak self] in
            guard let self else { return }
            for profile in profiles {
                guard !Task.isCancelled else { return }
                if !force, self.profileContentCache[profile.id] != nil {
                    continue
                }

                do {
                    let entry = try await Self.loadProfileContentCacheEntry(profile: profile, repository: repository)
                    guard !Task.isCancelled else { return }
                    self.profileContentCache[profile.id] = entry
                    self.applyProfileCacheToOpenEditors(profileID: profile.id, entry: entry)
                } catch {
                    continue
                }
            }
        }
    }

    private nonisolated static func loadProfileContentCacheEntry(
        profile: ProxyProfile,
        repository: ProfileRepository
    ) async throws -> ProfileContentCacheEntry {
        try await Task.detached(priority: .utility) {
            let content = try repository.profileContent(profile)
            return makeProfileContentCacheEntry(content)
        }.value
    }

    private nonisolated static func makeProfileContentCacheEntry(_ content: String) -> ProfileContentCacheEntry {
        ProfileContentCacheEntry(
            content: content,
            sections: YAMLTopLevelSection.parse(content),
            topLevelBlocks: topLevelBlocks(in: content)
        )
    }

    private nonisolated static func topLevelBlocks(in yaml: String) -> [String: String] {
        let lines = yaml.components(separatedBy: .newlines)
        var blocks: [String: String] = [:]
        var currentKey: String?
        var currentBlock: [String] = []

        func flush() {
            guard let currentKey else { return }
            let block = currentBlock.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            if !block.isEmpty {
                blocks[currentKey] = block
            }
        }

        for line in lines {
            if let key = ChumenConfigurationBuilder.topLevelKey(in: line) {
                flush()
                currentKey = key
                currentBlock = [line]
            } else if currentKey != nil {
                currentBlock.append(line)
            }
        }

        flush()
        return blocks
    }

    private nonisolated static func cachedTopLevelBlock(
        _ key: String,
        in entry: ProfileContentCacheEntry
    ) -> String {
        entry.topLevelBlocks[key] ?? "\(key):\n"
    }

    private nonisolated static func cachedVisualSections(
        _ key: String,
        in entry: ProfileContentCacheEntry,
        fallbackBlock: String
    ) -> [YAMLTopLevelSection] {
        let matched = entry.sections.filter { $0.key == key }
        return matched.isEmpty ? YAMLTopLevelSection.parse(fallbackBlock) : matched
    }

    private func rebuildProfileContentCache(_ content: String, for profile: ProxyProfile) {
        let profileID = profile.id
        Task { [weak self] in
            let entry = await Task.detached(priority: .utility) {
                Self.makeProfileContentCacheEntry(content)
            }.value
            guard let self else { return }
            self.profileContentCache[profileID] = entry
            self.applyProfileCacheToOpenEditors(profileID: profileID, entry: entry)
        }
    }

    private func applyProfileCacheToOpenEditors(profileID: String, entry: ProfileContentCacheEntry) {
        if editingProfile?.id == profileID, profileEditorText.isEmpty {
            profileEditorVisualSections = entry.sections
        }
        if let editingProfileSection, editingProfileSection.profile.id == profileID {
            let key = editingProfileSection.kind.yamlKey
            let block = Self.cachedTopLevelBlock(key, in: entry)
            if profileSectionEditorText.isEmpty || profileSectionEditorText == "\(key):\n" {
                profileSectionEditorVisualSections = Self.cachedVisualSections(key, in: entry, fallbackBlock: block)
            }
        }
    }

    var connectionAnalysisSnapshot: ConnectionAnalysisSnapshot {
        ConnectionAnalyzer.analyze(connections)
    }

    var logAnalysisSnapshot: LogAnalysisSnapshot {
        LogAnalyzer.analyze(processLog: logs, runtimeLog: runtimeLogs)
    }

    var activeProfileConfigUpdateText: String {
        guard let activeProfile else { return "-" }
        let fileURL = URL(fileURLWithPath: activeProfile.filePath)
        let modificationDate = (try? FileManager.default.attributesOfItem(atPath: fileURL.path)[.modificationDate] as? Date)
            ?? activeProfile.updatedAt
        return modificationDate.formatted(date: .omitted, time: .standard)
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

    var systemProxyRuntimeFailureDetail: String {
        guard systemProxyRuntimeFailed else { return "" }
        let message = systemProxyRuntimeFailureMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        return message.isEmpty ? t(.failed) : message
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
            preloadProfileVisualData(for: [profile], force: true)
            startupImportPromptPresented = false
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
                preloadProfileVisualData(for: [profile], force: true)
                startupImportPromptPresented = false
                remoteProfileURL = ""
                remoteProfileName = ""
                statusText = "\(t(.imported)) \(profile.name)"
            } catch {
                statusText = displayError(error)
            }
        }
    }

    func createBlankProfileForEditing() {
        do {
            var library = profileLibrary
            let profile = try profileRepository.createBlankProfile(
                name: t(.newProfile),
                content: Self.blankProfileTemplate,
                into: &library
            )
            profileLibrary = library
            rebuildProfileContentCache(Self.blankProfileTemplate, for: profile)
            startupImportPromptPresented = false
            statusText = "\(t(.created)) \(profile.name)"
            beginEditProfile(profile)
        } catch {
            statusText = displayError(error)
        }
    }

    var aiReady: Bool {
        settings.ai.isEnabled &&
            (!settings.ai.requiresAPIKey || aiAPIKeyStored) &&
            !settings.ai.baseURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            !settings.ai.model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func useLocalOllamaAI() {
        settings.ai.useLocalOllamaDefaults()
        saveSettings()
        aiStatusText = t(.aiOllamaReady)
    }

    func saveAIAPIKey() {
        let key = aiAPIKeyInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else {
            aiStatusText = t(.aiKeyMissing)
            return
        }

        do {
            try aiKeychainStore.saveAPIKey(key)
            aiAPIKeyInput = ""
            aiAPIKeyStored = true
            aiStatusText = t(.aiKeyStored)
        } catch {
            aiStatusText = displayError(error)
        }
    }

    func clearAIAPIKey() {
        do {
            try aiKeychainStore.deleteAPIKey()
            aiAPIKeyInput = ""
            aiAPIKeyStored = false
            aiStatusText = settings.ai.usesLocalOllama ? t(.aiOllamaReady) : t(.aiSearchOnly)
        } catch {
            aiStatusText = displayError(error)
        }
    }

    func clearAIMessages() {
        aiTask?.cancel()
        aiTask = nil
        aiMessages = []
        aiPendingChanges = []
        aiStatusText = aiReady ? "" : t(.aiSearchOnly)
    }

    func sendAIMessage() {
        let prompt = aiInputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prompt.isEmpty else { return }
        guard settings.ai.isEnabled else {
            aiStatusText = t(.aiSearchOnly)
            return
        }
        let apiKey: String
        if settings.ai.requiresAPIKey {
            guard let storedKey = try? aiKeychainStore.loadAPIKey(),
                  !storedKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                aiAPIKeyStored = false
                aiStatusText = t(.aiKeyMissing)
                return
            }
            apiKey = storedKey
        } else {
            apiKey = "ollama"
        }

        aiTask?.cancel()
        aiInputText = ""
        let userMessage = ChumenAIChatMessage(role: .user, content: prompt)
        aiMessages.append(userMessage)
        aiIsSending = true
        aiStatusText = t(.aiThinking)
        let requestMessages = Array(aiMessages.suffix(16))
        let aiSettings = settings.ai
        let systemPrompt = aiSystemPrompt()

        aiTask = Task { [weak self] in
            guard let self else { return }
            do {
                let response = try await aiClient.complete(
                    settings: aiSettings,
                    apiKey: apiKey,
                    systemPrompt: systemPrompt,
                    messages: requestMessages
                )
                guard !Task.isCancelled else { return }
                aiMessages.append(ChumenAIChatMessage(role: .assistant, content: response.reply))
                let normalizedChanges = response.changes.map { normalizeAIProposedChange($0) }
                if !normalizedChanges.isEmpty {
                    aiPendingChanges.append(contentsOf: normalizedChanges)
                    aiStatusText = "\(t(.aiPendingChanges)) \(normalizedChanges.count)"
                } else {
                    aiStatusText = ""
                }
                aiIsSending = false
                aiTask = nil
            } catch {
                guard !Task.isCancelled else { return }
                aiMessages.append(ChumenAIChatMessage(role: .assistant, content: displayError(error)))
                aiStatusText = displayError(error)
                aiIsSending = false
                aiTask = nil
            }
        }
    }

    func dismissAIProposedChange(_ change: ChumenAIProposedChange) {
        aiPendingChanges.removeAll { $0.id == change.id }
    }

    func applyAIProposedChange(_ change: ChumenAIProposedChange) {
        switch change.kind {
        case .importSubscription:
            applyAIImportSubscription(change)
        case .setMode:
            guard let mode = change.mode else {
                aiStatusText = t(.unsupportedFeature)
                return
            }
            applyMode(mode)
            dismissAIProposedChange(change)
            aiStatusText = t(.aiChangeApplied)
        case .setTun:
            guard let enabled = change.enabled else {
                aiStatusText = t(.unsupportedFeature)
                return
            }
            setTunEnabled(enabled)
            dismissAIProposedChange(change)
            aiStatusText = t(.aiChangeApplied)
        case .setSystemProxy:
            guard let enabled = change.enabled else {
                aiStatusText = t(.unsupportedFeature)
                return
            }
            if enabled != systemProxyEnabled {
                toggleSystemProxy()
            }
            dismissAIProposedChange(change)
            aiStatusText = t(.aiChangeApplied)
        case .setConfigAppendix:
            guard let yaml = change.configAppendixYAML else {
                aiStatusText = t(.unsupportedFeature)
                return
            }
            settings.configAppendixYAML = yaml
            saveSettings()
            reloadRunningCoreAfterProfileChange()
            dismissAIProposedChange(change)
            aiStatusText = t(.aiChangeApplied)
        case .reloadRuntimeConfig:
            reloadRuntimeConfigViaAPI()
            dismissAIProposedChange(change)
            aiStatusText = t(.aiChangeApplied)
        }
    }

    private func applyAIImportSubscription(_ change: ChumenAIProposedChange) {
        guard let urlString = change.subscriptionURL?.trimmingCharacters(in: .whitespacesAndNewlines),
              !urlString.isEmpty else {
            aiStatusText = t(.subscriptionURLEmpty)
            return
        }

        Task {
            do {
                let profile = try await importRemoteProfileFromAI(
                    urlString: urlString,
                    name: change.profileName?.trimmingCharacters(in: .whitespacesAndNewlines)
                )
                dismissAIProposedChange(change)
                aiStatusText = "\(t(.imported)) \(profile.name)"
            } catch {
                aiStatusText = displayError(error)
            }
        }
    }

    private func importRemoteProfileFromAI(urlString: String, name: String?) async throws -> ProxyProfile {
        var library = profileLibrary
        let profile = try await profileRepository.importRemoteProfile(
            urlString: urlString,
            name: name?.isEmpty == false ? name : nil,
            into: &library
        )
        profileLibrary = library
        activateProfile(profile)
        return profile
    }

    private func normalizeAIProposedChange(_ change: ChumenAIProposedChange) -> ChumenAIProposedChange {
        var normalized = change
        if normalized.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            normalized.title = aiTitle(for: normalized)
        }
        if normalized.detail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            normalized.detail = aiDetail(for: normalized)
        }
        if normalized.diff.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            normalized.diff = aiDiff(for: normalized)
        }
        return normalized
    }

    private func aiTitle(for change: ChumenAIProposedChange) -> String {
        switch change.kind {
        case .importSubscription:
            t(.importSubscription)
        case .setMode:
            t(.mode)
        case .setTun:
            t(.tunMode)
        case .setSystemProxy:
            t(.systemProxy)
        case .setConfigAppendix:
            t(.configAppendix)
        case .reloadRuntimeConfig:
            t(.reloadRuntimeConfig)
        }
    }

    private func aiDetail(for change: ChumenAIProposedChange) -> String {
        switch change.kind {
        case .importSubscription:
            change.subscriptionURL ?? ""
        case .setMode:
            change.mode?.rawValue ?? ""
        case .setTun, .setSystemProxy:
            (change.enabled ?? false) ? t(.on) : t(.off)
        case .setConfigAppendix:
            change.configAppendixYAML ?? ""
        case .reloadRuntimeConfig:
            t(.applySettingsToCore)
        }
    }

    private func aiDiff(for change: ChumenAIProposedChange) -> String {
        switch change.kind {
        case .importSubscription:
            return """
            diff --chumen a/profiles b/profiles
            --- a/profiles
            +++ b/profiles
            @@
            + \(t(.importSubscription)): \(change.subscriptionURL ?? "")
            + \(t(.displayName)): \(change.profileName ?? t(.unknown))
            """
        case .setMode:
            return aiSettingsDiff(label: t(.mode), oldValue: settings.mode.rawValue, newValue: change.mode?.rawValue ?? t(.unknown))
        case .setTun:
            return aiSettingsDiff(label: t(.tunMode), oldValue: settings.enableTun ? t(.on) : t(.off), newValue: (change.enabled ?? false) ? t(.on) : t(.off))
        case .setSystemProxy:
            return aiSettingsDiff(label: t(.systemProxy), oldValue: systemProxyEnabled ? t(.on) : t(.off), newValue: (change.enabled ?? false) ? t(.on) : t(.off))
        case .setConfigAppendix:
            return aiTextDiff(
                path: "settings/configAppendixYAML",
                oldText: settings.configAppendixYAML,
                newText: change.configAppendixYAML ?? ""
            )
        case .reloadRuntimeConfig:
            return """
            diff --chumen a/runtime b/runtime
            --- a/runtime
            +++ b/runtime
            @@
            + \(t(.reloadRuntimeConfig))
            """
        }
    }

    private func aiSettingsDiff(label: String, oldValue: String, newValue: String) -> String {
        """
        diff --chumen a/settings b/settings
        --- a/settings
        +++ b/settings
        @@
        - \(label): \(oldValue)
        + \(label): \(newValue)
        """
    }

    private func aiTextDiff(path: String, oldText: String, newText: String) -> String {
        let oldLines = oldText.trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: .newlines)
        let newLines = newText.trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: .newlines)
        let removed = oldLines
            .filter { !$0.isEmpty }
            .prefix(80)
            .map { "- \($0)" }
        let added = newLines
            .filter { !$0.isEmpty }
            .prefix(120)
            .map { "+ \($0)" }
        let body = (removed + added).joined(separator: "\n")
        return """
        diff --chumen a/\(path) b/\(path)
        --- a/\(path)
        +++ b/\(path)
        @@
        \(body.isEmpty ? "+ <empty>" : body)
        """
    }

    private func aiSystemPrompt() -> String {
        let profiles = profileLibrary.profiles.map { profile in
            "- \(profile.name): \(profile.remoteURL ?? profile.filePath)"
        }.joined(separator: "\n")
        let connectionAnalysis = connectionAnalysisSnapshot.aiContext
        let logAnalysis = logAnalysisSnapshot.aiContext
        return """
        \(ChumenAIKnowledgeBase.text)

        Current Chumen state:
        - running: \(isRunning)
        - mode: \(settings.mode.rawValue)
        - active profile: \(activeProfile?.name ?? "-")
        - system proxy enabled: \(systemProxyEnabled)
        - tun enabled: \(settings.enableTun)
        - mixed port: \(settings.mixedPort)
        - controller: \(settings.externalControllerHost):\(settings.externalControllerPort)
        - global append YAML:
        \(settings.configAppendixYAML.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "-" : settings.configAppendixYAML)

        Profiles:
        \(profiles.isEmpty ? "-" : profiles)

        \(connectionAnalysis)

        \(logAnalysis)

        Never claim a proposed change has been applied. Say it is waiting for review.
        Do not propose destructive delete operations.
        """
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

    func importExternalProfiles(_ candidates: [ExternalProfileCandidate]) {
        guard !candidates.isEmpty else { return }
        performExternalProfileImport(candidates)
    }

    func importExternalProfile(_ candidate: ExternalProfileCandidate) {
        performExternalProfileImport([candidate])
    }

    func dismissStartupImportPrompt() {
        startupImportPromptPresented = false
    }

    private func presentStartupImportPromptIfNeeded() {
        // First-run onboarding should appear only after the PIN/key choice is resolved. At that
        // point an empty profile library means Chumen has nothing useful to route with, so reuse
        // the existing client scanner and show an import-focused next step instead of dropping the
        // user into an empty dashboard.
        guard profileLibrary.profiles.isEmpty, !pinOverlayPresented else { return }
        startupImportPromptPresented = true
        if !externalProfileScanCompleted {
            scanExternalProfiles()
        }
    }

    func updateProfile(_ profile: ProxyProfile) {
        Task {
            do {
                var library = profileLibrary
                let updated = try await profileRepository.update(profile, in: &library)
                profileLibrary = library
                preloadProfileVisualData(for: [updated], force: true)
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

    func updateProfileViaProxy(_ profile: ProxyProfile) {
        Task {
            do {
                var library = profileLibrary
                let updated = try await profileRepository.update(
                    profile,
                    usingHTTPProxyHost: settings.systemProxyHost,
                    port: settings.mixedPort,
                    in: &library
                )
                profileLibrary = library
                preloadProfileVisualData(for: [updated], force: true)
                statusText = "\(t(.updated)) \(profile.name)"
                if isRunning, profile.id == settings.activeProfileID {
                    restart()
                }
            } catch {
                statusText = displayError(error)
            }
        }
    }

    func beginEditProfileMetadata(_ profile: ProxyProfile) {
        profileMetadataEditorName = profile.name
        profileMetadataEditorRemoteURL = profile.remoteURL ?? ""
        editingProfileMetadata = profile
    }

    func saveProfileMetadataEditor() {
        guard let editingProfileMetadata else { return }

        do {
            var library = profileLibrary
            let updated = try profileRepository.updateMetadata(
                editingProfileMetadata,
                name: profileMetadataEditorName,
                remoteURL: profileMetadataEditorRemoteURL,
                in: &library
            )
            profileLibrary = library
            self.editingProfileMetadata = nil
            profileMetadataEditorName = ""
            profileMetadataEditorRemoteURL = ""
            statusText = "\(t(.saved)) \(updated.name)"
        } catch {
            statusText = displayError(error)
        }
    }

    func cancelProfileMetadataEditor() {
        editingProfileMetadata = nil
        profileMetadataEditorName = ""
        profileMetadataEditorRemoteURL = ""
    }

    func beginEditProfile(_ profile: ProxyProfile) {
        profileEditorLoadTask?.cancel()
        profileEditorName = profile.name
        profileEditorRemoteURL = profile.remoteURL ?? ""
        profileEditorText = ""
        profileEditorOriginalText = ""
        profileEditorVisualSections = []
        profileEditorIsLoading = true
        editingProfile = profile

        if let entry = profileContentCache[profile.id] {
            profileEditorVisualSections = entry.sections
            profileEditorText = entry.content
            profileEditorOriginalText = entry.content
            profileEditorIsLoading = false
            return
        }

        let repository = profileRepository
        profileEditorLoadTask = Task { [weak self] in
            do {
                let entry = try await Self.loadProfileContentCacheEntry(profile: profile, repository: repository)
                guard !Task.isCancelled else { return }
                self?.profileContentCache[profile.id] = entry
                self?.profileEditorVisualSections = entry.sections
                self?.profileEditorText = entry.content
                self?.profileEditorOriginalText = entry.content
                self?.profileEditorIsLoading = false
            } catch {
                guard !Task.isCancelled else { return }
                guard let self else { return }
                if self.isAgeIdentityMismatch(error) {
                    let recoveryText = Self.profileEditorRecoveryTemplate(profile: profile)
                    self.profileEditorVisualSections = YAMLTopLevelSection.parse(recoveryText)
                    self.profileEditorText = recoveryText
                    self.profileEditorOriginalText = ""
                    self.profileEditorIsLoading = false
                    self.statusText = "\(self.t(.profileRecoveryEditorReady)) \(profile.name)"
                    self.manager.appendEventLog(
                        "profile-editor opened recovery template for \(profile.id) \(profile.filePath): \(error.localizedDescription)"
                    )
                } else {
                    self.profileEditorIsLoading = false
                    self.editingProfile = nil
                    self.statusText = self.displayError(error)
                }
            }
        }
    }

    func saveProfileEditor() {
        guard let editingProfile else { return }
        guard !profileEditorIsLoading else { return }
        do {
            let editorText = focusedYAMLCodeEditorText() ?? profileEditorText
            profileEditorText = editorText
            let contentChanged = editorText != profileEditorOriginalText
            var library = profileLibrary
            let updated = try profileRepository.saveContentAndMetadata(
                editingProfile,
                content: editorText,
                name: profileEditorName,
                remoteURL: profileEditorRemoteURL,
                in: &library
            )
            profileLibrary = library
            rebuildProfileContentCache(editorText, for: updated)
            self.editingProfile = nil
            profileEditorVisualSections = []
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
        profileEditorVisualSections = []
        profileEditorIsLoading = false
    }

    func beginEditProfileSection(_ profile: ProxyProfile, kind: ProfileSectionEditorKind) {
        profileSectionEditorLoadTask?.cancel()
        profileSectionEditorText = "\(kind.yamlKey):\n"
        profileSectionEditorVisualSections = YAMLTopLevelSection.parse(profileSectionEditorText)
        profileSectionEditorIsLoading = true
        editingProfileSection = ProfileSectionEditorState(profile: profile, kind: kind)

        if let entry = profileContentCache[profile.id] {
            let block = Self.cachedTopLevelBlock(kind.yamlKey, in: entry)
            profileSectionEditorVisualSections = Self.cachedVisualSections(kind.yamlKey, in: entry, fallbackBlock: block)
            profileSectionEditorText = block
            profileSectionEditorIsLoading = false
            return
        }

        let repository = profileRepository
        let yamlKey = kind.yamlKey
        profileSectionEditorLoadTask = Task { [weak self] in
            do {
                let entry = try await Self.loadProfileContentCacheEntry(profile: profile, repository: repository)
                guard !Task.isCancelled else { return }
                let block = Self.cachedTopLevelBlock(yamlKey, in: entry)
                self?.profileContentCache[profile.id] = entry
                self?.profileSectionEditorVisualSections = Self.cachedVisualSections(yamlKey, in: entry, fallbackBlock: block)
                self?.profileSectionEditorText = block
                self?.profileSectionEditorIsLoading = false
            } catch {
                guard !Task.isCancelled else { return }
                self?.profileSectionEditorIsLoading = false
                self?.editingProfileSection = nil
                self?.statusText = self?.displayError(error) ?? error.localizedDescription
            }
        }
    }

    func saveProfileSectionEditor() {
        guard let editingProfileSection else { return }
        guard !profileSectionEditorIsLoading else { return }

        do {
            let editorText = focusedYAMLCodeEditorText() ?? profileSectionEditorText
            profileSectionEditorText = editorText
            let current: String
            if let cachedContent = profileContentCache[editingProfileSection.profile.id]?.content {
                current = cachedContent
            } else {
                current = try profileRepository.profileContent(editingProfileSection.profile)
            }
            let content = Self.replacingTopLevelBlock(
                editingProfileSection.kind.yamlKey,
                in: current,
                with: editorText
            )
            var library = profileLibrary
            let updated = try profileRepository.saveContent(editingProfileSection.profile, content: content, in: &library)
            profileLibrary = library
            rebuildProfileContentCache(content, for: updated)
            self.editingProfileSection = nil
            profileSectionEditorText = ""
            profileSectionEditorVisualSections = []
            profileSectionEditorIsLoading = false
            statusText = "\(t(.saved)) \(t(editingProfileSection.kind.titleKey))"
            if isRunning, updated.id == settings.activeProfileID {
                reloadRunningCoreAfterProfileChange()
            }
        } catch {
            statusText = displayError(error)
        }
    }

    func cancelProfileSectionEditor() {
        profileSectionEditorLoadTask?.cancel()
        profileSectionEditorLoadTask = nil
        editingProfileSection = nil
        profileSectionEditorText = ""
        profileSectionEditorVisualSections = []
        profileSectionEditorIsLoading = false
    }

    func beginEditProfileAppendix(_ profile: ProxyProfile) {
        profileAppendixEditorText = profile.configAppendixYAML ?? ""
        profileAppendixEditorVisualSections = YAMLTopLevelSection.parse(profileAppendixEditorText)
        editingProfileAppendix = .profile(profile)
    }

    func beginEditGlobalProfileAppendix() {
        profileAppendixEditorText = settings.configAppendixYAML
        profileAppendixEditorVisualSections = YAMLTopLevelSection.parse(profileAppendixEditorText)
        editingProfileAppendix = .global
    }

    func saveProfileAppendixEditor() {
        guard let editingProfileAppendix else { return }

        do {
            let editorText = focusedYAMLCodeEditorText() ?? profileAppendixEditorText
            profileAppendixEditorText = editorText
            switch editingProfileAppendix {
            case .global:
                settings.configAppendixYAML = editorText
                saveSettings()
                statusText = "\(t(.saved)) \(t(.configAppendix))"
                reloadRunningCoreAfterProfileChange()
            case let .profile(profile):
                var library = profileLibrary
                let updated = try profileRepository.updateConfigAppendix(profile, yaml: editorText, in: &library)
                profileLibrary = library
                statusText = "\(t(.saved)) \(updated.name)"
                if isRunning, updated.id == settings.activeProfileID {
                    reloadRunningCoreAfterProfileChange()
                }
            }
            self.editingProfileAppendix = nil
            profileAppendixEditorText = ""
            profileAppendixEditorVisualSections = []
        } catch {
            statusText = displayError(error)
        }
    }

    func cancelProfileAppendixEditor() {
        editingProfileAppendix = nil
        profileAppendixEditorText = ""
        profileAppendixEditorVisualSections = []
    }

    func noteProfileScriptUnsupported() {
        statusText = "\(t(.extendScript)) \(t(.unsupportedFeature))"
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
            profileContentCache[profile.id] = nil
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
            startupImportPromptPresented = false
            statusText = "\(t(.activeProfile)): \(profile.name)"
            reloadRunningCoreAfterProfileChange()
        } catch {
            statusText = displayError(error)
        }
    }

    private nonisolated static func extractTopLevelBlock(_ key: String, from yaml: String) -> String {
        let lines = yaml.components(separatedBy: .newlines)
        var block: [String] = []
        var isCapturing = false

        for line in lines {
            if isCapturing {
                if !line.isEmpty, indentation(of: line) == 0 {
                    break
                }
                block.append(line)
                continue
            }

            if ChumenConfigurationBuilder.topLevelKey(in: line) == key {
                isCapturing = true
                block.append(line)
            }
        }

        let text = block.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? "\(key):\n" : text
    }

    private nonisolated static func replacingTopLevelBlock(_ key: String, in yaml: String, with editedBlock: String) -> String {
        let stripped = ChumenConfigurationBuilder.removeTopLevelKeys([key], from: yaml)
        let normalizedBlock = normalizedTopLevelBlock(key, editedBlock)
        return [stripped, normalizedBlock]
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .joined(separator: "\n\n")
    }

    private nonisolated static func normalizedTopLevelBlock(_ key: String, _ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "\(key): []" }

        if let firstLine = trimmed.components(separatedBy: .newlines).first,
           ChumenConfigurationBuilder.topLevelKey(in: firstLine) == key {
            return trimmed
        }

        let nested = trimmed.components(separatedBy: .newlines)
            .map { $0.isEmpty ? "" : "  \($0)" }
            .joined(separator: "\n")
        return "\(key):\n\(nested)"
    }

    private nonisolated static func indentation(of line: String) -> Int {
        var count = 0
        for character in line {
            if character == " " {
                count += 1
            } else if character == "\t" {
                count += 4
            } else {
                break
            }
        }
        return count
    }

    private func focusedYAMLCodeEditorText() -> String? {
        guard let textView = NSApplication.shared.keyWindow?.firstResponder as? STTextView,
              textView.identifier?.rawValue == "ChumenYAMLCodeEditor" else {
            return nil
        }
        return textView.text ?? ""
    }

    private func performExternalProfileImport(_ candidates: [ExternalProfileCandidate]) {
        do {
            var library = profileLibrary
            let summary = try profileRepository.importExternalProfiles(candidates, into: &library)
            profileLibrary = library
            if !library.profiles.isEmpty {
                startupImportPromptPresented = false
            }
            preloadProfileVisualData(for: summary.imported, force: true)
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
                let runtimeConfigURL = try ChumenConfigurationBuilder.writeRuntimeConfig(
                    settings: launch,
                    paths: paths,
                    profileAppendixYAML: activeProfileAppendixYAML,
                    protectionKeyStore: protectionKeyStore
                )
                defer {
                    ChumenConfigurationBuilder.cleanupRuntimePlaintextFile(runtimeConfigURL, paths: paths)
                }
                settings = launch
                saveSettings()
                try await mihomoClient().reloadConfig(path: runtimeConfigURL.path, force: true)
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
        guard !pinOverlayPresented else {
            statusText = pinStatusText.isEmpty ? t(.pinRequired) : pinStatusText
            return
        }
        guard !isCoreTransitioning else { return }
        let launch = launchSettings()
        let profileAppendixYAML = activeProfileAppendixYAML
        resetTunRuntimeState(for: launch)
        resetConnectionTrafficBreakdown()
        resetMemoryTelemetry()
        isCoreTransitioning = true
        statusText = t(.pending)

        coreTransitionTask = Task { [weak self, manager] in
            do {
                // Process.run / helper 安装可能阻塞，放到 detached task，避免 SwiftUI 主线程卡住。
                try await Task.detached(priority: .userInitiated) {
                    try manager.start(settings: launch, profileAppendixYAML: profileAppendixYAML)
                }.value

                guard let self, !Task.isCancelled else { return }
                self.settings = launch
                self.isRunning = true
                self.statusText = self.t(.running)
                self.saveSettings()
                self.startControllerStreams()
                self.notify(
                    title: self.t(.notificationCoreStarted),
                    body: self.activeProfileNotificationBody(),
                    level: .success
                )

                if launch.setSystemProxyOnStart {
                    self.resetSystemProxyRuntimeState()
                    self.systemProxyEnabled = true
                    do {
                        try await self.setSystemProxy(true, using: launch)
                        self.systemProxyEnabled = true
                        self.statusText = self.t(.systemProxyEnabled)
                        await self.refreshSystemProxyStateAsync()
                    } catch {
                        self.systemProxyEnabled = false
                        self.recordSystemProxyFailure(error)
                    }
                }

                self.isCoreTransitioning = false
                self.coreTransitionTask = nil
                try? await Task.sleep(for: .milliseconds(600))
                await self.refreshAll()
            } catch {
                guard let self, !Task.isCancelled else { return }
                let failureMessage = self.recordCoreTransitionFailure(action: "start", error: error)
                if let recovery = self.recoverUnreadableActiveProfileForDefaultLaunch(after: error),
                   await self.startRecoveredDefaultRuntime(
                       recovery: recovery,
                       manager: manager,
                       notificationTitle: self.t(.activeProfileDisabled)
                   ) {
                    return
                }
                self.isRunning = manager.isRunning
                self.isCoreTransitioning = false
                self.statusText = failureMessage
                self.notify(title: self.t(.notificationCoreFailed), body: self.statusText, level: .failure)
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
            self.notify(
                title: self.t(.notificationCoreStopped),
                body: self.activeProfileNotificationBody(),
                level: .info
            )

            if shouldClearProxy {
                self.resetSystemProxyRuntimeState()
                self.systemProxyEnabled = false
                    do {
                        try await self.setSystemProxy(false, using: stopSettings)
                        self.systemProxyEnabled = false
                        self.statusText = self.t(.systemProxyDisabled)
                        await self.refreshSystemProxyStateAsync()
                    } catch {
                        self.systemProxyEnabled = true
                        self.recordSystemProxyFailure(error)
                    }
                }

            self.isCoreTransitioning = false
            self.coreTransitionTask = nil
        }
    }

    func restart() {
        guard !pinOverlayPresented else {
            statusText = pinStatusText.isEmpty ? t(.pinRequired) : pinStatusText
            return
        }
        guard !isCoreTransitioning else { return }
        let launch = launchSettings()
        let profileAppendixYAML = activeProfileAppendixYAML
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
                    try manager.restart(settings: launch, profileAppendixYAML: profileAppendixYAML)
                }.value
                guard let self, !Task.isCancelled else { return }
                self.settings = launch
                self.isRunning = true
                self.isCoreTransitioning = false
                self.statusText = self.t(.running)
                self.saveSettings()
                self.startControllerStreams()
                self.notify(
                    title: self.t(.notificationCoreRestarted),
                    body: self.activeProfileNotificationBody(),
                    level: .success
                )
                self.pendingTunToggleTarget = nil
                try? await Task.sleep(for: .milliseconds(600))
                await self.refreshAll()
                self.coreTransitionTask = nil
            } catch {
                guard let self, !Task.isCancelled else { return }
                let failureMessage = self.recordCoreTransitionFailure(action: "restart", error: error)
                let wasTunToggle = self.pendingTunToggleTarget != nil
                self.pendingTunToggleTarget = nil
                self.isRunning = manager.isRunning
                self.isCoreTransitioning = false
                if wasTunToggle {
                    self.recordTunOperationFailure(error)
                } else if let recovery = self.recoverUnreadableActiveProfileForDefaultLaunch(after: error),
                          await self.startRecoveredDefaultRuntime(
                              recovery: recovery,
                              manager: manager,
                              notificationTitle: self.t(.activeProfileDisabled)
                    ) {
                    return
                } else {
                    self.statusText = failureMessage
                    self.notify(title: self.t(.notificationCoreFailed), body: self.statusText, level: .failure)
                }
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
                startControllerStreams()
                await refreshAll()
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
            pendingTunToggleTarget = enabled
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
        let previousEnabled = systemProxyEnabled
        let shouldEnable = !systemProxyEnabled
        let proxySettings = settings
        resetSystemProxyRuntimeState()
        systemProxyEnabled = shouldEnable
        statusText = shouldEnable ? t(.systemProxyEnabled) : t(.systemProxyDisabled)

        Task {
            do {
                try await setSystemProxy(shouldEnable, using: proxySettings)
                systemProxyEnabled = shouldEnable
                statusText = shouldEnable ? t(.systemProxyEnabled) : t(.systemProxyDisabled)
                await refreshSystemProxyStateAsync()
            } catch {
                systemProxyEnabled = previousEnabled
                recordSystemProxyFailure(error)
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
            resetSystemProxyRuntimeState()
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

    func restartApplication() {
        guard scheduleRelaunch() else {
            quit()
            return
        }
        prepareForQuit()
        NSApplication.shared.terminate(nil)
    }

    func prepareForQuit() {
        guard !isPreparingForQuit else { return }
        isPreparingForQuit = true
        if settings.disableTunOnQuit && settings.enableTun {
            // 退出时先持久化关闭 TUN，避免下次自动启动内核时继续启用 TUN 路由。
            settings.enableTun = false
            resetTunRuntimeState(for: settings)
            pendingTunToggleTarget = nil
        }
        saveSettings()
        coreTransitionTask?.cancel()
        coreTransitionTask = nil
        stopControllerStreams()
        autoRefreshTask?.cancel()
        autoRefreshTask = nil
        profileVisualPreloadTask?.cancel()
        profileVisualPreloadTask = nil
        if settings.clearSystemProxyOnStop, systemProxyEnabled {
            disableSystemProxySynchronously()
        }
        // 状态栏退出必须同步停掉本应用启动的内核，避免代理/TUN 进程残留。
        manager.stop(waitForExit: true)
        isRunning = false
        statusText = t(.stopped)
    }

    private func scheduleRelaunch() -> Bool {
        let bundlePath = Bundle.main.bundlePath
        guard !bundlePath.isEmpty else { return false }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = [
            "-c",
            "sleep 0.4; /usr/bin/open \(Self.shellQuoted(bundlePath))"
        ]

        do {
            try process.run()
            return true
        } catch {
            statusText = displayError(error)
            return false
        }
    }

    private static func shellQuoted(_ value: String) -> String {
        "'\(value.replacingOccurrences(of: "'", with: "'\\''"))'"
    }

    private func handleCoreLog(_ text: String) {
        appendProcessLog(text)
        guard settings.enableTun else { return }

        // TUN 初始化失败通常只出现在 mihomo 日志里，这里提取成 UI 可读状态。
        let lowercased = text.lowercased()
        guard lowercased.contains("tun"),
              lowercased.contains("error") || lowercased.contains("operation not permitted") else {
            return
        }

        let message = compactLogMessage(from: text)
        let alreadyReported = tunRuntimeFailed && tunRuntimeFailureMessage == message
        tunRuntimeFailed = true
        tunRuntimeFailureMessage = message
        statusText = "\(t(.tunFailed)): \(tunFailureTitle(for: message))"
        if !alreadyReported {
            notify(title: t(.tunFailed), body: tunRuntimeFailureDetail, level: .failure)
        }
    }

    private func resetTunRuntimeState(for settings: ChumenRuntimeSettings) {
        tunRuntimeFailed = false
        tunRuntimeFailureMessage = ""
    }

    private func resetSystemProxyRuntimeState() {
        systemProxyRuntimeFailed = false
        systemProxyRuntimeFailureMessage = ""
    }

    private func recordSystemProxyFailure(_ error: Error) {
        let message = displayError(error)
        systemProxyRuntimeFailed = true
        systemProxyRuntimeFailureMessage = message
        statusText = "\(t(.systemProxyFailed)): \(message)"
        notify(title: t(.systemProxyFailed), body: message, level: .failure)
    }

    private func recordTunOperationFailure(_ error: Error) {
        let message = displayError(error)
        tunRuntimeFailed = true
        tunRuntimeFailureMessage = message
        statusText = "\(t(.tunFailed)): \(message)"
        notify(title: t(.tunFailed), body: message, level: .failure)
    }

    func clearLogs() {
        logs.removeAll()
        runtimeLogs.removeAll()
        logReportSamples.removeAll()
        lastLogReportSampleDate = nil
    }

    private func appendProcessLog(_ text: String) {
        logs.append(text)
        appendLogReportSample()
    }

    private func appendRuntimeLog(_ text: String) {
        runtimeLogs.append(text)
        appendLogReportSample()
    }

    private func appendLogReportSample(now: Date = Date()) {
        if let lastLogReportSampleDate,
           now.timeIntervalSince(lastLogReportSampleDate) < 2 {
            return
        }

        let snapshot = logAnalysisSnapshot
        appendBounded(
            LogReportSample(
                timestamp: now,
                errorCount: snapshot.errorCount,
                warningCount: snapshot.warningCount,
                totalLines: snapshot.totalLines
            ),
            to: &logReportSamples,
            limit: 240
        )
        lastLogReportSampleDate = now
    }

    private func appendConnectionReportSample(from snapshot: ConnectionAnalysisSnapshot, now: Date = Date()) {
        if let lastConnectionReportSampleDate,
           now.timeIntervalSince(lastConnectionReportSampleDate) < 1 {
            return
        }

        appendBounded(
            ConnectionReportSample(
                timestamp: now,
                activeCount: snapshot.activeCount,
                proxyCount: snapshot.routeBuckets.first { $0.label == "proxy" }?.count ?? 0,
                directCount: snapshot.routeBuckets.first { $0.label == "direct" }?.count ?? 0,
                uploadSpeed: uploadSpeed,
                downloadSpeed: downloadSpeed
            ),
            to: &connectionReportSamples,
            limit: 360
        )
        lastConnectionReportSampleDate = now
    }

    private func appendBounded<T>(_ value: T, to values: inout [T], limit: Int) {
        values.append(value)
        if values.count > limit {
            values.removeFirst(values.count - limit)
        }
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
                let runtimeConfigURL = try ChumenConfigurationBuilder.writeRuntimeConfig(
                    settings: launch,
                    paths: paths,
                    profileAppendixYAML: activeProfileAppendixYAML,
                    protectionKeyStore: protectionKeyStore
                )
                defer {
                    ChumenConfigurationBuilder.cleanupRuntimePlaintextFile(runtimeConfigURL, paths: paths)
                }
                try await mihomoClient().reloadConfig(path: runtimeConfigURL.path, force: true)
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
        guard let url = settings.dashboardLaunchURL(paths: paths, language: language) else {
            statusText = t(.dashboardNotConfigured)
            return
        }
        NSWorkspace.shared.open(url)
    }

    func saveSettings() {
        settingsAutosaveTask?.cancel()
        settingsAutosaveTask = nil
        guard !pinStorageLocked, !pinSetupRequired else { return }
        guard settings != lastSavedSettings else { return }
        do {
            try paths.ensureDirectories()
            try settingsStore.save(settings)
            lastSavedSettings = settings
        } catch {
            statusText = displayError(error)
        }
    }

    func scheduleSettingsAutosave() {
        guard settings != lastSavedSettings else { return }
        settingsAutosaveTask?.cancel()
        settingsAutosaveTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(450))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                self?.saveSettings()
            }
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
        resetSystemProxyRuntimeState()
        do {
            try systemProxyManager(for: settings).disable()
            systemProxyEnabled = false
            statusText = t(.systemProxyDisabled)
        } catch {
            recordSystemProxyFailure(error)
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
                self?.appendRuntimeLog(text)
            }
        }
    }

    private func startTelemetryStreams() {
        guard let url = settings.controllerBaseURL else { return }
        trafficStream.start(baseURL: url, secret: settings.secret, path: "/traffic") { [weak self] event in
            Task { @MainActor in
                guard let self else { return }
                if event.up != nil || event.down != nil || event.upTotal != nil || event.downTotal != nil {
                    self.lastTrafficEventDate = Date()
                }
                self.uploadSpeed = event.up ?? self.uploadSpeed
                self.downloadSpeed = event.down ?? self.downloadSpeed
                self.uploadTotal = event.upTotal ?? self.uploadTotal
                self.downloadTotal = event.downTotal ?? self.downloadTotal
            }
        } onError: { [weak self] text in
            Task { @MainActor in self?.appendRuntimeLog(text + "\n") }
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
            Task { @MainActor in self?.appendRuntimeLog(text + "\n") }
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
            Task { @MainActor in self?.appendRuntimeLog(text + "\n") }
        }
    }

    private func applyConnectionTelemetry(_ response: MihomoConnectionsResponse) {
        connections = response.connections
        let connectionTotals = Self.connectionTrafficTotals(response.connections)
        let nextUploadTotal = Self.resolvedTrafficTotal(
            reported: response.uploadTotal,
            current: uploadTotal,
            activeConnectionTotal: connectionTotals.upload
        )
        let nextDownloadTotal = Self.resolvedTrafficTotal(
            reported: response.downloadTotal,
            current: downloadTotal,
            activeConnectionTotal: connectionTotals.download
        )
        applyConnectionSpeedFallback(uploadTotal: nextUploadTotal, downloadTotal: nextDownloadTotal)
        uploadTotal = nextUploadTotal
        downloadTotal = nextDownloadTotal

        let includeInitialSamples = shouldSeedConnectionTrafficSnapshot && !response.connections.isEmpty
        connectionTrafficAccumulator.apply(
            connections: response.connections,
            includeInitialSamples: includeInitialSamples
        )
        if !response.connections.isEmpty {
            shouldSeedConnectionTrafficSnapshot = false
        }
        proxyRoutedUploadTotal = connectionTrafficAccumulator.proxyUploadTotal
        proxyRoutedDownloadTotal = connectionTrafficAccumulator.proxyDownloadTotal
        directRoutedUploadTotal = connectionTrafficAccumulator.directUploadTotal
        directRoutedDownloadTotal = connectionTrafficAccumulator.directDownloadTotal
        unknownRoutedUploadTotal = connectionTrafficAccumulator.unknownUploadTotal
        unknownRoutedDownloadTotal = connectionTrafficAccumulator.unknownDownloadTotal
        appendConnectionReportSample(from: connectionAnalysisSnapshot)
    }

    private func applyConnectionSpeedFallback(uploadTotal: Int64, downloadTotal: Int64, at now: Date = Date()) {
        defer {
            lastConnectionTelemetryDate = now
            lastConnectionUploadTotal = uploadTotal
            lastConnectionDownloadTotal = downloadTotal
        }

        guard shouldUseConnectionSpeedFallback(at: now),
              let previousDate = lastConnectionTelemetryDate,
              let previousUploadTotal = lastConnectionUploadTotal,
              let previousDownloadTotal = lastConnectionDownloadTotal else {
            return
        }

        let elapsed = now.timeIntervalSince(previousDate)
        guard elapsed >= 0.25 else { return }

        uploadSpeed = Int64(Double(max(0, uploadTotal - previousUploadTotal)) / elapsed)
        downloadSpeed = Int64(Double(max(0, downloadTotal - previousDownloadTotal)) / elapsed)
    }

    private func shouldUseConnectionSpeedFallback(at now: Date) -> Bool {
        guard let lastTrafficEventDate else { return true }
        return now.timeIntervalSince(lastTrafficEventDate) > 2.5
    }

    private func resetConnectionTrafficBreakdown() {
        connectionTrafficAccumulator.reset()
        shouldSeedConnectionTrafficSnapshot = true
        lastTrafficEventDate = nil
        lastConnectionTelemetryDate = nil
        lastConnectionUploadTotal = nil
        lastConnectionDownloadTotal = nil
        uploadSpeed = 0
        downloadSpeed = 0
        proxyRoutedUploadTotal = 0
        proxyRoutedDownloadTotal = 0
        directRoutedUploadTotal = 0
        directRoutedDownloadTotal = 0
        unknownRoutedUploadTotal = 0
        unknownRoutedDownloadTotal = 0
        connectionReportSamples.removeAll()
        lastConnectionReportSampleDate = nil
    }

    private static func connectionTrafficTotals(_ connections: [MihomoConnection]) -> (upload: Int64, download: Int64) {
        connections.reduce(into: (upload: Int64(0), download: Int64(0))) { totals, connection in
            totals.upload += max(0, connection.upload ?? 0)
            totals.download += max(0, connection.download ?? 0)
        }
    }

    private static func resolvedTrafficTotal(
        reported: Int64?,
        current: Int64,
        activeConnectionTotal: Int64
    ) -> Int64 {
        let activeTotal = max(0, activeConnectionTotal)
        guard let reported else {
            return max(max(0, current), activeTotal)
        }
        return max(max(0, reported), activeTotal)
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
        } else {
            launch.profilePath = nil
            launch.activeProfileID = nil
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
