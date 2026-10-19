import Foundation
import XCTest
@testable import StratovoCore

final class AndroidClipboardTests: XCTestCase {
    func testUnicodeClipboardUsesUTF8LengthAndPinnedScrcpyPasteMessage() throws {
        let input = try AndroidClipboardText("Grüße 👋 @\\\r\n")
        XCTAssertEqual(input.text, "Grüße 👋 @\\")
        let packet = ScrcpyWire.paste(input)
        let payload = Data(input.text.utf8)
        XCTAssertEqual(packet.prefix(10), Data([9,0,0,0,0,0,0,0,0,1]), "SET_CLIPBOARD, no ACK, paste flag")
        XCTAssertEqual(Array(packet[10..<14]), [0,0,0,UInt8(payload.count)])
        XCTAssertEqual(packet.dropFirst(14), payload, "No extra key or Enter may follow clipboard text")
        XCTAssertEqual(String(data: packet.dropFirst(14), encoding: .utf8), input.text)
    }
    func testNewlineNormalizationRequiresExplicitMultilineApproval() throws {
        XCTAssertThrowsError(try AndroidClipboardText("one\r\ntwo\rthree"))
        XCTAssertEqual(try AndroidClipboardText("one\r\ntwo\rthree\n\n", allowLineBreaks: true).text, "one\ntwo\nthree")
        XCTAssertEqual(try AndroidClipboardText("copy\n").text, "copy")
        XCTAssertThrowsError(try AndroidClipboardText("\r\n"))
    }
    func testByteLimitDoesNotSplitUnicodeAndRejectsControlCharacters() throws {
        XCTAssertNoThrow(try AndroidClipboardText(String(repeating: "👋", count: 16_384)))
        XCTAssertThrowsError(try AndroidClipboardText(String(repeating: "👋", count: 16_385)))
        XCTAssertThrowsError(try AndroidClipboardText("hello\u{0}world"))
        XCTAssertThrowsError(try AndroidClipboardText("hello\u{1b}world"))
        XCTAssertNoThrow(try AndroidClipboardText("one\ttwo"))
        XCTAssertThrowsError(try AndroidClipboardText(""))
    }
}
