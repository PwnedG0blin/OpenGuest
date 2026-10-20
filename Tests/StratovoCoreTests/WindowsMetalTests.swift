import Foundation
import XCTest
@testable import StratovoCore

final class WindowsMetalTests: XCTestCase {
    func testMetalKeepsExistingDiskIdentityAndSetupWhileUsingEmbeddedPlayer() throws {
        let spec = try LaunchPlan.windowsVM(qemu: "/old/qemu", firmware: "/data/Windows/firmware.fd",
            variables: "/data/Windows/uefi-vars.fd", disk: "/data/Windows/windows.qcow2",
            tpmSocket: "/tmp/og-test/tpm.sock", iso: "/data/windows.iso", driversISO: "/data/tools.iso",
            proISO: "/data/local-account.iso", installing: true,
            resources: GuestResources(memoryMiB: 6144, cores: 6), displaySocket: "/tmp/og-test/display.sock",
            network: false, qmpSocket: "/tmp/og-test/qmp.sock", metalRoot: "/data/GraphicsLab")
        XCTAssertEqual(spec.executable, "/data/GraphicsLab/Runtime/bin/qemu-system-aarch64")
        XCTAssertEqual(spec.environment["STRATOVO_EMBEDDED_V1"], "1")
        XCTAssertTrue(spec.arguments.contains("unix:/tmp/og-test/display.sock"))
        XCTAssertTrue(spec.arguments.contains("virtio-ramfb-gl,hostmem=8G,blob=true,venus=false,neptune=true"))
        XCTAssertTrue(spec.arguments.contains("hvf,ipa-granule-size=0x1000"))
        XCTAssertTrue(spec.arguments.contains("6144")); XCTAssertTrue(spec.arguments.contains("6"))
        XCTAssertTrue(spec.arguments.contains("none"))
        let nodes = try stride(from: 0, to: spec.arguments.count-1, by: 1).compactMap { index -> [String: Any]? in
            guard spec.arguments[index] == "-blockdev" else { return nil }
            return try JSONSerialization.jsonObject(with: Data(spec.arguments[index+1].utf8)) as? [String: Any]
        }
        let system = try XCTUnwrap(nodes.first { $0["node-name"] as? String == "systemdisk" })
        XCTAssertEqual((system["file"] as? [String: String])?["filename"], "/data/Windows/windows.qcow2")
        XCTAssertTrue(nodes.contains { ($0["file"] as? [String: String])?["filename"] == "/data/local-account.iso" })
        XCTAssertTrue(nodes.contains { ($0["file"] as? [String: String])?["filename"] == "/data/GraphicsLab/GraphicsDrivers.iso" })
        XCTAssertFalse(spec.arguments.contains { $0.contains("TestVM") })
    }
    func testBootArtworkLeavesGuestContentAndSourceBytesUntouched() {
        let width = 64, height = 64, frameWidth = 128, frameHeight = 128
        var samples: [BootArtwork.Sample] = []
        var bytes = Data(repeating: 0, count: frameWidth*frameHeight*4)
        for y in stride(from: 0, to: height, by: 8) {
            for x in stride(from: 0, to: width, by: 8) {
                let red: UInt8 = x < 32 ? 200 : 20
                samples.append(.init(x: x, y: y, red: red, green: 80, blue: 40))
                let index = ((32+y)*frameWidth+32+x)*4
                bytes[index] = 40; bytes[index+1] = 80; bytes[index+2] = red
            }
        }
        let artwork = BootArtwork(width: width, height: height, samples: samples)
        let original = bytes
        XCTAssertNotEqual(artwork.displayBytes(bytes, frameWidth: frameWidth, frameHeight: frameHeight), original)
        XCTAssertEqual(bytes, original)
        bytes[32*frameWidth*4+32*4] = 255
        XCTAssertEqual(artwork.displayBytes(bytes, frameWidth: frameWidth, frameHeight: frameHeight), bytes)
        let desktop = Data(repeating: 255, count: original.count)
        XCTAssertEqual(artwork.displayBytes(desktop, frameWidth: frameWidth, frameHeight: frameHeight), desktop)
    }
}
