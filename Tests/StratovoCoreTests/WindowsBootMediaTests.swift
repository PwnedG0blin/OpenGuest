import Foundation
import XCTest
@testable import StratovoCore

final class WindowsBootMediaTests: XCTestCase {
    func testISOCheckAcceptsExistingSymlinkButRejectsMissingEmptyAndOtherFiles() throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent("og-iso-check-\(UUID())")
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: root) }
        let iso = root.appendingPathComponent("Windows ARM.ISO")
        try Data([0x43, 0x44]).write(to: iso)
        XCTAssertEqual(try WindowsISOInfo.check(path: iso.path).bytes, 2)
        let link = root.appendingPathComponent("Selected.iso")
        try fm.createSymbolicLink(at: link, withDestinationURL: iso)
        XCTAssertEqual(try WindowsISOInfo.check(path: link.path).path, link.path)
        let empty = root.appendingPathComponent("Empty.iso")
        try Data().write(to: empty)
        let other = root.appendingPathComponent("Driver.exe")
        try Data([1]).write(to: other)
        for path in [empty.path, other.path, root.appendingPathComponent("missing.iso").path, root.path] {
            XCTAssertThrowsError(try WindowsISOInfo.check(path: path))
        }
    }
    func testQMPConnectedDVDIsNotConfusedWithSelectedPathOrDriverDisc() throws {
        let state = Data(#"{"status":"running","running":true}"#.utf8)
        let blocks = Data(#"[{"qdev":"/machine/peripheral/drivers-cd","inserted":{"file":"Drivers.iso","ro":true}},{"qdev":"/machine/peripheral/installer-cd","tray_open":false,"inserted":{"file":"/Volumes/Extern/Windows ARM.iso","ro":true}}]"#.utf8)
        let result = try WindowsBootEvidence(status: state, blocks: blocks)
        XCTAssertTrue(result.dvdConnected)
        XCTAssertEqual(result.dvdPath, "/Volumes/Extern/Windows ARM.iso")
        for json in [#"[]"#, #"[{"qdev":"installer-cd","tray_open":true,"inserted":{"file":"x.iso","ro":true}}]"#,
                     #"[{"qdev":"installer-cd","inserted":{"file":"x.iso","ro":false}}]"#,
                     #"[{"qdev":"drivers-cd","inserted":{"file":"x.iso","ro":true}}]"#] {
            XCTAssertFalse(try WindowsBootEvidence(status: state, blocks: Data(json.utf8)).dvdConnected)
        }
        let paused = try WindowsBootEvidence(status: Data(#"{"status":"paused"}"#.utf8), blocks: Data("[]".utf8))
        XCTAssertTrue(paused.machineStatus.contains("paused"))
    }
}
