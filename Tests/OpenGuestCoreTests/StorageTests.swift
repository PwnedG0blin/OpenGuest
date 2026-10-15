import Foundation
import XCTest
@testable import OpenGuestCore

final class StorageTests: XCTestCase {
    struct Fixture {
        let temporary: URL
        let home: URL
        let support: URL
        let root: URL
        var sdk: URL { home.appendingPathComponent("Library/Android/sdk") }
        var avd: URL { home.appendingPathComponent(".android/avd") }
        init() throws {
            temporary = FileManager.default.temporaryDirectory.appendingPathComponent("og-storage-\(UUID())")
            home = temporary.appendingPathComponent("home")
            support = home.appendingPathComponent("Library/Application Support/OpenGuest")
            root = temporary.appendingPathComponent("External SSD/OpenGuest")
            for directory in [home, support, root.deletingLastPathComponent(), home.appendingPathComponent("Downloads")] {
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            }
        }
        func seed() throws {
            try FileManager.default.createDirectory(at: sdk, withIntermediateDirectories: true)
            try FileManager.default.createDirectory(at: avd, withIntermediateDirectories: true)
            try Data("engine".utf8).write(to: sdk.appendingPathComponent("emulator-file"))
            try Data("precious saved game".utf8).write(to: avd.appendingPathComponent("userdata.img"))
        }
        func prepare(media: [String] = []) throws -> GuestStorage {
            try StorageMigration.prepare(root: root, home: home, support: support, mediaSources: media)
        }
        func cleanup(_ storage: GuestStorage) throws { try StorageMigration.cleanup(storage, home: home, support: support) }
        func remove() { try? FileManager.default.removeItem(at: temporary) }
    }
    func testMigrationRetainsOriginalsAndRedirectsWrites() throws {
        let f = try Fixture(); defer { f.remove() }; try f.seed()
        let storage = try f.prepare()
        XCTAssertEqual(try Data(contentsOf: storage.avd.appendingPathComponent("userdata.img")), Data("precious saved game".utf8))
        XCTAssertEqual(try FileManager.default.destinationOfSymbolicLink(atPath: f.avd.path), storage.avd.path)
        XCTAssertTrue(FileManager.default.fileExists(atPath: f.sdk.path + ".OpenGuest-intern"))
        try Data("new game progress".utf8).write(to: f.avd.appendingPathComponent("userdata.img"))
        XCTAssertEqual(try Data(contentsOf: storage.avd.appendingPathComponent("userdata.img")), Data("new game progress".utf8))
        try f.cleanup(storage)
        XCTAssertFalse(FileManager.default.fileExists(atPath: f.avd.path + ".OpenGuest-intern"))
        XCTAssertEqual(try Data(contentsOf: storage.avd.appendingPathComponent("userdata.img")), Data("new game progress".utf8))
    }
    func testConflictingTargetPreservesSource() throws {
        let f = try Fixture(); defer { f.remove() }; try f.seed()
        let target = f.root.appendingPathComponent("Android/sdk")
        try FileManager.default.createDirectory(at: target, withIntermediateDirectories: true)
        try Data("different".utf8).write(to: target.appendingPathComponent("emulator-file"))
        XCTAssertThrowsError(try f.prepare())
        XCTAssertEqual(try Data(contentsOf: f.sdk.appendingPathComponent("emulator-file")), Data("engine".utf8))
        XCTAssertNil(try? FileManager.default.destinationOfSymbolicLink(atPath: f.sdk.path))
    }
    func testChangedBackupStopsAllCleanup() throws {
        let f = try Fixture(); defer { f.remove() }; try f.seed()
        let storage = try f.prepare()
        try Data("changed".utf8).write(to: URL(fileURLWithPath: f.avd.path + ".OpenGuest-intern/userdata.img"))
        XCTAssertThrowsError(try f.cleanup(storage))
        XCTAssertTrue(FileManager.default.fileExists(atPath: f.sdk.path + ".OpenGuest-intern"))
    }
    func testMissingDestinationDiskPreventsCleanup() throws {
        let f = try Fixture(); defer { f.remove() }; try f.seed()
        let storage = try f.prepare()
        try FileManager.default.removeItem(at: storage.avd.appendingPathComponent("userdata.img"))
        XCTAssertThrowsError(try f.cleanup(storage))
        XCTAssertTrue(FileManager.default.fileExists(atPath: f.avd.path + ".OpenGuest-intern"))
    }
    func testResumeAfterRenameAndRepeatAreSafe() throws {
        let f = try Fixture(); defer { f.remove() }; try f.seed()
        let first = try f.prepare()
        try FileManager.default.removeItem(at: f.avd) // remove link only
        let resumed = try f.prepare()
        XCTAssertEqual(first.id, resumed.id)
        XCTAssertEqual(try f.prepare().id, first.id)
        XCTAssertEqual(try Data(contentsOf: f.avd.appendingPathComponent("userdata.img")), Data("precious saved game".utf8))
    }
    func testDisconnectedStorageDoesNotFallBackOrDelete() throws {
        let f = try Fixture(); defer { f.remove() }; try f.seed()
        let storage = try f.prepare()
        let detached = f.root.deletingLastPathComponent().appendingPathComponent("detached")
        try FileManager.default.moveItem(at: f.root, to: detached)
        XCTAssertThrowsError(try storage.validate())
        XCTAssertThrowsError(try f.cleanup(storage))
        XCTAssertFalse(FileManager.default.fileExists(atPath: f.root.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: f.avd.path + ".OpenGuest-intern"))
    }
    func testFirstRunCreatesExternalDefaultsAndPointerRoundTrip() throws {
        let f = try Fixture(); defer { f.remove() }
        let storage = try f.prepare()
        let pointer = f.support.appendingPathComponent("storage.json")
        try storage.save(to: pointer)
        XCTAssertEqual(GuestStorage.load(from: pointer), storage)
        XCTAssertEqual(storage.environment["ANDROID_AVD_HOME"], storage.avd.path)
        XCTAssertTrue(storage.sdk.path.hasPrefix(f.root.path))
        XCTAssertTrue(storage.windows.path.hasPrefix(f.root.path))
        XCTAssertEqual(try StorageMigration.backupPaths(storage, home: f.home, support: f.support), [])
    }
    func testISOIsMovedOnlyWhenExplicitlySelectedAndUnrelatedDownloadsRemain() throws {
        let f = try Fixture(); defer { f.remove() }; try f.seed()
        let iso = f.home.appendingPathComponent("Downloads/Windows ARM.iso")
        let unrelated = f.home.appendingPathComponent("Downloads/private.txt")
        try Data("ISO bytes".utf8).write(to: iso)
        try Data("unrelated".utf8).write(to: unrelated)
        let storage = try f.prepare(media: [iso.path, iso.path])
        XCTAssertEqual(storage.mediaSources, [iso.path])
        XCTAssertEqual(try Data(contentsOf: storage.url.appendingPathComponent("Installationsmedien/Windows ARM.iso")), Data("ISO bytes".utf8))
        try f.cleanup(storage)
        XCTAssertTrue(FileManager.default.fileExists(atPath: unrelated.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: iso.path + ".OpenGuest-intern"))
        XCTAssertEqual(try Data(contentsOf: iso), Data("ISO bytes".utf8))
    }
    func testOverlappingRootAndUnselectedPathsRejected() throws {
        let f = try Fixture(); defer { f.remove() }; try f.seed()
        XCTAssertThrowsError(try StorageMigration.prepare(root: f.sdk.appendingPathComponent("nested"), home: f.home, support: f.support))
        XCTAssertThrowsError(try f.prepare(media: [f.home.appendingPathComponent("private.iso").path]))
        XCTAssertEqual(try Data(contentsOf: f.avd.appendingPathComponent("userdata.img")), Data("precious saved game".utf8))
    }
}
