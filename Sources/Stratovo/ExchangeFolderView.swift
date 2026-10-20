import AppKit
import SwiftUI
import StratovoCore

@MainActor
final class ExchangeController: ObservableObject {
    @Published private(set) var transferring = false
    @Published private(set) var status = ""
    private var transferTask: Task<Void, Never>?
    func cancelTransfer() { transferTask?.cancel() }

    func openFinder(model: AppModel) {
        do {
            guard let storage = model.storage else { return }
            NSWorkspace.shared.open(try ExchangeFolder.prepare(storage: storage))
        } catch { status = error.localizedDescription }
    }

    func openSharingSettings() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.Sharing-Settings.extension")!)
    }

    func copy(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        status = L10n.text("Adresse kopiert")
    }

    private func run(adb: String, port: Int, storage: GuestStorage, arguments: [String]) async throws {
        try Task.checkCancellation()
        let result = try await Task.detached(priority: .utility) {
            try storage.validate()
            return try CommandCapture.run(CommandSpec(executable: adb, arguments: ["-s", "emulator-\(port)"] + arguments,
                environment: storage.environment), timeout: 7200)
        }.value
        try Task.checkCancellation()
        guard result.status == 0 else { throw StorageMigration.failure("Dateiübertragung fehlgeschlagen: " + result.output) }
    }

    func sendAndroid(model: AppModel) {
        guard !transferring, !model.busy, model.running, model.activeGuest == "android", model.androidBooted,
              let adb = model.adb, let port = model.androidExchangePort, let storage = model.storage else { return }
        let panel = NSOpenPanel()
        panel.title = L10n.text("Datei zu Android senden")
        panel.canChooseFiles = true; panel.canChooseDirectories = false; panel.allowsMultipleSelection = false
        do { panel.directoryURL = try ExchangeFolder.prepare(storage: storage) }
        catch { status = error.localizedDescription; return }
        guard panel.runModal() == .OK, let file = panel.url else { return }
        transferring = true; model.setGraphicsLabBusy(true)
        status = L10n.text("Datei wird zu Android kopiert …")
        let remote = ExchangeFolder.androidDirectory + "/" + UUID().uuidString
        transferTask = Task {
            defer { transferring = false; transferTask = nil; if model.activeGuest == "android" { model.setGraphicsLabBusy(false) } }
            do {
                try await run(adb: adb, port: port, storage: storage, arguments: ["shell", "mkdir", "-p", remote])
                try await run(adb: adb, port: port, storage: storage, arguments: ["push", file.path, remote + "/"])
                status = L10n.text("Datei kopiert: Android → Downloads → Stratovo-Austausch. Jede Übertragung erhält einen eigenen Unterordner.")
            } catch { status = error.localizedDescription }
        }
    }

    func receiveAndroid(model: AppModel) {
        guard !transferring, !model.busy, model.running, model.activeGuest == "android", model.androidBooted,
              let adb = model.adb, let port = model.androidExchangePort, let storage = model.storage else { return }
        transferring = true; model.setGraphicsLabBusy(true)
        status = L10n.text("Android-Dateien werden abgeholt …")
        transferTask = Task {
            defer { transferring = false; transferTask = nil; if model.activeGuest == "android" { model.setGraphicsLabBusy(false) } }
            do {
                let target = try ExchangeFolder.newAndroidImport(storage: storage)
                try await run(adb: adb, port: port, storage: storage,
                              arguments: ["shell", "mkdir", "-p", ExchangeFolder.androidDirectory])
                try await run(adb: adb, port: port, storage: storage,
                              arguments: ["pull", ExchangeFolder.androidDirectory, target.path])
                status = L10n.text("Android-Dateien in einen neuen Importordner kopiert. Vorhandene Dateien bleiben erhalten.")
                NSWorkspace.shared.open(target)
            } catch { status = error.localizedDescription }
        }
    }
}

@MainActor
struct ExchangeFolderView: View {
    @ObservedObject var model: AppModel
    @ObservedObject var controller: ExchangeController
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            macSteps
            sharingSteps
            windowsSteps
            ubuntuSteps
            androidSteps
            if controller.transferring { ProgressView() }
            Text(controller.status).textSelection(.enabled)
        }
    }
    private var macSteps: some View {
        GroupBox(L10n.text("Mac · Austauschordner öffnen")) {
            VStack(alignment: .leading, spacing: 12) {
                step(1, "Links in Stratovo Dateiaustausch wählen. Alle folgenden Schritte stehen hier dauerhaft zum Nachlesen.")
                step(2, "Austausch im Finder öffnen anklicken. Der Ordner wird bei Bedarf auf deinem gewählten Datenlaufwerk angelegt.")
                Text(model.storage?.url.appendingPathComponent("Austausch").path ?? L10n.text("Zuerst einen Datenordner wählen"))
                    .font(.body.monospaced()).textSelection(.enabled)
                Button(L10n.text("Austausch im Finder öffnen")) { controller.openFinder(model: model) }
                    .buttonStyle(.borderedProminent).disabled(!model.storageReady)
                step(3, "Dateien hineinlegen oder herauskopieren. Windows und Ubuntu greifen nach der Freigabe direkt darauf zu. Android verwendet die Senden-/Abholen-Schritte weiter unten.")
            }.padding(14).frame(maxWidth: .infinity, alignment: .leading)
        }
    }
    private var sharingSteps: some View {
        GroupBox(L10n.text("Einmalig auf dem Mac · Freigabe für Windows und Ubuntu")) {
            VStack(alignment: .leading, spacing: 12) {
                step(1, "macOS-Freigabeeinstellungen öffnen anklicken. Du findest sie auch unter Systemeinstellungen → Allgemein → Teilen.")
                Button(L10n.text("macOS-Freigabeeinstellungen öffnen"), action: controller.openSharingSettings)
                step(2, "Dateifreigabe einschalten und deren Informationen beziehungsweise Einstellungen öffnen.")
                step(3, "Unter Geteilte Ordner mit + genau den oben angezeigten Ordner Austausch hinzufügen. Der Freigabename muss Austausch lauten.")
                step(4, "Deinem Mac-Benutzer für diesen Ordner Lesen & Schreiben erlauben. Nicht die VM-Festplatten oder den ganzen Datenordner freigeben.")
                step(5, "Unter Optionen Dateien und Ordner über SMB teilen aktivieren und deinen Mac-Benutzer für SMB auswählen. Die Freigabe mit deinem Mac-Anmeldepasswort bestätigen.")
                Text(L10n.text("Freigaben können im lokalen Netzwerk erreichbar sein. Die App aktiviert keine Freigabe automatisch und speichert kein Mac-Passwort."))
                    .font(.callout).foregroundStyle(.secondary)
                Link(L10n.text("Apple-Anleitung zur Dateifreigabe"), destination: URL(string: "https://support.apple.com/guide/mac-help/mchlp1657/mac")!)
            }.padding(14).frame(maxWidth: .infinity, alignment: .leading)
        }
    }
    private var windowsSteps: some View {
        GroupBox(L10n.text("Windows Arm · Austauschordner öffnen")) {
            VStack(alignment: .leading, spacing: 12) {
                step(1, "Die Mac-Freigabe wie oben einrichten. In Stratovo das Windows-Netzwerk einschalten und Windows Arm starten.")
                step(2, "Ordner in Windows öffnen anklicken. Alternativ die Windows-Adresse kopieren und im Windows-Explorer oben in die Adressleiste einfügen, dann Enter drücken.")
                Text(ExchangeFolder.windowsAddress).font(.body.monospaced()).textSelection(.enabled)
                HStack {
                    Button(L10n.text("Windows-Adresse kopieren")) { controller.copy(ExchangeFolder.windowsAddress) }
                    Button(L10n.text("Ordner in Windows öffnen"), action: model.openWindowsExchangeFolder)
                        .disabled(!model.running || model.activeGuest != "windows" || !model.settings.windowsNetwork || model.windowsPasteBusy)
                }
                step(3, "Bei der Anmeldung deinen für SMB freigegebenen Mac-Benutzernamen und dein Mac-Anmeldepasswort verwenden. Dein Windows- oder Microsoft-Konto ist dafür nicht nötig.")
                step(4, "Dateien per Kopieren, Einfügen oder Ziehen austauschen. Für ein dauerhaftes Laufwerk: Dieser PC → Netzlaufwerk verbinden und dieselbe Adresse verwenden.")
            }.padding(14).frame(maxWidth: .infinity, alignment: .leading)
        }
    }
    private var ubuntuSteps: some View {
        GroupBox(L10n.text("Ubuntu · Austauschordner öffnen")) {
            VStack(alignment: .leading, spacing: 12) {
                step(1, "Die Mac-Freigabe wie oben einrichten und Ubuntu mit eingeschaltetem Netzwerk starten.")
                step(2, "In Ubuntu Dateien öffnen und Andere Orte wählen. Unter Mit Server verbinden die folgende Adresse einfügen.")
                Text(ExchangeFolder.smbAddress).font(.body.monospaced()).textSelection(.enabled)
                Button(L10n.text("Ubuntu-Adresse kopieren")) { controller.copy(ExchangeFolder.smbAddress) }
                step(3, "Verbinden wählen und als registrierter Benutzer mit deinem freigegebenen Mac-Benutzernamen und Mac-Anmeldepasswort anmelden.")
                step(4, "Der Ordner erscheint in Dateien. Dateien hinein- oder herauskopieren; bei Bedarf als Lesezeichen speichern.")
            }.padding(14).frame(maxWidth: .infinity, alignment: .leading)
        }
    }
    private var androidSteps: some View {
        GroupBox(L10n.text("Android · Dateien senden und abholen")) {
            VStack(alignment: .leading, spacing: 12) {
                Text(L10n.text("Vom Mac zu Android")).font(.headline)
                step(1, "Android in Stratovo starten und warten, bis der Start abgeschlossen ist. Für diese Übertragung ist keine SMB-Freigabe erforderlich.")
                step(2, "Datei zu Android senden anklicken und eine Datei auf dem Mac auswählen.")
                Button(L10n.text("Datei zu Android senden")) { controller.sendAndroid(model: model) }
                    .disabled(controller.transferring || !model.canInstallAPK)
                step(3, "In Android die Dateien-App öffnen: Downloads → Stratovo-Austausch. Jede gesendete Datei liegt in einem neuen Unterordner.")
                Divider()
                Text(L10n.text("Von Android zum Mac")).font(.headline)
                step(1, "In Android die gewünschten Dateien nach Downloads → Stratovo-Austausch kopieren oder verschieben.")
                step(2, "In Stratovo Android-Dateien abholen anklicken. Der gesamte Inhalt dieses Android-Ordners wird zum Mac kopiert.")
                Button(L10n.text("Android-Dateien abholen")) { controller.receiveAndroid(model: model) }
                    .disabled(controller.transferring || !model.canInstallAPK)
                step(3, "Der Finder öffnet einen neuen Importordner unter Austausch → Android. Frühere Importe und Dateien bleiben erhalten.")
                Text(L10n.text("Android-Übertragungen erstellen Kopien. Es gibt keinen automatischen Abgleich und keine automatische Löschung. Für direkten SMB-Zugriff kann zusätzlich ein Android-Dateimanager mit SMB-Unterstützung verwendet werden."))
                    .font(.callout).foregroundStyle(.secondary)
            }.padding(14).frame(maxWidth: .infinity, alignment: .leading)
        }
    }
    private func step(_ number: Int, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(String(number)).font(.headline).frame(width: 28, height: 28)
                .background(Color.teal.opacity(0.16), in: Circle())
            Text(L10n.text(text)).fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
