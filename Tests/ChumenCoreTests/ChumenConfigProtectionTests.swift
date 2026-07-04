import XCTest
@testable import ChumenCore

final class ChumenConfigProtectionTests: XCTestCase {
    func testProtectedEnvelopeRoundTrips() throws {
        let key = Data(repeating: 7, count: 32)
        let plain = Data("proxies:\n  - server: example.com\n".utf8)

        let encrypted = try ChumenConfigProtection.encrypt(plain, key: key)
        let decrypted = try ChumenConfigProtection.decrypt(encrypted, key: key)

        XCTAssertTrue(ChumenConfigProtection.isProtected(encrypted))
        XCTAssertNotEqual(encrypted, plain)
        XCTAssertEqual(decrypted, plain)
    }

    func testRuntimeSettingsProtectsConfigFilesByDefault() {
        XCTAssertTrue(ChumenRuntimeSettings().protectConfigFiles)
    }

    func testRuntimeConfigWritesEncryptedCanonicalFileAndPlainSessionFile() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("chumen-runtime-protection-\(UUID().uuidString)", isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: root)
        }

        let paths = ChumenPaths(appHome: root)
        try paths.ensureDirectories()
        let profileURL = paths.profilesDirectoryURL.appendingPathComponent("profile.yaml")
        try "proxies: []\nrules:\n  - MATCH,DIRECT\n".write(to: profileURL, atomically: true, encoding: .utf8)

        let runtimeURL = try ChumenConfigurationBuilder.writeRuntimeConfig(
            settings: ChumenRuntimeSettings(profilePath: profileURL.path, secret: "secret"),
            paths: paths
        )

        XCTAssertNotEqual(runtimeURL.path, paths.runtimeConfigURL.path)
        XCTAssertTrue(runtimeURL.path.hasPrefix(paths.runtimePlaintextDirectoryURL.path))
        XCTAssertTrue(ChumenConfigProtection.isProtected(try Data(contentsOf: paths.runtimeConfigURL)))
        XCTAssertTrue(try String(contentsOf: runtimeURL, encoding: .utf8).contains("MATCH,DIRECT"))
    }
}
