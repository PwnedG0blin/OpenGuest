import AppKit
import Foundation
import StratovoCore

@MainActor
final class AppUpdateInstaller: ObservableObject {
    @Published private(set) var busy = false
    @Published private(set) var status = ""

    func install(_ release: StratovoRelease, model: AppModel) async {
        guard Bundle.main.object(forInfoDictionaryKey: "StratovoBuildFlavor") as? String != "private" else {
            status = "Private Variante: Bitte ein privates Update verwenden."; return
        }
        guard let asset = release.assets?.first(where: { $0.isTrusted(for: release) }),
              let hash = asset.sha256, let version = release.version else {
            status = L10n.text("Kein geprüftes Apple-Silicon-App-Paket vorhanden. Bitte die Veröffentlichung öffnen."); return
        }
        await install(model: model, hash: hash, size: Int64(asset.size), version: version) {
            let config = URLSessionConfiguration.ephemeral; config.urlCache = nil
            let session = URLSession(configuration: config)
            defer { session.invalidateAndCancel() }
            var request = URLRequest(url: asset.browserDownloadURL); request.timeoutInterval = 180
            let (data, response) = try await session.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else {
                throw PrivateUpdateAPI.failure("Update-Download fehlgeschlagen.")
            }
            return data
        }
    }

    func installPrivate(_ artifact: PrivateUpdateArtifact, token: String, model: AppModel) async {
        guard Bundle.main.object(forInfoDictionaryKey: "StratovoBuildFlavor") as? String == "private",
              let current = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String,
              let currentBuild = Int(current), let build = artifact.build, build > currentBuild,
              let hash = artifact.sha256, !artifact.expired else {
            status = "Kein neueres privates Update vorhanden. Bitte erneut prüfen."; return
        }
        await install(model: model, hash: hash, size: artifact.size, privateBuild: build) {
            try await PrivateUpdateAPI(token: token).download(artifact)
        }
    }

    private func install(model: AppModel, hash: String, size: Int64,
                         version: StratovoVersion? = nil, privateBuild: Int? = nil,
                         download: () async throws -> Data) async {
        guard !busy, !model.busy, !model.running, !model.graphicsLab.active else {
            status = L10n.text("Bitte zuerst alle Gäste und den Grafikbau beenden."); return
        }
        guard let storage = model.storage, model.storageReady else {
            status = L10n.text("Datenordner nicht erreichbar"); return
        }
        busy = true; model.setGraphicsLabBusy(true)
        defer { busy = false; model.setGraphicsLabBusy(false) }
        do {
            try storage.validate()
            let current = Bundle.main.bundleURL.standardizedFileURL
            guard current.pathExtension == "app", current.lastPathComponent == "Stratovo.app",
                  current.resolvingSymlinksInPath() == current,
                  FileManager.default.isWritableFile(atPath: current.deletingLastPathComponent().path) else {
                throw PrivateUpdateAPI.failure("Kopiere Stratovo zunächst in einen beschreibbaren Programme-Ordner und starte sie von dort.")
            }
            let directory = storage.url.appendingPathComponent("Updates/" + UUID().uuidString, isDirectory: true)
            guard directory.resolvingSymlinksInPath() == directory.standardizedFileURL else {
                throw PrivateUpdateAPI.failure("Updateordner darf keine Verknüpfung sein.")
            }
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
            status = L10n.text("Update wird von GitHub geladen …")
            let data = try await download()
            status = L10n.text("Prüfsumme und App werden geprüft …")
            let prepared = try await Task.detached {
                try UpdatePackagePreparer.prepare(data: data, sha256: hash, size: size, directory: directory,
                                                 version: version, privateBuild: privateBuild)
            }.value
            try storage.validate()
            guard !model.running, !model.graphicsLab.active else { throw PrivateUpdateAPI.failure("Bitte alle Gäste vor dem Update beenden.") }
            guard let helper = Bundle.main.url(forResource: "install-update", withExtension: "sh") else { throw PrivateUpdateAPI.failure("Update-Helfer fehlt.") }
            let helperCopy = directory.appendingPathComponent("install-update.sh")
            try FileManager.default.copyItem(at: helper, to: helperCopy)
            let child = Process(); child.executableURL = URL(fileURLWithPath: "/bin/bash")
            child.arguments = [helperCopy.path, String(ProcessInfo.processInfo.processIdentifier), current.path, prepared.path]
            child.standardInput = FileHandle.nullDevice
            let log = directory.appendingPathComponent("Installation.log")
            FileManager.default.createFile(atPath: log.path, contents: nil)
            let output = try FileHandle(forWritingTo: log)
            child.standardOutput = output; child.standardError = output
            try child.run(); try? output.close()
            status = L10n.text("Update geprüft. Stratovo wird ausgetauscht und neu gestartet …")
            model.setGraphicsLabBusy(false)
            NSApplication.shared.terminate(nil)
        } catch {
            // Download errors may contain signed URLs; never display or log them.
            status = (error as NSError).domain == "Stratovo.PrivateUpdates"
                ? error.localizedDescription : "Update fehlgeschlagen. Prüfe Internetverbindung und Datenlaufwerk. Die bisherige App bleibt erhalten."
        }
    }
}
