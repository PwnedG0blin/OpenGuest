import Foundation

public struct AndroidClipboardText {
    public let text: String
    public init(_ input: String, allowLineBreaks: Bool = false) throws {
        var text = input.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
        while text.last == "\n" { text.removeLast() }
        guard !text.isEmpty, text.utf8.count <= 65_536 else {
            throw GuestError.commandFailed(1, "Bitte Text mit höchstens 64 KiB einfügen.")
        }
        guard !text.unicodeScalars.contains(where: { $0.value < 32 && $0.value != 9 && $0.value != 10 }) else {
            throw GuestError.commandFailed(1, "Der Text enthält nicht unterstützte Steuerzeichen.")
        }
        guard allowLineBreaks || !text.contains("\n") else {
            throw GuestError.commandFailed(1, "Mehrzeiligen Text ausdrücklich erlauben. Zeilenumbrüche können in einer Konsole Befehle auslösen.")
        }
        self.text = text
    }
}
