import XCTest
@testable import OpenGuestCore

final class WindowsTextInputTests: XCTestCase {
    func testDiagnosticCommandIsFullyPlannedWithoutSubmittingIt() throws {
        let command = #"reg query HKLM\SOFTWARE\Microsoft\Provisioning\Diagnostics\Autopilot /v CloudAssignedTenantDomain"#
        for layout in WindowsTextLayout.allCases {
            let input = try WindowsTextInput(text: command + "\r\n", layout: layout)
            XCTAssertEqual(input.count, command.count)
            XCTAssertFalse(input.units.flatMap(\.chords).flatMap { $0 }.contains("ret"))
            let slashes = zip(command, input.units).filter { $0.0 == "\\" }.map { $0.1.chords }
            XCTAssertEqual(slashes.count, 5)
            XCTAssertTrue(slashes.allSatisfy { $0 == (layout == .german ? [["alt_r", "minus"]] : [["backslash"]]) })
        }
    }

    func testLayoutsPreserveAtBackslashCaseAndGermanCharacters() throws {
        let de = try WindowsTextInput(text: "@\\Yz:äÄ€^`é", layout: .german)
        XCTAssertEqual(de.units.map(\.chords), [
            [["alt_r", "q"]], [["alt_r", "minus"]], [["shift", "z"]], [["y"]], [["shift", "dot"]],
            [["apostrophe"]], [["shift", "apostrophe"]], [["alt_r", "e"]], [["grave"], ["spc"]],
            [["shift", "equal"], ["spc"]], [["equal"], ["e"]]
        ])
        let us = try WindowsTextInput(text: "@\\Yz:", layout: .us)
        XCTAssertEqual(us.units.map(\.chords), [[["shift", "2"]], [["backslash"]], [["shift", "y"]], [["z"]], [["shift", "semicolon"]]])
    }

    func testLineBreaksRequireOptInAndNeverAddAnExtraEnter() throws {
        XCTAssertThrowsError(try WindowsTextInput(text: "first\nsecond\n", layout: .us))
        let input = try WindowsTextInput(text: "first\r\nsecond\r\n", layout: .us, allowLineBreaks: true)
        XCTAssertEqual(input.units.filter { $0.chords == [["ret"]] }.count, 1)
        XCTAssertEqual(input.units.last?.chords, [["d"]])
    }

    func testUnsupportedInputIsRejectedAsAWhole() throws {
        for text in ["", "\r\n", "ok😀", "ok\u{1b}", "a\tb", String(repeating: "a", count: 4097)] {
            XCTAssertThrowsError(try WindowsTextInput(text: text, layout: .german))
        }
        XCTAssertThrowsError(try WindowsTextInput(text: "ä", layout: .us))
        XCTAssertEqual(try WindowsTextInput(text: "a\u{308}", layout: .german).units.first?.chords, [["apostrophe"]])
        XCTAssertEqual(try WindowsTextInput(text: "  x  \n", layout: .us).count, 5)
    }
}
