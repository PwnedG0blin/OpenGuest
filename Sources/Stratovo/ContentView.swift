import SwiftUI
import StratovoCore

enum WorkspaceTab: String, CaseIterable, Identifiable {
    case dashboard = "Dashboard"
    case updates = "Updates"
    case android = "Android"
    case windows = "Windows"
    case ubuntu = "Ubuntu ARM"
    case setup = "Einrichtung"
    var id: String { rawValue }
    var title: String { L10n.text(rawValue) }
    var icon: String {
        switch self {
        case .dashboard: return "house.fill"
        case .updates: return "arrow.triangle.2.circlepath"
        case .android: return "apps.iphone"
        case .windows: return "desktopcomputer"
        case .ubuntu: return "terminal"
        case .setup: return "slider.horizontal.3"
        }
    }
}

@MainActor
struct ContentView: View {
    @ObservedObject var model: AppModel
    @State private var selection: WorkspaceTab = .dashboard
    @State private var showStopConfirmation = false
    @State private var showIdentityChange = false
    @State private var showIdentityRestore = false

    var body: some View {
        HStack(spacing: 0) {
            sidebar.frame(width: 214)
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    header
                    if !model.supportedHost || !model.hypervisorAvailable {
                        notice(L10n.text("Apple Silicon und Hardwarevirtualisierung benötigt"),
                               L10n.text("Starte die native ARM64-Version auf einem Mac mit M-Chip. Intel-Macs und Rosetta werden nicht unterstützt."), color: .orange)
                    }
                    if !model.storageReady && model.storage != nil {
                        notice(L10n.text("Datenordner nicht erreichbar"), L10n.text("Bitte die gewählte SSD anschließen. Android, Windows und Downloads bleiben bis dahin gesperrt."), color: .orange)
                    }
                    switch selection {
                    case .dashboard: DashboardView(model: model) { selection = $0 }
                    case .updates: GitHubUpdatesView(model: model)
                    case .android: android
                    case .windows: windows
                    case .ubuntu: UbuntuView(model: model, controller: model.ubuntu)
                    case .setup: setup
                    }
                    logPanel
                }
                .padding(30)
            }
            .background(Color(nsColor: .windowBackgroundColor))
        }
        .frame(minWidth: 900, minHeight: 680)
        .tint(.teal)
        .onChange(of: model.settings.iso) { _, _ in model.refreshWindowsISO() }
        .sheet(isPresented: $model.showStorageSetup) { storageSetup.interactiveDismissDisabled() }
        .alert("Stratovo", isPresented: Binding(get: { model.errorMessage != nil }, set: { if !$0 { model.errorMessage = nil } })) {
            Button("OK") { model.errorMessage = nil }
        } message: { Text(model.errorMessage ?? "") }
        .confirmationDialog(L10n.text("Gastprozess beenden?"), isPresented: $showStopConfirmation) {
            Button(L10n.text("Prozess beenden"), role: .destructive) { model.terminateGuest() }
            Button(L10n.text("Abbrechen"), role: .cancel) { }
        } message: {
            Text(L10n.text("Fahre Android oder Windows möglichst zuerst im Gastfenster herunter. Das Beenden des Prozesses kann nicht gespeicherte Änderungen verlieren oder das Gastdateisystem beschädigen."))
        }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 26) {
            HStack(spacing: 10) {
                Image(systemName: "square.stack.3d.up.fill").font(.title).foregroundStyle(.teal)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Stratovo").font(.headline)
                    Text("1.0 BETA 2").font(.system(size: 9, weight: .semibold, design: .monospaced)).foregroundStyle(.secondary)
                }
            }
            ForEach(WorkspaceTab.allCases) { tab in
                Button { selection = tab } label: {
                    Label(tab.title, systemImage: tab.icon)
                        .font(.system(size: 14, weight: .medium))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(11)
                        .background(selection == tab ? Color.teal.opacity(0.14) : Color.clear, in: RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
            }
            Spacer()
            DeveloperCredits()
        }
        .padding(20)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 5) {
                Text(selection.title).font(.system(size: 30, weight: .bold))
                Text(selection == .dashboard ? L10n.text("Deine Systeme. Dein Speicherort.") : selection == .android ? "Dein virtuelles Android auf dem Mac." : selection == .windows ? "Der erste Schritt zu Windows auf deinem Mac." : "Verbinde die lokalen Virtualisierungs-Engines.")
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if model.busy { ProgressView().controlSize(.small) }
            Button { Task { await model.refresh() } } label: { Label(L10n.text("System prüfen"), systemImage: "arrow.clockwise") }
                .disabled(model.busy || model.running)
        }
    }

    private var android: some View {
        VStack(alignment: .leading, spacing: 18) {
            AndroidVersionsView(model: model, installer: model.installer)
            playerPane(kind: "android", title: "Android Player")
            card {
                VStack(alignment: .leading, spacing: 18) {
                    HStack {
                        Image(systemName: "apps.iphone").font(.system(size: 32)).foregroundStyle(.teal)
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Android ARM64").font(.title2.bold())
                            Text("Android Emulator · Hypervisor.framework").foregroundStyle(.secondary)
                        }
                        Spacer()
                        status(model.androidReady ? L10n.text("Engine bereit") : L10n.text("Einrichtung nötig"), ready: model.androidReady)
                    }
                    Divider()
                    if model.devices.isEmpty {
                        Text(L10n.text("Noch kein Android eingerichtet. Wähle oben Android 16 oder Android 17 und klicke auf „Laden und installieren …“."))
                            .foregroundStyle(.secondary)
                    } else {
                        Picker(L10n.text("Virtuelles Gerät"), selection: $model.settings.selectedAVD) {
                            ForEach(model.devices) { device in
                            Text("\(model.androidSystem(for: device.name).map { "Android \($0.rawValue) · " } ?? "")\(device.name) · \(device.abi)\(device.googlePlay ? " · Google Play" : "")").tag(device.name)
                            }
                        }
                        .disabled(model.running || model.busy)
                        if let device = model.selectedDevice, !device.supported {
                            Text(L10n.text("Dieses Gerät ist kein erkanntes ARM64-Gerät und wird in diesem Prototyp nicht gestartet."))
                                .font(.caption).foregroundStyle(.orange)
                        }
                    }
                    resourceControls
                    Picker(L10n.text("Grafik"), selection: $model.settings.gpu) {
                        Text(L10n.text("Automatisch")).tag("auto")
                        Text(L10n.text("Mac-GPU bevorzugen")).tag("host")
                        Text(L10n.text("Software (Fehlersuche)")).tag("software")
                    }.disabled(model.running || model.busy)
                    Toggle(L10n.text("Vulkan für Android-Spiele zulassen"), isOn: $model.androidVulkanEnabled)
                        .disabled(model.running || model.busy)
                    Text(L10n.text("Mac-GPU nutzt die Grafikübersetzung des Android Emulators. Vulkan aus: OpenGL-ES-Kompatibilitätstest für Spiele ohne Vulkan-Pflicht. Ein Wechsel gilt beim nächsten Start und kann je nach Spiel helfen oder die Kompatibilität einschränken."))
                        .font(.caption).foregroundStyle(.secondary)
                    Picker(L10n.text("Android-Leistungsprofil"), selection: $model.androidProfile) {
                        ForEach(AndroidPerformance.allCases, id: \.rawValue) { profile in
                            Text(profile.title).tag(profile)
                        }
                    }.disabled(model.running || model.busy)
                    AndroidFrameRateControls(model: model)
                    Text(L10n.text("Flüssig reduziert die Android-Auflösung und Streamgröße. Änderungen gelten beim nächsten Android-Start. Originalauflösung hebt die Bildschirm-Anpassung wieder auf."))
                        .font(.caption).foregroundStyle(.secondary)
                    Text(model.androidDisplayStatus).font(.caption).textSelection(.enabled)
                    DisclosureGroup(L10n.text("Auflösung und Android-Skalierung")) {
                        AndroidDisplayControls(model: model).padding(.top, 8)
                    }
                    Label(model.androidRendererStatus, systemImage: model.androidSoftwareRendering ? "exclamationmark.triangle" : "info.circle")
                        .font(.caption).foregroundStyle(model.androidSoftwareRendering ? Color.orange : Color.secondary)
                    Toggle(L10n.text("Kaltstart beim nächsten Start"), isOn: $model.settings.coldBoot)
                        .disabled(model.running || model.busy)
                    Button(L10n.text("Android-Verbindung reparieren")) { Task { await model.repairAndroidConnection() } }
                        .disabled(!model.canRepairAndroidConnection)
                    Text(L10n.text("Bei „device offline“: Gastsystem herunterfahren, dann hier ADB neu starten und Kaltstart aktivieren. Apps, Konten und Spielstände bleiben erhalten. Der ADB-Neustart trennt auch andere ADB-Debugverbindungen auf diesem Mac."))
                        .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    if !model.androidRepairStatus.isEmpty { Text(model.androidRepairStatus).font(.caption).textSelection(.enabled) }
                    if let device = model.selectedDevice {
                        Label(device.googlePlay ? "Google-Play-Systemabbild im Profil erkannt" : L10n.text("Dieses Profil enthält keinen erkannten Google Play Store"),
                              systemImage: device.googlePlay ? "checkmark.seal" : "info.circle")
                            .font(.caption).foregroundStyle(device.googlePlay ? Color.teal : Color.orange)
                    }
                    Text(model.androidAcceleration).font(.caption).foregroundStyle(.secondary)
                    HStack {
                        Button(action: model.startAndroid) { Label(L10n.text("Android starten"), systemImage: "play.fill") }
                            .buttonStyle(.borderedProminent).controlSize(.large)
                            .disabled(!model.canStartAndroid)
                        Spacer()
                        Link(L10n.text("Gerät anlegen ↗"), destination: URL(string: "https://developer.android.com/studio/run/managing-avds")!)
                    }
                    Divider()
                    HStack {
                        Button(action: model.chooseAndInstallAPK) { Label(L10n.text("APK installieren …"), systemImage: "square.and.arrow.down") }
                            .disabled(!model.canInstallAPK)
                        if model.apkBusy { ProgressView().controlSize(.small) }
                    }
                    if !ScrcpySession.installed {
                        Text(L10n.text("Streaming-Modul fehlt. Unter „Einrichtung“ kannst du es vorbereiten."))
                            .font(.caption).foregroundStyle(.orange)
                    }
                    if !model.apkStatus.isEmpty { Text(model.apkStatus).font(.caption).foregroundStyle(.secondary) }
                    Divider()
                    Text(L10n.text("Google-Konto & Cloud-Spielstände")).font(.headline)
                    Button(action: model.openGoogleInMacBrowser) {
                        Label(L10n.text("Google im Mac-Browser öffnen"), systemImage: "arrow.up.forward.app")
                    }
                    Text(L10n.text("Öffnet die Google-Kontoauswahl außerhalb von Stratovo in deinem normalen Standardbrowser. Dort können vorhandene Google-Anmeldungen und gespeicherte Zugangsdaten deines Browserprofils genutzt werden."))
                        .font(.subheadline).foregroundStyle(.secondary)
                    Text(L10n.text("Die Browser-Anmeldung gilt für den Mac. Sie fügt kein Konto zu Android hinzu. Für Play Store und Cloud-Spielstände das Konto zusätzlich im Android-System anmelden."))
                        .font(.subheadline).foregroundStyle(.secondary)
                    Button(L10n.text("Google-Konto in Android hinzufügen"), action: model.openGoogleAccountSettings)
                        .disabled(!model.canInstallAPK || model.selectedDevice?.googlePlay != true)
                    HStack {
                        Button(L10n.text("Play Spiele"), action: model.openPlayGames)
                        Button(L10n.text("Kontosynchronisierung"), action: model.openSyncSettings)
                        Button(L10n.text("Android-Sicherung"), action: model.openBackupSettings)
                    }.disabled(!model.canInstallAPK || model.selectedDevice?.googlePlay != true)
                    Text(model.googleServicesStatus).font(.caption).foregroundStyle(.secondary)
                    Text(L10n.text("Melde dich in Play Spiele und im jeweiligen Spiel mit demselben Konto an. Cloud-Spielstände und Backups funktionieren nur, soweit App, Spiel und Systemabbild sie unterstützen. Lokale Apps, Daten und Anmeldungen bleiben unabhängig davon gespeichert."))
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            notice(L10n.text("Android auswählen → Starten → Apps nutzen"),
                   L10n.text("Einmalig ein offizielles Google-Play-Gerät einrichten. Mit „Android starten“ öffnest du dein ausgewähltes Android im eigenen Playerfenster. Apps, Google-Anmeldung und Einstellungen bleiben gespeichert. Die Google-Webseite lässt sich zusätzlich im normalen Mac-Browser öffnen; die Android-Anmeldung erfolgt separat im Gastsystem."), color: .teal)
        }
    }

    private var windows: some View {
        VStack(alignment: .leading, spacing: 18) {
            WindowsGraphicsLabView(model: model, lab: model.graphicsLab)

            windowsIdentityCard
            card {
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
                    Text(L10n.text("Windows-Festplatte, Einstellungen und TPM bleiben in diesem Ordner gespeichert. Beim ersten Start installierst du Windows aus deiner ARM64-ISO."))
                        .font(.subheadline).foregroundStyle(.secondary)
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
                    Text(L10n.text("64–4096 GB frei eingeben. Die Datei wächst mit deinen Daten; die maximale Größe wird nicht sofort auf der SSD belegt. Änderungen werden über „Größe anwenden“ oder beim nächsten Windows-Start übernommen. Vergrößern ist bei ausgeschaltetem Windows möglich; vorhandene Festplatten werden nicht verkleinert. Zusätzlichen Speicher anschließend in Windows zuordnen."))
                        .font(.subheadline).foregroundStyle(.secondary)
                    DisclosureGroup(L10n.text("Voraussetzungen und Entwicklungsstand")) {
                        Text(L10n.text("Windows verwendet die 3D-Laufzeit auf deiner bestehenden Festplatte. Die Grafiktreiber werden in Windows installiert; Metal und die Mac-Laufzeit werden wiederverwendet."))
                            .font(.subheadline).foregroundStyle(.secondary).padding(.top, 6)
                    }
                }
            }
            card {
                VStack(alignment: .leading, spacing: 18) {
                    HStack {
                        Image(systemName: "desktopcomputer").font(.system(size: 32)).foregroundStyle(.blue)
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Windows 11 Pro Arm64").font(.title2.bold())
                            Text(L10n.text("QEMU · HVF · 3D über Metal")).foregroundStyle(.secondary)
                        }
                        Spacer()
                        status(model.windowsReady && model.firmware != nil ? L10n.text("Engine bereit") : L10n.text("Einrichtung nötig"), ready: model.windowsReady && model.firmware != nil)
                    }
                    Divider()
                    resourceControls
                    Toggle(L10n.text("Nächster Start: Windows von DVD einrichten"), isOn: $model.settings.installWindows)
                        .disabled(model.running || model.busy)
                    Text(L10n.text("Der DVD-Start gilt einmalig. Danach startet die VM von ihrer gespeicherten Festplatte; die ISO-Auswahl bleibt erhalten. Für einen weiteren DVD-Start diese Option erneut einschalten."))
                        .font(.caption).foregroundStyle(.secondary)
                    windowsDVDControls
                    VStack(alignment: .leading, spacing: 10) {
                        Text(L10n.text("Windows-Grafik und Auflösung")).font(.headline)
                        Text(L10n.text("VirtIO / Neptune / DXMT → Metal. Auflösung und Skalierung stellst du unter Windows → System → Anzeige ein."))
                            .font(.subheadline)
                        Button(L10n.text("Treiber-CD in Windows suchen"), action: model.openWindowsDriverDisc)
                            .disabled(model.activeGuest != "windows" || !model.running || model.windowsPasteBusy)
                    }
                    fileRow(title: "ARM64-Treiber-ISO (empfohlen)", value: model.settings.driversISO.isEmpty ? L10n.text("Windows-Gastwerkzeuge / VirtIO-Netzwerktreiber") : model.settings.driversISO) {
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
                            Text(L10n.text("Dieses Windows-Konto entsteht während der Installation. Bei „sicher merken“ speichert Stratovo Benutzername und Kennwort vor dem Start im macOS-Schlüsselbund und stellt sie beim nächsten Öffnen wieder her, soweit macOS den Zugriff bereits erlaubt. Zum Freigeben „Aus Schlüsselbund laden“ wählen und das Kennwort des Mac-Anmeldeschlüsselbunds verwenden. Das Kennwort bleibt auch nach dem Start in diesen Feldern; es steht nicht in Einstellungen oder Protokollen. Dieser App-Eintrag wird in der Schlüsselbundverwaltung verwaltet. Das temporäre Einrichtungsmedium wird nach Ende der Sitzung entfernt."))
                                .font(.caption).foregroundStyle(.secondary)
                        }.disabled(model.running || model.busy)
                    }
                    Toggle(L10n.text("Windows-Netzwerk / Internet aktivieren"), isOn: $model.settings.windowsNetwork)
                        .disabled(model.running || model.busy)
                    Text(L10n.text("Wähle ausdrücklich Arm64, keine x64-ISO. Die ISO-Architektur wird hier noch nicht automatisch erkannt. Zum Start des Installationsmediums gegebenenfalls im Gastfenster eine Taste drücken."))
                        .font(.caption).foregroundStyle(.secondary)
                    Text(L10n.text("Deine Windows-Lizenz bleibt erforderlich. Für Internet im Gast den ARM64-VirtIO-Netzwerktreiber von der Treiber-ISO laden. Beim lokalen Konto ist keine Microsoft-Anmeldung nötig."))
                        .font(.caption).foregroundStyle(.secondary)
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
        }
    }

    private var windowsIdentityCard: some View {
        card {
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
                Text(L10n.text("UUID, Seriennummer und MAC bleiben bei Neustarts gleich und liegen im Windows-Ordner auf deinem gewählten Datenträger. Ein schon in Windows gespeichertes Autopilot-Firmenprofil wird durch die Kennung allein nicht entfernt."))
                    .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
        }
        .confirmationDialog(L10n.text("Eigene Windows-Gerätekennung einrichten?"), isPresented: $showIdentityChange) {
            Button(L10n.text("Eigene Kennung übernehmen")) { Task { await model.changeWindowsIdentity() } }
            Button(L10n.text("Abbrechen"), role: .cancel) { }
        } message: {
            Text(L10n.text("Die bisherige Kennung wird im gewählten Windows-Ordner gesichert. Die VM erhält eine eigene UUID, Seriennummer und MAC. Windows-Festplatte, UEFI-Dateien und TPM werden nicht geändert. Windows kann eine erneute Aktivierung oder bei Verschlüsselung den BitLocker-Wiederherstellungsschlüssel verlangen. Danach ist der Start vom vorhandenen Windows ausgewählt."))
        }
        .confirmationDialog(L10n.text("Ursprüngliche Gerätekennung wiederherstellen?"), isPresented: $showIdentityRestore) {
            Button(L10n.text("Kennung wiederherstellen")) { Task { await model.changeWindowsIdentity(restore: true) } }
            Button(L10n.text("Abbrechen"), role: .cancel) { }
        } message: {
            Text(L10n.text("Die ursprünglichen virtuellen Gerätekennungen werden aus der gespeicherten Sicherung übernommen. Die Festplatte wird nicht zurückgesetzt. Auch bei dieser Hardwareänderung kann Windows eine Aktivierung oder einen BitLocker-Schlüssel verlangen."))
        }
    }

    private var setup: some View {
        VStack(alignment: .leading, spacing: 18) {
            LanguageSettingsView(model: model)
            storageCard
            SetupDownloadsView(model: model, installer: model.installer)
            card {
                VStack(alignment: .leading, spacing: 18) {
                    Text(L10n.text("Lokale Engines")).font(.title2.bold())
                    Text(L10n.text("Vorhandene Engines und eigene Firmware auswählen. Downloads und Lizenzen werden oben direkt in Stratovo verwaltet."))
                        .foregroundStyle(.secondary)
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Android SDK").font(.subheadline.bold())
                        Text(model.sdk ?? model.storage?.sdk.path ?? L10n.text("Zuerst Speicherort wählen")).font(.system(size: 11, design: .monospaced)).textSelection(.enabled)
                        Text(model.sdk == nil ? L10n.text("Die Download-Auswahl richtet Android-Werkzeuge und Emulator im gewählten Datenordner ein.") : L10n.text("SDK gefunden")).font(.caption).foregroundStyle(.secondary)
                    }
                    fileRow(title: "qemu-system-aarch64", value: model.qemu ?? L10n.text("Nicht gefunden")) {
                        if let path = model.chooseFile(title: L10n.text("qemu-system-aarch64 auswählen")) { model.settings.qemu = path; Task { await model.refresh() } }
                    }
                    fileRow(title: "ARM64-UEFI-Firmware", value: model.firmware ?? L10n.text("Nicht gefunden")) {
                        if let path = model.chooseFile(title: L10n.text("edk2-aarch64-code.fd auswählen")) { model.settings.firmware = path; Task { await model.refresh() } }
                    }
                    fileRow(title: "swtpm · virtuelles TPM 2.0", value: model.swtpm ?? L10n.text("Nicht gefunden")) {
                        if let path = model.chooseFile(title: L10n.text("swtpm auswählen")) { model.settings.swtpm = path; Task { await model.refresh() } }
                    }
                    Button(L10n.text("Standardpfade verwenden")) {
                        model.settings.qemu = ""; model.settings.firmware = ""; model.settings.swtpm = ""
                        Task { await model.refresh() }
                    }
                }
            }.disabled(model.running || model.busy)
            card {
                VStack(alignment: .leading, spacing: 12) {
                    Text(L10n.text("Dein Mac")).font(.headline)
                    LabeledContent(L10n.text("Arbeitsspeicher"), value: "\(model.totalMemoryGB) GB")
                    LabeledContent(L10n.text("CPU-Kerne"), value: "\(model.hostCores)")
                    LabeledContent("Hypervisor", value: model.hypervisorAvailable ? L10n.text("Verfügbar") : L10n.text("Nicht verfügbar"))
                    Text(L10n.text("Für einen Mac mit 16 GB empfehlen wir zunächst 4 GB und 4 Kerne. In dieser Version läuft jeweils ein Gastprozess."))
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            Text(L10n.text("Stratovo enthält keine Telemetrie. Android, QEMU und das Gastbetriebssystem haben eigene Netzwerk- und Datenschutzeinstellungen. Protokolle und Einstellungen liegen lokal auf diesem Mac."))
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private var storageSetup: some View {
        VStack(alignment: .leading, spacing: 18) {
            Label(L10n.text("Wo sollen deine Systeme gespeichert werden?"), systemImage: "externaldrive.fill")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(.primary)
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text(L10n.text("Wähle ein Laufwerk oder einen Ordner. Stratovo erstellt dort einen eigenen Ordner „Stratovo“ für Android, Windows und die benötigten Dateien."))
                        .font(.system(size: 16)).foregroundStyle(.primary)
                    StorageBudgetView(windowsGiB: model.windowsCapacityGiB ?? 80)
                    Text(L10n.text("Vorhandene Daten werden kopiert und vollständig geprüft. Die Originale bleiben zunächst als Sicherung auf der internen Festplatte. Nach dem erfolgreichen Test kannst du diese Sicherungen in der App entfernen."))
                        .font(.system(size: 16)).foregroundStyle(.primary)
                    Label(L10n.text("Vorher Android und Windows herunterfahren und Android Studio beenden."), systemImage: "info.circle.fill")
                        .font(.system(size: 16, weight: .semibold)).foregroundStyle(.primary)
                        .padding(14).frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.teal.opacity(0.14), in: RoundedRectangle(cornerRadius: 10))
                    VStack(alignment: .leading, spacing: 10) {
                        Text(L10n.text("Dein Datenordner")).font(.system(size: 16, weight: .bold))
                        Text(model.proposedStoragePath.isEmpty ? L10n.text("Noch kein Ziel ausgewählt") : model.proposedStoragePath)
                            .font(.system(size: 16, weight: .medium, design: .monospaced))
                            .foregroundStyle(.primary).textSelection(.enabled)
                            .fixedSize(horizontal: false, vertical: true)
                        Button(L10n.text("SSD oder Ordner wählen …"), action: model.chooseStorageFolder)
                            .font(.system(size: 15, weight: .semibold)).controlSize(.large).disabled(model.busy)
                    }.frame(maxWidth: .infinity, alignment: .leading)
                    VStack(alignment: .leading, spacing: 10) {
                        Label(model.errorMessage == nil ? "Status" : "Umzug angehalten",
                              systemImage: model.errorMessage == nil ? "info.circle.fill" : "exclamationmark.triangle.fill")
                            .font(.system(size: 17, weight: .bold))
                        Text(model.storageStatus).font(.system(size: 16, weight: .medium))
                            .foregroundStyle(.primary).textSelection(.enabled)
                            .fixedSize(horizontal: false, vertical: true)
                        if model.busy { ProgressView().controlSize(.regular) }
                    }.padding(16).frame(maxWidth: .infinity, alignment: .leading)
                        .background((model.errorMessage == nil ? Color.teal : Color.orange).opacity(0.16), in: RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder((model.errorMessage == nil ? Color.teal : Color.orange).opacity(0.65)))
                }.padding(.trailing, 8)
            }
            Divider()
            Text(L10n.text("Kleine Einstellungen und macOS-Auslagerungsdateien können intern bleiben."))
                .font(.system(size: 14)).foregroundStyle(.primary)
            HStack {
                Spacer()
                Button(L10n.text("Speicherort einrichten und Daten übernehmen"), action: model.configureStorage)
                    .font(.system(size: 16, weight: .semibold))
                    .buttonStyle(.borderedProminent).controlSize(.large)
                    .disabled(model.proposedStoragePath.isEmpty || model.busy)
            }
        }.padding(28).frame(width: 820, height: 690)
    }

    private var storageCard: some View {
        card {
            VStack(alignment: .leading, spacing: 14) {
                Label(L10n.text("Daten und Speicherplatz"), systemImage: "externaldrive.fill").font(.title2.bold())
                Text(model.storage?.root ?? L10n.text("Noch kein Speicherort gewählt")).font(.system(size: 12, design: .monospaced)).textSelection(.enabled)
                Text(model.storageFree).foregroundStyle(model.storageReady ? Color.teal : Color.orange)
                Text(L10n.text("SDK, Android-Geräte, Windows-Festplatte, TPM, Streaming und neue Protokolle verwenden diesen Ordner. Die App und Homebrew-Werkzeuge können intern bleiben.")).font(.caption).foregroundStyle(.secondary)
                Text(model.storageStatus).font(.caption).textSelection(.enabled)
                HStack {
                    if model.storage == nil { Button(L10n.text("Speicherort wählen …")) { model.showStorageSetup = true } }
                    Button(L10n.text("Datenordner öffnen"), action: model.revealStorage).disabled(!model.storageReady)
                }
                if !model.backupPaths.isEmpty {
                    Divider()
                    Text(L10n.text("Diese internen Kopien können nach dem Test entfernt werden:")).font(.subheadline.bold())
                    ForEach(model.backupPaths, id: \.self) { path in
                        Text(path).font(.system(size: 10, design: .monospaced)).textSelection(.enabled)
                    }
                    Toggle(L10n.text("Android/Windows mit dem neuen Speicherort geprüft; interne Sicherungen dürfen entfernt werden"), isOn: $model.storageTested)
                        .font(.caption)
                    Button(L10n.text("Geprüfte interne Kopien endgültig entfernen …"), role: .destructive, action: model.confirmStorageCleanup)
                        .disabled(!model.storageTested || !model.storageReady)
                    Text(L10n.text("Entfernt ausschließlich die oben gelisteten Sicherungen. Aktive Daten auf der SSD, andere Downloads, Xcode und Homebrew werden nicht gelöscht.")).font(.caption).foregroundStyle(.secondary)
                }
            }
        }.disabled(model.running || model.busy)
    }

    private var resourceControls: some View {
        HStack(spacing: 24) {
            Picker(L10n.text("RAM"), selection: $model.settings.memoryGB) {
                ForEach(2...model.maxMemoryGB, id: \.self) { Text("\($0) GB").tag($0) }
            }
            Picker(L10n.text("CPU"), selection: $model.settings.cores) {
                ForEach(2...model.maxCores, id: \.self) { Text("\($0) Kerne").tag($0) }
            }
        }.disabled(model.running || model.busy)
    }

    private var logPanel: some View {
        card {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Circle().fill(model.running ? Color.green : Color.secondary).frame(width: 7, height: 7)
                    Text(model.sessionName).font(.headline)
                    Spacer()
                    if model.running {
                        Button(L10n.text("Herunterfahren"), action: model.shutdownGuest)
                        Button(L10n.text("Prozess beenden"), role: .destructive) { showStopConfirmation = true }
                    }
                    Button(L10n.text("Sitzungslog zeigen"), action: model.revealLogs).disabled(model.lastCommand.isEmpty)
                }
                HStack {
                    Button {
                        Task { await model.exportDiagnostics() }
                    } label: { Label(L10n.text("Gesamtprotokoll exportieren"), systemImage: "doc.badge.arrow.up") }
                        .disabled(model.diagnosticBusy || !model.storageReady)
                    if model.diagnosticBusy { ProgressView().controlSize(.small) }
                    Text(L10n.text("Android + Windows + Einrichtung in einer Datei")).font(.caption).foregroundStyle(.secondary)
                }
                if !model.diagnosticStatus.isEmpty { Text(model.diagnosticStatus).font(.caption).textSelection(.enabled) }
                ScrollView([.horizontal, .vertical]) {
                    Text(model.log).font(.system(size: 11, design: .monospaced))
                        .textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(height: 150)
            }
        }
    }

    private func playerPane(kind: String, title: String) -> some View {
        let active = model.activeGuest == kind
        return card {
            HStack(spacing: 16) {
                Image(systemName: kind == "android" ? "apps.iphone" : "desktopcomputer")
                    .font(.title).foregroundStyle(.teal)
                VStack(alignment: .leading, spacing: 5) {
                    Text(title).font(.headline)
                    Text(active ? model.playerStatus : L10n.text("Eigenes Fenster · frei skalierbar · Vollbild möglich"))
                        .font(.subheadline).foregroundStyle(.secondary)
                    if active && kind == "android" {
                        Text(L10n.message("Stream: \(Int(model.streamFPS.rounded())) FPS · Decoder-Zuführung: \(Int(model.decoderFPS.rounded())) FPS · Ziel \(model.androidTargetFPS)"))
                            .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                        Text(L10n.text("Empfangene und an den Decoder übergebene Bilder; keine Messung der Spiel-FPS."))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 0)
                Button(L10n.text("Player öffnen")) { model.showPlayer(kind: kind) }
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
                Text(L10n.text("Eine vorhandene ISO auf Extern auswählen. Der Pfad wird gespeichert. Geprüft werden Dateiverfügbarkeit und Größe; ARM64-Inhalt und Bootfähigkeit sind damit noch nicht bestätigt. Zum Ändern Windows ausschalten."))
                    .font(.caption).foregroundStyle(.secondary)
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
                Text(L10n.text("Verglichen wird die deutsche ARM64-ISO von Windows 11 26H2. Andere Versionen oder Sprachen brauchen ihren eigenen offiziellen Prüfwert. Es wird nichts neu heruntergeladen."))
                    .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }.frame(maxWidth: .infinity, alignment: .leading).padding(6)
        }
    }

    private func fileRow(title: String, value: String, action: @escaping () -> Void) -> some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.subheadline.bold())
                Text(value).font(.system(size: 11, design: .monospaced)).foregroundStyle(.secondary)
                    .textSelection(.enabled).lineLimit(2).truncationMode(.middle)
            }
            Spacer(minLength: 10)
            Button(L10n.text("Auswählen …"), action: action)
        }
    }

    private func status(_ text: String, ready: Bool) -> some View {
        Text(text).font(.caption.bold()).foregroundStyle(ready ? .teal : .orange)
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background((ready ? Color.teal : Color.orange).opacity(0.12), in: Capsule())
    }

    private func notice(_ title: String, _ message: String, color: Color) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "info.circle.fill").foregroundStyle(color).padding(.top, 1)
            VStack(alignment: .leading, spacing: 5) {
                Text(title).font(.subheadline.bold())
                Text(message).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
        }.padding(16).frame(maxWidth: .infinity, alignment: .leading)
            .background(color.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
    }

    private func card<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content().padding(20).frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Color.primary.opacity(0.07)))
    }
}
