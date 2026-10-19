import Foundation
import XCTest
@testable import StratovoCore

final class DiagnosticTests: XCTestCase {
    private func fixture() throws -> GuestStorage {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("og-diagnostic-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root.appendingPathComponent("Logs"), withIntermediateDirectories: true)
        try Data("fixture".utf8).write(to: root.appendingPathComponent(".openguest-storage-id"))
        return GuestStorage(root: root.path, id: "fixture")
    }
    func testExportCombinesAndroidWindowsAndPrelaunchErrorsWithoutReadingCredentials() throws {
        let storage = try fixture(); defer { try? FileManager.default.removeItem(at: storage.url) }
        try Data("Android emulator version 37\nforcing software rendering".utf8).write(to: storage.logs.appendingPathComponent("session-old.log"))
        try Data("QEMU boot diagnostic".utf8).write(to: storage.logs.appendingPathComponent("windows-session-new.log"))
        try DiagnosticReport.record("Windows: Das Passwort hat 7 Zeichen.", storage: storage)
        try Data("NEVER_INCLUDE_SETTINGS_OR_PASSWORDS".utf8).write(to: storage.url.appendingPathComponent("settings.json"))
        let url = try DiagnosticReport.export(storage: storage, snapshot: "Host snapshot", systemCheck: "HVF vorhanden", recentEvents: "Before VM launch")
        let result = try String(contentsOf: url, encoding: .utf8)
        for text in ["Android emulator version", "QEMU boot diagnostic", "7 Zeichen", "HVF vorhanden", "Before VM launch"] {
            XCTAssertTrue(result.contains(text), text)
        }
        XCTAssertFalse(result.contains("NEVER_INCLUDE"))
        XCTAssertTrue(url.path.hasPrefix(storage.logs.appendingPathComponent("Diagnose").path + "/"))
    }
    func testGraphicsCompilerErrorsAreIncludedButConfigAndSecretsAreExcluded() throws {
        let storage = try fixture(); defer { try? FileManager.default.removeItem(at: storage.url) }
        let graphics = storage.url.appendingPathComponent("GraphicsLab")
        try FileManager.default.createDirectory(at: graphics.appendingPathComponent("Logs"), withIntermediateDirectories: true)
        try Data("ANGLE_BUILD_CONTEXT".utf8).write(to: graphics.appendingPathComponent("Build.log"))
        try Data("shader.metal:42: error: ACTUAL_SHADER_ERROR\npassword=HIDDEN_GRAPHICS_PASSWORD".utf8)
            .write(to: graphics.appendingPathComponent("Logs/Letzter-Fehler.log"))
        try Data("METAL_PROBE_OUTPUT".utf8).write(to: graphics.appendingPathComponent("Logs/Metal-Pruefung.log"))
        try Data("CXX_PROBE_OUTPUT".utf8).write(to: graphics.appendingPathComponent("Logs/CXX-Pruefung.log"))
        try Data("NEVER_INCLUDE_GRAPHICS_CONFIG".utf8).write(to: graphics.appendingPathComponent("config.json"))
        let file = try DiagnosticReport.export(storage: storage, snapshot: "", systemCheck: "", recentEvents: "")
        let report = try String(contentsOf: file, encoding: .utf8)
        for text in ["ANGLE_BUILD_CONTEXT", "ACTUAL_SHADER_ERROR", "METAL_PROBE_OUTPUT", "CXX_PROBE_OUTPUT"] { XCTAssertTrue(report.contains(text)) }
        XCTAssertFalse(report.contains("HIDDEN_GRAPHICS_PASSWORD"))
        XCTAssertFalse(report.contains("NEVER_INCLUDE_GRAPHICS_CONFIG"))
    }
    func testRedactionRemovesKeysAddressesAndSecretsButKeepsValidationDetails() {
        let source = """
        /Users/privateperson/Library/Android/sdk
        Sending adb public key [PRIVATE_FIXTURE_KEY]
        androidboot.qemu.adb.pubkey=PRIVATE_FIXTURE_KEY
        mail=privateperson@example.com
        password=PASSWORD_FIXTURE
        refresh_token=TOKEN_FIXTURE
        https://download.microsoft.com/image.iso?t=SIGNED_FIXTURE
        Das Passwort hat 7 Zeichen.
        """
        let result = DiagnosticReport.redact(source)
        for text in ["privateperson", "PRIVATE_FIXTURE_KEY", "PASSWORD_FIXTURE", "TOKEN_FIXTURE", "SIGNED_FIXTURE"] {
            XCTAssertFalse(result.contains(text), text)
        }
        XCTAssertTrue(result.contains("Das Passwort hat 7 Zeichen."))
    }
    func testExportSkipsSymlinksAndDoesNotIncludeEarlierExports() throws {
        let storage = try fixture(); defer { try? FileManager.default.removeItem(at: storage.url) }
        let outside = FileManager.default.temporaryDirectory.appendingPathComponent("og-outside-\(UUID()).log")
        try Data("OUTSIDE_SECRET".utf8).write(to: outside)
        defer { try? FileManager.default.removeItem(at: outside) }
        try FileManager.default.createSymbolicLink(at: storage.logs.appendingPathComponent("android-session-link.log"), withDestinationURL: outside)
        let first = try DiagnosticReport.export(storage: storage, snapshot: "PREVIOUS_EXPORT_ONLY", systemCheck: "", recentEvents: "")
        let second = try DiagnosticReport.export(storage: storage, snapshot: "Current", systemCheck: "", recentEvents: "")
        XCTAssertNotEqual(first, second)
        let text = try String(contentsOf: second, encoding: .utf8)
        XCTAssertFalse(text.contains("OUTSIDE_SECRET"))
        XCTAssertFalse(text.contains("PREVIOUS_EXPORT_ONLY"))
    }
    func testLargeLogsKeepBeginningAndEndWithinBoundedReport() throws {
        let storage = try fixture(); defer { try? FileManager.default.removeItem(at: storage.url) }
        let content = "START_MARKER\n" + String(repeating: "x", count: 800_000) + "\nEND_MARKER"
        try Data(content.utf8).write(to: storage.logs.appendingPathComponent("android-session-large.log"))
        let url = try DiagnosticReport.export(storage: storage, snapshot: "", systemCheck: "", recentEvents: "")
        let report = try String(contentsOf: url, encoding: .utf8)
        XCTAssertTrue(report.contains("START_MARKER"))
        XCTAssertTrue(report.contains("END_MARKER"))
        XCTAssertTrue(report.contains("Protokoll gekürzt"))
        XCTAssertLessThan(report.utf8.count, 300_000)
    }
    func testMissingDriveRefusesExportAndWindowsPreparation() throws {
        let storage = try fixture(); defer { try? FileManager.default.removeItem(at: storage.url) }
        try FileManager.default.removeItem(at: storage.url.appendingPathComponent(".openguest-storage-id"))
        XCTAssertThrowsError(try DiagnosticReport.export(storage: storage, snapshot: "", systemCheck: "", recentEvents: ""))
        XCTAssertThrowsError(try storage.prepareWindowsFolder())
        XCTAssertFalse(FileManager.default.fileExists(atPath: storage.windows.path))
    }
    func testWindowsFolderPreparationPreservesExistingDataAndRejectsOutsideLink() throws {
        let storage = try fixture(); defer { try? FileManager.default.removeItem(at: storage.url) }
        XCTAssertFalse(storage.windowsFolderReady)
        try storage.prepareWindowsFolder()
        XCTAssertTrue(storage.windowsFolderReady)
        let disk = storage.windows.appendingPathComponent("precious.qcow2")
        try Data("keep".utf8).write(to: disk)
        try storage.prepareWindowsFolder()
        XCTAssertEqual(try Data(contentsOf: disk), Data("keep".utf8))
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: storage.windows.path), ["precious.qcow2"])
        try FileManager.default.removeItem(at: storage.windows)
        try FileManager.default.createSymbolicLink(at: storage.windows, withDestinationURL: storage.url.deletingLastPathComponent())
        XCTAssertFalse(storage.windowsFolderReady)
        XCTAssertThrowsError(try storage.prepareWindowsFolder())
    }
}
