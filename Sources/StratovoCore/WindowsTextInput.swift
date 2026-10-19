import Foundation

public enum WindowsTextLayout: String, CaseIterable, Identifiable, Sendable {
    case german, us
    public var id: String { rawValue }
    public var title: String { self == .german ? "Deutsch (Deutschland)" : "Englisch (US)" }
}

/// Text typed through QEMU's physical keyboard input; no guest agent is required.
/// The selected layout must match Windows, with Caps Lock off.
public struct WindowsTextInput: Sendable {
    public struct Unit: Equatable, Sendable {
        public let chords: [[String]]
    }
    public let units: [Unit]
    public let layout: WindowsTextLayout
    public var count: Int { units.count }
    public var chordCount: Int { units.reduce(0) { $0 + $1.chords.count } }

    public static func normalized(_ text: String) -> String {
        var text = text.replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n").precomposedStringWithCanonicalMapping
        // Copying a command from a code block must not submit it automatically.
        while text.hasSuffix("\n") { text.removeLast() }
        return text
    }

    public init(text: String, layout: WindowsTextLayout, allowLineBreaks: Bool = false) throws {
        let text = Self.normalized(text)
        guard !text.isEmpty else { throw Self.failure("Kein Text zum Einfügen vorhanden.") }
        guard text.unicodeScalars.count <= 4096 else { throw Self.failure("Bitte höchstens 4096 Zeichen auf einmal einfügen.") }
        var units = [Unit]()
        for scalar in text.unicodeScalars {
            if scalar.value == 10 {
                guard allowLineBreaks else { throw Self.failure("Der Text enthält Zeilenumbrüche. Bitte deren Übertragung ausdrücklich einschalten oder den Text auf eine Zeile kürzen.") }
                units.append(Unit(chords: [["ret"]])); continue
            }
            guard let chords = Self.chords(scalar, layout: layout) else {
                throw Self.failure(String(format: "Zeichen U+%04X wird mit dieser Windows-Tastatur noch nicht unterstützt. Es wurde nichts übertragen.", scalar.value))
            }
            units.append(Unit(chords: chords))
        }
        self.units = units; self.layout = layout
    }

    private static func chords(_ scalar: Unicode.Scalar, layout: WindowsTextLayout) -> [[String]]? {
        if (65...90).contains(scalar.value) || (97...122).contains(scalar.value) {
            let upper = scalar.value < 97
            var key = String(Unicode.Scalar(upper ? scalar.value + 32 : scalar.value)!)
            if layout == .german { key = key == "y" ? "z" : key == "z" ? "y" : key }
            return [upper ? ["shift", key] : [key]]
        }
        if (48...57).contains(scalar.value) { return [[String(scalar)]] }
        let key = String(scalar)
        if layout == .us {
            if let code = usBase[key] { return [[code]] }
            if let code = usShift[key] { return [["shift", code]] }
            return nil
        }
        if let code = deBase[key] { return [[code]] }
        if let code = deShift[key] { return [["shift", code]] }
        if let code = deAltGr[key] { return [["alt_r", code]] }
        if key == "^" { return [["grave"], ["spc"]] }
        if key == "´" { return [["equal"], ["spc"]] }
        if key == "`" { return [["shift", "equal"], ["spc"]] }
        let parts = Array(key.decomposedStringWithCanonicalMapping.unicodeScalars)
        if parts.count == 2, let base = Self.chords(parts[0], layout: layout) {
            let letter = String(parts[0])
            if parts[1].value == 0x301, "aeiouyAEIOUY".contains(letter) { return [["equal"]] + base }
            if parts[1].value == 0x300, "aeiouAEIOU".contains(letter) { return [["shift", "equal"]] + base }
            if parts[1].value == 0x302, "aeiouAEIOU".contains(letter) { return [["grave"]] + base }
        }
        return nil
    }

    private static let usBase = [" ": "spc", "-": "minus", "=": "equal", "[": "bracket_left", "]": "bracket_right",
        "\\": "backslash", ";": "semicolon", "'": "apostrophe", "`": "grave", ",": "comma", ".": "dot", "/": "slash"]
    private static let usShift = ["!": "1", "@": "2", "#": "3", "$": "4", "%": "5", "^": "6", "&": "7", "*": "8", "(": "9", ")": "0",
        "_": "minus", "+": "equal", "{": "bracket_left", "}": "bracket_right", "|": "backslash", ":": "semicolon", "\"": "apostrophe",
        "~": "grave", "<": "comma", ">": "dot", "?": "slash"]
    // Microsoft kbdgr: physical US key positions, interpreted by Windows' German layout.
    private static let deBase = [" ": "spc", "ß": "minus", "ü": "bracket_left", "+": "bracket_right", "ö": "semicolon", "ä": "apostrophe",
        "#": "backslash", "<": "less", ",": "comma", ".": "dot", "-": "slash"]
    private static let deShift = ["!": "1", "\"": "2", "§": "3", "$": "4", "%": "5", "&": "6", "/": "7", "(": "8", ")": "9", "=": "0",
        "?": "minus", "Ü": "bracket_left", "*": "bracket_right", "Ö": "semicolon", "Ä": "apostrophe", "'": "backslash", ">": "less",
        ";": "comma", ":": "dot", "_": "slash", "°": "grave"]
    private static let deAltGr = ["@": "q", "€": "e", "µ": "m", "{": "7", "[": "8", "]": "9", "}": "0", "\\": "minus", "|": "less", "~": "bracket_right",
        "²": "2", "³": "3"]

    private static func failure(_ message: String) -> NSError {
        NSError(domain: "Pixelkoje.WindowsText", code: 1, userInfo: [NSLocalizedDescriptionKey: message])
    }
}
