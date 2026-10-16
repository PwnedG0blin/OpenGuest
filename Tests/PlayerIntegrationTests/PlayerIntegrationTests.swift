import AppKit
import Foundation
import XCTest
@testable import OpenGuest

final class PlayerIntegrationTests: XCTestCase {
    @MainActor
    func testRealQemuVNCConnectionReceivesFirstFramebuffer() async throws {
        let fm = FileManager.default
        guard let engine = ["/opt/homebrew/bin/qemu-system-aarch64", "/usr/local/bin/qemu-system-aarch64"].first(where: { fm.isExecutableFile(atPath: $0) }) else {
            if ProcessInfo.processInfo.environment["OPENGUEST_REQUIRE_QEMU_TEST"] == "1" {
                XCTFail("QEMU required in CI"); return
            }
            throw XCTSkip("QEMU not installed")
        }
        let root = URL(fileURLWithPath: "/tmp/og-rfb-\(UUID().uuidString.prefix(8))")
        try fm.createDirectory(at: root, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        defer { try? fm.removeItem(at: root) }
        let socket = root.appendingPathComponent("display.sock")
        let output = root.appendingPathComponent("qemu.log")
        let qmp = root.appendingPathComponent("qmp.sock")
        let iso = root.appendingPathComponent("fixture.iso")
        try Data(count: 1024 * 1024).write(to: iso)
        let block = String(decoding: try JSONSerialization.data(withJSONObject: [
            "driver": "raw", "node-name": "installer", "read-only": true,
            "file": ["driver": "file", "filename": iso.path]
        ]), as: UTF8.self)
        fm.createFile(atPath: output.path, contents: nil)
        let log = try FileHandle(forWritingTo: output)
        defer { try? log.close() }
        let qemu = Process()
        qemu.executableURL = URL(fileURLWithPath: engine)
        qemu.arguments = ["-machine", "virt", "-accel", "tcg", "-cpu", "cortex-a72", "-m", "256",
            "-S", "-nodefaults", "-device", "ramfb", "-display", "none", "-vnc", "unix:\(socket.path)",
            "-monitor", "none", "-serial", "none", "-nic", "none",
            "-qmp", "unix:\(qmp.path),server=on,wait=off",
            "-device", "qemu-xhci,id=usb", "-blockdev", block,
            "-device", "usb-bot,id=installer-usb,bus=usb.0",
            "-device", "scsi-cd,id=installer-cd,drive=installer,bus=installer-usb.0,scsi-id=0,lun=0,bootindex=1"]
        qemu.standardInput = FileHandle.nullDevice
        qemu.standardOutput = log; qemu.standardError = log
        try qemu.run()
        defer { if qemu.isRunning { qemu.terminate() }; qemu.waitUntilExit() }
        let deadline = ProcessInfo.processInfo.systemUptime + 5
        while !fm.fileExists(atPath: socket.path), qemu.isRunning, ProcessInfo.processInfo.systemUptime < deadline {
            try await Task.sleep(nanoseconds: 20_000_000)
        }
        XCTAssertTrue(fm.fileExists(atPath: socket.path), (try? String(contentsOf: output)) ?? "QEMU socket absent")
        let client = RFBClient()
        var received = false
        client.onFrame = { image in
            XCTAssertGreaterThan(image.size.width, 0)
            XCTAssertGreaterThan(image.size.height, 0)
            received = true
            client.stop()
        }
        let timeout = Task {
            try? await Task.sleep(nanoseconds: 10_000_000_000)
            if !Task.isCancelled { client.stop() }
        }
        defer { timeout.cancel(); client.stop() }
        do { try await client.run(socket: socket.path) }
        catch { if !received { XCTFail("Real QEMU player failed: \(error)") } }
        XCTAssertTrue(client.initialized, "RFB handshake must complete")
        XCTAssertTrue(received, "A real QEMU framebuffer must arrive without a guest OS")
        let boot = try await QMPClient.inspect(socket: qmp.path)
        XCTAssertTrue(boot.dvdConnected, "The app must confirm the actual inserted optical drive")
        XCTAssertEqual(boot.dvdPath, iso.path)
    }
}
