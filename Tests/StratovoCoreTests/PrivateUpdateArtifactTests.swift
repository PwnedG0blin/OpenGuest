import XCTest
@testable import StratovoCore

final class PrivateUpdateArtifactTests: XCTestCase {
    private func run(branch: String = "main", conclusion: String = "success") throws -> PrivateUpdateRun {
        try JSONDecoder().decode(PrivateUpdateRun.self, from: JSONSerialization.data(withJSONObject: [
            "id": 12, "status": "completed", "conclusion": conclusion,
            "head_branch": branch, "head_sha": String(repeating: "a", count: 40), "event": "workflow_dispatch"
        ]))
    }
    private func artifact(_ changes: [String: Any] = [:], fork: Bool = false) throws -> PrivateUpdateArtifact {
        var value: [String: Any] = ["id": 42, "name": PrivateUpdateArtifact.prefix + "1024", "size_in_bytes": 1234,
            "expired": false, "digest": "sha256:" + String(repeating: "a", count: 64),
            "workflow_run": ["id": 12, "repository_id": 7, "head_repository_id": fork ? 8 : 7,
                             "head_branch": "main", "head_sha": String(repeating: "a", count: 40)]]
        value.merge(changes) { _, new in new }
        return try JSONDecoder().decode(PrivateUpdateArtifact.self, from: JSONSerialization.data(withJSONObject: value))
    }
    func testOnlySuccessfulMatchingMainBranchArtifactsAreTrusted() throws {
        let good = try artifact()
        XCTAssertTrue(good.isTrusted(run: try run()))
        XCTAssertEqual(good.build, 1024)
        XCTAssertFalse(good.isTrusted(run: try run(branch: "other")))
        XCTAssertFalse(good.isTrusted(run: try run(conclusion: "failure")))
        XCTAssertFalse(try artifact(fork: true).isTrusted(run: run()))
        let invalid: [[String: Any]] = [["expired": true], ["size_in_bytes": 0], ["size_in_bytes": 104857601],
            ["digest": "sha256:broken"], ["name": PrivateUpdateArtifact.prefix + "01024"],
            ["name": "Stratovo-Private-Beta-DMG"], ["id": -1]]
        for change in invalid {
            XCTAssertFalse(try artifact(change).isTrusted(run: run()))
        }
    }
    func testArchiveRejectsTraversalAbsolutePathsAndOtherPayloads() {
        XCTAssertTrue(PrivateUpdateArtifact.safeArchiveEntries(["Stratovo.app/", "Stratovo.app/Contents/MacOS/Stratovo"]))
        for entries in [[], ["/Stratovo.app/Contents"], ["Stratovo.app/../other"], ["Other.app/x"], ["Stratovo.app\\evil"]] {
            XCTAssertFalse(PrivateUpdateArtifact.safeArchiveEntries(entries))
        }
    }
}
