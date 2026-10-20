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
    @Published private(set) var status = L10n.text("3D-Testlaufzeit noch nicht geprüft")
    @Published private(set) var progress = ""
    private var process: Process?
    private var output: FileHandle?
    private var timer: Timer?
    private var root: URL?

    func start(action: String, model: AppModel) {
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
            for name in ["lab.py", "sources.json", "INSTALL_GRAPHICS.ps1", "INSTALL_GRAPHICS.cmd", "ZUERST_AUF_MAC_LESEN.txt", "pkgconf-2.3.0.tar.xz", "boot_appearance.py", "embedded_display.py", "embedded_bridge.m.inc", "embedded_repair.py", "shared_frame.m.inc", "gl_frame.m.inc", "metal_frame.m.inc", "vnc_frame.c.inc", "legacy_embedded_bridge.m.inc", "legacy_v2_gl_frame.m.inc", "native_display.py", "native_geometry.h.inc", "native_view.m.inc", "native_methods.m.inc", "ubuntu_vm.py"] {
                let bytes = try Data(contentsOf: bundled.appendingPathComponent(name))
                try bytes.write(to: resources.appendingPathComponent(name), options: .atomic)
            }
            let config: [String: String] = ["root": storage.root, "storageID": storage.id,
                                           "qemuImg": image, "swtpm": swtpm, "firmware": firmware]
            let configURL = resources.appendingPathComponent("config.json")
            try JSONSerialization.data(withJSONObject: config, options: [.sortedKeys]).write(to: configURL, options: .atomic)
            let logURL = root.appendingPathComponent(action == "launch" ? "Test-Start.log" : "Build.log")
            guard ((try? files.attributesOfItem(atPath: logURL.path))?[.type] as? FileAttributeType) != .typeSymbolicLink else {
                throw StorageMigration.failure(L10n.text("Grafik-Protokoll darf keine Verknüpfung sein."))
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
                    else if action == "check" { self.status = L10n.text("Mac-Voraussetzungen geprüft · jetzt Grafik vorbereiten") }
                    else if action == "build" { self.status = L10n.text("3D-Grafiklaufzeit und Treiber-DVD bereit · jetzt Windows starten") }
                    else { self.status = "3D-Test beendet · Testdaten bleiben gespeichert" }
                    model?.recordGraphicsLabEvent(self.status + "\n" + self.progress)
                }
            }
            do { try child.run() } catch { try? handle.close(); throw error }
            self.root = root; process = child; output = handle
            active = true; failed = false; building = action != "launch"; model.setGraphicsLabBusy(true)
            status = action == "check" ? L10n.text("Mac-Voraussetzungen werden geprüft …") : (building ? L10n.text("3D-Player wird auf dem gewählten Laufwerk vorbereitet …") : L10n.text("Testkopie wird im eigenen Grafikfenster gestartet …"))
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
            status = L10n.text("Test-Windows läuft im eigenen Fenster · dort Explorer > Dieser PC > PKGRAPHICS öffnen")
        }
    }
    func refresh(model: AppModel) {
        guard let root = model.storage?.url.appendingPathComponent("GraphicsLab") else { runtimeReady = false; return }
        let receipt = try? Data(contentsOf: root.appendingPathComponent("runtime-ready.json"))
        let metadata = receipt.flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] }
        let playerReady = metadata?["embeddedPlayer"] as? Int == 1 && metadata?["embeddedRevision"] as? Int == 4
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

@MainActor
struct WindowsGraphicsLabView: View {
    @ObservedObject var model: AppModel
    @ObservedObject var lab: WindowsGraphicsLabController
    @State private var showLog = false
    @State private var paste = false
    @State private var draft = ""
    @State private var exchangePresented = false
    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 14) {
                Label(L10n.text("Windows Arm"), systemImage: "desktopcomputer").font(.title2.bold())
                Text(L10n.text("3D über Metal · deine vorhandene Installation"))
                    .font(.headline).foregroundStyle(.teal)
                Text(L10n.text("Konten, Programme, Dateien und Einstellungen bleiben in deiner bisherigen Windows-Festplatte. Es wird keine neue Windows-Kopie angelegt."))
                Picker(L10n.text("Windows-Bildausgabe"), selection: $model.windowsEmbeddedPlayer) {
                    Text(L10n.text("Direktes Grafikfenster · Metal (Standard)")).tag(false)
                    Text(L10n.text("Eingebetteter Player · experimentell")).tag(true)
                }.disabled(model.running || model.busy || lab.active)
                Text(L10n.text(model.windowsEmbeddedPlayer
                    ? "Die Einbettung kopiert GPU-Bilder zur CPU und kann ruckeln oder hängen. Bei Problemen das direkte Grafikfenster wählen."
                    : "Das eigene Grafikfenster verwendet die direkte Ausgabe ohne VNC-Bildkopien. Text einfügen, Dateiaustausch und UEFI-Optionen bleiben hier verfügbar."))
                    .font(.callout).foregroundStyle(.secondary)
                GroupBox(L10n.text("Steam-Download testen")) {
                    VStack(alignment: .leading, spacing: 8) {
                        Picker(L10n.text("Windows-Schreiblimit"), selection: $model.windowsWriteLimit) {
                            ForEach(WindowsWriteLimit.allCases) { limit in
                                Text(L10n.text(limit.title)).tag(limit)
                            }
                        }.disabled(model.running || model.busy || lab.active)
                        Text(L10n.text("Testoption · gilt ab dem nächsten Windows-Start für alle Schreibzugriffe auf die Windows-Festplatte. Downloads und Installationen können länger dauern. Ob die Oberfläche flüssiger bleibt, bitte vergleichen."))
                            .font(.callout).foregroundStyle(.secondary)
                        Text(L10n.text("1. Windows herunterfahren. 2. Zum Vergleich zunächst Aus verwenden. 3. Danach 40 MiB/s wählen, Windows starten und denselben Steam-Download fortsetzen. 4. Bei keiner Verbesserung wieder Aus wählen. Spieleleistung anschließend separat testen."))
                            .font(.callout).textSelection(.enabled)
                    }.frame(maxWidth: .infinity, alignment: .leading)
                }
                if !lab.runtimeReady {
                    Button(L10n.text("3D-Player vorbereiten / aktualisieren")) { lab.start(action: "build", model: model) }
                        .buttonStyle(.borderedProminent).controlSize(.large)
                        .disabled(model.running || model.busy || lab.active || !model.storageReady)
                    Text(L10n.text("Einmalig: vollständiges Xcode mit Metal-Werkzeugen und mindestens 30 GiB für den Grafikbau. Bereits gebaute Laufzeiten werden weiterverwendet."))
                } else {
                    Label(L10n.text("3D-Laufzeit bereit"), systemImage: "checkmark.circle.fill").foregroundStyle(.green)
                }
                Text(L10n.text("Beim ersten 3D-Start: Windows-Explorer → Dieser PC → DVD PKGRAPHICS → INSTALL_GRAPHICS.cmd. Danach Windows herunterfahren und erneut starten."))
                if model.running && model.activeGuest == "windows" {
                    controls
                    Text(L10n.text("Esc beim Einschalten: UEFI / BIOS. Zum Verlassen des Menüs Continue wählen."))
                        .font(.system(size: 14, weight: .semibold))
                    Text(model.windowsPasteStatus).font(.callout).textSelection(.enabled)
                }
                DisclosureGroup(L10n.text("Grafikvorbereitung und Protokoll"), isExpanded: $showLog) {
                    Text(lab.status).textSelection(.enabled)
                    Button(L10n.text("Mac-Voraussetzungen prüfen")) { lab.start(action: "check", model: model) }
                        .disabled(model.running || model.busy || lab.active)
                    if lab.building { Button(L10n.text("Grafikbuild abbrechen"), action: lab.cancelBuild) }
                    ScrollView { Text(lab.progress).font(.system(.caption, design: .monospaced)).textSelection(.enabled) }.frame(height: 130)
                    Text(L10n.text("Eine vorhandene frühere Testkopie im Grafiklabor wird nicht gelöscht und nicht automatisch als Hauptinstallation verwendet."))
                        .font(.caption).foregroundStyle(.secondary)
                }
            }.padding(12).frame(maxWidth: .infinity, alignment: .leading)
        }
        .onAppear { lab.refresh(model: model) }
        .sheet(isPresented: $paste, onDismiss: { draft = "" }) { WindowsPasteSheet(model: model, text: $draft) }
        .sheet(isPresented: $exchangePresented) {
            VStack {
                ScrollView { ExchangeFolderView(model: model, controller: model.exchange).padding(20) }
                Button(L10n.text("Fertig")) { exchangePresented = false }.keyboardShortcut(.defaultAction).padding()
            }.frame(width: 720, height: 700)
        }
    }
    private var controls: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 165))], alignment: .leading, spacing: 10) {
            Button(L10n.text("Windows-Fenster zeigen"), action: model.activateWindows)
            Button(L10n.text("Dateiaustausch")) { exchangePresented = true }
            Button(L10n.text("Text einfügen …")) { draft = NSPasteboard.general.string(forType: .string) ?? ""; paste = true }
                .disabled(model.windowsPasteBusy)
            Button(L10n.text("Anzeige-Einstellungen"), action: model.openWindowsDisplaySettings)
            Button(L10n.text("UEFI / BIOS · Esc"), action: model.openWindowsFirmwareMenu)
            Button(L10n.text("Einrichtungskonsole öffnen"), action: model.openWindowsSetupConsole)
            Button(L10n.text("Herunterfahren")) { model.shutdownGuest() }
        }.buttonStyle(.bordered)
    }
}
