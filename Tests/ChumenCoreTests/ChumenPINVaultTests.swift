import XCTest
@testable import ChumenCore

final class ChumenPINVaultTests: XCTestCase {
    func testLocalPINVaultUnlocksAgeKeyAndRejectsWrongPIN() throws {
        let root = temporaryRoot()
        defer {
            try? FileManager.default.removeItem(at: root)
        }
        let vault = ChumenPINVault(paths: ChumenPaths(appHome: root), service: testService())
        let keyPair = MihomoAgeKeyPair(secretKey: "AGE-SECRET-KEY-LOCAL", publicKey: "age1local")

        try vault.create(pin: "123456", keyPair: keyPair, lockAppOnLaunch: false, storage: .local)

        XCTAssertTrue(vault.exists)
        XCTAssertEqual(vault.storageKind(), .local)
        XCTAssertEqual(try vault.unlock(pin: "123456"), keyPair)
        XCTAssertThrowsError(try vault.unlock(pin: "000000"))
    }

    func testKeychainPINVaultCanMoveToLocalWithoutKnowingPIN() throws {
        let root = temporaryRoot()
        defer {
            try? FileManager.default.removeItem(at: root)
        }
        let vault = ChumenPINVault(paths: ChumenPaths(appHome: root), service: testService())
        defer {
            try? vault.delete()
        }
        let keyPair = MihomoAgeKeyPair(secretKey: "AGE-SECRET-KEY-KEYCHAIN", publicKey: "age1keychain")

        try vault.create(pin: "pin", keyPair: keyPair, lockAppOnLaunch: true, storage: .keychain)

        XCTAssertTrue(vault.exists)
        XCTAssertEqual(vault.storageKind(), .keychain)
        XCTAssertFalse(FileManager.default.fileExists(atPath: ChumenPaths(appHome: root).pinVaultURL.path))
        XCTAssertEqual(try vault.unlock(pin: "pin", preferredStorage: .keychain), keyPair)

        try vault.move(to: .local)

        XCTAssertEqual(vault.storageKind(), .local)
        XCTAssertTrue(FileManager.default.fileExists(atPath: ChumenPaths(appHome: root).pinVaultURL.path))
        XCTAssertEqual(try vault.unlock(pin: "pin", preferredStorage: .local), keyPair)
        XCTAssertEqual(try vault.load()?.lockAppOnLaunch, true)
    }

    private func temporaryRoot() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("chumen-pin-vault-\(UUID().uuidString)", isDirectory: true)
    }

    private func testService() -> String {
        "io.github.chumen.tests.pin-vault.\(UUID().uuidString)"
    }
}
