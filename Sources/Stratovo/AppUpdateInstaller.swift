import AppKit
import CryptoKit
import Foundation
import StratovoCore

@MainActor
final class AppUpdateInstaller: ObservableObject {
    @Published private(set) var busy = false
    @Published private(set) var status = ""

    func install(_ release: StratovoRelease, model: AppModel) async {
        guard !busy, !model.busy, !model.running, !model.graphicsLab.active else {
            status = L10n.text("Bitte zuerst alle Gäste und den Grafikbau beenden."); return
        }
        guard let storage = model.storage, model.storageReady,
              let asset = release.assets?.first(where: { $0.isTrusted(for: release) }),
              let expected = asset.sha256 else {
            status = L10n.text("Kein geprüftes Apple-Silicon-App-Paket vorhanden. Bitte die Veröffentlichung öffnen."); return
        }
        busy = true
        model.setGraphicsLabBusy(true)
        defer { busy = false; model.setGraphicsLabBusy(false) }
        do {
            try storage.validate()
            let current = Bundle.main.bundleURL.standardizedFileURL
            guard current.pathExtension == "app", current.lastPathComponent == "Stratovo.app",
                  current.resolvingSymlinksInPath() == current,
                  FileManager.default.isWritableFile(atPath: current.deletingLastPathComponent().path),
                  !current.path.hasPrefix("/Volumes/Stratovo/") else {
                throw StorageMigration.failure(L10n.text("Kopiere Stratovo zunächst aus dem Installationsabbild in einen beschreibbaren Programme-Ordner. Danach erneut aktualisieren."))
            }
            let directory = storage.url.appendingPathComponent("Updates/" + UUID().uuidString, isDirectory: true)
            guard directory.resolvingSymlinksInPath() == directory.standardizedFileURL else {
                throw StorageMigration.failure(L10n.text("Updateordner darf keine Verknüpfung sein."))
            }
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
            status = L10n.text("Update wird von GitHub geladen …")
            let config = URLSessionConfiguration.ephemeral
            config.urlCache = nil
            let session = URLSession(configuration: config)
            defer { session.invalidateAndCancel() }
            var request = URLRequest(url: asset.browserDownloadURL)
            request.timeoutInterval = 180
            let (data, response) = try await session.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200, data.count == Int(asset.size) else {
                throw StorageMigration.failure(L10n.text("Update-Download unvollständig oder nicht erreichbar."))
            }
            status = L10n.text("Prüfsumme und App werden geprüft …")
            let expectedVersion = release.version
            let prepared = try await Task.detached { () throws -> URL in
                let hash = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
                guard hash == expected else { throw StorageMigration.failure(L10n.text("Update-Prüfsumme stimmt nicht. Die installierte App bleibt erhalten.")) }
                let zip = directory.appendingPathComponent("Update.zip")
                try data.write(to: zip, options: .atomic)
                func run(_ executable: String, _ args: [String]) throws {
                    let child = Process(); child.executableURL = URL(fileURLWithPath: executable); child.arguments = args
                    child.standardInput = FileHandle.nullDevice
                    child.standardOutput = FileHandle.nullDevice; child.standardError = FileHandle.nullDevice
                    try child.run(); child.waitUntilExit()
                    guard child.terminationStatus == 0 else { throw StorageMigration.failure(L10n.text("Update-Paket konnte nicht entpackt oder signaturgeprüft werden.")) }
                }
                try run("/usr/bin/ditto", ["-x", "-k", zip.path, directory.path])
                let app = directory.appendingPathComponent("Stratovo.app")
                guard app.resolvingSymlinksInPath() == app.standardizedFileURL,
                      let candidate = Bundle(url: app), candidate.bundleIdentifier == "org.pwnedg0blin.openguest",
                      let version = candidate.object(forInfoDictionaryKey: "StratovoReleaseVersion") as? String,
                      StratovoVersion(version) == expectedVersion else {
                    throw StorageMigration.failure("Bundle-ID oder Version des Updates stimmt nicht.")
                }
                try run("/usr/bin/codesign", ["--verify", "--deep", "--strict", app.path])
                return app
            }.value
            try storage.validate()
            guard !model.running, !model.graphicsLab.active else { throw StorageMigration.failure(L10n.text("Bitte alle Gäste vor dem Update beenden.")) }
            guard let helper = Bundle.main.url(forResource: "install-update", withExtension: "sh") else {
                throw StorageMigration.failure("Update-Helfer fehlt.")
            }
            let helperCopy = directory.appendingPathComponent("install-update.sh")
            try FileManager.default.copyItem(at: helper, to: helperCopy)
            let child = Process()
            child.executableURL = URL(fileURLWithPath: "/bin/bash")
            child.arguments = [helperCopy.path, String(ProcessInfo.processInfo.processIdentifier), current.path, prepared.path]
            child.standardInput = FileHandle.nullDevice
            let log = directory.appendingPathComponent("Installation.log")
            FileManager.default.createFile(atPath: log.path, contents: nil)
            let output = try FileHandle(forWritingTo: log)
            child.standardOutput = output; child.standardError = output
            try child.run()
            try? output.close()
            status = L10n.text("Update geprüft. Stratovo wird ausgetauscht und neu gestartet …")
            // The helper waits for this process to exit before replacing its bundle.
            model.setGraphicsLabBusy(false)
            NSApplication.shared.terminate(nil)
        } catch {
            status = error.localizedDescription
        }
    }
}
