import Foundation
#if canImport(FoundationXML)
import FoundationXML
#endif
import XCTest
@testable import StratovoCore

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
        XCTAssertTrue(spec.arguments.contains("tpm-tis-device,tpmdev=tpm0,ppi=off"))
        XCTAssertEqual(value("-accel", in: spec), "hvf")
        XCTAssertTrue(spec.arguments.contains("emulator,id=tpm0,chardev=chrtpm"))
    }

    func testWindowsISODevicesAreReadOnlyOpticalMedia() throws {
        let spec = try LaunchPlan.windowsVM(qemu: "/qemu", firmware: "/firmware.fd", variables: "/vars.fd", disk: "/saved.qcow2",
            tpmSocket: "/tmp/og-test/tpm.sock", iso: "/Win, ARM.iso", driversISO: "/Drivers.iso", proISO: "/Setup.iso",
            installing: true, resources: resources, displaySocket: "/tmp/og-test/display.sock", network: false,
            qmpSocket: "/tmp/og-test/qmp.sock")
        let blocks = try blockDevices(spec)
        for name in ["installer", "drivers", "edition"] {
            let block = try XCTUnwrap(blocks.first { $0["node-name"] as? String == name })
            XCTAssertEqual(block["read-only"] as? Bool, true)
            XCTAssertTrue(spec.arguments.contains("usb-bot,id=\(name)-usb,bus=usb.0"))
            let cd = try XCTUnwrap(spec.arguments.first { $0.hasPrefix("scsi-cd,id=\(name)-cd,") })
            XCTAssertTrue(cd.contains("drive=\(name),bus=\(name)-usb.0,scsi-id=0,lun=0"))
            XCTAssertEqual(cd.contains("bootindex=1"), name == "installer")
        }
        XCTAssertFalse(spec.arguments.contains { $0.hasPrefix("usb-storage,") })
        XCTAssertTrue(spec.arguments.contains("nvme,drive=systemdisk,serial=OpenGuestWindows,bootindex=2"))
    }

    func testNormalWindowsStartDoesNotReattachInstaller() throws {
        let spec = try windows(disk: "/disk.qcow2", installing: false, network: true)
        let blocks = try blockDevices(spec)
        XCTAssertFalse(blocks.contains { $0["node-name"] as? String == "installer" })
        XCTAssertFalse(blocks.contains { $0["node-name"] as? String == "edition" })
        XCTAssertEqual(value("-netdev", in: spec), "user,id=net0")
    }

    func testARMTPMDetectionRejectsPCDevicesAndSimilarNames() {
        let arm = "TPM devices:\nname \"tpm-tis-device\", bus System, desc \"TPM TIS\"\n"
        XCTAssertTrue(RuntimeDiscovery.hasDevice("tpm-tis-device", in: arm))
        XCTAssertFalse(RuntimeDiscovery.hasDevice("tpm-tis-device", in: "name \"tpm-tis\", bus ISA\nname \"tpm-crb\""))
        XCTAssertFalse(RuntimeDiscovery.hasDevice("tpm-tis-device", in: "name \"tpm-tis-device-extra\""))
        XCTAssertFalse(RuntimeDiscovery.hasDevice("tpm-tis-device", in: ""))
    }

    func testWindowsDownloadOnlyAcceptsDirectMicrosoftHTTPSLinks() throws {
        let link = "https://software.download.prss.microsoft.com/dbazure/Windows11_arm64.iso?t=temporary"
        XCTAssertEqual(try SetupDownloads.windowsISOURL(link).absoluteString, link)
        for bad in ["file:///tmp/Windows.iso", "http://download.microsoft.com/a.iso",
                    "https://microsoft.com.evil.example/a.iso", "https://evil.example/a.iso",
                    "https://download.microsoft.com/page.html", "https://user:pass@download.microsoft.com/a.iso",
                    "https://download.microsoft.com:444/a.iso"] {
            XCTAssertThrowsError(try SetupDownloads.windowsISOURL(bad), bad)
        }
    }

    func testLicenseButtonsOnlyAppearForAnUnansweredPromptAtEndOfOutput() {
        XCTAssertTrue(SetupDownloads.isLicensePrompt("License text\nAccept? (y/N): "))
        XCTAssertTrue(SetupDownloads.isLicensePrompt("Review licenses that have not been accepted (y/N)? "))
        XCTAssertFalse(SetupDownloads.isLicensePrompt("Accept? (y/N): y\nInstalling emulator 40%"))
        XCTAssertFalse(SetupDownloads.isLicensePrompt("Download complete"))
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

    func testWindowsSetupAcceptsValidEightCharacterPasswordForUserName() throws {
        let account = try WindowsEdition.validateSetupAccount(name: "PwnedG0blin", password: "Test123!", confirmation: "Test123!")
        XCTAssertEqual(account.name, "PwnedG0blin")
        XCTAssertNoThrow(try WindowsEdition.setupXML(selectPro: true, localAccount: account))
    }

    func testAccountValidationExplainsShortPasswordsAndMismatchWithoutLeakingThem() {
        XCTAssertThrowsError(try WindowsEdition.validateSetupAccount(name: "PwnedG0blin", password: "Short7!", confirmation: "Short7!")) { error in
            XCTAssertTrue(error.localizedDescription.contains("7 Zeichen"))
            XCTAssertFalse(error.localizedDescription.contains("Short7!"))
        }
        XCTAssertThrowsError(try WindowsEdition.validateSetupAccount(name: "PwnedG0blin", password: "Test123!", confirmation: "Other123!")) { error in
            XCTAssertTrue(error.localizedDescription.contains("stimmen nicht überein"))
            XCTAssertFalse(error.localizedDescription.contains("Test123!"))
            XCTAssertFalse(error.localizedDescription.contains("Other123!"))
        }
    }

    func testAccountValidationDistinguishesInvalidAndReservedNames() {
        for name in ["", "bad/name", "name.", " name", "Administrator", String(repeating: "a", count: 21)] {
            XCTAssertThrowsError(try WindowsEdition.validateSetupAccount(name: name, password: "Test123!", confirmation: "Test123!")) { error in
                XCTAssertTrue(error.localizedDescription.contains("Benutzername"))
                XCTAssertFalse(error.localizedDescription.contains("Test123!"))
            }
        }
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
