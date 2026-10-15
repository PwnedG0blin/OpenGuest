import Foundation

/// A bounded, local report from OpenGuest's own logs. Never reads settings, Keychain or guest disks.
public enum DiagnosticReport {
    public static func redact(_ text: String) -> String {
        var result = text.components(separatedBy: .newlines).map { line -> String in
            let lower = line.lowercased()
            if lower.contains("adb.pubkey") || lower.contains("sending adb public key") {
                return "[ADB-Geräteschlüssel ausgeblendet]"
            }
            if lower.contains("<password>") || lower.contains("<value>") || lower.contains("<autounattend") {
                return "[Einrichtungsdaten ausgeblendet]"
            }
            return line
        }.joined(separator: "\n")
        let rules: [(String, String)] = [
            (#"(?i)(password|passwd|passwort|authorization|cookie|access_token|refresh_token|id_token|client_secret)\s*[:=].*"#, "$1=[ausgeblendet]"),
            (#"https://[^\s'\"<>?]+\?[^\s'\"<>]+"#, "[HTTPS-Adresse mit Parametern ausgeblendet]"),
            (#"[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}"#, "[E-Mail ausgeblendet]"),
            (#"/Users/[^/\s'\"]+"#, "/Users/[Benutzer]")
        ]
        for (pattern, replacement) in rules {
            if let regex = try? NSRegularExpression(pattern: pattern) {
                result = regex.stringByReplacingMatches(in: result, range: NSRange(result.startIndex..., in: result), withTemplate: replacement)
            }
        }
        return result
    }

    public static func record(_ message: String, storage: GuestStorage) throws {
        try storage.validate()
        let root = storage.url.resolvingSymlinksInPath().path + "/"
        guard storage.logs.resolvingSymlinksInPath().path.hasPrefix(root) else {
            throw StorageMigration.failure("Protokollordner liegt außerhalb des gewählten Datenordners.")
        }
        try FileManager.default.createDirectory(at: storage.logs, withIntermediateDirectories: true)
        let url = storage.logs.appendingPathComponent("openguest-events.log")
        if FileManager.default.fileExists(atPath: url.path), !regularFile(url, storage: storage) {
            throw StorageMigration.failure("Diagnosejournal ist keine reguläre Datei im Datenordner.")
        }
        let previous = (try? readBounded(url, limit: 512_000)) ?? ""
        let line = "\n[\(ISO8601DateFormatter().string(from: Date()))] \(redact(message))\n"
        try Data((previous + line).utf8).write(to: url, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    }

    public static func export(storage: GuestStorage, snapshot: String, systemCheck: String, recentEvents: String) throws -> URL {
        try storage.validate()
        let fm = FileManager.default
        let root = storage.url.resolvingSymlinksInPath().path + "/"
        let destination = storage.logs.appendingPathComponent("Diagnose", isDirectory: true)
        guard destination.resolvingSymlinksInPath().path.hasPrefix(root) else {
            throw StorageMigration.failure("Diagnoseziel liegt außerhalb des gewählten Datenordners.")
        }
        var report = "OpenGuest · Gemeinsames Diagnoseprotokoll Android + Windows\n"
        report += "Erstellt: \(ISO8601DateFormatter().string(from: Date()))\n"
        report += "Keine Einstellungen, Antwortdateien, Schlüsselbunddaten oder Gastdateisysteme enthalten. Protokolle sind gekürzt und bekannte sensible Angaben ausgeblendet.\n"
        func section(_ title: String, _ content: String) {
            report += "\n## \(title)\n\(content.isEmpty ? "Keine Einträge vorhanden." : content)\n"
        }
        section("Aktueller Zustand", snapshot)
        section("Letzte Systemprüfung", systemCheck)
        section("Meldungen dieser App-Sitzung", recentEvents)
        let files = ((try? fm.contentsOfDirectory(at: storage.logs, includingPropertiesForKeys: [.contentModificationDateKey])) ?? [])
            .filter { regularFile($0, storage: storage) && $0.pathExtension == "log" }
            .sorted { modification($0) > modification($1) }
        var android: [URL] = [], windows: [URL] = [], legacy: [URL] = [], setup: [URL] = []
        for file in files {
            let name = file.lastPathComponent
            if name.hasPrefix("android-session-") { android.append(file) }
            else if name.hasPrefix("windows-session-") { windows.append(file) }
            else if name.hasPrefix("session-") {
                let head = (try? readBounded(file, limit: 8192)) ?? ""
                if head.contains("Android emulator version") { android.append(file) }
                else if head.contains("qemu-system-aarch64") { windows.append(file) }
                else { legacy.append(file) }
            } else if name.hasPrefix("setup-") { setup.append(file) }
        }
        func logs(_ title: String, _ values: [URL]) {
            var text = ""
            for file in values.prefix(4) {
                text += "\n### \(file.lastPathComponent) · \(ISO8601DateFormatter().string(from: modification(file)))\n"
                text += (try? readBounded(file)) ?? "Datei konnte nicht gelesen werden."
                text += "\n"
            }
            section(title, text)
        }
        logs("Android · letzte Sitzungen", android)
        logs("Windows · letzte Sitzungen", windows)
        logs("Ältere Sitzungen ohne eindeutige Zuordnung", legacy)
        logs("Downloads und Einrichtung", setup)
        for (title, file) in [
            ("App-Fehler und Verlauf", storage.logs.appendingPathComponent("openguest-events.log")),
            ("Android-Videostream", storage.runtime.appendingPathComponent("scrcpy-4.0/server-last.log")),
            ("Windows · TPM", storage.windows.appendingPathComponent("tpm-last.log"))
        ] {
            section(title, regularFile(file, storage: storage) ? ((try? readBounded(file)) ?? "Nicht lesbar.") : "")
        }
        try storage.validate()
        try fm.createDirectory(at: destination, withIntermediateDirectories: true)
        let stamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
        let file = destination.appendingPathComponent("OpenGuest-Diagnose-\(stamp)-\(UUID().uuidString.prefix(8)).log")
        try Data(redact(report).utf8).write(to: file, options: .atomic)
        try fm.setAttributes([.posixPermissions: 0o600], ofItemAtPath: file.path)
        return file
    }

    private static func modification(_ url: URL) -> Date {
        (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
    }
    private static func regularFile(_ url: URL, storage: GuestStorage) -> Bool {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
              attributes[.type] as? FileAttributeType == .typeRegular else { return false }
        return url.resolvingSymlinksInPath().path.hasPrefix(storage.url.resolvingSymlinksInPath().path + "/")
    }
    private static func readBounded(_ url: URL, limit: Int = 256_000) throws -> String {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        let size = try handle.seekToEnd()
        try handle.seek(toOffset: 0)
        if size <= UInt64(limit) { return String(decoding: try handle.read(upToCount: limit) ?? Data(), as: UTF8.self) }
        let head = try handle.read(upToCount: limit / 4) ?? Data()
        try handle.seek(toOffset: size - UInt64(limit * 3 / 4))
        let tail = try handle.read(upToCount: limit * 3 / 4) ?? Data()
        return String(decoding: head, as: UTF8.self) + "\n[Protokoll gekürzt: Anfang und Ende enthalten]\n" + String(decoding: tail, as: UTF8.self)
    }
}
