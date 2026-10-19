import Foundation

public enum AndroidFrameRate {
    public static func limit(_ value: Int) -> Int { max(1, min(90, value)) }
    public static func displayHz(for value: Int) -> Int { max(60, limit(value)) }

    /// Changes only the display refresh setting of a stopped, externally managed AVD.
    /// The previous config is retained; userdata and snapshots are never deleted.
    @discardableResult
    public static func prepareAVD(root: URL, name: String, fps: Int) throws -> Bool {
        let fm = FileManager.default
        func fail(_ text: String) -> NSError { NSError(domain: "Pixelkoje.AndroidFPS", code: 1, userInfo: [NSLocalizedDescriptionKey: text]) }
        guard !name.isEmpty, name != ".", name != "..", !name.contains("/"), !name.contains("\\"),
              !name.unicodeScalars.contains(where: CharacterSet.controlCharacters.contains) else { throw fail("Ungültiges Android-Profil.") }
        let base = root.standardizedFileURL
        guard base.resolvingSymlinksInPath().path == base.path else { throw fail("Der verwaltete Android-Ordner darf keine Verknüpfung sein.") }
        let locator = base.appendingPathComponent(name + ".ini")
        var folder = base.appendingPathComponent(name + ".avd")
        if fm.fileExists(atPath: locator.path) {
            guard try fm.attributesOfItem(atPath: locator.path)[.type] as? FileAttributeType == .typeRegular else { throw fail("Android-Profilverweis ist ungültig.") }
            let text = try String(contentsOf: locator, encoding: .utf8)
            for line in text.components(separatedBy: .newlines) {
                let pair = line.split(separator: "=", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
                if pair.count == 2, pair[0] == "path" { folder = URL(fileURLWithPath: pair[1]).standardizedFileURL }
            }
        }
        guard folder.deletingLastPathComponent().path == base.path, folder.resolvingSymlinksInPath().path == folder.path,
              try fm.attributesOfItem(atPath: folder.path)[.type] as? FileAttributeType == .typeDirectory else { throw fail("Android-Profil liegt nicht im gewählten Datenordner.") }
        let file = folder.appendingPathComponent("config.ini")
        guard try fm.attributesOfItem(atPath: file.path)[.type] as? FileAttributeType == .typeRegular else { throw fail("Android-Konfiguration fehlt oder ist verknüpft.") }
        let original = try String(contentsOf: file, encoding: .utf8)
        let wanted = "hw.lcd.vsync=\(displayHz(for: fps))"
        let lines = original.components(separatedBy: .newlines)
        let matches = lines.filter { $0.split(separator: "=", maxSplits: 1).first?.trimmingCharacters(in: .whitespaces) == "hw.lcd.vsync" }
        if matches.count == 1, matches[0].trimmingCharacters(in: .whitespaces) == wanted { return false }
        let backup = folder.appendingPathComponent("config.ini.Stratovo-FPS.bak")
        if !fm.fileExists(atPath: backup.path) { try fm.copyItem(at: file, to: backup) }
        let kept = lines.filter { $0.split(separator: "=", maxSplits: 1).first?.trimmingCharacters(in: .whitespaces) != "hw.lcd.vsync" }
        let updated = kept.joined(separator: "\n").trimmingCharacters(in: .newlines) + "\n" + wanted + "\n"
        try Data(updated.utf8).write(to: file, options: .atomic)
        return true
    }
}
