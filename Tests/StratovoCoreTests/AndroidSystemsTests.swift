import XCTest
@testable import StratovoCore

final class AndroidSystemsTests: XCTestCase {
    private struct Fixture {
        let storage: GuestStorage
        let temporary: URL
        let home: URL
        let keep = "MyWorkingAndroid16"
        init() throws {
            temporary = FileManager.default.temporaryDirectory.resolvingSymlinksInPath().appendingPathComponent("AndroidSystems-\(UUID().uuidString)")
            home = temporary.appendingPathComponent("Home")
            try FileManager.default.createDirectory(at: home, withIntermediateDirectories: true)
            let root = temporary.appendingPathComponent("External/Stratovo")
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
            try "test-id".write(to: root.appendingPathComponent(".openguest-storage-id"), atomically: true, encoding: .utf8)
            storage = GuestStorage(root: root.path, id: "test-id")
            try profile(keep, platform: "android-36")
            try profile("OldAndroid15", platform: "android-35")
            try write(storage.windows.appendingPathComponent("windows.qcow2"), "windows unchanged")
            try write(root.appendingPathComponent("Installationsmedien/windows.iso"), "installer unchanged")
        }
        func write(_ url: URL, _ text: String) throws {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try text.write(to: url, atomically: true, encoding: .utf8)
        }
        func profile(_ name: String, platform: String) throws {
            let directory = storage.avd.appendingPathComponent(name + ".avd")
            try write(directory.appendingPathComponent("config.ini"), "image.sysdir.1=system-images/\(platform)/google_apis_playstore/arm64-v8a/\nabi.type=arm64-v8a\n")
            try write(directory.appendingPathComponent("userdata-qemu.img"), "precious user data \(name)")
            try write(storage.avd.appendingPathComponent(name + ".ini"), "path=\(directory.path)\n")
            try write(storage.sdk.appendingPathComponent("system-images/\(platform)/google_apis_playstore/arm64-v8a/system.img"), "system")
        }
        func remove() { try? FileManager.default.removeItem(at: temporary) }
    }
    func testAndroidVersionsRecognizeImagePathRatherThanProfileName() {
        XCTAssertEqual(AndroidSystem.detect(["image.sysdir.1": "system-images/android-36/google_apis_playstore/arm64-v8a/"]), .android16)
        XCTAssertEqual(AndroidSystem.detect(["image.sysdir.1": "/Volumes/Extern/sdk/system-images/android-37.0/google_apis_playstore/arm64-v8a/"]), .android17)
        XCTAssertNil(AndroidSystem.detect(["image.sysdir.1": "system-images/android-35/google_apis_playstore/arm64-v8a/"]))
        XCTAssertNil(AndroidSystem.detect(["image.sysdir.1": "system-images/android-36/google_apis/x86_64/"]))
    }
    func testCleanupRemovesOldAndroidButPreservesWorkingGuestAndWindows() throws {
        let f = try Fixture(); defer { f.remove() }
        let backup = f.storage.url.appendingPathComponent("Backups/Android-vor-Vergroesserung.ABC/OpenGuest_GooglePlay.avd")
        try f.write(backup.appendingPathComponent("config.ini"), "image.sysdir.1=system-images/android-35/google_apis_playstore/arm64-v8a/\n")
        try f.write(backup.appendingPathComponent("userdata-qemu.img.qcow2"), "old saved data")
        let other = f.storage.url.appendingPathComponent("Backups/MyWindowsBackup/disk.qcow2")
        try f.write(other, "other backup")
        let plan = try AndroidMaintenance.plan(storage: f.storage, keeping: f.keep, homeDirectory: f.home)
        XCTAssertTrue(plan.paths.contains { URL(fileURLWithPath: $0).resolvingSymlinksInPath().path == f.storage.avd.appendingPathComponent("OldAndroid15.avd").resolvingSymlinksInPath().path }, "Planned paths: \(plan.paths)")
        XCTAssertTrue(plan.paths.contains { URL(fileURLWithPath: $0).resolvingSymlinksInPath().path == backup.deletingLastPathComponent().resolvingSymlinksInPath().path }, "Planned paths: \(plan.paths)")
        try AndroidMaintenance.cleanup(storage: f.storage, expected: plan, homeDirectory: f.home)
        XCTAssertEqual(try String(contentsOf: f.storage.avd.appendingPathComponent(f.keep + ".avd/userdata-qemu.img"), encoding: .utf8), "precious user data \(f.keep)")
        XCTAssertEqual(try String(contentsOf: f.storage.windows.appendingPathComponent("windows.qcow2"), encoding: .utf8), "windows unchanged")
        XCTAssertTrue(FileManager.default.fileExists(atPath: other.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: f.storage.avd.appendingPathComponent("OldAndroid15.avd").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: f.storage.sdk.appendingPathComponent("system-images/android-36/google_apis_playstore/arm64-v8a/system.img").path))
    }
    func testChangedPlanAbortsBeforeAnyDeletion() throws {
        let f = try Fixture(); defer { f.remove() }
        let plan = try AndroidMaintenance.plan(storage: f.storage, keeping: f.keep, homeDirectory: f.home)
        try f.profile("NewAndroid17", platform: "android-37.0")
        XCTAssertThrowsError(try AndroidMaintenance.cleanup(storage: f.storage, expected: plan, homeDirectory: f.home))
        XCTAssertTrue(FileManager.default.fileExists(atPath: f.storage.avd.appendingPathComponent("OldAndroid15.avd").path))
    }
    func testExternalSymlinkAbortsCleanupWithoutTouchingTarget() throws {
        let f = try Fixture(); defer { f.remove() }
        let target = f.temporary.appendingPathComponent("outside.avd")
        try f.write(target.appendingPathComponent("userdata-qemu.img"), "outside precious data")
        try FileManager.default.createSymbolicLink(at: f.storage.avd.appendingPathComponent("Unsafe.avd"), withDestinationURL: target)
        XCTAssertThrowsError(try AndroidMaintenance.plan(storage: f.storage, keeping: f.keep, homeDirectory: f.home))
        XCTAssertEqual(try String(contentsOf: target.appendingPathComponent("userdata-qemu.img"), encoding: .utf8), "outside precious data")
    }
    func testForeignLocatorAndWrongKeptVersionAreRejected() throws {
        let f = try Fixture(); defer { f.remove() }
        XCTAssertThrowsError(try AndroidMaintenance.plan(storage: f.storage, keeping: "OldAndroid15", homeDirectory: f.home))
        XCTAssertThrowsError(try AndroidMaintenance.plan(storage: f.storage, keeping: "../Windows", homeDirectory: f.home))
        try f.write(f.storage.avd.appendingPathComponent("Foreign.ini"), "path=/outside/foreign.avd\n")
        XCTAssertThrowsError(try AndroidMaintenance.plan(storage: f.storage, keeping: f.keep, homeDirectory: f.home))
    }
    func testUnknownBackupContentsAreNotDeleted() throws {
        let f = try Fixture(); defer { f.remove() }
        let dir = f.storage.url.appendingPathComponent("Backups/Android-vor-Vergroesserung.Unknown")
        try f.write(dir.appendingPathComponent("family-photos.txt"), "keep")
        let plan = try AndroidMaintenance.plan(storage: f.storage, keeping: f.keep, homeDirectory: f.home)
        XCTAssertFalse(plan.paths.contains(dir.path))
    }
    func testSeparateHomeReferenceRetainsSharedImageAndOutsideUserData() throws {
        let f = try Fixture(); defer { f.remove() }
        let external = f.home.appendingPathComponent("Studio/SharedAndroid15.avd")
        let image = f.storage.sdk.appendingPathComponent("system-images/android-35/google_apis_playstore/arm64-v8a")
        try f.write(external.appendingPathComponent("config.ini"), "image.sysdir.1=\(image.path)/\n")
        try f.write(external.appendingPathComponent("userdata-qemu.img"), "outside data unchanged")
        try f.write(f.home.appendingPathComponent(".android/avd/Studio.ini"), "path=\(external.path)\n")

        let plan = try AndroidMaintenance.plan(storage: f.storage, keeping: f.keep, homeDirectory: f.home)
        let platform = image.deletingLastPathComponent().deletingLastPathComponent().path
        XCTAssertFalse(plan.paths.contains(platform))
        try AndroidMaintenance.cleanup(storage: f.storage, expected: plan, homeDirectory: f.home)
        XCTAssertEqual(try String(contentsOf: image.appendingPathComponent("system.img"), encoding: .utf8), "system")
        XCTAssertEqual(try String(contentsOf: external.appendingPathComponent("userdata-qemu.img"), encoding: .utf8), "outside data unchanged")
        XCTAssertFalse(FileManager.default.fileExists(atPath: f.storage.avd.appendingPathComponent("OldAndroid15.avd").path))
    }
    func testInvalidSeparateHomeAVDPathAbortsBeforeAnyDeletion() throws {
        let f = try Fixture(); defer { f.remove() }
        let plan = try AndroidMaintenance.plan(storage: f.storage, keeping: f.keep, homeDirectory: f.home)
        let avd = f.home.appendingPathComponent(".android/avd")
        try f.write(avd, "an existing file, not an AVD directory")

        XCTAssertThrowsError(try AndroidMaintenance.plan(storage: f.storage, keeping: f.keep, homeDirectory: f.home))
        XCTAssertThrowsError(try AndroidMaintenance.cleanup(storage: f.storage, expected: plan, homeDirectory: f.home))
        XCTAssertEqual(try String(contentsOf: avd, encoding: .utf8), "an existing file, not an AVD directory")
        XCTAssertEqual(try String(contentsOf: f.storage.avd.appendingPathComponent("OldAndroid15.avd/userdata-qemu.img"), encoding: .utf8), "precious user data OldAndroid15")
        XCTAssertTrue(FileManager.default.fileExists(atPath: f.storage.sdk.appendingPathComponent("system-images/android-35/google_apis_playstore/arm64-v8a/system.img").path))
    }
}

