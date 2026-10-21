import Foundation
import CryptoKit
import StratovoCore

/// All filesystem work stays off the UI actor and inside a new staging folder.
enum UpdatePackagePreparer {
    static func prepare(data: Data, sha256: String, size: Int64, directory: URL,
                        version: StratovoVersion? = nil, privateBuild: Int? = nil) throws -> URL {
        guard Int64(data.count) == size, size > 0, size <= 100 * 1024 * 1024,
              SHA256.hash(data: data).map({ String(format: "%02x", $0) }).joined() == sha256 else {
            throw failure("Update-Prüfsumme stimmt nicht. Die installierte App bleibt erhalten.")
        }
        let archive = directory.appendingPathComponent("Update.zip")
        try data.write(to: archive, options: .atomic)
        var payload = archive
        if privateBuild != nil {
            // Actions wraps a ditto archive so executable modes and bundle layout
            // survive artifact storage. The API digest covers both ZIP layers.
            let entries = try contents(of: archive)
            guard entries == ["Private-App.zip"] else { throw failure("Unerwarteter Inhalt im privaten Updatepaket.") }
            try run("/usr/bin/ditto", ["-x", "-k", archive.path, directory.path])
            payload = directory.appendingPathComponent("Private-App.zip")
        }
        let entries = try contents(of: payload)
        let appEntries = entries.filter { !$0.hasPrefix("__MACOSX/") }
        let metadataSafe = entries.filter { $0.hasPrefix("__MACOSX/") }.allSatisfy {
            !$0.split(separator: "/").contains("..") && !$0.contains("\\")
        }
        guard metadataSafe && PrivateUpdateArtifact.safeArchiveEntries(appEntries) else {
            throw failure("Ungültige Dateipfade im Updatepaket.")
        }
        try run("/usr/bin/ditto", ["-x", "-k", payload.path, directory.path])
        let app = directory.appendingPathComponent("Stratovo.app")
        guard app.resolvingSymlinksInPath() == app.standardizedFileURL,
              let candidate = Bundle(url: app), candidate.bundleIdentifier == "org.pwnedg0blin.openguest" else {
            throw failure("Bundle-ID des Updates stimmt nicht.")
        }
        if let privateBuild {
            guard candidate.object(forInfoDictionaryKey: "StratovoBuildFlavor") as? String == "private",
                  let value = candidate.object(forInfoDictionaryKey: "CFBundleVersion") as? String,
                  Int(value) == privateBuild else { throw failure("Private Variante oder Buildnummer des Updates stimmt nicht.") }
        } else {
            guard let version,
                  let value = candidate.object(forInfoDictionaryKey: "StratovoReleaseVersion") as? String,
                  StratovoVersion(value) == version,
                  candidate.object(forInfoDictionaryKey: "StratovoBuildFlavor") as? String != "private" else {
                throw failure("Version oder Updatekanal stimmt nicht.")
            }
        }
        try run("/usr/bin/codesign", ["--verify", "--deep", "--strict", app.path])
        guard candidate.executableArchitectures?.contains(where: {
            $0.intValue == NSBundleExecutableArchitectureARM64
        }) == true else { throw failure("Das Update enthält keine Apple-Silicon-App.") }
        return app
    }
    private static func contents(of archive: URL) throws -> [String] {
        let child = Process(); child.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        child.arguments = ["-Z1", archive.path]
        child.standardInput = FileHandle.nullDevice; child.standardError = FileHandle.nullDevice
        let pipe = Pipe(); child.standardOutput = pipe
        try child.run()
        let data = pipe.fileHandleForReading.readDataToEndOfFile(); child.waitUntilExit()
        guard child.terminationStatus == 0, let text = String(data: data, encoding: .utf8) else { throw failure("Update-Archiv konnte nicht gelesen werden.") }
        return text.split(separator: "\n").map(String.init)
    }
    static func run(_ executable: String, _ args: [String]) throws {
        let child = Process(); child.executableURL = URL(fileURLWithPath: executable); child.arguments = args
        child.standardInput = FileHandle.nullDevice
        child.standardOutput = FileHandle.nullDevice; child.standardError = FileHandle.nullDevice
        try child.run(); child.waitUntilExit()
        guard child.terminationStatus == 0 else {
            throw NSError(domain: "Stratovo.PrivateUpdates", code: Int(child.terminationStatus),
                userInfo: [NSLocalizedDescriptionKey: "Update-Paket konnte nicht entpackt oder signaturgeprüft werden.",
                           "tool": URL(fileURLWithPath: executable).lastPathComponent])
        }
    }
    private static func failure(_ message: String) -> NSError { PrivateUpdateAPI.failure(message) }
}
