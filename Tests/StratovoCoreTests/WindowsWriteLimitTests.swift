import Foundation
import XCTest
@testable import StratovoCore

final class WindowsWriteLimitTests: XCTestCase {
    private func plan(_ limit: WindowsWriteLimit = .off) throws -> CommandSpec {
        try LaunchPlan.windowsVM(qemu: "/qemu", firmware: "/fw", variables: "/vars", disk: "/data/My, disk.qcow2",
            tpmSocket: "/tmp/og-test/tpm.sock", iso: nil, driversISO: nil, proISO: nil, installing: false,
            resources: GuestResources(memoryMiB: 4096, cores: 4), displaySocket: "/tmp/og-test/display.sock",
            network: true, qmpSocket: "/tmp/og-test/qmp.sock", writeLimit: limit)
    }
    func testOffPreservesOriginalGraphAndDefault() throws {
        let spec = try plan()
        XCTAssertEqual(spec, try plan(.off))
        XCTAssertFalse(spec.arguments.contains("-object"))
        XCTAssertFalse(spec.arguments.contains { $0.contains("limited-systemdisk") })
        XCTAssertTrue(spec.arguments.contains("nvme,drive=systemdisk,serial=OpenGuestWindows,bootindex=2"))
        XCTAssertNil(WindowsWriteLimit(rawValue: -1))
        XCTAssertNil(WindowsWriteLimit(rawValue: 999))
    }
    func testLimitsPreserveImageAndIdentityAndCapOnlyWrites() throws {
        for limit in WindowsWriteLimit.allCases where limit != .off {
            let spec = try plan(limit), args = spec.arguments
            let i = try XCTUnwrap(args.firstIndex(of: "-object"))
            let group = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(args[i+1].utf8)) as? [String: Any])
            XCTAssertEqual(group["qom-type"] as? String, "throttle-group")
            XCTAssertEqual(group["limits"] as? [String: Int], ["bps-write": limit.rawValue * 1_048_576])
            let blocks = try args.indices.dropLast().filter { args[$0] == "-blockdev" }.map {
                try XCTUnwrap(JSONSerialization.jsonObject(with: Data(args[$0+1].utf8)) as? [String: Any])
            }
            let disk = try XCTUnwrap(blocks.first { $0["node-name"] as? String == "systemdisk" })
            XCTAssertEqual((disk["file"] as? [String: String])?["filename"], "/data/My, disk.qcow2")
            let filter = try XCTUnwrap(blocks.first { $0["driver"] as? String == "throttle" })
            XCTAssertEqual(filter["file"] as? String, "systemdisk")
            XCTAssertEqual(filter["throttle-group"] as? String, group["id"] as? String)
            XCTAssertTrue(args.contains("nvme,drive=limited-systemdisk,serial=OpenGuestWindows,bootindex=2"))
            XCTAssertFalse(args.contains("-snapshot"))
        }
    }
    func testRealQEMUThrottleWritesAndReadsTheSameQCOW2() throws {
        func tool(_ name: String) throws -> URL {
            let paths = (ProcessInfo.processInfo.environment["PATH"] ?? "").split(separator: ":").map(String.init)
                + ["/opt/homebrew/bin", "/usr/local/bin"]
            guard let path = paths.map({ URL(fileURLWithPath: $0).appendingPathComponent(name) })
                .first(where: { FileManager.default.isExecutableFile(atPath: $0.path) }) else {
                if ProcessInfo.processInfo.environment["OPENGUEST_REQUIRE_QEMU_TEST"] == "1" {
                    throw NSError(domain: "QEMURequired", code: 1)
                }
                throw XCTSkip("QEMU disk utilities unavailable")
            }
            return path
        }
        let imageTool = try tool("qemu-img"), ioTool = try tool("qemu-io")
        let temp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temp) }
        let disk = temp.appendingPathComponent("write-test.qcow2")
        func run(_ tool: URL, _ args: [String]) throws {
            let child = Process(); child.executableURL = tool; child.arguments = args
            child.standardOutput = FileHandle.nullDevice
            // Keep error output for failed QEMU options or data corruption.
            try child.run(); child.waitUntilExit()
            XCTAssertEqual(child.terminationStatus, 0)
        }
        try run(imageTool, ["create", "-f", "qcow2", disk.path, "128M"])
        let spec = try plan(.gentle), args = spec.arguments
        let groupIndex = try XCTUnwrap(args.firstIndex(of: "-object"))
        let blocks = try args.indices.dropLast().filter { args[$0] == "-blockdev" }.map {
            try XCTUnwrap(JSONSerialization.jsonObject(with: Data(args[$0+1].utf8)) as? [String: Any])
        }
        var image = try XCTUnwrap(blocks.first { $0["node-name"] as? String == "systemdisk" })
        image["file"] = ["driver": "file", "filename": disk.path]
        var filter = try XCTUnwrap(blocks.first { $0["driver"] as? String == "throttle" })
        filter["file"] = image
        let json = String(decoding: try JSONSerialization.data(withJSONObject: filter), as: UTF8.self)
        let start = Date()
        let writes = (0..<64).flatMap { ["-c", "write -P 0x5a \($0 * 1_048_576) 1M"] }
        try run(ioTool, ["--object", args[groupIndex+1]] + writes + ["-c", "flush", "json:" + json])
        XCTAssertGreaterThan(Date().timeIntervalSince(start), 1.5, "64 MiB writes must pass through the 20 MiB/s limit")
        // Reopen without the filter: data was stored in the same qcow2.
        try run(ioTool, ["-f", "qcow2", "-c", "read -P 0x5a 0 64M", disk.path])
    }

}
