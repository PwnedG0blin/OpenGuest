import Foundation
#if canImport(FoundationXML)
import FoundationXML
#endif
import XCTest
@testable import OpenGuestCore

final class CoreTests: XCTestCase {
    private let resources = GuestResources(memoryMiB: 4096, cores: 4)

    func testAndroidPreservesDataAndUsesSelectedSerialPort() throws {
        let spec = try LaunchPlan.android(sdk: "/SDK with spaces", device: AndroidDevice(name: "GooglePlay", abi: "arm64-v8a"),
                                          resources: resources, coldBoot: false, gpu: "auto", port: 5562)
        XCTAssertEqual(spec.executable, "/SDK with spaces/emulator/emulator")
        XCTAssertTrue(spec.arguments.contains("-no-window"))
        XCTAssertEqual(value("-port", in: spec), "5562")
        XCTAssertEqual(value("-accel", in: spec), "on")
        for flag in ["-wipe-data", "-read-only", "-no-snapshot", "-no-snapshot-save"] { XCTAssertFalse(spec.arguments.contains(flag)) }
    }

    func testWrongArchitectureAndResourceLimitsAreRejected() {
        XCTAssertThrowsError(try LaunchPlan.android(sdk: "/SDK", device: AndroidDevice(name: "Intel", abi: "x86_64"), resources: resources, coldBoot: false, gpu: "auto"))
        XCTAssertThrowsError(try GuestResources(memoryMiB: 1024, cores: 4).validate())
        XCTAssertThrowsError(try GuestResources(memoryMiB: 2048, cores: 4).validate(windows: true))
        XCTAssertThrowsError(try GuestResources(memoryMiB: 4096, cores: 99).validate())
    }

    func testColdBootDoesNotResetAndroidData() throws {
        let spec = try LaunchPlan.android(sdk: "/SDK", device: AndroidDevice(name: "Phone", abi: "arm64-v8a"), resources: resources, coldBoot: true, gpu: "host")
        XCTAssertTrue(spec.arguments.contains("-no-snapshot-load"))
        XCTAssertFalse(spec.arguments.contains("-wipe-data"))
    }

    func testAPKIsAlwaysTargetedAndFilenameRemainsOneArgument() throws {
        let file = FileManager.default.temporaryDirectory.appendingPathComponent("Game ; echo ignored \(UUID()).apk")
        try Data("fixture".utf8).write(to: file)
        defer { try? FileManager.default.removeItem(at: file) }
        let spec = try LaunchPlan.installAPK(adb: "/sdk/adb", port: 5558, apk: file.path)
        XCTAssertEqual(spec.arguments, ["-s", "emulator-5558", "install", "-r", file.path])
        XCTAssertThrowsError(try LaunchPlan.installAPK(adb: "/sdk/adb", port: 5559, apk: file.path))
        XCTAssertThrowsError(try LaunchPlan.installAPK(adb: "/sdk/adb", port: 5558, apk: "/does-not-exist.apk"))
    }

    func testWindowsUsesPersistentStorageAndPrivateSockets() throws {
        let disk = "/My VM/a,b\"c.qcow2"
        let spec = try windows(disk: disk, installing: true, network: false)
        XCTAssertEqual(value("-vnc", in: spec), "unix:/tmp/og-test/display.sock")
        XCTAssertEqual(value("-nic", in: spec), "none")
        XCTAssertFalse(spec.arguments.contains("-snapshot"))
        XCTAssertFalse(spec.arguments.contains("-virtfs"))
        XCTAssertFalse(spec.arguments.contains("-fsdev"))
        let blocks = try blockDevices(spec)
        let system = try XCTUnwrap(blocks.first { $0["node-name"] as? String == "systemdisk" })
        XCTAssertEqual((system["file"] as? [String: Any])?["filename"] as? String, disk)
        XCTAssertEqual(system["read-only"] as? Bool, false)
        XCTAssertTrue(spec.arguments.contains("tpm-crb-device,tpmdev=tpm0"))
    }

    func testNormalWindowsStartDoesNotReattachInstaller() throws {
        let spec = try windows(disk: "/disk.qcow2", installing: false, network: true)
        let blocks = try blockDevices(spec)
        XCTAssertFalse(blocks.contains { $0["node-name"] as? String == "installer" })
        XCTAssertFalse(blocks.contains { $0["node-name"] as? String == "edition" })
        XCTAssertEqual(value("-netdev", in: spec), "user,id=net0")
    }

    func testProAnswerFileKeepsNormalSetup() throws {
        let xml = try WindowsEdition.setupXML(selectPro: true, localAccount: nil)
        XCTAssertTrue(XMLParser(data: Data(xml.utf8)).parse())
        XCTAssertTrue(xml.contains("Windows 11 Pro"))
        for token in ["SkipMachineOOBE", "SkipUserOOBE", "DiskConfiguration", "ProductKey", "AutoLogon"] { XCTAssertFalse(xml.contains(token)) }
    }

    func testLocalAccountIsEscapedAndPasswordIsNotPlainText() throws {
        let password = "A_password_123&<>"
        let xml = try WindowsEdition.setupXML(selectPro: true, localAccount: .init(name: "Alex&Co", password: password))
        XCTAssertTrue(XMLParser(data: Data(xml.utf8)).parse())
        XCTAssertTrue(xml.contains("Alex&amp;Co"))
        XCTAssertTrue(xml.contains("<HideOnlineAccountScreens>true</HideOnlineAccountScreens>"))
        XCTAssertFalse(xml.contains(password))
        XCTAssertFalse(xml.contains("AutoLogon"))
        XCTAssertThrowsError(try WindowsEdition.setupXML(selectPro: true, localAccount: .init(name: "../admin", password: password)))
        XCTAssertThrowsError(try WindowsEdition.setupXML(selectPro: true, localAccount: .init(name: "Alex", password: "")))
    }

    func testScrcpySessionAndPacketHeaders() throws {
        XCTAssertEqual(try ScrcpyWire.header(Data([0x80, 0, 0, 0, 0, 0, 7, 128, 0, 0, 4, 56])), .session(width: 1920, height: 1080))
        XCTAssertEqual(try ScrcpyWire.header(Data([0x40, 0, 0, 0, 0, 0, 0, 10, 0, 0, 0, 5])), .packet(size: 5, pts: 10, configuration: true))
        XCTAssertThrowsError(try ScrcpyWire.header(Data(repeating: 0, count: 12)))
        XCTAssertThrowsError(try ScrcpyWire.header(Data([1, 2])))
        XCTAssertThrowsError(try ScrcpyWire.header(Data([0, 0, 0, 0, 0, 0, 0, 0, 255, 255, 255, 255])))
    }

    func testH264MixedStartCodesAndControlMessageSizes() {
        XCTAssertEqual(ScrcpyWire.nalUnits(Data([0, 0, 0, 1, 0x67, 1, 2, 0, 0, 1, 0x68, 3])), [Data([0x67, 1, 2]), Data([0x68, 3])])
        XCTAssertEqual(ScrcpyWire.key(66, down: true).count, 14)
        XCTAssertEqual(ScrcpyWire.touch(x: -10, y: 9999, width: 1920, height: 1080, action: 0).count, 32)
        XCTAssertEqual(ScrcpyWire.text("hello").count, 10)
    }

    func testINIAllowsEqualsInValueAndIgnoresComments() {
        let values = RuntimeDiscovery.parseINI("# ignored\nabi.type = arm64-v8a\npath=/dir/a=b\n; note\n")
        XCTAssertEqual(values["abi.type"], "arm64-v8a")
        XCTAssertEqual(values["path"], "/dir/a=b")
    }

    func testProcessDoesNotInterpretShellSyntax() throws {
        let result = try CommandCapture.run(CommandSpec(executable: "/bin/echo", arguments: ["$(echo should-not-run);*`uname`"], environment: [:]))
        XCTAssertEqual(result.status, 0)
        XCTAssertEqual(result.output.trimmingCharacters(in: .newlines), "$(echo should-not-run);*`uname`")
    }

    func testProbeTimeoutReturnsAnError() {
        XCTAssertThrowsError(try CommandCapture.run(CommandSpec(executable: "/bin/sleep", arguments: ["3"]), timeout: 0.1))
    }

    private func value(_ flag: String, in spec: CommandSpec) -> String? {
        guard let i = spec.arguments.firstIndex(of: flag), i + 1 < spec.arguments.count else { return nil }
        return spec.arguments[i + 1]
    }
    private func windows(disk: String, installing: Bool, network: Bool) throws -> CommandSpec {
        try LaunchPlan.windowsVM(qemu: "/qemu", firmware: "/firmware.fd", variables: "/variables.fd", disk: disk,
            tpmSocket: "/tmp/og-test/tpm.sock", iso: "/Windows.iso", driversISO: nil, proISO: "/Pro.iso",
            installing: installing, resources: resources, displaySocket: "/tmp/og-test/display.sock", network: network, qmpSocket: "/tmp/og-test/qmp.sock")
    }
    private func blockDevices(_ spec: CommandSpec) throws -> [[String: Any]] {
        try spec.arguments.indices.filter { spec.arguments[$0] == "-blockdev" }.map {
            try JSONSerialization.jsonObject(with: Data(spec.arguments[$0 + 1].utf8)) as! [String: Any]
        }
    }
}
