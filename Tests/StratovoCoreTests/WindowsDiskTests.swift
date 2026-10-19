import Foundation
import XCTest
@testable import StratovoCore

final class WindowsDiskTests: XCTestCase {
    func testCapacityBoundsAndShrinkRefusal() throws {
        XCTAssertEqual(try WindowsDisk.capacityGiB(" 256 "), 256)
        for text in ["0", "63", "4097", "1.5", "-80", "not a size"] {
            XCTAssertThrowsError(try WindowsDisk.capacityGiB(text))
        }
        let bytes: Int64 = 80 * 1_073_741_824
        XCTAssertFalse(try WindowsDisk.requiresGrowth(currentBytes: bytes, requestedGiB: 80))
        XCTAssertTrue(try WindowsDisk.requiresGrowth(currentBytes: bytes, requestedGiB: 128))
        XCTAssertThrowsError(try WindowsDisk.requiresGrowth(currentBytes: bytes, requestedGiB: 64))
    }
    func testDiskInfoRejectsBackingChainsAndWrongFormats() throws {
        let valid = Data(#"{"format":"qcow2","virtual-size":85899345920}"#.utf8)
        XCTAssertEqual(try WindowsDisk.virtualBytes(from: valid), 80 * 1_073_741_824)
        for json in [#"{"format":"raw","virtual-size":100}"#,
                     #"{"format":"qcow2","virtual-size":100,"backing-filename":"base.qcow2"}"#,
                     #"{"format":"qcow2","virtual-size":-1}"#] {
            XCTAssertThrowsError(try WindowsDisk.virtualBytes(from: Data(json.utf8)))
        }
    }
    func testRealQcowGrowthPreservesGuestBytesAndRefusesShrink() throws {
        let fm = FileManager.default
        guard let engine = ["/opt/homebrew/bin/qemu-img", "/usr/local/bin/qemu-img", "/usr/bin/qemu-img"].first(where: { fm.isExecutableFile(atPath: $0) }) else {
            if ProcessInfo.processInfo.environment["OPENGUEST_REQUIRE_QEMU_TEST"] == "1" {
                XCTFail("QEMU disk utilities are required in CI")
                return
            }
            throw XCTSkip("QEMU disk utilities are installed by macOS CI.")
        }
        let io = URL(fileURLWithPath: engine).deletingLastPathComponent().appendingPathComponent("qemu-io").path
        XCTAssertTrue(fm.isExecutableFile(atPath: io))
        let root = fm.temporaryDirectory.appendingPathComponent("og-real-disk-\(UUID().uuidString)")
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: root) }
        try Data("fixture".utf8).write(to: root.appendingPathComponent(".openguest-storage-id"))
        let storage = GuestStorage(root: root.path, id: "fixture")
        let disk = storage.windows.appendingPathComponent("windows.qcow2")
        XCTAssertEqual(try WindowsDiskImage.prepare(qemuImg: engine, storage: storage, capacityGiB: 64), 64 * 1_073_741_824)
        let write = try CommandCapture.run(CommandSpec(executable: io, arguments: ["-f", "qcow2", "-c", "write -P 0x5a 0 64k", disk.path]))
        XCTAssertEqual(write.status, 0, write.output)
        XCTAssertEqual(try WindowsDiskImage.prepare(qemuImg: engine, storage: storage, capacityGiB: 80), 80 * 1_073_741_824)
        let read = try CommandCapture.run(CommandSpec(executable: io, arguments: ["-f", "qcow2", "-c", "read -P 0x5a 0 64k", disk.path]))
        XCTAssertEqual(read.status, 0, read.output)
        XCTAssertThrowsError(try WindowsDiskImage.prepare(qemuImg: engine, storage: storage, capacityGiB: 64))
        XCTAssertEqual(try WindowsDiskImage.info(qemuImg: engine, disk: disk), 80 * 1_073_741_824)
        let after = try CommandCapture.run(CommandSpec(executable: io, arguments: ["-f", "qcow2", "-c", "read -P 0x5a 0 64k", disk.path]))
        XCTAssertEqual(after.status, 0, after.output)
    }
}
