import XCTest
@testable import OpenGuestCore

final class WindowsKeyboardTests: XCTestCase {
    func testFunctionKeysUseHardwareCodeInsteadOfAppKitPrivateUnicode() {
        XCTAssertEqual(WindowsKeyboard.symbol(code: 122, text: "\u{f704}"), 0xffbe) // F1
        XCTAssertEqual(WindowsKeyboard.symbol(code: 109, text: "\u{f70d}"), 0xffc7) // F10
        XCTAssertEqual(WindowsKeyboard.symbol(code: 111, text: ""), 0xffc9) // F12
        XCTAssertEqual(WindowsKeyboard.symbol(code: 0, text: "@"), 0x40)
        XCTAssertNil(WindowsKeyboard.symbol(code: 65535, text: "\u{f720}"))
    }

    func testSetupConsoleHoldsShiftDuringF10AndReleasesAllKeys() {
        var held = Set<UInt32>()
        var presses = [UInt32]()
        for event in WindowsKeyboard.setupConsole {
            if event.down {
                if event.symbol == 0xffc7 { XCTAssertTrue(held.contains(0xffe1), "F10 must be shifted") }
                XCTAssertTrue(held.insert(event.symbol).inserted)
                presses.append(event.symbol)
            } else {
                XCTAssertNotNil(held.remove(event.symbol), "Every release must match a held key")
            }
        }
        XCTAssertEqual(presses, [0xffe1, 0xffc7])
        XCTAssertTrue(held.isEmpty, "The shortcut must not leave Shift or F10 stuck")
    }
}
