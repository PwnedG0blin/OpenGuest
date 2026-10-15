import SwiftUI
import OpenGuestCore

enum WorkspaceTab: String, CaseIterable, Identifiable {
    case android = "Android"
    case windows = "Windows Arm"
    case setup = "Einrichtung"
    var id: String { rawValue }
    var icon: String {
        switch self {
        case .android: return "apps.iphone"
        case .windows: return "desktopcomputer"
        case .setup: return "slider.horizontal.3"
        }
    }
}

@MainActor
struct ContentView: View {
    @ObservedObject var model: AppModel
    @State private var selection: WorkspaceTab = .android
    @State private var showStopConfirmation = false

    var body: some View {
        HStack(spacing: 0) {
            sidebar.frame(width: 214)
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    header
                    if !model.supportedHost || !model.hypervisorAvailable {
                        notice("Apple Silicon und Hardwarevirtualisierung benötigt",
                               "Starte die native ARM64-Version auf einem Mac mit M-Chip. Intel-Macs und Rosetta sind in Version 0.1 nicht unterstützt.", color: .orange)
                    }
                    if !model.storageReady && model.storage != nil {
                        notice("Datenordner nicht erreichbar", "Bitte die gewählte SSD anschließen. Android, Windows und Downloads bleiben bis dahin gesperrt.", color: .orange)
                    }
                    switch selection {
                    case .android: android
                    case .windows: windows
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
        .sheet(isPresented: $model.showStorageSetup) { storageSetup.interactiveDismissDisabled() }
        .alert("OpenGuest", isPresented: Binding(get: { model.errorMessage != nil }, set: { if !$0 { model.errorMessage = nil } })) {
            Button("OK") { model.errorMessage = nil }
        } message: { Text(model.errorMessage ?? "") }
        .confirmationDialog("Gastprozess beenden?", isPresented: $showStopConfirmation) {
            Button("Prozess beenden", role: .destructive) { model.terminateGuest() }
            Button("Abbrechen", role: .cancel) { }
        } message: {
            Text("Fahre Android oder Windows möglichst zuerst im Gastfenster herunter. Das Beenden des Prozesses kann nicht gespeicherte Änderungen verlieren oder das Gastdateisystem beschädigen.")
        }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 26) {
            HStack(spacing: 10) {
                Image(systemName: "square.stack.3d.up.fill").font(.title).foregroundStyle(.teal)
                VStack(alignment: .leading, spacing: 2) {
                    Text("OpenGuest").font(.headline)
                    Text("DEVELOPMENT 0.3.4").font(.system(size: 9, weight: .semibold, design: .monospaced)).foregroundStyle(.secondary)
                }
            }
            ForEach(WorkspaceTab.allCases) { tab in
                Button { selection = tab } label: {
                    Label(tab.rawValue, systemImage: tab.icon)
                        .font(.system(size: 14, weight: .medium))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(11)
                        .background(selection == tab ? Color.teal.opacity(0.14) : Color.clear, in: RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
            }
            Spacer()
            VStack(alignment: .leading, spacing: 8) {
                Label("Open Source · MIT", systemImage: "curlybraces")
                Text("Eine Oberfläche. Zwei Engines.\nEntwickelt für Apple Silicon.")
                    .font(.caption).foregroundStyle(.secondary)
            }.font(.caption)
        }
        .padding(20)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 5) {
                Text(selection.rawValue).font(.system(size: 30, weight: .bold))
                Text(selection == .android ? "Dein virtuelles Android auf dem Mac." : selection == .windows ? "Der erste Schritt zu Windows auf deinem Mac." : "Verbinde die lokalen Virtualisierungs-Engines.")
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if model.busy { ProgressView().controlSize(.small) }
            Button { Task { await model.refresh() } } label: { Label("System prüfen", systemImage: "arrow.clockwise") }
                .disabled(model.busy || model.running)
        }
    }

    private var android: some View {
        VStack(alignment: .leading, spacing: 18) {
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
                        status(model.androidReady ? "Engine bereit" : "Einrichtung nötig", ready: model.androidReady)
                    }
                    Divider()
                    if model.devices.isEmpty {
                        Text("Noch kein virtuelles Gerät gefunden. Lege in Android Studio ein Gerät mit arm64-v8a-Systemabbild an und klicke auf „System prüfen“.")
                            .foregroundStyle(.secondary)
                    } else {
                        Picker("Virtuelles Gerät", selection: $model.settings.selectedAVD) {
                            ForEach(model.devices) { device in
                            Text("\(device.name) · \(device.abi)\(device.googlePlay ? " · Google Play" : "")").tag(device.name)
                            }
                        }
                        .disabled(model.running || model.busy)
                        if let device = model.selectedDevice, !device.supported {
                            Text("Dieses Gerät ist kein erkanntes ARM64-Gerät und wird in diesem Prototyp nicht gestartet.")
                                .font(.caption).foregroundStyle(.orange)
                        }
                    }
                    resourceControls
                    Picker("Grafik", selection: $model.settings.gpu) {
                        Text("Automatisch").tag("auto")
                        Text("Mac-GPU bevorzugen").tag("host")
                        Text("Software (Fehlersuche)").tag("software")
                    }.disabled(model.running || model.busy)
                    Toggle("Kaltstart beim nächsten Start", isOn: $model.settings.coldBoot)
                        .disabled(model.running || model.busy)
                    if let device = model.selectedDevice {
                        Label(device.googlePlay ? "Google-Play-Systemabbild im Profil erkannt" : "Dieses Profil enthält keinen erkannten Google Play Store",
                              systemImage: device.googlePlay ? "checkmark.seal" : "info.circle")
                            .font(.caption).foregroundStyle(device.googlePlay ? Color.teal : Color.orange)
                    }
                    Text(model.androidAcceleration).font(.caption).foregroundStyle(.secondary)
                    HStack {
                        Button(action: model.startAndroid) { Label("Android starten", systemImage: "play.fill") }
                            .buttonStyle(.borderedProminent).controlSize(.large)
                            .disabled(!model.canStartAndroid)
                        Spacer()
                        Link("Gerät anlegen ↗", destination: URL(string: "https://developer.android.com/studio/run/managing-avds")!)
                    }
                    Divider()
                    HStack {
                        Button(action: model.chooseAndInstallAPK) { Label("APK installieren …", systemImage: "square.and.arrow.down") }
                            .disabled(!model.canInstallAPK)
                        if model.apkBusy { ProgressView().controlSize(.small) }
                    }
                    if !ScrcpySession.installed {
                        Text("Streaming-Modul fehlt. Unter „Einrichtung“ kannst du es vorbereiten.")
                            .font(.caption).foregroundStyle(.orange)
                    }
                    if !model.apkStatus.isEmpty { Text(model.apkStatus).font(.caption).foregroundStyle(.secondary) }
                    Divider()
                    Text("Google-Konto & Cloud-Spielstände").font(.headline)
                    Button(action: model.openGoogleInMacBrowser) {
                        Label("Google im Mac-Browser öffnen", systemImage: "arrow.up.forward.app")
                    }
                    Text("Öffnet die Google-Kontoauswahl außerhalb von OpenGuest in deinem normalen Standardbrowser. Dort können vorhandene Google-Anmeldungen und gespeicherte Zugangsdaten deines Browserprofils genutzt werden.")
                        .font(.subheadline).foregroundStyle(.secondary)
                    Text("Die Browser-Anmeldung gilt für den Mac. Sie fügt kein Konto zu Android hinzu. Für Play Store und Cloud-Spielstände das Konto zusätzlich im Android-System anmelden.")
                        .font(.subheadline).foregroundStyle(.secondary)
                    Button("Google-Konto in Android hinzufügen", action: model.openGoogleAccountSettings)
                        .disabled(!model.canInstallAPK || model.selectedDevice?.googlePlay != true)
                    HStack {
                        Button("Play Spiele", action: model.openPlayGames)
                        Button("Kontosynchronisierung", action: model.openSyncSettings)
                        Button("Android-Sicherung", action: model.openBackupSettings)
                    }.disabled(!model.canInstallAPK || model.selectedDevice?.googlePlay != true)
                    Text(model.googleServicesStatus).font(.caption).foregroundStyle(.secondary)
                    Text("Melde dich in Play Spiele und im jeweiligen Spiel mit demselben Konto an. Cloud-Spielstände und Backups funktionieren nur, soweit App, Spiel und Systemabbild sie unterstützen. Lokale Apps, Daten und Anmeldungen bleiben unabhängig davon gespeichert.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            notice("Android auswählen → Starten → Apps nutzen",
                   "Einmalig ein offizielles Google-Play-Gerät einrichten. Mit „Android starten“ öffnest du dein ausgewähltes Android im eigenen Playerfenster. Apps, Google-Anmeldung und Einstellungen bleiben gespeichert. Die Google-Webseite lässt sich zusätzlich im normalen Mac-Browser öffnen; die Android-Anmeldung erfolgt separat im Gastsystem.", color: .teal)
        }
    }

    private var windows: some View {
        VStack(alignment: .leading, spacing: 18) {
            playerPane(kind: "windows", title: "Windows Player")
            notice("Windows 11 Pro Arm64 · erster Installationsprototyp",
                   "Eigene 80-GB-Festplatte, dauerhaftes TPM 2.0 und UEFI. Beim ersten Start installierst und konfigurierst du Windows selbst. ARM64-Treiber und passende Secure-Boot-fähige Firmware sind Voraussetzung. Installation und OOBE sind auf echter Mac-Hardware noch nicht verifiziert. 3D-Beschleunigung fehlt in dieser Version.", color: .orange)
            card {
                VStack(alignment: .leading, spacing: 18) {
                    HStack {
                        Image(systemName: "desktopcomputer").font(.system(size: 32)).foregroundStyle(.blue)
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Windows 11 Pro Arm64").font(.title2.bold())
                            Text("QEMU · HVF · einfacher Framebuffer").foregroundStyle(.secondary)
                        }
                        Spacer()
                        status(model.windowsReady && model.firmware != nil ? "Engine bereit" : "Einrichtung nötig", ready: model.windowsReady && model.firmware != nil)
                    }
                    Divider()
                    resourceControls
                    Toggle("Windows installieren · ISO einlegen", isOn: $model.settings.installWindows)
                        .disabled(model.running || model.busy)
                    Text("Nach der Installation ausschalten: Dann bootet die VM von ihrer gespeicherten Windows-Festplatte.")
                        .font(.caption).foregroundStyle(.secondary)
                    fileRow(title: "Windows-Arm64-ISO", value: model.settings.iso.isEmpty ? "Für die erste Installation auswählen" : model.settings.iso) {
                        if let file = model.chooseFile(title: "Windows-Arm64-ISO auswählen") { model.settings.iso = file }
                    }
                    .disabled(model.running || model.busy)
                    if !model.settings.iso.isEmpty {
                        Button("ISO aus Auswahl entfernen") { model.settings.iso = "" }
                            .font(.caption).disabled(model.running || model.busy)
                    }
                    fileRow(title: "ARM64-Treiber-ISO (empfohlen)", value: model.settings.driversISO.isEmpty ? "Windows-Gastwerkzeuge / VirtIO-Netzwerktreiber" : model.settings.driversISO) {
                        if let file = model.chooseFile(title: "ARM64-Windows-Gasttreiber-ISO auswählen") { model.settings.driversISO = file }
                    }.disabled(model.running || model.busy)
                    if !model.settings.driversISO.isEmpty {
                        Button("Treiber-ISO aus Auswahl entfernen") { model.settings.driversISO = "" }
                            .font(.caption).disabled(model.running || model.busy)
                    }
                    if model.settings.driversISO == model.settings.iso && !model.settings.iso.isEmpty {
                        Text("Hier ist dieselbe ISO zweimal ausgewählt. Eine Windows-ISO ist keine Treiber-ISO.").font(.caption).foregroundStyle(.orange)
                    }
                    Toggle("Windows 11 Pro vorauswählen", isOn: $model.settings.selectPro)
                        .disabled(model.running || model.busy || !model.settings.installWindows)
                    Toggle("Lokales Windows-Konto · ohne Microsoft-Anmeldung", isOn: $model.settings.localWindowsAccount)
                        .disabled(model.running || model.busy || !model.settings.installWindows)
                    if model.settings.installWindows && model.settings.localWindowsAccount {
                        VStack(alignment: .leading, spacing: 10) {
                            TextField("Lokaler Benutzername", text: $model.settings.localWindowsUser)
                            SecureField("Passwort (mindestens 8 Zeichen)", text: $model.localPassword)
                            SecureField("Passwort wiederholen", text: $model.localPasswordConfirmation)
                            Text("Passwort: \(model.localPassword.count) Zeichen · Wiederholung: \(model.localPasswordConfirmation.count) Zeichen")
                                .font(.subheadline.monospacedDigit())
                            Label(model.localAccountIssue ?? "Kontodaten gültig · Passwörter stimmen überein",
                                  systemImage: model.localAccountIssue == nil ? "checkmark.circle.fill" : "info.circle.fill")
                                .foregroundStyle(model.localAccountIssue == nil ? Color.teal : Color.orange)
                            HStack {
                                Button("Im Schlüsselbund speichern") { Task { await model.saveWindowsCredential() } }
                                    .disabled(model.localAccountIssue != nil)
                                Button("Aus Schlüsselbund laden") { Task { await model.loadWindowsCredential() } }
                            }
                            Text(model.credentialStatus).font(.subheadline).textSelection(.enabled)
                            Text("Dieses Konto wird während der Windows-Installation angelegt. Der Benutzername bleibt in OpenGuest gespeichert. Mit „Im Schlüsselbund speichern“ merkst du dir das Passwort auf diesem Mac; es wird nicht in die App-Einstellungen oder Protokolle geschrieben. Bei Startfehlern bleiben deine Eingaben erhalten. Das temporäre Einrichtungsmedium wird nach Ende der Sitzung entfernt.")
                                .font(.caption).foregroundStyle(.secondary)
                        }.disabled(model.running || model.busy)
                    }
                    Toggle("Windows-Netzwerk / Internet aktivieren", isOn: $model.settings.windowsNetwork)
                        .disabled(model.running || model.busy)
                    Text("Wähle ausdrücklich Arm64, keine x64-ISO. Die ISO-Architektur wird hier noch nicht automatisch erkannt. Zum Start des Installationsmediums gegebenenfalls im Gastfenster eine Taste drücken.")
                        .font(.caption).foregroundStyle(.secondary)
                    Text("Deine Windows-Lizenz bleibt erforderlich. Für Internet im Gast den ARM64-VirtIO-Netzwerktreiber von der Treiber-ISO laden. Beim lokalen Konto ist keine Microsoft-Anmeldung nötig.")
                        .font(.caption).foregroundStyle(.secondary)
                    Text(model.windowsAcceleration).font(.caption).foregroundStyle(.secondary)
                    if model.settings.memoryGB < 4 { Text("Für den Windows-Boot-Test mindestens 4 GB RAM wählen.").foregroundStyle(.orange).font(.caption) }
                    HStack {
                        Button(action: model.startWindows) { Label(model.settings.installWindows ? "Windows einrichten" : "Windows starten", systemImage: "play.fill") }
                            .buttonStyle(.borderedProminent).controlSize(.large)
                            .disabled(!model.canStartWindows)
                        Spacer()
                        Link("Windows Arm64 ↗", destination: URL(string: "https://www.microsoft.com/de-de/software-download/windows11arm64")!)
                    }
                    Link("ARM64-Windows-Gasttreiber ↗", destination: URL(string: "https://docs.getutm.app/guest-support/windows/")!)
                    Button("Windows-Dateien im Finder zeigen") {
                        NSWorkspace.shared.open(WindowsSession.root)
                    }.disabled(model.busy)
                }
            }
        }
    }

    private var setup: some View {
        VStack(alignment: .leading, spacing: 18) {
            storageCard
            SetupDownloadsView(model: model, installer: model.installer)
            card {
                VStack(alignment: .leading, spacing: 18) {
                    Text("Lokale Engines").font(.title2.bold())
                    Text("Vorhandene Engines und eigene Firmware auswählen. Downloads und Lizenzen werden oben direkt in OpenGuest verwaltet.")
                        .foregroundStyle(.secondary)
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Android SDK").font(.subheadline.bold())
                        Text(model.sdk ?? model.storage?.sdk.path ?? "Zuerst Speicherort wählen").font(.system(size: 11, design: .monospaced)).textSelection(.enabled)
                        Text(model.sdk == nil ? "Die Download-Auswahl richtet Android-Werkzeuge und Emulator im gewählten Datenordner ein." : "SDK gefunden").font(.caption).foregroundStyle(.secondary)
                    }
                    fileRow(title: "qemu-system-aarch64", value: model.qemu ?? "Nicht gefunden") {
                        if let path = model.chooseFile(title: "qemu-system-aarch64 auswählen") { model.settings.qemu = path; Task { await model.refresh() } }
                    }
                    fileRow(title: "ARM64-UEFI-Firmware", value: model.firmware ?? "Nicht gefunden") {
                        if let path = model.chooseFile(title: "edk2-aarch64-code.fd auswählen") { model.settings.firmware = path; Task { await model.refresh() } }
                    }
                    fileRow(title: "swtpm · virtuelles TPM 2.0", value: model.swtpm ?? "Nicht gefunden") {
                        if let path = model.chooseFile(title: "swtpm auswählen") { model.settings.swtpm = path; Task { await model.refresh() } }
                    }
                    Button("Standardpfade verwenden") {
                        model.settings.qemu = ""; model.settings.firmware = ""; model.settings.swtpm = ""
                        Task { await model.refresh() }
                    }
                }
            }.disabled(model.running || model.busy)
            card {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Dein Mac").font(.headline)
                    LabeledContent("Arbeitsspeicher", value: "\(model.totalMemoryGB) GB")
                    LabeledContent("CPU-Kerne", value: "\(model.hostCores)")
                    LabeledContent("Hypervisor", value: model.hypervisorAvailable ? "Verfügbar" : "Nicht verfügbar")
                    Text("Für einen Mac mit 16 GB empfehlen wir zunächst 4 GB und 4 Kerne. In dieser Version läuft jeweils ein Gastprozess.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            Text("OpenGuest enthält keine Telemetrie. Android, QEMU und das Gastbetriebssystem haben eigene Netzwerk- und Datenschutzeinstellungen. Protokolle und Einstellungen liegen lokal auf diesem Mac.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private var storageSetup: some View {
        VStack(alignment: .leading, spacing: 18) {
            Label("Wo sollen deine Systeme gespeichert werden?", systemImage: "externaldrive.fill")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(.primary)
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Wähle ein Laufwerk oder einen Ordner. OpenGuest erstellt dort einen eigenen Ordner „OpenGuest“ für Android, Windows und die benötigten Dateien.")
                        .font(.system(size: 16)).foregroundStyle(.primary)
                    Text("Vorhandene Daten werden kopiert und vollständig geprüft. Die Originale bleiben zunächst als Sicherung auf der internen Festplatte. Nach dem erfolgreichen Test kannst du diese Sicherungen in der App entfernen.")
                        .font(.system(size: 16)).foregroundStyle(.primary)
                    Label("Vorher Android und Windows herunterfahren und Android Studio beenden.", systemImage: "info.circle.fill")
                        .font(.system(size: 16, weight: .semibold)).foregroundStyle(.primary)
                        .padding(14).frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.teal.opacity(0.14), in: RoundedRectangle(cornerRadius: 10))
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Dein Datenordner").font(.system(size: 16, weight: .bold))
                        Text(model.proposedStoragePath.isEmpty ? "Noch kein Ziel ausgewählt" : model.proposedStoragePath)
                            .font(.system(size: 16, weight: .medium, design: .monospaced))
                            .foregroundStyle(.primary).textSelection(.enabled)
                            .fixedSize(horizontal: false, vertical: true)
                        Button("Ordner wählen …", action: model.chooseStorageFolder)
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
            Text("Kleine Einstellungen und macOS-Auslagerungsdateien können intern bleiben.")
                .font(.system(size: 14)).foregroundStyle(.primary)
            HStack {
                Spacer()
                Button("Speicherort einrichten und Daten übernehmen", action: model.configureStorage)
                    .font(.system(size: 16, weight: .semibold))
                    .buttonStyle(.borderedProminent).controlSize(.large)
                    .disabled(model.proposedStoragePath.isEmpty || model.busy)
            }
        }.padding(28).frame(width: 820, height: 690)
    }

    private var storageCard: some View {
        card {
            VStack(alignment: .leading, spacing: 14) {
                Label("Daten und Speicherplatz", systemImage: "externaldrive.fill").font(.title2.bold())
                Text(model.storage?.root ?? "Noch kein Speicherort gewählt").font(.system(size: 12, design: .monospaced)).textSelection(.enabled)
                Text(model.storageFree).foregroundStyle(model.storageReady ? Color.teal : Color.orange)
                Text("SDK, Android-Geräte, Windows-Festplatte, TPM, Streaming und neue Protokolle verwenden diesen Ordner. Die App und Homebrew-Werkzeuge können intern bleiben.").font(.caption).foregroundStyle(.secondary)
                Text(model.storageStatus).font(.caption).textSelection(.enabled)
                HStack {
                    if model.storage == nil { Button("Speicherort wählen …") { model.showStorageSetup = true } }
                    Button("Datenordner öffnen", action: model.revealStorage).disabled(!model.storageReady)
                }
                if !model.backupPaths.isEmpty {
                    Divider()
                    Text("Diese internen Kopien können nach dem Test entfernt werden:").font(.subheadline.bold())
                    ForEach(model.backupPaths, id: \.self) { path in
                        Text(path).font(.system(size: 10, design: .monospaced)).textSelection(.enabled)
                    }
                    Toggle("Android/Windows mit dem neuen Speicherort geprüft; interne Sicherungen dürfen entfernt werden", isOn: $model.storageTested)
                        .font(.caption)
                    Button("Geprüfte interne Kopien endgültig entfernen …", role: .destructive, action: model.confirmStorageCleanup)
                        .disabled(!model.storageTested || !model.storageReady)
                    Text("Entfernt ausschließlich die oben gelisteten Sicherungen. Aktive Daten auf der SSD, andere Downloads, Xcode und Homebrew werden nicht gelöscht.").font(.caption).foregroundStyle(.secondary)
                }
            }
        }.disabled(model.running || model.busy)
    }

    private var resourceControls: some View {
        HStack(spacing: 24) {
            Picker("RAM", selection: $model.settings.memoryGB) {
                ForEach(2...model.maxMemoryGB, id: \.self) { Text("\($0) GB").tag($0) }
            }
            Picker("CPU", selection: $model.settings.cores) {
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
                        Button("Herunterfahren", action: model.shutdownGuest)
                        Button("Prozess beenden", role: .destructive) { showStopConfirmation = true }
                    }
                    Button("Protokolldatei", action: model.revealLogs).disabled(model.lastCommand.isEmpty)
                }
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
                    Text(active ? model.playerStatus : "Eigenes Fenster · frei skalierbar · Vollbild möglich")
                        .font(.subheadline).foregroundStyle(.secondary)
                    if active && kind == "android" {
                        Text("\(Int(model.streamFPS.rounded())) Video-Frames/s · Ziel 60")
                            .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 0)
                Button("Player öffnen") { model.showPlayer(kind: kind) }
            }
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
            Button("Auswählen …", action: action)
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
