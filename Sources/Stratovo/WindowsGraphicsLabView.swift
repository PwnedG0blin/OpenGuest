import AppKit
import Darwin
import Foundation
import SwiftUI
import StratovoCore

@MainActor
final class WindowsGraphicsLabController: ObservableObject {
    @Published private(set) var active = false
    @Published private(set) var building = false
    @Published private(set) var failed = false
    @Published private(set) var runtimeReady = false
    @Published private(set) var status = "3D-Testlaufzeit noch nicht geprüft"
    @Published private(set) var progress = ""
    private var process: Process?
    private var output: FileHandle?
    private var timer: Timer?
    private var root: URL?

    func start(action: String, model: AppModel) {
        guard !active, !model.running, !model.busy, let storage = model.storage,
              let image = model.qemuImg, let swtpm = model.swtpm, let firmware = model.firmware else {
            status = "Windows vollständig beenden und die QEMU-/TPM-Werkzeuge sowie den Datenordner prüfen."
            failed = true
            return
        }
        do {
            try storage.validate()
            _ = try storage.prepareWindowsFolder()
            let root = storage.url.appendingPathComponent("GraphicsLab", isDirectory: true)
            guard root.resolvingSymlinksInPath().path == root.standardizedFileURL.path else {
                throw StorageMigration.failure("Grafiklabor darf keine Verknüpfung sein.")
            }
            let files = FileManager.default
            let resources = root.appendingPathComponent("AppResources", isDirectory: true)
            try files.createDirectory(at: resources, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
            guard resources.resolvingSymlinksInPath().path == resources.standardizedFileURL.path else {
                throw StorageMigration.failure("Grafik-Ressourcen dürfen keine Verknüpfung sein.")
            }
            guard let bundled = Bundle.main.resourceURL?.appendingPathComponent("GraphicsLab") else {
                throw StorageMigration.failure("Grafiklabor-Ressourcen fehlen.")
            }
            for name in ["lab.py", "sources.json", "INSTALL_GRAPHICS.ps1", "INSTALL_GRAPHICS.cmd", "ZUERST_AUF_MAC_LESEN.txt", "pkgconf-2.3.0.tar.xz"] {
                let bytes = try Data(contentsOf: bundled.appendingPathComponent(name))
                try bytes.write(to: resources.appendingPathComponent(name), options: .atomic)
            }
            let config: [String: String] = ["root": storage.root, "storageID": storage.id,
                                           "qemuImg": image, "swtpm": swtpm, "firmware": firmware]
            let configURL = resources.appendingPathComponent("config.json")
            try JSONSerialization.data(withJSONObject: config, options: [.sortedKeys]).write(to: configURL, options: .atomic)
            let logURL = root.appendingPathComponent(action == "launch" ? "Test-Start.log" : "Build.log")
            guard ((try? files.attributesOfItem(atPath: logURL.path))?[.type] as? FileAttributeType) != .typeSymbolicLink else {
                throw StorageMigration.failure("Grafik-Protokoll darf keine Verknüpfung sein.")
            }
            files.createFile(atPath: logURL.path, contents: nil, attributes: [.posixPermissions: 0o600])
            let handle = try FileHandle(forWritingTo: logURL)
            let child = Process()
            child.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
            child.arguments = [resources.appendingPathComponent("lab.py").path, "--config", configURL.path, "--managed-process-group", action]
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
                    else if action == "check" { self.status = "Mac-Voraussetzungen geprüft · jetzt Grafik vorbereiten" }
                    else if action == "build" { self.status = "Grafiklaufzeit und Treiber-DVD bereit · jetzt Test-Windows starten" }
                    else { self.status = "3D-Test beendet · Testdaten bleiben gespeichert" }
                    model?.recordGraphicsLabEvent(self.status + "\n" + self.progress)
                }
            }
            do { try child.run() } catch { try? handle.close(); throw error }
            self.root = root; process = child; output = handle
            active = true; failed = false; building = action != "launch"; model.setGraphicsLabBusy(true)
            status = action == "check" ? "Mac-Voraussetzungen werden geprüft …" : (building ? "Grafik wird auf dem gewählten Laufwerk vorbereitet · noch kein Test-Windows geöffnet …" : "Testkopie wird im eigenen Grafikfenster gestartet …")
            progress = "Protokoll: " + logURL.path
            model.recordGraphicsLabEvent(status + " · " + logURL.path)
            timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
                Task { @MainActor in self?.readProgress(logURL) }
            }
        } catch { status = error.localizedDescription; failed = true }
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
            status = "Test-Windows läuft im eigenen Fenster · dort Explorer > Dieser PC > PKGRAPHICS öffnen"
        }
    }
    func refresh(model: AppModel) {
        guard let root = model.storage?.url.appendingPathComponent("GraphicsLab") else { runtimeReady = false; return }
        runtimeReady = ["runtime-ready.json", "Runtime/bin/qemu-system-aarch64", "Runtime/libexec/virgl_render_server", "Runtime/lib/libdxmt-native.dylib", "GraphicsDrivers.iso"].allSatisfy {
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
                    throw StorageMigration.failure("Testfenster wird noch vorbereitet. Kurz warten.")
                }
                try await QMPClient.shutdown(socket: socket)
                status = "Herunterfahren der Testkopie angefordert …"
            } catch { status = "Testkopie noch nicht erreichbar: " + error.localizedDescription }
        }
    }
    func cancelBuild() {
        guard active, building, let process else { return }
        if Darwin.kill(-process.processIdentifier, SIGTERM) != 0 { process.terminate() }
        status = "Grafikbuild wird abgebrochen. Bereits geladene Quellen bleiben für einen neuen Versuch erhalten."
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

@MainActor
struct WindowsGraphicsLabView: View {
    @ObservedObject var model: AppModel
    @ObservedObject var lab: WindowsGraphicsLabController
    @State private var showLog = false
    @State private var showDriverHelp = false
    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 14) {
                Label("Windows-Modus", systemImage: "display.2").font(.title3.bold())
                Picker("Windows-Modus", selection: $model.windowsLabSelected) {
                    Text("Normales Windows").tag(false)
                    Text("3D-Testkopie · privat").tag(true)
                }.pickerStyle(.segmented).disabled(model.running || lab.active)
                if model.windowsLabSelected {
                    Text("Triton / Neptune → DXMT → Metal").font(.headline).foregroundStyle(.teal)
                    Text("Experimentelle ARM64-Grafik in einer unabhängigen Kopie deines Windows. Eigene Programme, Anmeldungen und Teständerungen bleiben in dieser Kopie gespeichert. Beim Zurückwechseln öffnest du dein normales Windows; Änderungen werden nicht übertragen.")
                    Text(lab.status).font(.subheadline.bold()).textSelection(.enabled)
                    buttons
                    Label(lab.runtimeReady ? "Mac-Grafiklaufzeit und Treiber-DVD vorhanden" : "Schritt 1: Mac-Grafiklaufzeit vorbereiten · Test-Windows noch nicht verfügbar", systemImage: lab.runtimeReady ? "checkmark.circle.fill" : "hammer.fill")
                        .font(.subheadline.bold()).foregroundStyle(lab.runtimeReady ? .green : .orange)
                    Text("Alles beginnt auf deinem Mac: Voraussetzungen prüfen, dann Grafik vorbereiten und Test-Windows starten. Der erste Bau benötigt vollständiges Xcode mit Metal-Werkzeugen, Internet und mindestens 30 GiB auf deinem Datenlaufwerk. Quellen, Werkzeuge und die spätere Windows-Kopie liegen dort. Fehlendes pkg-config wird dort automatisch gebaut.")
                        .font(.subheadline)
                    Button("Wo installiere ich den Windows-Grafiktreiber?") { showDriverHelp = true }.buttonStyle(.bordered)
                    Text("Die Treiber-DVD entsteht erst nach erfolgreichem Mac-Bau. Im gestarteten Test-Windows: Explorer → Dieser PC → DVD PKGRAPHICS → INSTALL_GRAPHICS.cmd. Die .cmd funktioniert im virtuellen Windows; du brauchst keinen zweiten PC. Danach Test-Windows herunterfahren und erneut starten.")
                        .font(.subheadline).textSelection(.enabled)
                    Text("Das 3D-Testfenster verwendet direkte Metal-Ausgabe. Zwischenablage und Trackpad-Regler des normalen Players sind dort noch nicht verbunden.")
                        .font(.subheadline).foregroundStyle(.secondary)
                    HStack {
                        Button("Mac-Protokolle im Finder öffnen") { lab.openFolder(model: model) }.buttonStyle(.bordered)
                        Toggle("Protokoll anzeigen", isOn: $showLog).toggleStyle(.checkbox)
                    }
                    if lab.building { Button("Grafikbuild abbrechen", action: lab.cancelBuild).buttonStyle(.bordered) }
                    if lab.failed {
                        Button("Konkreten Baufehler öffnen") { lab.openBuildLog(model: model) }.buttonStyle(.borderedProminent)
                        Text("Der Vorgang ist beendet. Das Protokoll ist keine Terminal-Eingabe; Enter ist hier nicht nötig.").font(.subheadline)
                    }
                    if showLog || lab.failed { ScrollView { Text(lab.progress).font(.system(.caption, design: .monospaced)).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading) }.frame(height: 160) }
                } else {
                    Text("Dein bisheriges Windows mit den vorhandenen Programmen und Daten.").font(.subheadline)
                    Button(action: model.startExistingWindows) { Label("Normales Windows starten", systemImage: "play.fill") }
                        .buttonStyle(.borderedProminent).controlSize(.large)
                        .disabled(!model.canResumeWindows || lab.active)
                }
            }.padding(12).frame(maxWidth: .infinity, alignment: .leading)
             .onAppear { lab.refresh(model: model) }
             .onChange(of: model.windowsLabSelected) { _ in lab.refresh(model: model) }
             .sheet(isPresented: $showDriverHelp) {
                 VStack(alignment: .leading, spacing: 18) {
                     Label("Grafik auf Mac und Windows einrichten", systemImage: "display.2").font(.title2.bold()).foregroundStyle(.teal)
                     Text("1 · Auf dem Mac").font(.headline)
                     Text("Voraussetzungen prüfen und Grafik vorbereiten anklicken. Erst wenn der Bau erfolgreich ist, kann das Test-Windows geöffnet werden.")
                     Text("2 · Im virtuellen Windows").font(.headline)
                     Text("Im Test-Windows den Datei-Explorer öffnen. Unter Dieser PC erscheint die DVD PKGRAPHICS. Dort INSTALL_GRAPHICS.cmd doppelklicken und die Windows-Administratorabfrage bestätigen.")
                     Text("3 · Testkopie neu starten").font(.headline)
                     Text("Das Test-Windows herunterfahren und anschließend hier erneut starten. Die Treiberinstallation bleibt in der Testkopie gespeichert.")
                     Text("Im Mac-Finder lassen sich .cmd und .ps1 nicht ausführen. Der Grafikordner enthält nur die Hilfsdateien und Protokolle.").foregroundStyle(.secondary)
                     Button("Verstanden") { showDriverHelp = false }.buttonStyle(.borderedProminent).frame(maxWidth: .infinity, alignment: .trailing)
                 }.font(.system(size: 15)).padding(28).frame(width: 580)
                  .background(Color(nsColor: .windowBackgroundColor))
             }
        }
    }
    private var buttons: some View { VStack(alignment: .leading, spacing: 12) {
        Button("Mac-Voraussetzungen prüfen") { lab.start(action: "check", model: model) }.buttonStyle(.bordered).disabled(model.busy || model.running || lab.active || !model.storageReady)
        buildButton; startButton; stopButton
    } }
    private var buildButton: some View {
        Button("1 · Grafik vorbereiten und Test-Windows öffnen") { lab.start(action: "setup", model: model) }
            .buttonStyle(.bordered).controlSize(.large).disabled(model.busy || model.running || lab.active || !model.storageReady)
    }
    private var startButton: some View {
        Button("2 · Vorbereitetes Test-Windows öffnen") { lab.start(action: "launch", model: model) }
            .buttonStyle(.borderedProminent).controlSize(.large).disabled(model.busy || model.running || lab.active || !model.storageReady || !lab.runtimeReady)
    }
    private var stopButton: some View {
        Button("Test-Windows herunterfahren", action: lab.shutdown)
            .buttonStyle(.bordered).controlSize(.large).disabled(!lab.active || lab.building)
    }
}
