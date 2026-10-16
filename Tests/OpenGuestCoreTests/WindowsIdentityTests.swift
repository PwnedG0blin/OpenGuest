import Foundation
import XCTest
@testable import OpenGuestCore
#if canImport(Darwin)
import Darwin
#else
import Glibc
#endif

final class WindowsIdentityTests: XCTestCase {
    private func fixture() throws -> GuestStorage {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("pk-id-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try Data("identity-fixture".utf8).write(to: root.appendingPathComponent(".openguest-storage-id"))
        return GuestStorage(root: root.path, id: "identity-fixture")
    }
    func testNewVMGetsDifferentStableIdentifiersBeforeDiskCreation() throws {
        let a = try fixture(), b = try fixture()
        defer { try? FileManager.default.removeItem(at: a.url); try? FileManager.default.removeItem(at: b.url) }
        let first = try WindowsIdentityStore.prepare(root: a.prepareWindowsFolder())
        let second = try WindowsIdentityStore.prepare(root: b.prepareWindowsFolder())
        try first.validate(); try second.validate()
        XCTAssertEqual(first.mode, .unique)
        XCTAssertNotEqual(first.uuid, second.uuid)
        XCTAssertNotEqual(first.serial, second.serial)
        XCTAssertNotEqual(first.mac, second.mac)
        XCTAssertEqual(first.serial.utf8.count, 20, "NVMe serial must fit its 20-byte field")
        XCTAssertEqual(try WindowsIdentityStore.prepare(root: a.windows), first)
    }
    func testExistingDiskKeepsLegacyIdentityUntilExplicitChangeAndCanRestore() throws {
        let storage = try fixture()
        defer { try? FileManager.default.removeItem(at: storage.url) }
        let root = try storage.prepareWindowsFolder()
        let disk = root.appendingPathComponent("windows.qcow2")
        let vars = root.appendingPathComponent("uefi-vars.fd")
        let tpm = root.appendingPathComponent("TPM")
        try Data("guest-disk-preserve".utf8).write(to: disk)
        try Data("firmware-vars-preserve".utf8).write(to: vars)
        try FileManager.default.createDirectory(at: tpm, withIntermediateDirectories: true)
        let state = tpm.appendingPathComponent("tpm2-00.permall")
        try Data("tpm-preserve".utf8).write(to: state)
        XCTAssertEqual(try WindowsIdentityStore.prepare(root: root), .legacy)
        let unique = try WindowsIdentityStore.useUnique(storage: storage)
        XCTAssertEqual(unique.mode, .unique)
        XCTAssertTrue(try WindowsIdentityStore.canRestore(root: root))
        XCTAssertEqual(try WindowsIdentityStore.useUnique(storage: storage), unique, "Never rotate on repeat")
        XCTAssertEqual(try WindowsIdentityStore.useUnique(storage: storage, restore: true), .legacy)
        XCTAssertEqual(try WindowsIdentityStore.useUnique(storage: storage), unique, "Retry reuses the saved candidate")
        XCTAssertEqual(try Data(contentsOf: disk), Data("guest-disk-preserve".utf8))
        XCTAssertEqual(try Data(contentsOf: vars), Data("firmware-vars-preserve".utf8))
        XCTAssertEqual(try Data(contentsOf: state), Data("tpm-preserve".utf8))
    }
    func testChangingIdentityIsRejectedWhileAnotherVMHoldsSessionLock() throws {
        let storage = try fixture()
        defer { try? FileManager.default.removeItem(at: storage.url) }
        let root = try storage.prepareWindowsFolder()
        try Data([1]).write(to: root.appendingPathComponent("windows.qcow2"))
        XCTAssertEqual(try WindowsIdentityStore.prepare(root: root), .legacy)
        let fd = open(root.appendingPathComponent("session.lock").path, O_CREAT | O_RDWR, 0o600)
        XCTAssertGreaterThanOrEqual(fd, 0)
        defer { flock(fd, LOCK_UN); close(fd) }
        XCTAssertEqual(flock(fd, LOCK_EX | LOCK_NB), 0)
        XCTAssertThrowsError(try WindowsIdentityStore.useUnique(storage: storage))
        XCTAssertEqual(try WindowsIdentityStore.load(root: root), .legacy)
    }
    func testMissingCorruptOrLinkedIdentityNeverSilentlyRegenerates() throws {
        let storage = try fixture()
        defer { try? FileManager.default.removeItem(at: storage.url) }
        let root = try storage.prepareWindowsFolder()
        _ = try WindowsIdentityStore.prepare(root: root)
        let file = root.appendingPathComponent("Machine/identity.json")
        let outside = storage.url.appendingPathComponent("outside.json")
        let original = try Data(contentsOf: file)
        try FileManager.default.removeItem(at: file)
        XCTAssertThrowsError(try WindowsIdentityStore.prepare(root: root))
        try Data("broken-json".utf8).write(to: file)
        XCTAssertThrowsError(try WindowsIdentityStore.prepare(root: root))
        try FileManager.default.removeItem(at: file)
        try original.write(to: outside)
        try FileManager.default.createSymbolicLink(at: file, withDestinationURL: outside)
        XCTAssertThrowsError(try WindowsIdentityStore.prepare(root: root))
        XCTAssertEqual(try Data(contentsOf: outside), original)
    }
    func testLaunchPlanUsesUniqueUUIDSerialAndMACWithoutChangingLegacyArguments() throws {
        let identity = WindowsMachineIdentity.generate()
        func plan(_ id: WindowsMachineIdentity) throws -> CommandSpec {
            try LaunchPlan.windowsVM(qemu: "/qemu", firmware: "/fw.fd", variables: "/vars.fd", disk: "/disk.qcow2", tpmSocket: "/tmp/og-test/tpm.sock", iso: nil, driversISO: nil, proISO: nil,
                installing: false, resources: GuestResources(memoryMiB: 4096, cores: 4), displaySocket: "/tmp/og-test/display.sock", network: true, qmpSocket: "/tmp/og-test/qmp.sock", identity: id)
        }
        let new = try plan(identity)
        let uuidFlag = try XCTUnwrap(new.arguments.firstIndex(of: "-uuid"))
        XCTAssertEqual(new.arguments[uuidFlag + 1], identity.uuid)
        XCTAssertTrue(new.arguments.contains("nvme,drive=systemdisk,serial=\(identity.serial),bootindex=2"))
        XCTAssertTrue(new.arguments.contains("virtio-net-pci,netdev=net0,mac=\(identity.mac!)"))
        XCTAssertTrue(new.arguments.contains { $0.hasPrefix("type=1,") && $0.contains("serial=\(identity.serial)") })
        let old = try plan(.legacy)
        XCTAssertFalse(old.arguments.contains("-uuid"))
        XCTAssertFalse(old.arguments.contains("-smbios"))
        XCTAssertTrue(old.arguments.contains("nvme,drive=systemdisk,serial=OpenGuestWindows,bootindex=2"))
        XCTAssertTrue(old.arguments.contains("virtio-net-pci,netdev=net0"))
    }
    func testMalformedIdentityIsRejectedBeforeLaunch() throws {
        let bad = Data(#"{"version":1,"mode":"unique","uuid":"00000000-0000-0000-0000-000000000000","serial":"PK000000000000000000","mac":"02:11:22:33:44:55"}"#.utf8)
        let id = try JSONDecoder().decode(WindowsMachineIdentity.self, from: bad)
        XCTAssertThrowsError(try id.validate())
    }
    func testISOHashReadsExistingBytesAndDoesNotCertifyUnknownImage() throws {
        let file = FileManager.default.temporaryDirectory.appendingPathComponent("pk-hash-\(UUID().uuidString).iso")
        defer { try? FileManager.default.removeItem(at: file) }
        try Data("abc".utf8).write(to: file)
        let result = try WindowsISOHash.calculate(path: file.path)
        XCTAssertEqual(result.sha256, "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
        XCTAssertFalse(result.matchesMicrosoftGerman26H2)
        XCTAssertEqual(try Data(contentsOf: file), Data("abc".utf8))
    }
}
