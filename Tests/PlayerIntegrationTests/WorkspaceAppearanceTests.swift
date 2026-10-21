import AppKit
import XCTest
@testable import Stratovo

final class WorkspaceAppearanceTests: XCTestCase {
    @MainActor
    func testNativeAlertAndFilePanelFollowSavedAppearance() throws {
        let application = NSApplication.shared
        let original = application.appearance
        defer { application.appearance = original }
        WorkspaceAppearance.applyApplicationAppearance(.glass)
        XCTAssertEqual(NSAlert().window.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]), .darkAqua)
        XCTAssertEqual(NSOpenPanel().effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]), .darkAqua)
        WorkspaceAppearance.applyApplicationAppearance(.classic)
        XCTAssertNil(application.appearance, "Classic must restore the system appearance")
    }
}
