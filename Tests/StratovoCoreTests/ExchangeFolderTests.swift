import Foundation
import XCTest
@testable import StratovoCore

final class ExchangeFolderTests: XCTestCase {
    private func fixture() throws -> GuestStorage {
        let root = FileManager.default.temporaryDirectory.resolvingSymlinksInPath().appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try Data("exchange-test".utf8).write(to: root.appendingPathComponent(".openguest-storage-id"))
        return GuestStorage(root: root.path, id: "exchange-test")
    }
    func testExistingFilesAndGuestFoldersArePreservedAndImportsAreUnique() throws {
        let storage = try fixture()
        defer { try? FileManager.default.removeItem(at: storage.url) }
        let windows = storage.url.appendingPathComponent("Windows")
        try FileManager.default.createDirectory(at: windows, withIntermediateDirectories: false)
        let original = windows.appendingPathComponent("keep"); try Data([1, 2, 3]).write(to: original)
        let exchange = try ExchangeFolder.prepare(storage: storage)
        let file = exchange.appendingPathComponent("keep"); try Data([4, 5, 6]).write(to: file)
        XCTAssertEqual(try ExchangeFolder.prepare(storage: storage), exchange)
        XCTAssertEqual(try Data(contentsOf: file), Data([4, 5, 6]))
        XCTAssertEqual(try Data(contentsOf: original), Data([1, 2, 3]))
        let a = try ExchangeFolder.newAndroidImport(storage: storage)
        let b = try ExchangeFolder.newAndroidImport(storage: storage)
        XCTAssertNotEqual(a, b)
        XCTAssertTrue(a.path.hasPrefix(exchange.path + "/Android/"))
    }
    func testSymlinkAndMissingVolumeAreRejectedWithoutWritingTarget() throws {
        let storage = try fixture(), outside = try fixture()
        defer { try? FileManager.default.removeItem(at: storage.url); try? FileManager.default.removeItem(at: outside.url) }
        try FileManager.default.createSymbolicLink(at: storage.url.appendingPathComponent("Austausch"), withDestinationURL: outside.url)
        XCTAssertThrowsError(try ExchangeFolder.prepare(storage: storage))
        XCTAssertFalse(FileManager.default.fileExists(atPath: outside.url.appendingPathComponent("Android").path))
        try FileManager.default.removeItem(at: storage.url.appendingPathComponent(".openguest-storage-id"))
        XCTAssertThrowsError(try ExchangeFolder.prepare(storage: storage))
    }
}
