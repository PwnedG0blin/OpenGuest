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
            GroupBox {
                VStack(alignment: .leading, spacing: 14) {
                    Label(L10n.text("Ein Austauschordner für deine Systeme"), systemImage: "folder.badge.plus")
                        .font(.title2.bold())
                    Text(model.storage?.url.appendingPathComponent("Austausch").path ?? L10n.text("Zuerst einen Datenordner wählen"))
                        .font(.body.monospaced()).textSelection(.enabled)
                    Text(L10n.text("Der Ordner liegt neben Android, Windows und Ubuntu auf deinem gewählten Datenträger. Deine VM-Festplatten werden nicht als Austauschordner freigegeben."))
                    Button(L10n.text("Austausch im Finder öffnen")) { controller.openFinder(model: model) }
                        .buttonStyle(.borderedProminent).disabled(!model.storageReady)
                }.padding(14).frame(maxWidth: .infinity, alignment: .leading)
            }
            GroupBox(L10n.text("Windows und Ubuntu · gemeinsamer Ordner über SMB")) {
                VStack(alignment: .leading, spacing: 12) {
                    Text(L10n.text("Einmalig auf dem Mac: Systemeinstellungen → Allgemein → Teilen → Dateifreigabe. Nur den Ordner Austausch hinzufügen und deinem Mac-Benutzer Lesen & Schreiben erlauben. Unter Optionen SMB und den gewünschten Benutzer aktivieren."))
                    Text(L10n.text("Freigaben können im lokalen Netzwerk erreichbar sein. Die App aktiviert keine Freigabe automatisch und speichert kein Mac-Passwort."))
                        .font(.callout).foregroundStyle(.secondary)
                    Button(L10n.text("macOS-Freigabeeinstellungen öffnen"), action: controller.openSharingSettings)
                    Text(ExchangeFolder.windowsAddress).font(.body.monospaced()).textSelection(.enabled)
                    HStack {
                        Button(L10n.text("Windows-Adresse kopieren")) { controller.copy(ExchangeFolder.windowsAddress) }
                        Button(L10n.text("Ordner in Windows öffnen"), action: model.openWindowsExchangeFolder)
                            .disabled(!model.running || model.activeGuest != "windows" || !model.settings.windowsNetwork || model.windowsPasteBusy)
                    }
                    Text(L10n.text("Windows: mit deinem freigegebenen Mac-Benutzer anmelden. Unter Dieser PC → Netzlaufwerk verbinden kannst du den Ordner dauerhaft als Laufwerk einbinden."))
                    Text(ExchangeFolder.smbAddress).font(.body.monospaced()).textSelection(.enabled)
                    Button(L10n.text("Ubuntu-Adresse kopieren")) { controller.copy(ExchangeFolder.smbAddress) }
                    Text(L10n.text("Ubuntu: Dateien → Andere Orte → Mit Server verbinden. Die SMB-Adresse einfügen und mit deinem Mac-Benutzer anmelden. Die VM-Netzwerkverbindung muss eingeschaltet sein."))
                    Link(L10n.text("Apple-Anleitung zur Dateifreigabe"), destination: URL(string: "https://support.apple.com/guide/mac-help/mchlp1657/mac")!)
                }.padding(14).frame(maxWidth: .infinity, alignment: .leading)
            }
            GroupBox(L10n.text("Android · Dateien senden und abholen")) {
                VStack(alignment: .leading, spacing: 12) {
                    Text(L10n.text("Ohne zusätzliche Android-App: Dateien landen unter Downloads/Stratovo-Austausch. Zum Abholen dort Dateien ablegen. Übertragungen kopieren ausdrücklich ausgewählte Dateien; es gibt keinen automatischen Löschabgleich."))
                    HStack {
                        Button(L10n.text("Datei zu Android senden")) { controller.sendAndroid(model: model) }
                        Button(L10n.text("Android-Dateien abholen")) { controller.receiveAndroid(model: model) }
                    }.disabled(controller.transferring || !model.canInstallAPK)
                    Text(L10n.text("Abgeholte Dateien liegen in Austausch/Android in einem neuen Importordner. Für direkten SMB-Zugriff kann zusätzlich ein Android-Dateimanager mit SMB-Unterstützung verwendet werden."))
                }.padding(14).frame(maxWidth: .infinity, alignment: .leading)
            }
            if controller.transferring { ProgressView() }
            Text(controller.status).textSelection(.enabled)
        }
    }
}
