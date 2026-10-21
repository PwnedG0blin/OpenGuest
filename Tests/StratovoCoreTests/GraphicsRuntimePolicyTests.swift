import Foundation
import XCTest
@testable import StratovoCore

final class GraphicsRuntimePolicyTests: XCTestCase {
    private func policy(resources: [String] = ["runtime-policy.json", "lab.py"]) throws -> GraphicsRuntimePolicy {
        try GraphicsRuntimePolicy.decode(JSONSerialization.data(withJSONObject: [
            "version": 1, "embeddedPlayer": 1, "embeddedRevision": 8,
            "runtimeDependencies": 1, "resources": resources
        ]))
    }
    func testReceiptsRequireEveryCompatibilityField() throws {
        let policy = try policy()
        func receipt(_ revision: Int, dependencies: Int = 1) throws -> Data {
            try JSONSerialization.data(withJSONObject: ["embeddedPlayer": 1,
                "embeddedRevision": revision, "runtimeDependencies": dependencies])
        }
        XCTAssertTrue(policy.accepts(receipt: try receipt(8)))
        XCTAssertFalse(policy.accepts(receipt: try receipt(7)))
        XCTAssertFalse(policy.accepts(receipt: try receipt(9)))
        XCTAssertFalse(policy.accepts(receipt: try receipt(8, dependencies: 0)))
        XCTAssertFalse(policy.accepts(receipt: Data("{}".utf8)))
    }
    func testUnsafeAndDuplicateResourceNamesAreRejected() {
        for name in ["../lab.py", "/tmp/lab.py", "sub/lab.py", "sub\\lab.py", "", ".hidden"] {
            XCTAssertThrowsError(try policy(resources: ["runtime-policy.json", name]))
        }
        XCTAssertThrowsError(try policy(resources: ["runtime-policy.json", "runtime-policy.json"]))
    }
    func testCompleteResourcesAreReadBeforeAnyCallerCanWrite() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        try Data("policy".utf8).write(to: folder.appendingPathComponent("runtime-policy.json"))
        let value = try policy()
        XCTAssertThrowsError(try value.readResources(from: folder))
        try Data("source".utf8).write(to: folder.appendingPathComponent("lab.py"))
        XCTAssertEqual(try value.readResources(from: folder).map(\.name), ["runtime-policy.json", "lab.py"])
        try FileManager.default.removeItem(at: folder.appendingPathComponent("lab.py"))
        try FileManager.default.createSymbolicLink(at: folder.appendingPathComponent("lab.py"),
                                                 withDestinationURL: folder.appendingPathComponent("runtime-policy.json"))
        XCTAssertThrowsError(try value.readResources(from: folder))
    }
}
