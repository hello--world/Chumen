import ChumenCore
@preconcurrency import CloudKit
import Foundation

enum ChumenSyncBackendKind: String, CaseIterable, Codable, Identifiable {
    case directory
    case cloudKit

    var id: String { rawValue }
}

struct ChumenSyncSettings: Codable, Equatable {
    var backend: ChumenSyncBackendKind
    var directoryPath: String
    var cloudKitContainerIdentifier: String
    var lastSyncedAt: Date?

    init(
        backend: ChumenSyncBackendKind = .directory,
        directoryPath: String = "",
        cloudKitContainerIdentifier: String = "",
        lastSyncedAt: Date? = nil
    ) {
        self.backend = backend
        self.directoryPath = directoryPath
        self.cloudKitContainerIdentifier = cloudKitContainerIdentifier
        self.lastSyncedAt = lastSyncedAt
    }
}

struct ChumenImportedSyncState {
    let settings: ChumenRuntimeSettings
    let profileLibrary: ProfileLibrary
}

@MainActor
final class ChumenConfigSyncService: ObservableObject {
    // Sync snapshots are portability artifacts, not Chumen's local storage format. They keep
    // profile paths relative and profile YAML readable so another Chumen install can import them;
    // importPayload is the boundary that re-applies local config protection and rewrites paths.
    @Published private(set) var settings: ChumenSyncSettings
    @Published private(set) var statusText = ""
    @Published private(set) var isSyncing = false

    private let paths: ChumenPaths
    private let settingsURL: URL
    private let fileManager: FileManager

    init(paths: ChumenPaths, fileManager: FileManager = .default) {
        self.paths = paths
        self.fileManager = fileManager
        self.settingsURL = paths.appHome.appendingPathComponent("sync-settings.json")
        self.settings = Self.loadSettings(from: settingsURL)
    }

    func backendTitle(_ backend: ChumenSyncBackendKind, language: AppLanguage) -> String {
        switch backend {
        case .directory:
            L10n.text(.syncBackendDirectory, language: language)
        case .cloudKit:
            L10n.text(.syncBackendCloudKit, language: language)
        }
    }

    func setBackend(_ backend: ChumenSyncBackendKind) {
        settings.backend = backend
        saveSettings()
    }

    func setDirectory(_ url: URL) {
        settings.directoryPath = url.path
        settings.backend = .directory
        saveSettings()
    }

    func setCloudKitContainerIdentifier(_ identifier: String) {
        settings.cloudKitContainerIdentifier = identifier.trimmingCharacters(in: .whitespacesAndNewlines)
        saveSettings()
    }

    func push(
        appSettings: ChumenRuntimeSettings,
        profileLibrary: ProfileLibrary,
        readProfileContent: (ProxyProfile) throws -> String
    ) async throws {
        try await runSync {
            let payload = try makePayload(
                appSettings: appSettings,
                profileLibrary: profileLibrary,
                readProfileContent: readProfileContent
            )
            switch settings.backend {
            case .directory:
                try writePayloadToDirectory(payload)
            case .cloudKit:
                try await pushPayloadToCloudKit(payload)
            }
            markSynced()
        }
    }

    func pull(currentSettings: ChumenRuntimeSettings) async throws -> ChumenImportedSyncState {
        try await runSync {
            let payload: ChumenSyncPayload
            switch settings.backend {
            case .directory:
                payload = try readPayloadFromDirectory()
            case .cloudKit:
                payload = try await pullPayloadFromCloudKit()
            }

            let state = try importPayload(payload, currentSettings: currentSettings)
            markSynced()
            return state
        }
    }

    func checkCloudKitStatus() async throws {
        try await runSync {
            let container = cloudKitContainer()
            let status = try await container.chumenAccountStatus()
            switch status {
            case .available:
                statusText = L10n.text(.syncCloudKitAvailable, language: AppLanguage.defaultLanguage())
            case .noAccount:
                throw ChumenSyncError.cloudKitUnavailable(L10n.text(.syncCloudKitNoAccount, language: AppLanguage.defaultLanguage()))
            case .restricted:
                throw ChumenSyncError.cloudKitUnavailable(L10n.text(.syncCloudKitRestricted, language: AppLanguage.defaultLanguage()))
            case .couldNotDetermine:
                throw ChumenSyncError.cloudKitUnavailable(L10n.text(.syncCloudKitUnknown, language: AppLanguage.defaultLanguage()))
            case .temporarilyUnavailable:
                throw ChumenSyncError.cloudKitUnavailable(L10n.text(.syncCloudKitTemporaryUnavailable, language: AppLanguage.defaultLanguage()))
            @unknown default:
                throw ChumenSyncError.cloudKitUnavailable(L10n.text(.syncCloudKitUnknown, language: AppLanguage.defaultLanguage()))
            }
        }
    }

    private func runSync<T>(_ operation: () async throws -> T) async throws -> T {
        isSyncing = true
        defer { isSyncing = false }
        do {
            let result = try await operation()
            return result
        } catch {
            statusText = error.localizedDescription
            throw error
        }
    }

    private func makePayload(
        appSettings: ChumenRuntimeSettings,
        profileLibrary: ProfileLibrary,
        readProfileContent: (ProxyProfile) throws -> String
    ) throws -> ChumenSyncPayload {
        var exportedSettings = appSettings
        var exportedLibrary = profileLibrary
        var profileFiles: [String: String] = [:]

        for index in exportedLibrary.profiles.indices {
            let profile = exportedLibrary.profiles[index]
            let fileName = "\(profile.id).yaml"
            exportedLibrary.profiles[index].filePath = "profiles/\(fileName)"
            profileFiles[fileName] = try readProfileContent(profile)
        }

        if let activeProfileID = exportedLibrary.activeProfileID {
            exportedSettings.profilePath = "profiles/\(activeProfileID).yaml"
        } else {
            exportedSettings.profilePath = nil
        }

        return ChumenSyncPayload(
            manifest: ChumenSyncManifest(
                version: 1,
                exportedAt: Date(),
                sourceAppHome: paths.appHome.path
            ),
            settings: exportedSettings,
            profileLibrary: exportedLibrary,
            profileFiles: profileFiles
        )
    }

    private func writePayloadToDirectory(_ payload: ChumenSyncPayload) throws {
        let root = try syncDirectoryURL()
        let profilesURL = root.appendingPathComponent("profiles", isDirectory: true)
        try fileManager.createDirectory(at: profilesURL, withIntermediateDirectories: true)

        let encoder = Self.prettyJSONEncoder()
        try encoder.encode(payload.manifest).write(
            to: root.appendingPathComponent("sync-manifest.json"),
            options: .atomic
        )
        try encoder.encode(payload.settings).write(
            to: root.appendingPathComponent("settings.json"),
            options: .atomic
        )
        try encoder.encode(payload.profileLibrary).write(
            to: root.appendingPathComponent("profiles.json"),
            options: .atomic
        )
        try encoder.encode(payload).write(
            to: root.appendingPathComponent("chumen-sync-bundle.json"),
            options: .atomic
        )

        for (fileName, content) in payload.profileFiles {
            try Data(content.utf8).write(
                to: profilesURL.appendingPathComponent(fileName),
                options: .atomic
            )
        }
    }

    private func readPayloadFromDirectory() throws -> ChumenSyncPayload {
        let root = try syncDirectoryURL()
        let bundleURL = root.appendingPathComponent("chumen-sync-bundle.json")
        let decoder = JSONDecoder()
        if fileManager.fileExists(atPath: bundleURL.path) {
            return try decoder.decode(ChumenSyncPayload.self, from: Data(contentsOf: bundleURL))
        }

        let settings = try decoder.decode(
            ChumenRuntimeSettings.self,
            from: Data(contentsOf: root.appendingPathComponent("settings.json"))
        )
        let profileLibrary = try decoder.decode(
            ProfileLibrary.self,
            from: Data(contentsOf: root.appendingPathComponent("profiles.json"))
        )
        var profileFiles: [String: String] = [:]
        for profile in profileLibrary.profiles {
            let relativePath = profile.filePath.hasPrefix("/") ? "profiles/\(URL(fileURLWithPath: profile.filePath).lastPathComponent)" : profile.filePath
            let sourceURL = root.appendingPathComponent(relativePath)
            profileFiles[sourceURL.lastPathComponent] = try String(contentsOf: sourceURL, encoding: .utf8)
        }

        return ChumenSyncPayload(
            manifest: ChumenSyncManifest(version: 1, exportedAt: nil, sourceAppHome: nil),
            settings: settings,
            profileLibrary: profileLibrary,
            profileFiles: profileFiles
        )
    }

    private func importPayload(
        _ payload: ChumenSyncPayload,
        currentSettings: ChumenRuntimeSettings
    ) throws -> ChumenImportedSyncState {
        try paths.ensureDirectories(fileManager: fileManager)

        var importedSettings = payload.settings
        importedSettings.corePath = currentSettings.corePath
        // Local protection is an installation policy, not a property that should be forced by a
        // synced snapshot from another machine.
        importedSettings.protectConfigFiles = currentSettings.protectConfigFiles

        var localLibrary = payload.profileLibrary
        let protection = ChumenConfigProtection(enabled: currentSettings.protectConfigFiles)

        for index in localLibrary.profiles.indices {
            let profile = localLibrary.profiles[index]
            let fileName = URL(fileURLWithPath: profile.filePath).lastPathComponent.isEmpty
                ? "\(profile.id).yaml"
                : URL(fileURLWithPath: profile.filePath).lastPathComponent
            guard let content = payload.profileFiles[fileName] ?? payload.profileFiles["\(profile.id).yaml"] else {
                throw ChumenSyncError.missingProfileFile(fileName)
            }

            let targetURL = paths.profilesDirectoryURL.appendingPathComponent("\(profile.id).yaml")
            try protection.writeText(content, to: targetURL, fileManager: fileManager)
            localLibrary.profiles[index].filePath = targetURL.path
        }

        if let activeProfileID = localLibrary.activeProfileID,
           let activeProfile = localLibrary.profiles.first(where: { $0.id == activeProfileID }) {
            importedSettings.profilePath = activeProfile.filePath
            importedSettings.activeProfileID = activeProfile.id
        } else {
            importedSettings.profilePath = localLibrary.profiles.first?.filePath
            importedSettings.activeProfileID = localLibrary.profiles.first?.id
            localLibrary.activeProfileID = localLibrary.profiles.first?.id
        }

        try ChumenSettingsStore(paths: paths).save(importedSettings)
        try ProfileRepository(paths: paths, protectConfigFiles: currentSettings.protectConfigFiles).save(localLibrary)

        return ChumenImportedSyncState(settings: importedSettings, profileLibrary: localLibrary)
    }

    private func pushPayloadToCloudKit(_ payload: ChumenSyncPayload) async throws {
        let bundleURL = try writeTemporaryBundle(payload)
        let database = cloudKitContainer().privateCloudDatabase
        let record: CKRecord
        do {
            record = try await database.chumenFetch(with: Self.cloudKitRecordID)
        } catch {
            if let ckError = error as? CKError, ckError.code == .unknownItem {
                record = CKRecord(recordType: Self.cloudKitRecordType, recordID: Self.cloudKitRecordID)
            } else {
                throw error
            }
        }
        record["bundle"] = CKAsset(fileURL: bundleURL)
        record["exportedAt"] = payload.manifest.exportedAt as CKRecordValue?
        _ = try await database.chumenSave(record)
    }

    private func pullPayloadFromCloudKit() async throws -> ChumenSyncPayload {
        let record = try await cloudKitContainer().privateCloudDatabase.chumenFetch(with: Self.cloudKitRecordID)
        guard let asset = record["bundle"] as? CKAsset,
              let fileURL = asset.fileURL else {
            throw ChumenSyncError.cloudKitUnavailable(L10n.text(.syncCloudKitNoSnapshot, language: AppLanguage.defaultLanguage()))
        }
        return try JSONDecoder().decode(ChumenSyncPayload.self, from: Data(contentsOf: fileURL))
    }

    private func writeTemporaryBundle(_ payload: ChumenSyncPayload) throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("chumen-cloudkit-sync-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent("chumen-sync-bundle.json")
        try Self.prettyJSONEncoder().encode(payload).write(to: url, options: .atomic)
        return url
    }

    private func cloudKitContainer() -> CKContainer {
        let identifier = settings.cloudKitContainerIdentifier.trimmingCharacters(in: .whitespacesAndNewlines)
        if identifier.isEmpty {
            return .default()
        }
        return CKContainer(identifier: identifier)
    }

    private func syncDirectoryURL() throws -> URL {
        let path = settings.directoryPath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !path.isEmpty else {
            throw ChumenSyncError.directoryNotSelected
        }
        let url = URL(fileURLWithPath: path, isDirectory: true)
        try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func markSynced() {
        settings.lastSyncedAt = Date()
        saveSettings()
        statusText = L10n.text(.syncCompleted, language: AppLanguage.defaultLanguage())
    }

    private func saveSettings() {
        do {
            try paths.ensureDirectories(fileManager: fileManager)
            try Self.prettyJSONEncoder().encode(settings).write(to: settingsURL, options: .atomic)
        } catch {
            statusText = error.localizedDescription
        }
    }

    private static func loadSettings(from url: URL) -> ChumenSyncSettings {
        guard let data = try? Data(contentsOf: url),
              let settings = try? JSONDecoder().decode(ChumenSyncSettings.self, from: data) else {
            return ChumenSyncSettings()
        }
        return settings
    }

    private static func prettyJSONEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }

    private static let cloudKitRecordType = "ChumenSyncSnapshot"
    private static let cloudKitRecordID = CKRecord.ID(recordName: "current")
}

private struct ChumenSyncManifest: Codable, Equatable {
    let version: Int
    let exportedAt: Date?
    let sourceAppHome: String?
}

private struct ChumenSyncPayload: Codable, Equatable {
    let manifest: ChumenSyncManifest
    let settings: ChumenRuntimeSettings
    let profileLibrary: ProfileLibrary
    let profileFiles: [String: String]
}

private enum ChumenSyncError: LocalizedError {
    case directoryNotSelected
    case missingProfileFile(String)
    case cloudKitUnavailable(String)

    var errorDescription: String? {
        switch self {
        case .directoryNotSelected:
            L10n.text(.syncDirectoryNotSelected, language: AppLanguage.defaultLanguage())
        case let .missingProfileFile(fileName):
            "\(L10n.text(.syncMissingProfileFile, language: AppLanguage.defaultLanguage())): \(fileName)"
        case let .cloudKitUnavailable(message):
            message
        }
    }
}

private extension CKContainer {
    func chumenAccountStatus() async throws -> CKAccountStatus {
        try await withCheckedThrowingContinuation { continuation in
            accountStatus { status, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: status)
                }
            }
        }
    }
}

private extension CKDatabase {
    func chumenSave(_ record: CKRecord) async throws -> CKRecord {
        try await withCheckedThrowingContinuation { continuation in
            save(record) { savedRecord, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let savedRecord {
                    continuation.resume(returning: savedRecord)
                } else {
                    continuation.resume(throwing: ChumenSyncError.cloudKitUnavailable(
                        L10n.text(.syncCloudKitUnknown, language: AppLanguage.defaultLanguage())
                    ))
                }
            }
        }
    }

    func chumenFetch(with recordID: CKRecord.ID) async throws -> CKRecord {
        try await withCheckedThrowingContinuation { continuation in
            fetch(withRecordID: recordID) { record, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let record {
                    continuation.resume(returning: record)
                } else {
                    continuation.resume(throwing: ChumenSyncError.cloudKitUnavailable(
                        L10n.text(.syncCloudKitNoSnapshot, language: AppLanguage.defaultLanguage())
                    ))
                }
            }
        }
    }
}
