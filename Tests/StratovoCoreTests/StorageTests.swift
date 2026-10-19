import Foundation
import XCTest
@testable import StratovoCore

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
            root = temporary.appendingPathComponent("External SSD/Stratovo")
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
    func testExtraDestinationMetadataDoesNotFailCopyVerification() throws {
        let f = try Fixture(); defer { f.remove() }; try f.seed()
        let destination = f.root.appendingPathComponent("Android/sdk")
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
        try Data([0, 5, 22, 7, 0, 2, 0, 0]).write(to: destination.appendingPathComponent("._emulator-file"))
        try Data("Finder metadata".utf8).write(to: destination.appendingPathComponent(".DS_Store"))
        try Data("preserve additional file".utf8).write(to: destination.appendingPathComponent("existing-extra"))
        let storage = try f.prepare()
        XCTAssertEqual(try Data(contentsOf: storage.sdk.appendingPathComponent("emulator-file")), Data("engine".utf8))
        XCTAssertEqual(try Data(contentsOf: storage.sdk.appendingPathComponent("existing-extra")), Data("preserve additional file".utf8))
        try f.cleanup(storage)
        XCTAssertTrue(FileManager.default.fileExists(atPath: storage.sdk.appendingPathComponent("existing-extra").path))
    }

    func testPayloadVerificationStillRejectsChangedMissingAndWrongTypeFiles() throws {
        let f = try Fixture(); defer { f.remove() }; try f.seed()
        let destination = f.root.appendingPathComponent("verification")
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
        let file = destination.appendingPathComponent("emulator-file")
        XCTAssertThrowsError(try StorageMigration.verifyCopy(f.sdk, destination: destination))
        try Data("wrong bytes".utf8).write(to: file)
        XCTAssertThrowsError(try StorageMigration.verifyCopy(f.sdk, destination: destination))
        try FileManager.default.removeItem(at: file)
        try FileManager.default.createDirectory(at: file, withIntermediateDirectories: true)
        XCTAssertThrowsError(try StorageMigration.verifyCopy(f.sdk, destination: destination))
        try FileManager.default.removeItem(at: file)
        try Data("engine".utf8).write(to: file)
        XCTAssertNoThrow(try StorageMigration.verifyCopy(f.sdk, destination: destination))
    }

    func testInterruptedMigrationResumesWithExtraTargetMetadata() throws {
        let f = try Fixture(); defer { f.remove() }; try f.seed()
        let storage = try f.prepare()
        try FileManager.default.removeItem(at: f.avd)
        try Data("external metadata".utf8).write(to: storage.avd.appendingPathComponent("._userdata.img"))
        let resumed = try f.prepare()
        XCTAssertEqual(storage.id, resumed.id)
        XCTAssertEqual(try Data(contentsOf: f.avd.appendingPathComponent("userdata.img")), Data("precious saved game".utf8))
    }

}
