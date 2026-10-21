import SwiftUI
import StratovoCore

@MainActor
struct WindowsGraphicsLabView: View {
    @ObservedObject var model: AppModel
    @ObservedObject var lab: WindowsGraphicsLabController
    @State private var showLog = false
    @State private var paste = false
    @State private var draft = ""
    @State private var exchangePresented = false
    var body: some View {
        WorkspaceCard {
            VStack(alignment: .leading, spacing: 14) {
                Label(L10n.text("Grafik und Leistung"), systemImage: "display").font(.headline)
                Text(L10n.text("3D über Metal · deine vorhandene Installation"))
                    .font(.headline).foregroundStyle(.teal)
                ContextHelpButton("Vorhandene Windows-Installation") {
                    Text(L10n.text("Konten, Programme, Dateien und Einstellungen bleiben in deiner bisherigen Windows-Festplatte. Es wird keine neue Windows-Kopie angelegt."))
                }
                Picker(L10n.text("Windows-Bildwiederholrate"), selection: $model.windowsRefreshRate) {
                    ForEach(WindowsRefreshRate.allCases) { rate in
                        Text(L10n.text(rate.title)).tag(rate)
                    }
                }.disabled(model.running || model.busy || lab.active)
                ContextHelpButton("Bildwiederholrate") {
                    Text(L10n.text("Gilt nach vollständigem Herunterfahren beim nächsten Windows-Start. Windows übernimmt die gewählte Frequenz für seine Auflösungen. Das FPS-Limit stellst du separat im Spiel ein; hohe Hz-Werte garantieren keine entsprechende Spieleleistung."))
                        .font(.body).foregroundStyle(.secondary)
                }
                if model.windowsEmbeddedPlayer {
                    Label(L10n.text("Eingebetteter Player · experimentell"), systemImage: "exclamationmark.triangle")
                        .font(.caption).foregroundStyle(.orange)
                }
                DisclosureGroup(L10n.text("Erweiterte Grafikoptionen")) {
                    Picker(L10n.text("Windows-Bildausgabe"), selection: $model.windowsEmbeddedPlayer) {
                        Text(L10n.text("Direktes Grafikfenster · Metal (Standard)")).tag(false)
                        Text(L10n.text("Eingebetteter Player · experimentell")).tag(true)
                    }.disabled(model.running || model.busy || lab.active)
                    Text(L10n.text(model.windowsEmbeddedPlayer
                        ? "Die Einbettung kopiert GPU-Bilder zur CPU und kann ruckeln oder hängen. Bei Problemen das direkte Grafikfenster wählen."
                        : "Das eigene Grafikfenster verwendet die direkte Ausgabe ohne VNC-Bildkopien. Text einfügen, Dateiaustausch und UEFI-Optionen bleiben hier verfügbar."))
                        .font(.callout).foregroundStyle(.secondary)
                    GroupBox(L10n.text("Schreiblimit")) {
                        VStack(alignment: .leading, spacing: 8) {
                            Picker(L10n.text("Windows-Schreiblimit"), selection: $model.windowsWriteLimit) {
                                ForEach(WindowsWriteLimit.allCases) { limit in
                                    Text(L10n.text(limit.title)).tag(limit)
                                }
                            }.disabled(model.running || model.busy || lab.active)
                            ContextHelpButton("Schreiblimit") {
                                Text(L10n.text("Testoption · gilt ab dem nächsten Windows-Start für alle Schreibzugriffe auf die Windows-Festplatte. Downloads und Installationen können länger dauern. Ob die Oberfläche flüssiger bleibt, bitte vergleichen."))
                                    .font(.body).foregroundStyle(.secondary)
                            }
                            ContextHelpButton("Schreiblimit") {
                                Text(L10n.text("1. Windows herunterfahren. 2. Zum Vergleich zunächst Aus verwenden. 3. Danach 40 MiB/s wählen, Windows starten und denselben Steam-Download fortsetzen. 4. Bei keiner Verbesserung wieder Aus wählen. Spieleleistung anschließend separat testen."))
                                    .font(.body).textSelection(.enabled)
                            }
                        }.frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                if lab.active {
                    HStack(spacing: 12) {
                        ProgressView().controlSize(.small)
                        Text(lab.status).font(.callout).textSelection(.enabled)
                    }
                }
                if !lab.runtimeReady {
                    Button(L10n.text("3D-Player vorbereiten / aktualisieren")) { lab.start(action: .build, model: model) }
                        .buttonStyle(.borderedProminent).controlSize(.large)
                        .disabled(model.running || model.busy || lab.active || !model.storageReady)
                    ContextHelpButton("3D-Player vorbereiten") {
                        Text(L10n.text("Einmalig: vollständiges Xcode mit Metal-Werkzeugen und mindestens 30 GiB für den Grafikbau. Bereits gebaute Laufzeiten werden weiterverwendet."))
                    }
                } else {
                    Label(L10n.text("3D-Laufzeit bereit"), systemImage: "checkmark.circle.fill").foregroundStyle(.green)
                }
                ContextHelpButton("Treiber einrichten") {
                    Text(L10n.text("Beim ersten 3D-Start: Windows-Explorer → Dieser PC → DVD PKGRAPHICS → INSTALL_GRAPHICS.cmd. Danach Windows herunterfahren und erneut starten."))
                }
                if model.running && model.activeGuest == "windows" {
                    GuestAudioControls(audio: model.audio, kind: "windows")
                    controls
                    Text(L10n.text("Esc beim Einschalten: UEFI / BIOS. Zum Verlassen des Menüs Continue wählen."))
                        .font(.system(size: 14, weight: .semibold))
                    Text(model.windowsPasteStatus).font(.callout).textSelection(.enabled)
                }
                DisclosureGroup(L10n.text("Grafikvorbereitung und Protokoll"), isExpanded: $showLog) {
                    Text(lab.status).textSelection(.enabled)
                    Button(L10n.text("Protokoll öffnen")) { lab.openBuildLog(model: model) }
                    Button(L10n.text("Mac-Voraussetzungen prüfen")) { lab.start(action: .check, model: model) }
                        .disabled(model.running || model.busy || lab.active)
                    if lab.building { Button(L10n.text("Grafikbuild abbrechen"), action: lab.cancelBuild) }
                    ScrollView { Text(lab.progress).font(.system(.caption, design: .monospaced)).textSelection(.enabled) }.frame(height: 130)
                    ContextHelpButton("Details und Anleitung") {
                        Text(L10n.text("Eine vorhandene frühere Testkopie im Grafiklabor wird nicht gelöscht und nicht automatisch als Hauptinstallation verwendet."))
                            .font(.body).foregroundStyle(.secondary)
                    }
                }
            }.frame(maxWidth: .infinity, alignment: .leading)
        }
        .onAppear { lab.refresh(model: model) }
        .onChange(of: lab.failed) { _, failed in
            if failed { showLog = true }
        }
        .sheet(isPresented: $paste, onDismiss: { draft = "" }) { WindowsPasteSheet(model: model, text: $draft) }
        .sheet(isPresented: $exchangePresented) {
            VStack {
                ScrollView { ExchangeFolderView(model: model, controller: model.exchange).padding(20) }
                Button(L10n.text("Fertig")) { exchangePresented = false }.keyboardShortcut(.defaultAction).padding()
            }.frame(width: 720, height: 700).modifier(WorkspaceDialogTheme())
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
