import Foundation
import XCTest
import OpenGuestCore
@testable import OpenGuest

final class WindowsIdentityIntegrationTests: XCTestCase {
    @MainActor
    func testProductionIdentityAndVirtioGraphicsAcceptedAndUUIDConfirmedByRealQEMU() async throws {
        let fm = FileManager.default
        guard let engine = ["/opt/homebrew/bin/qemu-system-aarch64", "/usr/local/bin/qemu-system-aarch64", "/usr/bin/qemu-system-aarch64"].first(where: { fm.isExecutableFile(atPath: $0) }) else {
            if ProcessInfo.processInfo.environment["OPENGUEST_REQUIRE_QEMU_TEST"] == "1" { XCTFail("QEMU is required in CI"); return }
            throw XCTSkip("QEMU is installed in macOS CI")
        }
        let root = URL(fileURLWithPath: "/tmp/pk-id-\(UUID().uuidString.prefix(8))")
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: root) }
        let socket = root.appendingPathComponent("qmp.sock")
        let disk = root.appendingPathComponent("test.qcow2")
        let img = URL(fileURLWithPath: engine).deletingLastPathComponent().appendingPathComponent("qemu-img").path
        let made = try CommandCapture.run(CommandSpec(executable: img, arguments: ["create", "-f", "qcow2", disk.path, "64M"]))
        XCTAssertEqual(made.status, 0, made.output)
        let identity = WindowsMachineIdentity.generate()
        let plan = try LaunchPlan.windowsVM(qemu: engine, firmware: "/not-used.fd", variables: "/not-used-vars.fd", disk: disk.path,
            tpmSocket: "/tmp/og-id/tpm.sock", iso: nil, driversISO: nil, proISO: nil, installing: false,
            resources: GuestResources(memoryMiB: 4096, cores: 4), displaySocket: "/tmp/og-id/display.sock", network: true,
            qmpSocket: "/tmp/og-id/qmp.sock", identity: identity, graphics: .virtio, resolution: .qhd)
        var hardware = [String]()
        for (i, flag) in plan.arguments.enumerated() where i + 1 < plan.arguments.count {
            let value = plan.arguments[i + 1]
            if ["-uuid", "-smbios", "-netdev"].contains(flag) ||
               (flag == "-device" && (value.hasPrefix("nvme,") || value.hasPrefix("virtio-net-pci,") || value.hasPrefix("virtio-gpu-pci,"))) ||
               (flag == "-blockdev" && value.contains("\"node-name\":\"systemdisk\"")) {
                hardware += [flag, value]
            }
        }
        XCTAssertTrue(hardware.contains("virtio-gpu-pci,id=display0,xres=2560,yres=1440"))
        let output = root.appendingPathComponent("qemu.log")
        fm.createFile(atPath: output.path, contents: nil)
        let log = try FileHandle(forWritingTo: output)
        defer { try? log.close() }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: engine)
        process.arguments = ["-machine", "virt", "-accel", "tcg", "-cpu", "cortex-a72", "-m", "256", "-S", "-nodefaults", "-display", "none", "-serial", "none", "-monitor", "none", "-qmp", "unix:\(socket.path),server=on,wait=off"] + hardware
        process.standardInput = FileHandle.nullDevice
        process.standardOutput = log; process.standardError = log
        try process.run()
        defer { if process.isRunning { process.terminate() }; process.waitUntilExit() }
        let deadline = ProcessInfo.processInfo.systemUptime + 5
        while !fm.fileExists(atPath: socket.path), process.isRunning, ProcessInfo.processInfo.systemUptime < deadline {
            try await Task.sleep(nanoseconds: 20_000_000)
        }
        XCTAssertTrue(fm.fileExists(atPath: socket.path), (try? String(contentsOf: output)) ?? "QMP socket absent")
        let actual = try await QMPClient.machineUUID(socket: socket.path)
        XCTAssertEqual(actual, identity.uuid)
        XCTAssertTrue(process.isRunning, "Real QEMU must accept production SMBIOS, NVMe serial and MAC arguments")
    }
}
