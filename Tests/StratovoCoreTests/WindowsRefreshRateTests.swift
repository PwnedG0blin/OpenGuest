import XCTest
@testable import StratovoCore

final class WindowsRefreshRateTests: XCTestCase {
    private func plan(_ rate: WindowsRefreshRate, embedded: Bool) throws -> CommandSpec {
        try LaunchPlan.windowsVM(qemu: "/qemu", firmware: "/fw", variables: "/vars", disk: "/data/windows.qcow2",
            tpmSocket: "/tmp/og-test/tpm.sock", iso: nil, driversISO: nil, proISO: nil, installing: false,
            resources: GuestResources(memoryMiB: 6144, cores: 6), displaySocket: "/tmp/og-test/display.sock",
            network: true, qmpSocket: "/tmp/og-test/qmp.sock", metalRoot: "/data/GraphicsLab",
            embeddedPlayer: embedded, refreshRate: rate)
    }
    func testTimingSelectionChangesOnlyTheMonitorEnvironment() throws {
        for embedded in [false, true] {
            let original = try plan(.automatic, embedded: embedded)
            XCTAssertNil(original.environment["STRATOVO_DISPLAY_HZ"])
            for rate in WindowsRefreshRate.allCases where rate != .automatic {
                let selected = try plan(rate, embedded: embedded)
                XCTAssertEqual(selected.arguments, original.arguments)
                XCTAssertEqual(selected.executable, original.executable)
                var expected = original.environment
                expected["STRATOVO_DISPLAY_HZ"] = String(rate.rawValue)
                XCTAssertEqual(selected.environment, expected)
            }
        }
        XCTAssertNil(WindowsRefreshRate(rawValue: -1))
        XCTAssertNil(WindowsRefreshRate(rawValue: 999))
    }
}
