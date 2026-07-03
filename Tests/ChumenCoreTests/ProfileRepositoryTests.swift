import XCTest
@testable import ChumenCore

@MainActor
final class ProfileRepositoryTests: XCTestCase {
    func testImportLocalProfilePersistsLibraryAndCopiesFile() throws {
        let root = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("chumen-profile-test-\(UUID().uuidString)", isDirectory: true)
        let source = root.appendingPathComponent("source.yaml")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try "proxies: []\nrules:\n  - MATCH,DIRECT\n".write(to: source, atomically: true, encoding: .utf8)
        defer {
            try? FileManager.default.removeItem(at: root)
        }

        let paths = ChumenPaths(appHome: root.appendingPathComponent("app", isDirectory: true))
        let repository = ProfileRepository(paths: paths)
        var library = ProfileLibrary()

        let profile = try repository.importLocalProfile(from: source, into: &library)
        let reloaded = repository.load()

        XCTAssertEqual(library.activeProfileID, profile.id)
        XCTAssertEqual(reloaded.activeProfileID, profile.id)
        XCTAssertEqual(reloaded.profiles.first?.name, "source")
        XCTAssertTrue(FileManager.default.fileExists(atPath: profile.filePath))
    }

    func testDeleteActiveProfileSelectsNextProfile() throws {
        let root = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("chumen-profile-delete-test-\(UUID().uuidString)", isDirectory: true)
        let sourceA = root.appendingPathComponent("a.yaml")
        let sourceB = root.appendingPathComponent("b.yaml")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try "proxies: []\n".write(to: sourceA, atomically: true, encoding: .utf8)
        try "rules: []\n".write(to: sourceB, atomically: true, encoding: .utf8)
        defer {
            try? FileManager.default.removeItem(at: root)
        }

        let paths = ChumenPaths(appHome: root.appendingPathComponent("app", isDirectory: true))
        let repository = ProfileRepository(paths: paths)
        var library = ProfileLibrary()
        let first = try repository.importLocalProfile(from: sourceA, into: &library)
        let second = try repository.importLocalProfile(from: sourceB, into: &library)

        try repository.delete(first, from: &library)

        XCTAssertEqual(library.activeProfileID, second.id)
        XCTAssertFalse(FileManager.default.fileExists(atPath: first.filePath))
    }

    func testSaveContentAndRenameUpdateProfileLibrary() throws {
        let root = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("chumen-profile-edit-test-\(UUID().uuidString)", isDirectory: true)
        let source = root.appendingPathComponent("editable.yaml")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try "proxies: []\n".write(to: source, atomically: true, encoding: .utf8)
        defer {
            try? FileManager.default.removeItem(at: root)
        }

        let paths = ChumenPaths(appHome: root.appendingPathComponent("app", isDirectory: true))
        let repository = ProfileRepository(paths: paths)
        var library = ProfileLibrary()
        let profile = try repository.importLocalProfile(from: source, into: &library)

        let edited = try repository.saveContent(profile, content: "rules:\n  - MATCH,DIRECT\n", in: &library)
        let renamed = try repository.rename(edited, name: "Daily Profile", in: &library)
        let content = try String(contentsOfFile: renamed.filePath, encoding: .utf8)

        XCTAssertEqual(content, "rules:\n  - MATCH,DIRECT\n")
        XCTAssertEqual(library.profiles.first?.name, "Daily Profile")
        XCTAssertEqual(repository.load().profiles.first?.name, "Daily Profile")
    }

    func testSaveContentAndMetadataUpdatesNameAndRemoteURL() throws {
        let root = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("chumen-profile-metadata-test-\(UUID().uuidString)", isDirectory: true)
        let source = root.appendingPathComponent("editable.yaml")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try "proxies: []\n".write(to: source, atomically: true, encoding: .utf8)
        defer {
            try? FileManager.default.removeItem(at: root)
        }

        let paths = ChumenPaths(appHome: root.appendingPathComponent("app", isDirectory: true))
        let repository = ProfileRepository(paths: paths)
        var library = ProfileLibrary()
        let profile = try repository.importLocalProfile(from: source, into: &library)

        let updated = try repository.saveContentAndMetadata(
            profile,
            content: "rules:\n  - MATCH,DIRECT\n",
            name: "Imported Subscription",
            remoteURL: " https://example.com/sub.yaml?token=abc ",
            in: &library
        )

        XCTAssertEqual(updated.name, "Imported Subscription")
        XCTAssertEqual(updated.remoteURL, "https://example.com/sub.yaml?token=abc")
        XCTAssertEqual(try String(contentsOfFile: updated.filePath, encoding: .utf8), "rules:\n  - MATCH,DIRECT\n")
        XCTAssertEqual(repository.load().profiles.first?.remoteURL, "https://example.com/sub.yaml?token=abc")

        let localOnly = try repository.updateMetadata(updated, name: "Local Only", remoteURL: "", in: &library)
        XCTAssertEqual(localOnly.name, "Local Only")
        XCTAssertNil(localOnly.remoteURL)
        XCTAssertNil(repository.load().profiles.first?.remoteURL)
    }

    func testDiscoverExternalProfilesUsesClientMetadataAndFiltersNonRuntimeFiles() throws {
        let root = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("chumen-external-discover-test-\(UUID().uuidString)", isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: root)
        }

        let clientRoot = root
            .appendingPathComponent("Library/Application Support/io.github.clash-verge-rev.clash-verge-rev", isDirectory: true)
        let profiles = clientRoot.appendingPathComponent("profiles", isDirectory: true)
        let ruleset = clientRoot.appendingPathComponent("ruleset", isDirectory: true)
        try FileManager.default.createDirectory(at: profiles, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: ruleset, withIntermediateDirectories: true)

        try """
        current: airport
        items:
        - uid: airport
          type: remote
          name: Airport
          file: airport.yaml
          url: https://example.com/sub.yaml?token=test#fragment
        - uid: merge
          type: merge
          name: Merge
          file: merge.yaml
        """.write(to: clientRoot.appendingPathComponent("profiles.yaml"), atomically: true, encoding: .utf8)
        try "proxies: []\nproxy-groups: []\nrules:\n  - MATCH,DIRECT\n"
            .write(to: profiles.appendingPathComponent("airport.yaml"), atomically: true, encoding: .utf8)
        try "prepend: []\nappend: []\ndelete: []\n"
            .write(to: profiles.appendingPathComponent("merge.yaml"), atomically: true, encoding: .utf8)
        try "payload:\n  - DOMAIN,example.com\n"
            .write(to: ruleset.appendingPathComponent("direct.yaml"), atomically: true, encoding: .utf8)

        let paths = ChumenPaths(appHome: root.appendingPathComponent("app", isDirectory: true))
        let repository = ProfileRepository(paths: paths)

        let candidates = repository.discoverExternalProfiles(homeDirectory: root)

        XCTAssertEqual(candidates.count, 1)
        XCTAssertEqual(candidates.first?.sourceName, "Clash Verge Rev")
        XCTAssertEqual(candidates.first?.name, "Airport")
        XCTAssertEqual(candidates.first?.remoteURL, "https://example.com/sub.yaml?token=test#fragment")
        XCTAssertTrue(candidates.first?.filePath.hasSuffix("/profiles/airport.yaml") == true)
    }

    func testImportExternalProfilesSkipsDuplicateContent() throws {
        let root = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("chumen-external-import-test-\(UUID().uuidString)", isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: root)
        }

        let clientRoot = root.appendingPathComponent(".config/clash.meta", isDirectory: true)
        try FileManager.default.createDirectory(at: clientRoot, withIntermediateDirectories: true)
        let source = clientRoot.appendingPathComponent("config.yaml")
        try "proxies: []\nproxy-groups: []\nrules:\n  - MATCH,DIRECT\n"
            .write(to: source, atomically: true, encoding: .utf8)

        let paths = ChumenPaths(appHome: root.appendingPathComponent("app", isDirectory: true))
        let repository = ProfileRepository(paths: paths)
        let candidates = repository.discoverExternalProfiles(homeDirectory: root)
        var library = ProfileLibrary()

        let first = try repository.importExternalProfiles(candidates, into: &library)
        let second = try repository.importExternalProfiles(candidates, into: &library)

        XCTAssertEqual(first.imported.count, 1)
        XCTAssertEqual(first.imported.first?.name, "~/.config/clash.meta - config")
        XCTAssertEqual(second.imported.count, 0)
        XCTAssertEqual(second.skipped.count, 1)
        XCTAssertEqual(library.profiles.count, 1)
        XCTAssertEqual(repository.load().profiles.count, 1)
    }

    func testImportExternalProfilesPreservesRemoteURL() throws {
        let root = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("chumen-external-url-test-\(UUID().uuidString)", isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: root)
        }

        let clientRoot = root
            .appendingPathComponent("Library/Application Support/io.github.clash-verge-rev.clash-verge-rev", isDirectory: true)
        let profiles = clientRoot.appendingPathComponent("profiles", isDirectory: true)
        try FileManager.default.createDirectory(at: profiles, withIntermediateDirectories: true)
        try """
        items:
        - uid: remote-one
          type: remote
          name: Remote One
          file: remote-one.yaml
          url: "https://example.com/remote-one.yaml?token=abc"
        """.write(to: clientRoot.appendingPathComponent("profiles.yaml"), atomically: true, encoding: .utf8)
        try "proxies: []\nproxy-groups: []\nrules:\n  - MATCH,DIRECT\n"
            .write(to: profiles.appendingPathComponent("remote-one.yaml"), atomically: true, encoding: .utf8)

        let paths = ChumenPaths(appHome: root.appendingPathComponent("app", isDirectory: true))
        let repository = ProfileRepository(paths: paths)
        let candidates = repository.discoverExternalProfiles(homeDirectory: root)
        var library = ProfileLibrary()

        let summary = try repository.importExternalProfiles(candidates, into: &library)

        XCTAssertEqual(summary.imported.first?.remoteURL, "https://example.com/remote-one.yaml?token=abc")
        XCTAssertEqual(repository.load().profiles.first?.remoteURL, "https://example.com/remote-one.yaml?token=abc")
    }

    func testLoadMigratesLegacyProfileFilePaths() throws {
        let root = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("chumen-profile-library-migration-\(UUID().uuidString)", isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: root)
        }

        let paths = ChumenPaths(appHome: root.appendingPathComponent("io.github.chumen.native-macos", isDirectory: true))
        try paths.ensureDirectories()
        let legacyFile = root
            .appendingPathComponent(previousAppSupportDirectoryName, isDirectory: true)
            .appendingPathComponent("profiles/imported.yaml")
        let migratedFile = paths.profilesDirectoryURL.appendingPathComponent("imported.yaml")
        try "proxies: []\n".write(to: migratedFile, atomically: true, encoding: .utf8)
        let library = ProfileLibrary(
            activeProfileID: "imported",
            profiles: [
                ProxyProfile(id: "imported", name: "Imported", filePath: legacyFile.path)
            ]
        )
        let data = try JSONEncoder().encode(library)
        try data.write(to: paths.profileLibraryURL, options: .atomic)

        let loaded = ProfileRepository(paths: paths).load()

        XCTAssertEqual(loaded.profiles.first?.filePath, migratedFile.path)
        XCTAssertFalse(try String(contentsOf: paths.profileLibraryURL, encoding: .utf8).contains(previousAppSupportDirectoryName))
    }

    private var previousAppToken: String {
        "lu" + "men"
    }

    private var previousAppSupportDirectoryName: String {
        "io.github." + previousAppToken + ".native-macos"
    }
}
