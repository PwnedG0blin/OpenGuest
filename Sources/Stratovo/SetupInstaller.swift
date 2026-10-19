import Foundation
import Combine
import StratovoCore

@MainActor
final class SetupInstaller: ObservableObject {
    @Published private(set) var running = false
    @Published private(set) var status = "Komponenten auswählen und auf dem gewählten Datenträger einrichten."
    @Published private(set) var output = ""
    @Published private(set) var licensePrompt = false
    @Published private(set) var installingAndroid: AndroidSystem?
    static let android17DataProfile = "Pixelkoje_Android17_mit_Daten"
    private var input: FileHandle?
    private var responseOffset: UInt64 = 0
    private var outputOffset: UInt64 = 0

    static func bundledScript(_ name: String) throws -> URL {
        let bundled = Bundle.main.resourceURL?.appendingPathComponent(name)
        let development = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().appendingPathComponent(name)
        guard let file = [bundled, development].compactMap({ $0 }).first(where: { FileManager.default.isReadableFile(atPath: $0.path) }) else {
            throw StorageMigration.failure("Einrichtungsskript fehlt: \(name)")
        }
        return file
    }

    func answerLicense(accept: Bool) {
        guard running, licensePrompt, let input else { return }
        do {
            try input.write(contentsOf: Data((accept ? "y\n" : "n\n").utf8))
            responseOffset = outputOffset
            licensePrompt = false
        } catch { status = "Antwort konnte nicht gesendet werden: \(error.localizedDescription)" }
    }

    func install(_ selected: Set<SetupComponent>, storage: GuestStorage, existingISO: String,
                 existingDrivers: String, microsoftLink: String, ready: Set<SetupComponent>, androidChannel: Int = 0, preferredAndroidProfile: String = "", androidDataSource: String? = nil, qemuImg: String? = nil) async throws -> (iso: String?, drivers: String?, androidProfile: String?) {
        guard !running else { throw StorageMigration.failure("Einrichtung läuft bereits.") }
        try storage.validate()
        var pending = selected.subtracting(ready)
        let copyData = selected.contains(.android17) && androidDataSource != nil
        if copyData {
            guard let qemuImg, FileManager.default.isExecutableFile(atPath: qemuImg) else {
                throw StorageMigration.failure("Für die geprüfte Android-Datenkopie fehlt qemu-img. Bitte die vorhandene QEMU-Installation unter Windows prüfen oder Android 17 ohne Datenübernahme einrichten.")
            }
            let target = storage.avd.appendingPathComponent(Self.android17DataProfile + ".avd")
            guard !FileManager.default.fileExists(atPath: target.path) else {
                throw StorageMigration.failure("Die Android-17-Datenkopie existiert bereits. Bitte im Hauptfenster auswählen. Es wird nichts überschrieben.")
            }
            pending.insert(.android17)
        }
        // Reject invalid links before starting any downloads.
        let canImportISO = !existingISO.isEmpty && FileManager.default.isReadableFile(atPath: existingISO)
        let isoURL = pending.contains(.windowsISO) && !canImportISO ? try SetupDownloads.windowsISOURL(microsoftLink) : nil
        // Set up every working directory on the selected volume before launching tools.
        for relative in ["Downloads/Temporary", "Installationsmedien", "Logs", "Android/user", "Runtime/Java"] {
            let directory = storage.url.appendingPathComponent(relative)
            let root = storage.url.resolvingSymlinksInPath().path + "/"
            guard directory.resolvingSymlinksInPath().path.hasPrefix(root) else {
                throw StorageMigration.failure("Arbeitsordner verweist außerhalb des gewählten Datenträgers: \(directory.path)")
            }
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        running = true
        installingAndroid = selected.contains(.android17) ? .android17 : selected.contains(.android) ? .android16 : nil
        defer { running = false; licensePrompt = false; input = nil; installingAndroid = nil }
        var iso: String?, drivers: String?, androidProfile: String?
        for item in SetupComponent.allCases where selected.contains(item) {
            try storage.validate()
            status = item.title
            if !pending.contains(item) { status = "\(item.title): vorhanden, kein erneuter Download."; continue }
            let minimum: Int64 = (item == .android || item == .android17) ? 80 : item == .windowsISO ? 12 : 1
            guard let free = storage.freeBytes, free >= minimum * 1_073_741_824 else {
                throw StorageMigration.failure("Für \(item.title) werden mindestens \(minimum) GB auf \(storage.root) benötigt.")
            }
            if item == .android || item == .android17 {
                try await run(CommandSpec(executable: "/bin/bash", arguments: [try Self.bundledScript("Android_Werkzeuge_einrichten.command").path]), storage: storage)
            }
            if item == .windowsDrivers, !existingDrivers.isEmpty, FileManager.default.isReadableFile(atPath: existingDrivers) {
                drivers = try await importISO(existingDrivers, name: "utm-guest-tools.iso", storage: storage)
                continue
            }
            if item == .windowsISO, canImportISO {
                iso = try await importISO(existingISO, name: URL(fileURLWithPath: existingISO).lastPathComponent, storage: storage)
                continue
            }
            if let script = item.script {
                let args = [try Self.bundledScript(script).path] + ((item == .android || item == .android17)
                    ? [item == .android ? "16" : "17", item == .android17 && copyData ? "download" : "install", String(androidChannel), preferredAndroidProfile] : [])
                try await run(CommandSpec(executable: "/bin/bash", arguments: args), storage: storage)
            } else if let isoURL {
                let media = storage.url.appendingPathComponent("Installationsmedien")
                try FileManager.default.createDirectory(at: media, withIntermediateDirectories: true)
                let destination = media.appendingPathComponent("Windows11_ARM64_Microsoft.iso")
                guard !FileManager.default.fileExists(atPath: destination.path) else {
                    throw StorageMigration.failure("Windows11_ARM64_Microsoft.iso existiert bereits. Bitte diese Datei im Windows-Bereich auswählen; sie wird nicht überschrieben.")
                }
                let temporary = media.appendingPathComponent("windows-\(UUID().uuidString).part")
                defer { try? FileManager.default.removeItem(at: temporary) }
                try await run(CommandSpec(executable: "/usr/bin/curl", arguments: [
                    "--fail", "--location", "--proto", "=https", "--proto-redir", "=https", "--tlsv1.2",
                    "--connect-timeout", "30", "--max-time", "14400", "--retry", "2", "--progress-bar",
                    "--output", temporary.path, isoURL.absoluteString
                ]), storage: storage)
                try Self.validateISO(temporary)
                try storage.validate()
                try FileManager.default.moveItem(at: temporary, to: destination)
                iso = destination.path
            }
            if item == .android17, copyData, let androidDataSource, let qemuImg {
                status = "Android-16-Daten kopieren und prüfen …"
                try await run(CommandSpec(executable: "/usr/bin/python3", arguments: [
                    try Self.bundledScript("Android_Daten_uebernehmen.py").path,
                    "--source", androidDataSource, "--qemu-img", qemuImg]), storage: storage)
                androidProfile = Self.android17DataProfile
            }
            if item == .windowsDrivers {
                let destination = storage.url.appendingPathComponent("Installationsmedien/utm-guest-tools.iso")
                try Self.validateISO(destination)
                drivers = destination.path
            }
        }
        status = "Einrichtung abgeschlossen. Vorhandene Komponenten wurden wiederverwendet."
        return (iso, drivers, androidProfile)
    }

    func manageAndroid(_ system: AndroidSystem, mode: String, channel: Int, storage: GuestStorage) async throws {
        guard !running, ["check", "update"].contains(mode), (0...3).contains(channel) else {
            throw StorageMigration.failure("Android-Verwaltung ist gerade nicht verfügbar.")
        }
        running = true
        defer { running = false }
        status = mode == "check" ? "Android-Updates prüfen …" : "Android-Systemabbild aktualisieren …"
        try await run(CommandSpec(executable: "/bin/bash", arguments: [try Self.bundledScript("Android_System_verwalten.command").path,
            String(system.rawValue), mode, String(channel)]), storage: storage)
        status = mode == "check" ? "Updateprüfung abgeschlossen. Verfügbare Pakete stehen im Protokoll; es wurde nichts installiert."
            : "Systemabbild aktualisiert. Nächster Start erfolgt als Kaltstart; Apps und Konten bleiben im Profil."
    }

    static func validateISO(_ url: URL) throws {
        let reader = try FileHandle(forReadingFrom: url)
        defer { try? reader.close() }
        try reader.seek(toOffset: 32769)
        let magic = String(decoding: try reader.read(upToCount: 5) ?? Data(), as: UTF8.self)
        guard ["CD001", "BEA01", "NSR02", "NSR03"].contains(magic) else {
            throw StorageMigration.failure("Die heruntergeladene Datei ist kein erkanntes ISO-Abbild.")
        }
    }

    private func importISO(_ path: String, name: String, storage: GuestStorage) async throws -> String {
        let source = URL(fileURLWithPath: path)
        let media = storage.url.appendingPathComponent("Installationsmedien")
        let target = media.appendingPathComponent(name)
        try Self.validateISO(source)
        try FileManager.default.createDirectory(at: media, withIntermediateDirectories: true)
        status = "Vorhandene ISO auf den gewählten Datenträger übernehmen …"
        try await Task.detached(priority: .userInitiated) {
            let fm = FileManager.default
            if fm.fileExists(atPath: target.path) {
                guard fm.contentsEqual(atPath: source.path, andPath: target.path) else {
                    throw StorageMigration.failure("Am Ziel existiert eine andere ISO mit gleichem Namen. Sie wird nicht überschrieben.")
                }
                return
            }
            let partial = media.appendingPathComponent("import-\(UUID().uuidString).part")
            defer { try? fm.removeItem(at: partial) }
            try fm.copyItem(at: source, to: partial)
            guard fm.contentsEqual(atPath: source.path, andPath: partial.path) else {
                throw StorageMigration.failure("ISO-Kopierprüfung fehlgeschlagen. Original bleibt erhalten.")
            }
            try storage.validate()
            try fm.moveItem(at: partial, to: target)
        }.value
        output = "ISO übernommen. Die ursprüngliche Datei wurde nicht gelöscht.\n\(target.path)"
        return target.path
    }

    private func run(_ spec: CommandSpec, storage: GuestStorage) async throws {
        try storage.validate()
        let fm = FileManager.default
        let temporary = storage.url.appendingPathComponent("Downloads/Temporary")
        try fm.createDirectory(at: temporary, withIntermediateDirectories: true)
        try fm.createDirectory(at: storage.logs, withIntermediateDirectories: true)
        let log = storage.logs.appendingPathComponent("setup-\(UUID().uuidString).log")
        guard fm.createFile(atPath: log.path, contents: nil) else { throw GuestError.missingFile(log.path) }
        let handle = try FileHandle(forWritingTo: log)
        let pipe = Pipe()
        let child = Process()
        child.executableURL = URL(fileURLWithPath: spec.executable)
        child.arguments = spec.arguments
        var environment = ProcessInfo.processInfo.environment.merging(storage.environment) { _, new in new }
        environment["TMPDIR"] = temporary.path + "/"
        environment["ANDROID_USER_HOME"] = storage.url.appendingPathComponent("Android/user").path
        let escaped = temporary.path.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
        environment["JAVA_TOOL_OPTIONS"] = "-Djava.io.tmpdir=\"\(escaped)\""
        environment["PATH"] = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
        child.environment = environment
        child.standardInput = pipe
        child.standardOutput = handle
        child.standardError = handle
        input = pipe.fileHandleForWriting
        responseOffset = 0; outputOffset = 0; output = ""; licensePrompt = false
        defer { try? pipe.fileHandleForWriting.close(); input = nil; try? handle.close(); licensePrompt = false }
        try child.run()
        while child.isRunning {
            readOutput(log)
            try? await Task.sleep(nanoseconds: 300_000_000)
        }
        child.waitUntilExit()
        readOutput(log)
        guard child.terminationStatus == 0 else {
            status = "Einrichtung fehlgeschlagen. Details stehen im Downloadprotokoll."
            throw GuestError.commandFailed(child.terminationStatus, String(output.suffix(2500)))
        }
        try storage.validate()
    }

    private func readOutput(_ url: URL) {
        guard let reader = try? FileHandle(forReadingFrom: url) else { return }
        defer { try? reader.close() }
        let size = (try? reader.seekToEnd()) ?? 0
        try? reader.seek(toOffset: size > 80_000 ? size - 80_000 : 0)
        output = String(decoding: (try? reader.read(upToCount: 80_000)) ?? Data(), as: UTF8.self)
        outputOffset = size
        licensePrompt = size > responseOffset && SetupDownloads.isLicensePrompt(output)
    }
}
