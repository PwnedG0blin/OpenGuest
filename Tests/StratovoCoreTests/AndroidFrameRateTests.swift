import Foundation
import XCTest
@testable import StratovoCore

final class AndroidFrameRateTests: XCTestCase {
    func testFreeFPSRangeAndGuestDisplayFrequency() {
        for value in 1...90 { XCTAssertEqual(AndroidFrameRate.limit(value), value) }
        XCTAssertEqual(AndroidFrameRate.limit(0), 1)
        XCTAssertEqual(AndroidFrameRate.limit(999), 90)
        XCTAssertEqual(AndroidFrameRate.displayHz(for: 30), 60)
        XCTAssertEqual(AndroidFrameRate.displayHz(for: 75), 75)
        XCTAssertEqual(AndroidFrameRate.displayHz(for: 90), 90)
    }
    func testExistingProfileUses90HzWithoutTouchingUserdataOrStorageSize() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).resolvingSymlinksInPath()
        defer { try? FileManager.default.removeItem(at: root) }
        let folder = root.appendingPathComponent("Actual.avd")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let original = "disk.dataPartition.size=64G\nhw.lcd.width=1440\nhw.lcd.vsync=60\nhw.lcd.vsync=60\n"
        let config = folder.appendingPathComponent("config.ini")
        try original.write(to: config, atomically: true, encoding: .utf8)
        let userdata = folder.appendingPathComponent("userdata-qemu.img")
        try Data([1,2,3,4]).write(to: userdata)
        try "path=\(folder.path)\n".write(to: root.appendingPathComponent("DisplayName.ini"), atomically: true, encoding: .utf8)
        XCTAssertTrue(try AndroidFrameRate.prepareAVD(root: root, name: "DisplayName", fps: 90))
        let text = try String(contentsOf: config, encoding: .utf8)
        XCTAssertTrue(text.contains("disk.dataPartition.size=64G")); XCTAssertTrue(text.contains("hw.lcd.width=1440"))
        XCTAssertEqual(text.components(separatedBy: "hw.lcd.vsync=").count, 2)
        XCTAssertTrue(text.contains("hw.lcd.vsync=90"))
        XCTAssertEqual(try Data(contentsOf: userdata), Data([1,2,3,4]))
        XCTAssertEqual(try String(contentsOf: folder.appendingPathComponent("config.ini.Stratovo-FPS.bak"), encoding: .utf8), original)
        XCTAssertFalse(try AndroidFrameRate.prepareAVD(root: root, name: "DisplayName", fps: 90))
    }
    func testForeignOrLinkedProfilesAndTraversalNeverChangeConfiguration() throws {
        let base = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).resolvingSymlinksInPath()
        defer { try? FileManager.default.removeItem(at: base) }
        let root = base.appendingPathComponent("managed"), outside = base.appendingPathComponent("outside.avd")
        for folder in [root, outside] { try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true) }
        let config = outside.appendingPathComponent("config.ini")
        try "hw.lcd.vsync=60\n".write(to: config, atomically: true, encoding: .utf8)
        try "path=\(outside.path)\n".write(to: root.appendingPathComponent("Foreign.ini"), atomically: true, encoding: .utf8)
        XCTAssertThrowsError(try AndroidFrameRate.prepareAVD(root: root, name: "Foreign", fps: 90))
        try FileManager.default.createSymbolicLink(at: root.appendingPathComponent("Linked.avd"), withDestinationURL: outside)
        XCTAssertThrowsError(try AndroidFrameRate.prepareAVD(root: root, name: "Linked", fps: 90))
        XCTAssertThrowsError(try AndroidFrameRate.prepareAVD(root: root, name: "../outside", fps: 90))
        XCTAssertEqual(try String(contentsOf: config, encoding: .utf8), "hw.lcd.vsync=60\n")
    }
}
