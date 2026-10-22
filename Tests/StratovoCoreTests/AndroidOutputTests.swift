import XCTest
@testable import StratovoCore

final class AndroidOutputTests: XCTestCase {
    func testDirectLaunchUsesHostGPUAndNativeWindowWithoutResettingGuest() throws {
        for requested in ["auto", "host", "software"] {
            let direct = try plan(output: .direct, gpu: requested)
            XCTAssertFalse(direct.arguments.contains("-no-window"))
            XCTAssertEqual(direct.arguments[try XCTUnwrap(direct.arguments.firstIndex(of: "-gpu")) + 1], "host")
            XCTAssertTrue(AndroidOutputMode.direct.canLaunch(streamInstalled: false))
            for flag in ["-wipe-data", "-no-snapshot", "-no-snapshot-save", "-read-only"] {
                XCTAssertFalse(direct.arguments.contains(flag))
            }
        }
        let stream = try plan(output: .player, gpu: "host")
        let direct = try plan(output: .direct, gpu: "host")
        XCTAssertEqual(stream.arguments.filter { $0 != "-no-window" }, direct.arguments)
        XCTAssertEqual(stream.environment, direct.environment)
        XCTAssertFalse(AndroidOutputMode.player.canLaunch(streamInstalled: false))
        XCTAssertTrue(AndroidOutputMode.player.canLaunch(streamInstalled: true))
    }

    func testStreamKeepsRequestedGraphicsAndHeadlessPresentation() throws {
        let stream = try plan(output: .player, gpu: "software")
        XCTAssertTrue(stream.arguments.contains("-no-window"))
        XCTAssertEqual(stream.arguments[try XCTUnwrap(stream.arguments.firstIndex(of: "-gpu")) + 1], "software")
        XCTAssertEqual(stream.arguments[try XCTUnwrap(stream.arguments.firstIndex(of: "-port")) + 1], "5562")
        XCTAssertTrue(stream.arguments.contains("-no-snapshot-load"))
    }

    func testActivationIncludesOnlyCurrentLaunchDescendantsAndTerminatesOnCycles() {
        let snapshot = "10 1\n11 10\n12 11\n25 1\n26 25\n13 12\n1 13\ninvalid\n"
        XCTAssertEqual(AndroidProcessTree.descendants(of: 10, snapshot: snapshot), [11, 12, 13])
        // A normal system tree never has the cycle above. Even malformed input must stop.
        XCTAssertEqual(AndroidProcessTree.descendants(of: 10, snapshot: "11 10\n12 11\n25 1\n26 25"), [11, 12])
        XCTAssertEqual(AndroidProcessTree.descendants(of: 10, snapshot: "garbage"), [])
    }

    private func plan(output: AndroidOutputMode, gpu: String) throws -> CommandSpec {
        try LaunchPlan.android(sdk: "/SDK with spaces", device: AndroidDevice(name: "SavedPhone", abi: "arm64-v8a"),
                               resources: GuestResources(memoryMiB: 4096, cores: 4), coldBoot: true, gpu: gpu,
                               port: 5562, vulkan: false, output: output)
    }
}
