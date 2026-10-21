import SwiftUI
import StratovoCore

@MainActor
struct WindowsWorkspaceView: View {
    @ObservedObject var model: AppModel
    @State private var showInstallation = false
    @State private var showGraphics = false
    @State private var showIdentityChange = false
    @State private var showIdentityRestore = false
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            WorkspaceCard {
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        Label("Windows 11 Arm64", systemImage: "desktopcomputer").font(.title2.bold())
                        Text(model.windowsDiskBytes == nil ? L10n.text("Einrichtung nötig") : L10n.text("Deine vorhandene Installation mit 3D über Metal."))
                            .font(.callout).foregroundStyle(.secondary)
                    }
                    Spacer()
                    if model.running && model.activeGuest == "windows" {
                        Button(L10n.text("Player öffnen")) { model.showPlayer(kind: "windows") }
                            .buttonStyle(.borderedProminent).controlSize(.large)
                    } else if !model.graphicsLab.runtimeReady {
                        Button(L10n.text("Windows vorbereiten")) { showGraphics = true }
                            .buttonStyle(.borderedProminent).controlSize(.large)
                            .disabled(model.running || model.busy || !model.storageReady)
                    } else {
                        Button(L10n.text("Windows starten"), action: model.startExistingWindows)
                            .buttonStyle(.borderedProminent).controlSize(.large)
                            .disabled(!model.canResumeWindows || !model.graphicsLab.runtimeReady)
                    }
                }
                if model.windowsDiskBytes == nil {
                    Button(L10n.text("Windows einrichten")) { showInstallation = true; model.settings.installWindows = true }
                        .disabled(model.running || model.busy || !model.storageReady)
                }
            }
            DisclosureGroup(L10n.text("Erweiterte Einstellungen: Grafik und Leistung"), isExpanded: $showGraphics) {
                WindowsGraphicsLabView(model: model, lab: model.graphicsLab).padding(.top, 8)
            }
            DisclosureGroup(L10n.text("Speicher und virtuelle Festplatte")) {
                WorkspaceCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Label(L10n.text("Windows-Speicherort"), systemImage: "externaldrive.fill").font(.headline)
                        Text(model.storage?.windows.path ?? L10n.text("Zuerst unter Einrichtung einen Datenordner wählen"))
                            .font(.body.monospaced()).textSelection(.enabled)
                        Text(model.windowsFolderStatus).font(.subheadline)
                        HStack {
                            Button(L10n.text("Windows-Ordner anlegen / prüfen"), action: model.prepareWindowsFolder)
                                .disabled(model.busy || model.running || !model.storageReady)
                            Button(L10n.text("Ordner öffnen"), action: model.revealWindowsFolder)
                                .disabled(model.storage?.windowsFolderReady != true)
                        }
                        ContextHelpButton("Details und Anleitung") {
                            Text(L10n.text("Windows-Festplatte, Einstellungen und TPM bleiben in diesem Ordner gespeichert. Beim ersten Start installierst du Windows aus deiner ARM64-ISO."))
                                .font(.subheadline).foregroundStyle(.secondary)
                        }
                        Divider()
                        HStack {
                            Text(L10n.text("Maximale Windows-Festplatte"))
                            TextField("GB", text: $model.windowsDiskSize)
                                .textFieldStyle(.roundedBorder).frame(width: 100)
                                .disabled(model.busy || model.running)
                            Text("GB")
                            Spacer(minLength: 0)
                            Button(L10n.text("Größe anwenden")) { Task { await model.applyWindowsDiskSize() } }
                                .disabled(model.busy || model.running || !model.storageReady || model.qemuImg == nil || model.windowsCapacityIssue != nil)
                        }
                        Text(model.windowsDiskStatus).font(.subheadline).textSelection(.enabled)
                        if let issue = model.windowsCapacityIssue { Text(issue).font(.subheadline).foregroundStyle(.orange) }
                        ContextHelpButton("Virtuelle Festplatte") {
                            Text(L10n.text("64–4096 GB frei eingeben. Die Datei wächst mit deinen Daten; die maximale Größe wird nicht sofort auf der SSD belegt. Änderungen werden über „Größe anwenden“ oder beim nächsten Windows-Start übernommen. Vergrößern ist bei ausgeschaltetem Windows möglich; vorhandene Festplatten werden nicht verkleinert. Zusätzlichen Speicher anschließend in Windows zuordnen."))
                                .font(.subheadline).foregroundStyle(.secondary)
                        }
                        DisclosureGroup(L10n.text("Zusätzlichen Speicher in Windows zuordnen")) {
                            VStack(alignment: .leading, spacing: 8) {
                                ContextHelpButton("Details und Anleitung") {
                                    Text(L10n.text("„Größe anwenden“ prüft die Kapazität der virtuellen Festplatte. Die Größe des Windows-Laufwerks C: wird dadurch noch nicht geändert."))
                                }
                                ContextHelpButton("Details und Anleitung") {
                                    Text(L10n.text("1. Windows starten. 2. Win + R drücken und diskmgmt.msc öffnen. 3. Unten den Datenträger mit C: und den nicht zugeordneten Platz prüfen."))
                                }
                                Text(L10n.text("Nur wenn der freie Platz direkt rechts neben C: liegt: Rechtsklick auf C: → Volume erweitern. Ist die Option ausgegraut oder liegt eine Wiederherstellungspartition dazwischen, zuerst die Aufteilung prüfen lassen. Keine Partition löschen oder formatieren."))
                                Text("diskmgmt.msc").font(.system(.body, design: .monospaced)).textSelection(.enabled)
                            }.font(.callout).padding(.top, 6)
                        }
                        DisclosureGroup(L10n.text("Voraussetzungen und Entwicklungsstand")) {
                            ContextHelpButton("Details und Anleitung") {
                                Text(L10n.text("Windows verwendet die 3D-Laufzeit auf deiner bestehenden Festplatte. Die Grafiktreiber werden in Windows installiert; Metal und die Mac-Laufzeit werden wiederverwendet."))
                                    .font(.subheadline).foregroundStyle(.secondary).padding(.top, 6)
                            }
                        }
                    }
                }
            }
            DisclosureGroup(L10n.text("Installation und virtuelle Hardware"), isExpanded: $showInstallation) {
                WorkspaceCard {
                    VStack(alignment: .leading, spacing: 18) {
                        HStack {
                            Image(systemName: "desktopcomputer").font(.system(size: 32)).foregroundStyle(.blue)
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Windows 11 Pro Arm64").font(.title2.bold())
                                Text(L10n.text("QEMU · HVF · 3D über Metal")).foregroundStyle(.secondary)
                            }
                            Spacer()
                            WorkspaceStatusBadge(model.windowsReady && model.firmware != nil ? L10n.text("Engine bereit") : L10n.text("Einrichtung nötig"), ready: model.windowsReady && model.firmware != nil)
                        }
                        Divider()
                        GuestResourceControls(model: model)
                        Toggle(L10n.text("Nächster Start: Windows von DVD einrichten"), isOn: $model.settings.installWindows)
                            .disabled(model.running || model.busy)
                        ContextHelpButton("Installations-DVD") {
                            Text(L10n.text("Der DVD-Start gilt einmalig. Danach startet die VM von ihrer gespeicherten Festplatte; die ISO-Auswahl bleibt erhalten. Für einen weiteren DVD-Start diese Option erneut einschalten."))
                                .font(.body).foregroundStyle(.secondary)
                        }
                        windowsDVDControls
                        VStack(alignment: .leading, spacing: 10) {
                            Text(L10n.text("Windows-Grafik und Auflösung")).font(.headline)
                            Text(L10n.text("VirtIO / Neptune / DXMT → Metal. Auflösung und Skalierung stellst du unter Windows → System → Anzeige ein."))
                                .font(.subheadline)
                            Button(L10n.text("Treiber-CD in Windows suchen"), action: model.openWindowsDriverDisc)
                                .disabled(model.activeGuest != "windows" || !model.running || model.windowsPasteBusy)
                        }
                        WorkspaceFileRow(title: "ARM64-Treiber-ISO (empfohlen)", value: model.settings.driversISO.isEmpty ? L10n.text("Windows-Gastwerkzeuge / VirtIO-Netzwerktreiber") : model.settings.driversISO) {
                            if let file = model.chooseFile(title: L10n.text("ARM64-Windows-Gasttreiber-ISO auswählen")) { model.settings.driversISO = file }
                        }.disabled(model.running || model.busy)
                        if !model.settings.driversISO.isEmpty {
                            Button(L10n.text("Treiber-ISO aus Auswahl entfernen")) { model.settings.driversISO = "" }
                                .font(.caption).disabled(model.running || model.busy)
                        }
                        if model.settings.driversISO == model.settings.iso && !model.settings.iso.isEmpty {
                            Text(L10n.text("Hier ist dieselbe ISO zweimal ausgewählt. Eine Windows-ISO ist keine Treiber-ISO.")).font(.caption).foregroundStyle(.orange)
                        }
                        Toggle(L10n.text("Windows 11 Pro vorauswählen"), isOn: $model.settings.selectPro)
                            .disabled(model.running || model.busy || !model.settings.installWindows)
                        Toggle(L10n.text("Lokales Windows-Konto · ohne Microsoft-Anmeldung"), isOn: $model.settings.localWindowsAccount)
                            .disabled(model.running || model.busy || !model.settings.installWindows)
                        if model.settings.installWindows && model.settings.localWindowsAccount {
                            VStack(alignment: .leading, spacing: 10) {
                                TextField("Lokaler Benutzername", text: $model.settings.localWindowsUser)
                                SecureField("Passwort (mindestens 8 Zeichen)", text: $model.localPassword)
                                SecureField(L10n.text("Passwort wiederholen"), text: $model.localPasswordConfirmation)
                                Text(L10n.message("Passwort: \(model.localPassword.count) Zeichen · Wiederholung: \(model.localPasswordConfirmation.count) Zeichen"))
                                    .font(.subheadline.monospacedDigit())
                                Label(model.localAccountIssue ?? L10n.text("Kontodaten gültig · Passwörter stimmen überein"),
                                      systemImage: model.localAccountIssue == nil ? "checkmark.circle.fill" : "info.circle.fill")
                                    .foregroundStyle(model.localAccountIssue == nil ? Color.teal : Color.orange)
                                Toggle(L10n.text("Benutzername und Kennwort sicher merken"), isOn: $model.rememberWindowsCredential)
                                HStack {
                                    Button(L10n.text("Im Schlüsselbund speichern")) { Task { await model.saveWindowsCredential() } }
                                        .disabled(model.localAccountIssue != nil)
                                    Button(L10n.text("Aus Schlüsselbund laden")) { Task { await model.loadWindowsCredential() } }
                                }
                                Text(model.credentialStatus).font(.subheadline).textSelection(.enabled)
                                ContextHelpButton("Schlüsselbund und lokale Konten") {
                                    Text(L10n.text("Dieses Windows-Konto entsteht während der Installation. Bei „sicher merken“ speichert Stratovo Benutzername und Kennwort vor dem Start im macOS-Schlüsselbund und stellt sie beim nächsten Öffnen wieder her, soweit macOS den Zugriff bereits erlaubt. Zum Freigeben „Aus Schlüsselbund laden“ wählen und das Kennwort des Mac-Anmeldeschlüsselbunds verwenden. Das Kennwort bleibt auch nach dem Start in diesen Feldern; es steht nicht in Einstellungen oder Protokollen. Dieser App-Eintrag wird in der Schlüsselbundverwaltung verwaltet. Das temporäre Einrichtungsmedium wird nach Ende der Sitzung entfernt."))
                                        .font(.body).foregroundStyle(.secondary)
                                }
                            }.disabled(model.running || model.busy)
                        }
                        Toggle(L10n.text("Windows-Netzwerk / Internet aktivieren"), isOn: $model.settings.windowsNetwork)
                            .disabled(model.running || model.busy)
                        ContextHelpButton("Installations-DVD") {
                            Text(L10n.text("Wähle ausdrücklich Arm64, keine x64-ISO. Die ISO-Architektur wird hier noch nicht automatisch erkannt. Zum Start des Installationsmediums gegebenenfalls im Gastfenster eine Taste drücken."))
                                .font(.body).foregroundStyle(.secondary)
                        }
                        ContextHelpButton("Installations-DVD") {
                            Text(L10n.text("Deine Windows-Lizenz bleibt erforderlich. Für Internet im Gast den ARM64-VirtIO-Netzwerktreiber von der Treiber-ISO laden. Beim lokalen Konto ist keine Microsoft-Anmeldung nötig."))
                                .font(.body).foregroundStyle(.secondary)
                        }
                        Text(model.windowsAcceleration).font(.caption).foregroundStyle(.secondary)
                        if model.settings.memoryGB < 4 { Text(L10n.text("Für den Windows-Boot-Test mindestens 4 GB RAM wählen.")).foregroundStyle(.orange).font(.caption) }
                        HStack {
                            Button(action: model.startWindows) { Label(model.settings.installWindows ? L10n.text("Windows einrichten") : L10n.text("Windows starten"), systemImage: "play.fill") }
                                .buttonStyle(.borderedProminent).controlSize(.large)
                                .disabled(!model.canStartWindows)
                            Button(L10n.text("Vorhandenes Windows starten"), action: model.startExistingWindows)
                                .disabled(!model.canResumeWindows)
                            Spacer()
                            Link("Windows Arm64 ↗", destination: URL(string: "https://www.microsoft.com/de-de/software-download/windows11arm64")!)
                        }
                        Link(L10n.text("ARM64-Windows-Gasttreiber ↗"), destination: URL(string: "https://docs.getutm.app/guest-support/windows/")!)
                        Button(L10n.text("Windows-Dateien im Finder zeigen")) {
                            model.revealWindowsFolder()
                        }.disabled(model.busy)
                    }
                }
                windowsIdentityCard
            }
        }
    }
    private var windowsIdentityCard: some View {
        WorkspaceCard {
            VStack(alignment: .leading, spacing: 12) {
                Label(L10n.text("Windows-Gerätekennung"), systemImage: "cpu").font(.headline).foregroundStyle(.teal)
                Text(model.windowsIdentityStatus).font(.subheadline).textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
                if let identity = model.windowsIdentity, identity.mode == .unique {
                    Text("Seriennummer: \(identity.serial) · Netzwerk-MAC: \(identity.mac ?? "")")
                        .font(.caption.monospaced()).textSelection(.enabled)
                }
                if model.windowsIdentity?.mode == .legacy {
                    Text(L10n.text("Die bisherige Standardkennung wurde von mehreren VMs verwendet. Eine eigene Kennung verhindert diese Überschneidung; eine damit zusammenhängende Firmenzuordnung ist noch im Gast zu prüfen."))
                        .font(.caption).foregroundStyle(.orange).fixedSize(horizontal: false, vertical: true)
                    Button(L10n.text("Eigene Gerätekennung einrichten …")) { showIdentityChange = true }
                        .buttonStyle(.borderedProminent).disabled(model.running || model.busy || !model.storageReady)
                }
                if model.windowsIdentityCanRestore {
                    Button(L10n.text("Ursprüngliche Kennung wiederherstellen …")) { showIdentityRestore = true }
                        .disabled(model.running || model.busy || !model.storageReady)
                }
                ContextHelpButton("Windows-Gerätekennung") {
                    Text(L10n.text("UUID, Seriennummer und MAC bleiben bei Neustarts gleich und liegen im Windows-Ordner auf deinem gewählten Datenträger. Ein schon in Windows gespeichertes Autopilot-Firmenprofil wird durch die Kennung allein nicht entfernt."))
                        .font(.body).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .confirmationDialog(L10n.text("Eigene Windows-Gerätekennung einrichten?"), isPresented: $showIdentityChange) {
            Button(L10n.text("Eigene Kennung übernehmen")) { Task { await model.changeWindowsIdentity() } }
            Button(L10n.text("Abbrechen"), role: .cancel) { }
        } message: {
            ContextHelpButton("Windows-Gerätekennung") {
                Text(L10n.text("Die bisherige Kennung wird im gewählten Windows-Ordner gesichert. Die VM erhält eine eigene UUID, Seriennummer und MAC. Windows-Festplatte, UEFI-Dateien und TPM werden nicht geändert. Windows kann eine erneute Aktivierung oder bei Verschlüsselung den BitLocker-Wiederherstellungsschlüssel verlangen. Danach ist der Start vom vorhandenen Windows ausgewählt."))
            }
        }
        .confirmationDialog(L10n.text("Ursprüngliche Gerätekennung wiederherstellen?"), isPresented: $showIdentityRestore) {
            Button(L10n.text("Kennung wiederherstellen")) { Task { await model.changeWindowsIdentity(restore: true) } }
            Button(L10n.text("Abbrechen"), role: .cancel) { }
        } message: {
            ContextHelpButton("Details und Anleitung") {
                Text(L10n.text("Die ursprünglichen virtuellen Gerätekennungen werden aus der gespeicherten Sicherung übernommen. Die Festplatte wird nicht zurückgesetzt. Auch bei dieser Hardwareänderung kann Windows eine Aktivierung oder einen BitLocker-Schlüssel verlangen."))
            }
        }
    }
    private var windowsDVDControls: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 10) {
                Label(L10n.text("Installations-DVD · Windows ARM64"), systemImage: "opticaldiscdrive")
                    .font(.headline)
                Text(model.settings.iso.isEmpty ? L10n.text("Keine ISO ausgewählt") : model.settings.iso)
                    .font(.system(size: 12, design: .monospaced)).textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
                Label(model.windowsISODetail, systemImage: model.windowsISOReady ? "checkmark.circle" : "exclamationmark.triangle")
                    .font(.subheadline).foregroundStyle(model.windowsISOReady ? Color.teal : Color.orange)
                Text(model.settings.installWindows
                     ? L10n.text("Diese ISO wird beim nächsten Einrichtungsstart als DVD verbunden.")
                     : L10n.text("DVD ist nicht zum Start ausgewählt. Die VM startet von ihrer gespeicherten Festplatte."))
                    .font(.caption).foregroundStyle(.secondary)
                HStack {
                    Button(L10n.text("DVD-ISO manuell auswählen …"), action: model.chooseWindowsISO)
                        .buttonStyle(.borderedProminent)
                    Button(L10n.text("Auswahl entfernen")) { model.settings.iso = ""; model.refreshWindowsISO() }
                        .disabled(model.settings.iso.isEmpty)
                }.disabled(model.running || model.busy)
                ContextHelpButton("Details und Anleitung") {
                    Text(L10n.text("Eine vorhandene ISO auf Extern auswählen. Der Pfad wird gespeichert. Geprüft werden Dateiverfügbarkeit und Größe; ARM64-Inhalt und Bootfähigkeit sind damit noch nicht bestätigt. Zum Ändern Windows ausschalten."))
                        .font(.body).foregroundStyle(.secondary)
                }
                Text(model.windowsBootMediaStatus).font(.caption).textSelection(.enabled)
                Divider()
                HStack {
                    Button(L10n.text("ISO mit Microsoft-Prüfsumme vergleichen")) { Task { await model.verifyWindowsISO() } }
                        .disabled(model.running || model.busy || !model.windowsISOReady || !model.storageReady)
                    Link(L10n.text("Microsoft-Prüfwerte ↗"), destination: URL(string: WindowsISOHash.source)!)
                }
                Text(model.windowsISOHashStatus).font(.caption).fixedSize(horizontal: false, vertical: true)
                if !model.windowsISOHashDigest.isEmpty {
                    Text("SHA-256: " + model.windowsISOHashDigest).font(.caption.monospaced()).textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                }
                ContextHelpButton("ISO-Prüfsumme") {
                    Text(L10n.text("Verglichen wird die deutsche ARM64-ISO von Windows 11 26H2. Andere Versionen oder Sprachen brauchen ihren eigenen offiziellen Prüfwert. Es wird nichts neu heruntergeladen."))
                        .font(.body).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
            }.frame(maxWidth: .infinity, alignment: .leading).padding(6)
        }
    }
}
