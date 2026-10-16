import Foundation

/// Converts macOS hardware key codes to the X11 keysyms used by RFB.
public enum WindowsKeyboard {
    public struct Event: Equatable, Sendable {
        public let symbol: UInt32
        public let down: Bool
        public init(symbol: UInt32, down: Bool) { self.symbol = symbol; self.down = down }
    }

    private static let special: [UInt16: UInt32] = [
        36: 0xff0d, 51: 0xff08, 48: 0xff09, 53: 0xff1b, 123: 0xff51, 124: 0xff53,
        125: 0xff54, 126: 0xff52, 117: 0xffff, 115: 0xff50, 119: 0xff57, 116: 0xff55, 121: 0xff56,
        56: 0xffe1, 60: 0xffe2, 59: 0xffe3, 62: 0xffe4, 58: 0xffe9, 61: 0xffea, 55: 0xffeb, 54: 0xffec,
        // AppKit supplies private-use Unicode for these keys. It is not an RFB keysym.
        122: 0xffbe, 120: 0xffbf, 99: 0xffc0, 118: 0xffc1, 96: 0xffc2, 97: 0xffc3,
        98: 0xffc4, 100: 0xffc5, 101: 0xffc6, 109: 0xffc7, 103: 0xffc8, 111: 0xffc9
    ]

    public static func symbol(code: UInt16, text: String) -> UInt32? {
        if let symbol = special[code] { return symbol }
        guard let scalar = text.unicodeScalars.first,
              !(0xf700...0xf8ff).contains(scalar.value) else { return nil }
        return scalar.value <= 255 ? scalar.value : 0x0100_0000 | scalar.value
    }

    /// One complete chord, including key-up events, for Windows Setup/OOBE.
    public static let setupConsole: [Event] = [
        Event(symbol: 0xffe1, down: true), Event(symbol: 0xffc7, down: true),
        Event(symbol: 0xffc7, down: false), Event(symbol: 0xffe1, down: false)
    ]
    public static let settings: [Event] = [
        Event(symbol: 0xffeb, down: true), Event(symbol: 0x69, down: true),
        Event(symbol: 0x69, down: false), Event(symbol: 0xffeb, down: false)
    ]
    public static let explorer: [Event] = [
        Event(symbol: 0xffeb, down: true), Event(symbol: 0x65, down: true),
        Event(symbol: 0x65, down: false), Event(symbol: 0xffeb, down: false)
    ]
}
