import ChumenCore
import SwiftUI
import UniformTypeIdentifiers

struct AppSettingsView: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var notifications: ChumenNotificationService
    @EnvironmentObject private var configSync: ChumenConfigSyncService
    @State private var choosingSyncDirectory = false

    var body: some View {
        Form {
            Section(model.t(.notifications)) {
                HStack {
                    Text(model.t(.notificationPermission))
                    Spacer()
                    Text(notificationPermissionText)
                        .foregroundStyle(notificationPermissionColor)
                }

                HStack {
                    Button {
                        notifications.requestAuthorizationIfNeeded()
                    } label: {
                        Label(model.t(.requestNotificationPermission), systemImage: "bell.badge")
                    }

                    Button {
                        model.sendTestNotification()
                    } label: {
                        Label(model.t(.testNotification), systemImage: "bell")
                    }
                }
            }

            Section(model.t(.pinProtection)) {
                Text(model.t(.pinDescription))
                    .font(.caption)
                    .foregroundStyle(ChumenStyle.mutedText)

                Picker(model.t(.pinStorage), selection: Binding(
                    get: { model.pinStorageKind },
                    set: { model.setPINStorageKind($0) }
                )) {
                    ForEach(ChumenAgeKeyStorageKind.allCases) { storage in
                        Text(pinStorageTitle(storage)).tag(storage)
                    }
                }
                .pickerStyle(.segmented)

                if model.pinVaultExists {
                    Toggle(model.t(.pinLockAppOnLaunch), isOn: Binding(
                        get: { model.pinAppLockOnLaunch },
                        set: { model.setPINAppLockOnLaunch($0) }
                    ))
                    Text(model.t(.pinLockAppOnLaunchHint))
                        .font(.caption)
                        .foregroundStyle(ChumenStyle.mutedText)

                    HStack {
                        Button {
                            model.lockAppWithPIN()
                        } label: {
                            Label(model.t(.pinLockNow), systemImage: "lock")
                        }

                        Button(role: .destructive) {
                            model.disablePINProtection()
                        } label: {
                            Label(model.t(.pinDisable), systemImage: "lock.open")
                        }
                    }
                } else {
                    SecureField(model.t(.pinValue), text: $model.pinSetupPIN)
                        .textFieldStyle(.roundedBorder)
                    SecureField(model.t(.pinConfirm), text: $model.pinSetupConfirm)
                        .textFieldStyle(.roundedBorder)

                    Toggle(model.t(.pinLockAppOnLaunch), isOn: Binding(
                        get: { model.pinAppLockOnLaunch },
                        set: { model.setPINAppLockOnLaunch($0) }
                    ))
                    Text(model.t(.pinLockAppOnLaunchHint))
                        .font(.caption)
                        .foregroundStyle(ChumenStyle.mutedText)

                    HStack {
                        Button {
                            model.skipPINProtectionSetup()
                        } label: {
                            Label(model.t(.pinSkip), systemImage: "xmark.circle")
                        }

                        Button {
                            model.enablePINProtection()
                        } label: {
                            Label(model.t(.pinEnable), systemImage: "key")
                        }
                    }
                }

                if !model.pinStatusText.isEmpty {
                    Text(model.pinStatusText)
                        .font(.caption)
                        .foregroundStyle(ChumenStyle.mutedText)
                }
            }

            Section(model.t(.configSync)) {
                Picker(model.t(.syncBackend), selection: Binding(
                    get: { configSync.settings.backend },
                    set: { model.setConfigSyncBackend($0) }
                )) {
                    ForEach(ChumenSyncBackendKind.allCases) { backend in
                        Text(model.syncBackendTitle(backend)).tag(backend)
                    }
                }
                .pickerStyle(.segmented)

                if configSync.settings.backend == .directory {
                    HStack {
                        Text(model.t(.syncDirectory))
                        Spacer()
                        Text(syncDirectoryText)
                            .font(.caption)
                            .foregroundStyle(ChumenStyle.mutedText)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .textSelection(.enabled)
                    }

                    Button {
                        choosingSyncDirectory = true
                    } label: {
                        Label(model.t(.chooseSyncDirectory), systemImage: "folder.badge.gearshape")
                    }
                } else {
                    TextField(model.t(.cloudKitContainerIdentifier), text: Binding(
                        get: { configSync.settings.cloudKitContainerIdentifier },
                        set: { model.setCloudKitContainerIdentifier($0) }
                    ))
                    .textFieldStyle(.roundedBorder)

                    Button {
                        model.checkCloudKitSyncStatus()
                    } label: {
                        Label(model.t(.checkCloudKitStatus), systemImage: "icloud")
                    }
                }

                HStack {
                    Button {
                        model.pushConfigSync()
                    } label: {
                        Label(model.t(.syncUpload), systemImage: "arrow.up.doc")
                    }
                    .disabled(configSync.isSyncing || syncActionUnavailable)

                    Button {
                        model.pullConfigSync()
                    } label: {
                        Label(model.t(.syncDownload), systemImage: "arrow.down.doc")
                    }
                    .disabled(configSync.isSyncing || syncActionUnavailable)
                }

                HStack {
                    Text(model.t(.lastSync))
                    Spacer()
                    Text(syncLastSyncedText)
                        .foregroundStyle(ChumenStyle.mutedText)
                }

                if !configSync.statusText.isEmpty {
                    Text(configSync.statusText)
                        .font(.caption)
                        .foregroundStyle(ChumenStyle.mutedText)
                }

                Text(model.t(.syncPlaintextWarning))
                    .font(.caption)
                    .foregroundStyle(ChumenStyle.mutedText)
            }

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
                Toggle(model.t(.enableTunOnStart), isOn: $model.settings.enableTunOnStart)
                Toggle(model.t(.clearProxyOnStop), isOn: $model.settings.clearSystemProxyOnStop)
                Toggle(model.t(.disableTunOnQuit), isOn: $model.settings.disableTunOnQuit)
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
        .onAppear {
            notifications.refreshAuthorizationState()
        }
        .onChange(of: model.settings) {
            model.scheduleSettingsAutosave()
        }
        .fileImporter(
            isPresented: $choosingSyncDirectory,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            if case let .success(urls) = result, let url = urls.first {
                model.chooseConfigSyncDirectory(url)
            }
        }
        .padding(.vertical, 8)
    }

    private var syncActionUnavailable: Bool {
        switch configSync.settings.backend {
        case .directory:
            configSync.settings.directoryPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .cloudKit:
            false
        }
    }

    private var syncDirectoryText: String {
        let path = configSync.settings.directoryPath.trimmingCharacters(in: .whitespacesAndNewlines)
        return path.isEmpty ? model.t(.syncDirectoryNotSelected) : path
    }

    private var syncLastSyncedText: String {
        guard let date = configSync.settings.lastSyncedAt else { return "-" }
        return date.formatted(date: .abbreviated, time: .standard)
    }

    private func pinStorageTitle(_ storage: ChumenAgeKeyStorageKind) -> String {
        switch storage {
        case .local:
            model.t(.pinStorageLocal)
        case .keychain:
            model.t(.pinStorageKeychain)
        }
    }

    private var notificationPermissionText: String {
        switch notifications.authorizationState {
        case .unknown:
            model.t(.unknown)
        case .notDetermined:
            model.t(.notificationPermissionNotDetermined)
        case .authorized:
            model.t(.notificationPermissionAuthorized)
        case .denied:
            model.t(.notificationPermissionDenied)
        }
    }

    private var notificationPermissionColor: Color {
        switch notifications.authorizationState {
        case .authorized:
            .green
        case .denied:
            .orange
        case .unknown, .notDetermined:
            ChumenStyle.mutedText
        }
    }
}
