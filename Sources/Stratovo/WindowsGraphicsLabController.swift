import AppKit
import Darwin
import Foundation
import Combine
import StratovoCore

enum GraphicsLabAction: String {
    case check, build, launch
}

@MainActor
final class WindowsGraphicsLabController: ObservableObject {
    @Published private(set) var active = false
    @Published private(set) var building = false
    @Published private(set) var failed = false
    @Published private(set) var runtimeReady = false
    @Published private(set) var status = L10n.text("3D-Testlaufzeit noch nicht geprüft")
    @Published private(set) var progress = ""
    private var process: Process?
    private var output: FileHandle?
    private var timer: Timer?
    private var root: URL?

    func start(action: GraphicsLabAction, model: AppModel) {
        guard !active, !model.running, !model.busy, let storage = model.storage,
              let image = model.qemuImg, let swtpm = model.swtpm, let firmware = model.firmware else {
            status = L10n.text("Windows vollständig beenden und die QEMU-/TPM-Werkzeuge sowie den Datenordner prüfen.")
            failed = true
            return
        }
        do {
            try storage.validate()
            _ = try storage.prepareWindowsFolder()
            let root = storage.url.appendingPathComponent("GraphicsLab", isDirectory: true)
            guard root.resolvingSymlinksInPath().path == root.standardizedFileURL.path else {
                throw StorageMigration.failure(L10n.text("Grafiklabor darf keine Verknüpfung sein."))
            }
            let files = FileManager.default
            let resources = root.appendingPathComponent("AppResources", isDirectory: true)
            try files.createDirectory(at: resources, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
            guard resources.resolvingSymlinksInPath().path == resources.standardizedFileURL.path else {
                throw StorageMigration.failure(L10n.text("Grafik-Ressourcen dürfen keine Verknüpfung sein."))
            }
            guard let bundled = Bundle.main.resourceURL?.appendingPathComponent("GraphicsLab") else {
                throw StorageMigration.failure("Grafiklabor-Ressourcen fehlen.")
            }
            let policy = try GraphicsRuntimePolicy.load(from: bundled)
            let resourceSet = try policy.readResources(from: bundled)
            for resource in resourceSet {
                try resource.data.write(to: resources.appendingPathComponent(resource.name), options: .atomic)
            }
            let config: [String: String] = ["root": storage.root, "storageID": storage.id,
                                           "qemuImg": image, "swtpm": swtpm, "firmware": firmware]
            let configURL = resources.appendingPathComponent("config.json")
            try JSONSerialization.data(withJSONObject: config, options: [.sortedKeys]).write(to: configURL, options: .atomic)
            let logURL = root.appendingPathComponent(action == .launch ? "Test-Start.log" : "Build.log")
            guard ((try? files.attributesOfItem(atPath: logURL.path))?[.type] as? FileAttributeType) != .typeSymbolicLink else {
                throw StorageMigration.failure(L10n.text("Grafik-Protokoll darf keine Verknüpfung sein."))
            }
            files.createFile(atPath: logURL.path, contents: nil, attributes: [.posixPermissions: 0o600])
            let handle = try FileHandle(forWritingTo: logURL)
            let child = Process()
            child.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
            child.arguments = [resources.appendingPathComponent("lab.py").path, "--config", configURL.path, "--managed-process-group", action.rawValue]
            child.standardInput = FileHandle.nullDevice
            child.standardOutput = handle; child.standardError = handle
            child.terminationHandler = { [weak self, weak model] child in
                let code = child.terminationStatus
                Task { @MainActor in
                    guard let self else { return }
                    self.readProgress(logURL)
                    self.timer?.invalidate(); self.timer = nil
                    try? self.output?.close(); self.output = nil
                    self.process = nil; self.active = false; self.building = false
                    self.failed = code != 0
                    if let model { self.refresh(model: model) }
                    model?.setGraphicsLabBusy(false)
                    if code != 0 { self.status = "Grafikvorbereitung angehalten · Ursache unten im Protokoll (Code \(code))" }
                    else if action == .check { self.status = L10n.text("Mac-Voraussetzungen geprüft · jetzt Grafik vorbereiten") }
                    else if action == .build { self.status = L10n.text("3D-Grafiklaufzeit und Treiber-DVD bereit · jetzt Windows starten") }
                    else { self.status = "3D-Test beendet · Testdaten bleiben gespeichert" }
                    model?.recordGraphicsLabEvent(self.status + "\n" + self.progress)
                }
            }
            do { try child.run() } catch { try? handle.close(); throw error }
            self.root = root; process = child; output = handle
            active = true; failed = false; building = action != .launch; model.setGraphicsLabBusy(true)
            status = action == .check ? L10n.text("Mac-Voraussetzungen werden geprüft …") : (building ? L10n.text("3D-Player wird auf dem gewählten Laufwerk vorbereitet …") : L10n.text("Testkopie wird im eigenen Grafikfenster gestartet …"))
            progress = "Protokoll: " + logURL.path
            model.recordGraphicsLabEvent(status + " · " + logURL.path)
            timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
                Task { @MainActor in self?.readProgress(logURL) }
            }
        } catch {
            status = error.localizedDescription
            progress = status
            failed = true
            model.recordGraphicsLabEvent("Grafikvorbereitung angehalten: " + status)
        }
    }

    private func readProgress(_ url: URL) {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return }
        defer { try? handle.close() }
        let size = (try? handle.seekToEnd()) ?? 0
        try? handle.seek(toOffset: size > 2400 ? size - 2400 : 0)
        let text = String(decoding: (try? handle.readToEnd()) ?? Data(), as: UTF8.self)
        if progress != text { progress = text }
        if active, let root, FileManager.default.fileExists(atPath: root.appendingPathComponent("running.json").path) {
            building = false
            status = L10n.text("Test-Windows läuft im eigenen Fenster · dort Explorer > Dieser PC > PKGRAPHICS öffnen")
        }
    }
    func refresh(model: AppModel) {
        guard let root = model.storage?.url.appendingPathComponent("GraphicsLab"),
              let bundled = Bundle.main.resourceURL?.appendingPathComponent("GraphicsLab"),
              let policy = try? GraphicsRuntimePolicy.load(from: bundled),
              let receipt = try? Data(contentsOf: root.appendingPathComponent("runtime-ready.json")) else {
            runtimeReady = false
            return
        }
        let playerReady = policy.accepts(receipt: receipt)
        runtimeReady = playerReady && ["runtime-ready.json", "Runtime/bin/qemu-system-aarch64", "Runtime/libexec/virgl_render_server", "Runtime/lib/libdxmt-native.dylib", "GraphicsDrivers.iso"].allSatisfy {
            FileManager.default.fileExists(atPath: root.appendingPathComponent($0).path)
        }
    }

    func shutdown() {
        guard active, !building, let root else { return }
        Task {
            do {
                let data = try Data(contentsOf: root.appendingPathComponent("running.json"))
                let value = try JSONSerialization.jsonObject(with: data) as? [String: String]
                guard let socket = value?["qmp"], socket.hasPrefix("/tmp/pk-gpu-") else {
                    throw StorageMigration.failure(L10n.text("Testfenster wird noch vorbereitet. Kurz warten."))
                }
                try await QMPClient.shutdown(socket: socket)
                status = "Herunterfahren der Testkopie angefordert …"
            } catch { status = "Testkopie noch nicht erreichbar: " + error.localizedDescription }
        }
    }
    func cancelBuild() {
        guard active, building, let process else { return }
        if Darwin.kill(-process.processIdentifier, SIGTERM) != 0 { process.terminate() }
        status = L10n.text("Grafikbuild wird abgebrochen. Bereits geladene Quellen bleiben für einen neuen Versuch erhalten.")
    }
    func openBuildLog(model: AppModel) {
        guard let folder = model.storage?.url.appendingPathComponent("GraphicsLab") else { return }
        let choices = ["Logs/Letzter-Fehler.log", "Logs/Metal-Pruefung.log", "Logs/ANGLE-Build.log", "Build.log"]
        if let file = choices.map({ folder.appendingPathComponent($0) }).first(where: { FileManager.default.fileExists(atPath: $0.path) }) {
            NSWorkspace.shared.open(file)
        }
    }
    func openFolder(model: AppModel) {
        guard let folder = model.storage?.url.appendingPathComponent("GraphicsLab") else { return }
        NSWorkspace.shared.open(folder)
    }
}

