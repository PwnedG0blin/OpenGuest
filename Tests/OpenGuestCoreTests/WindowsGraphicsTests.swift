import Foundation
import XCTest
@testable import OpenGuestCore

final class WindowsGraphicsTests: XCTestCase {
    func testOptInGraphicsChangesOnlyDisplayDeviceInExistingVMLaunch() throws {
        let identity = WindowsMachineIdentity.generate()
        func plan(_ graphics: WindowsGraphics = .basic, _ mode: WindowsDisplayMode = .fullHD) throws -> CommandSpec {
            try LaunchPlan.windowsVM(qemu: "/qemu", firmware: "/fw.fd", variables: "/vars.fd", disk: "/disk.qcow2",
                tpmSocket: "/tmp/og-test/tpm.sock", iso: nil, driversISO: nil, proISO: nil, installing: false,
                resources: GuestResources(memoryMiB: 4096, cores: 4), displaySocket: "/tmp/og-test/display.sock",
                network: true, qmpSocket: "/tmp/og-test/qmp.sock", identity: identity, graphics: graphics, resolution: mode)
        }
        let original = try plan()
        XCTAssertTrue(original.arguments.contains("ramfb"))
        for mode in WindowsDisplayMode.allCases {
            let changed = try plan(.virtio, mode)
            XCTAssertEqual(changed.arguments, original.arguments.map { $0 == "ramfb" ? WindowsGraphics.virtio.device(resolution: mode) : $0 })
            XCTAssertEqual(mode.width * 9, mode.height * 16)
        }
    }
}
