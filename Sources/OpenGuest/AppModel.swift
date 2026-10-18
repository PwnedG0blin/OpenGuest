import AppKit
import Combine
import Darwin
import Foundation
import UniformTypeIdentifiers
import OpenGuestCore

struct AppSettings: Codable {
    var sdk = ""
    var qemu = ""
    var firmware = ""
    var swtpm = ""
    var iso = ""
    var driversISO = ""
    var installWindows = true
    var selectPro = true
    var localWindowsAccount = true
    var localWindowsUser = "Benutzer"
    var windowsNetwork = false
    var selectedAVD = ""
    var memoryGB = 4
    var cores = 4
    var coldBoot = false
    var gpu = "auto"

    static func load() -> AppSettings {
        guard let data = UserDefaults.standard.data(forKey: "OpenGuest.settings"),
              let decoded = try? JSONDecoder().decode(Self.self, from: data) else { return Self() }
        return decoded
    }
    func save() {
        if let data = try? JSONEncoder().encode(self) { UserDefaults.standard.set(data, forKey: "OpenGuest.settings") }
    }
}

@MainActor
final class AppModel: ObservableObject {
    @Published var settings = AppSettings.load() { didSet { settings.save() } }
    @Published var androidProfile = AndroidPerformance(rawValue: UserDefaults.standard.string(forKey: "Pixelkoje.androidProfile") ?? "smooth") ?? .smooth {
        didSet { UserDefaults.standard.set(androidProfile.rawValue, forKey: "Pixelkoje.androidProfile") }
    }
    @Published var androidTargetFPS = UserDefaults.standard.integer(forKey: "Pixelkoje.androidFPS") == 30 ? 30 : 60 {
        didSet { UserDefaults.standard.set(androidTargetFPS, forKey: "Pixelkoje.androidFPS") }
    }
    @Published private(set) var androidRendererStatus = "Grafikrenderer wird beim Android-Start geprüft"
    @Published private(set) var androidSoftwareRendering = false
    @Published private(set) var androidDisplayStatus = "Leistungsprofil wird nach dem Android-Start angewendet"
    @Published var androidCustomDisplay = UserDefaults.standard.bool(forKey: "Pixelkoje.androidCustomDisplay") {
        didSet { UserDefaults.standard.set(androidCustomDisplay, forKey: "Pixelkoje.androidCustomDisplay") }
    }
    @Published var androidDisplayWidth = UserDefaults.standard.string(forKey: "Pixelkoje.androidWidth") ?? "720" {
        didSet { UserDefaults.standard.set(androidDisplayWidth, forKey: "Pixelkoje.androidWidth") }
    }
    @Published var androidDisplayHeight = UserDefaults.standard.string(forKey: "Pixelkoje.androidHeight") ?? "1600" {
        didSet { UserDefaults.standard.set(androidDisplayHeight, forKey: "Pixelkoje.androidHeight") }
    }
    @Published var androidDisplayDensity = UserDefaults.standard.string(forKey: "Pixelkoje.androidDensity") ?? "280" {
        didSet { UserDefaults.standard.set(androidDisplayDensity, forKey: "Pixelkoje.androidDensity") }
    }
    @Published private(set) var androidDisplayBusy = false
    func selectGalaxyS26UltraDisplay() {
        guard canEditAndroidDisplay else { return }
        androidDisplayWidth = "1440"; androidDisplayHeight = "3120"; androidDisplayDensity = "500"
        androidCustomDisplay = true
        androidDisplayStatus = "S26-Ultra-Displayprofil gewählt · 1440 × 3120 · 500 dpi. Jetzt anwenden oder Android neu starten."
        UserDefaults.standard.set(true, forKey: "Pixelkoje.playerFit.android")
    }
    private func requestedAndroidDisplay() throws -> AndroidCustomDisplay? {
        guard androidCustomDisplay else { return nil }
        guard let w = Int(androidDisplayWidth.trimmingCharacters(in: .whitespacesAndNewlines)),
              let h = Int(androidDisplayHeight.trimmingCharacters(in: .whitespacesAndNewlines)),
              let dpi = Int(androidDisplayDensity.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            throw GuestError.commandFailed(1, "Bitte Breite, Höhe und Dichte als ganze Zahlen eingeben.")
        }
        return try AndroidCustomDisplay(width: w, height: h, density: dpi)
    }
    var androidDisplayIssue: String? {
        do { _ = try requestedAndroidDisplay(); return nil } catch { return error.localizedDescription }
    }
    var canEditAndroidDisplay: Bool { !busy && !androidDisplayBusy && (!running || (activeGuest == "android" && androidBooted)) }
    var canApplyAndroidDisplay: Bool { canEditAndroidDisplay && running && activeGuest == "android" && androidBooted && androidDisplayIssue == nil }
    func applyAndroidDisplayNow() async {
        guard canApplyAndroidDisplay, storageReady, let port = androidPort else { return }
        androidDisplayBusy = true
        defer { androidDisplayBusy = false }
        await applyAndroidDisplay(port: port)
    }
    func restoreAndroidDisplay() async {
        guard canEditAndroidDisplay else { return }
        androidCustomDisplay = false; androidProfile = .native
        if canApplyAndroidDisplay { await applyAndroidDisplayNow() }
        else { androidDisplayStatus = "Originalauflösung wird beim nächsten Android-Start wiederhergestellt." }
    }
    @Published private(set) var decoderFPS = 0.0
    @Published private(set) var decoderRecoveries = 0

    @Published private(set) var devices: [AndroidDevice] = []
    @Published private(set) var sdk: String?
    @Published private(set) var qemu: String?
    @Published private(set) var firmware: String?
    @Published private(set) var swtpm: String?
    @Published private(set) var qemuImg: String?
    @Published private(set) var variablesTemplate: String?
    @Published private(set) var androidAcceleration = "Noch nicht geprüft"
    @Published private(set) var windowsAcceleration = "Noch nicht geprüft"
    @Published private(set) var windowsISOReady = false
    @Published private(set) var windowsISODetail = "Noch keine Installations-DVD ausgewählt"
    @Published private(set) var windowsBootMediaStatus = "DVD-Verbindung wird nach dem Start direkt bei QEMU geprüft"
    @Published private(set) var windowsIdentity: WindowsMachineIdentity?
    @Published private(set) var windowsIdentityStatus = "Gerätekennung noch nicht geprüft"
    @Published private(set) var windowsIdentityCanRestore = false
    @Published private(set) var windowsISOHashStatus = "Originalität der ISO noch nicht geprüft"
    @Published private(set) var windowsISOHashDigest = ""
    private var hashedISOPath = ""
    @Published var windowsGraphics: WindowsGraphics = .basic { didSet { saveWindowsDisplayChoice() } }
    @Published var windowsResolution: WindowsDisplayMode = .fullHD { didSet { saveWindowsDisplayChoice() } }
    private var loadingWindowsDisplay = false
    private func saveWindowsDisplayChoice() {
        guard !loadingWindowsDisplay, let storage else { return }
        UserDefaults.standard.set(windowsGraphics.rawValue, forKey: "Pixelkoje.windowsGraphics.\(storage.id)")
        UserDefaults.standard.set(windowsResolution.rawValue, forKey: "Pixelkoje.windowsResolution.\(storage.id)")
    }
    private func loadWindowsDisplayChoice() {
        guard let storage else { return }
        loadingWindowsDisplay = true
        defer { loadingWindowsDisplay = false }
        windowsGraphics = WindowsGraphics(rawValue: UserDefaults.standard.string(forKey: "Pixelkoje.windowsGraphics.\(storage.id)") ?? "") ?? .basic
        windowsResolution = WindowsDisplayMode(rawValue: UserDefaults.standard.string(forKey: "Pixelkoje.windowsResolution.\(storage.id)") ?? "") ?? .fullHD
    }
    @Published private(set) var androidPasteStatus = ""
    @Published private(set) var androidRepairStatus = ""
    var canRepairAndroidConnection: Bool { storageReady && adb != nil && !running && !busy }
    func repairAndroidConnection() async {
        guard canRepairAndroidConnection, let adb, let storage else { return }
        busy = true
        androidRepairStatus = "Android-Verbindung wird repariert …"
        defer { busy = false }
        do {
            try storage.validate()
            for action in ["kill-server", "start-server"] {
                let result = try await Self.capture(CommandSpec(executable: adb, arguments: [action], environment: storage.environment), timeout: 15)
                guard result.status == 0 else { throw GuestError.commandFailed(result.status, result.output) }
            }
            settings.coldBoot = true
            androidRepairStatus = "ADB neu gestartet · Kaltstart aktiviert. Jetzt Android starten."
            recordDiagnostic("Android · Verbindung repariert", "ADB-Dienst auf ausdrücklichen Wunsch neu gestartet; Kaltstart aktiviert. Keine Gastdaten gelöscht.")
        } catch {
            androidRepairStatus = "Reparatur fehlgeschlagen: " + error.localizedDescription
            recordDiagnostic("Android · Verbindungsreparatur", androidRepairStatus)
        }
    }
    @discardableResult
    func pasteAndroidText(_ input: AndroidClipboardText) async -> Bool {
        guard running, activeGuest == "android", androidBooted, !busy, let stream = androidStream else {
            androidPasteStatus = "Android-Eingabeverbindung noch nicht bereit."; return false
        }
        do {
            try await stream.paste(input)
            androidPasteStatus = "Text an Android gesendet. Das Eingabefeld muss im Gast aktiv sein."
            return true
        } catch {
            // Clipboard contents and errors containing payload are never logged.
            androidPasteStatus = "Text konnte nicht übertragen werden. Android-Verbindung prüfen und erneut versuchen."
            return false
        }
    }
    func openWindowsDriverDisc() {
        guard running, activeGuest == "windows", !windowsPasteBusy,
              windowsPlayer?.sendKeySequence(WindowsKeyboard.explorer) == true else { return }
        playerStatus = "Windows-Explorer angefordert · Unter Dieser PC die eingelegte Treiber-CD öffnen."
    }

    func refreshWindowsIdentity() {
        guard let storage, storageReady else { windowsIdentity = nil; windowsIdentityCanRestore = false; return }
        do {
            let saved = try WindowsIdentityStore.load(root: storage.windows)
            windowsIdentity = saved ?? (FileManager.default.fileExists(atPath: storage.windows.appendingPathComponent("windows.qcow2").path) ? .legacy : nil)
            windowsIdentityStatus = windowsIdentity?.summary ?? "Neue Windows-VM: eigene UUID, Seriennummer und MAC werden vor dem ersten Start gespeichert."
            windowsIdentityCanRestore = try WindowsIdentityStore.canRestore(root: storage.windows)
        } catch {
            windowsIdentity = nil; windowsIdentityCanRestore = false
            windowsIdentityStatus = "Gerätekennung nicht lesbar: " + error.localizedDescription
        }
    }
    func changeWindowsIdentity(restore: Bool = false) async {
        guard !running, !busy, let storage, storageReady else { return }
        busy = true
        defer { busy = false }
        do {
            let value = try await Task.detached(priority: .utility) {
                try WindowsIdentityStore.useUnique(storage: storage, restore: restore)
            }.value
            refreshWindowsIdentity()
            windowsIdentityStatus = (restore ? "Ursprüngliche Kennung wiederhergestellt. " : "Eigene Kennung gespeichert. ") + value.summary
            // Resume the existing OS; changing hardware is not a request to reinstall Windows.
            settings.installWindows = false
            recordDiagnostic("Windows · Gerätekennung", windowsIdentityStatus)
        } catch { errorMessage = error.localizedDescription }
    }
    func verifyWindowsISO() async {
        guard !running, !busy, storageReady, windowsISOReady else { return }
        busy = true
        let path = settings.iso
        hashedISOPath = path
        windowsISOHashDigest = ""
        windowsISOHashStatus = "SHA-256 wird berechnet. Die vorhandene ISO wird nur gelesen …"
        defer { busy = false }
        do {
            let result = try await Task.detached(priority: .utility) { try WindowsISOHash.calculate(path: path) }.value
            guard settings.iso == path else { return }
            windowsISOHashDigest = result.sha256
            let checkedAt = DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .short)
            let detail = result.matchesMicrosoftGerman26H2
                ? "Original bestätigt: Microsoft Windows 11 26H2 · ARM64 · Deutsch. SHA-256 stimmt überein."
                : "Kein Treffer für Microsoft Windows 11 26H2 ARM64 Deutsch. Andere Version/Sprache oder eine veränderte Datei möglich. Das allein beweist keine Beschädigung."
            windowsISOHashStatus = "Prüfergebnis vom \(checkedAt): " + detail
            recordDiagnostic("Windows · ISO-Prüfsumme", windowsISOHashStatus + " SHA-256: " + result.sha256)
        } catch {
            windowsISOHashStatus = "Prüfsumme nicht ermittelt: " + error.localizedDescription
            recordDiagnostic("Windows · ISO-Prüfsumme", windowsISOHashStatus)
        }
    }
    @Published var windowsTextLayout = WindowsTextLayout(rawValue: UserDefaults.standard.string(forKey: "Pixelkoje.windowsTextLayout") ?? "german") ?? .german {
        didSet { UserDefaults.standard.set(windowsTextLayout.rawValue, forKey: "Pixelkoje.windowsTextLayout") }
    }
    @Published private(set) var windowsPasteBusy = false
    @Published private(set) var windowsPasteStatus = ""
    func refreshWindowsISO() {
        if hashedISOPath != settings.iso {
            hashedISOPath = settings.iso
            windowsISOHashDigest = ""
            windowsISOHashStatus = "Originalität der ISO noch nicht geprüft"
        }
        do {
            let info = try WindowsISOInfo.check(path: settings.iso)
            windowsISOReady = true
            windowsISODetail = "ISO-Datei lesbar · " + ByteCountFormatter.string(fromByteCount: info.bytes, countStyle: .file)
        } catch {
            windowsISOReady = false
            windowsISODetail = settings.iso.isEmpty ? "Keine DVD-ISO ausgewählt" : error.localizedDescription
        }
    }
    func chooseWindowsISO() {
        guard !running, !busy else { return }
        let panel = NSOpenPanel()
        panel.title = "Windows-ARM64-ISO als Installations-DVD auswählen"
        panel.prompt = "Als DVD verwenden"
        panel.canChooseFiles = true; panel.canChooseDirectories = false; panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [UTType(filenameExtension: "iso") ?? .data]
        if !settings.iso.isEmpty { panel.directoryURL = URL(fileURLWithPath: settings.iso).resolvingSymlinksInPath().deletingLastPathComponent() }
        else if let storage { panel.directoryURL = storage.url.appendingPathComponent("Installationsmedien") }
        if panel.runModal() == .OK, let url = panel.url {
            settings.iso = url.path
            settings.installWindows = true
            refreshWindowsISO()
        }
    }

    @Published private(set) var windowsFolderStatus = "Windows-Ordner noch nicht geprüft."
    @Published var windowsDiskSize = "80" {
        didSet {
            if let storage, let value = try? WindowsDisk.capacityGiB(windowsDiskSize) {
                UserDefaults.standard.set(value, forKey: "OpenGuest.windowsDiskGiB.\(storage.id)")
            }
        }
    }
    @Published private(set) var windowsDiskBytes: Int64?
    @Published private(set) var windowsDiskStatus = "Größe für die virtuelle Windows-Festplatte wählen."
    var windowsCapacityGiB: Int? { try? WindowsDisk.capacityGiB(windowsDiskSize) }
    var windowsCapacityIssue: String? {
        do {
            let value = try WindowsDisk.capacityGiB(windowsDiskSize)
            if let current = windowsDiskBytes { _ = try WindowsDisk.requiresGrowth(currentBytes: current, requestedGiB: value) }
            return nil
        } catch { return error.localizedDescription }
    }
    func applyWindowsDiskSize() async {
        guard !busy, !running, let storage, storageReady, let qemuImg else { return }
        do {
            let value = try WindowsDisk.capacityGiB(windowsDiskSize)
            busy = true
            defer { busy = false }
            let bytes = try await Task.detached {
                try WindowsDiskImage.prepare(qemuImg: qemuImg, storage: storage, capacityGiB: value)
            }.value
            windowsDiskBytes = bytes
            windowsDiskStatus = "Virtuelle Festplatte: \(value) GB. Zusätzlichen Speicher nach einer Vergrößerung in Windows zuordnen."
            recordDiagnostic("Windows · Festplatte", "Größe angewendet: \(value) GB")
        } catch { windowsDiskStatus = error.localizedDescription; errorMessage = error.localizedDescription }
    }
    func prepareWindowsFolder() {
        guard !busy, !running, let storage else { return }
        do {
            try storage.prepareWindowsFolder()
            windowsFolderStatus = "Windows-Ordner vorhanden und beschreibbar."
            recordDiagnostic("Windows · Datenordner", "Angelegt / geprüft: \(storage.windows.path)")
        } catch { windowsFolderStatus = error.localizedDescription; errorMessage = error.localizedDescription }
    }
    func revealWindowsFolder() {
        guard let storage, storage.windowsFolderReady else { return }
        NSWorkspace.shared.open(storage.windows)
    }
    @Published private(set) var androidReady = false
    @Published private(set) var windowsReady = false
    @Published private(set) var busy = false
    @Published private(set) var running = false
    @Published private(set) var androidBooted = false
    @Published private(set) var apkBusy = false
    @Published private(set) var apkStatus = ""
    @Published private(set) var sessionName = "Kein Gast gestartet"
    @Published private(set) var log = "Pixelkoje 0.3.18 · Entwicklungsprototyp\nSystem prüfen, dann einen Gast auswählen."
    @Published private(set) var lastCommand = ""
    @Published var errorMessage: String? {
        didSet {
            if let message = errorMessage, message != oldValue { recordDiagnostic("Fehler", message) }
        }
    }
    @Published private(set) var diagnosticBusy = false
    @Published private(set) var diagnosticStatus = ""
    private var diagnosticEvents: [String] = []
    private var systemCheckLog = ""
    private func recordDiagnostic(_ category: String, _ message: String) {
        let event = DiagnosticReport.redact("\(category): \(message)")
        diagnosticEvents.append(event)
        if diagnosticEvents.count > 100 { diagnosticEvents.removeFirst(diagnosticEvents.count - 100) }
        if let storage { try? DiagnosticReport.record(event, storage: storage) }
    }
    func exportDiagnostics() async {
        guard !diagnosticBusy, let storage, storageReady else {
            if !storageReady { errorMessage = "Für den Diagnoseexport bitte den gewählten Datenträger anschließen." }
            return
        }
        diagnosticBusy = true
        diagnosticStatus = "Android- und Windows-Protokolle werden zusammengeführt …"
        defer { diagnosticBusy = false }
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Entwicklung"
        let snapshot = """
        Version: \(version)
        macOS: \(ProcessInfo.processInfo.operatingSystemVersionString)
        Mac: \(supportedHost ? "Apple Silicon nativ" : "Nicht unterstützt / Rosetta") · \(totalMemoryGB) GB · \(hostCores) CPU-Kerne
        Datenordner: \(storage.root) · \(storageFree)
        Gast: \(activeGuest.isEmpty ? "Keiner" : activeGuest) · \(sessionName)
        Android: \(androidAcceleration)
        Android-Profil: \(settings.selectedAVD)
        Leistungsprofil: \(androidProfile.rawValue) · Ziel: \(androidTargetFPS) FPS · Stream-Maximum: \(androidProfile.streamMaxSize)
        Android-Bildschirm: \(androidDisplayStatus)
        Android-Grafikrenderer: \(androidRendererStatus)
        Decoder-Zuführung: \(Int(decoderFPS.rounded())) FPS · Wiederanläufe: \(decoderRecoveries) · verworfene verspätete Frames: \(androidDroppedFrames)
        Grafik gewählt: \(settings.gpu) · RAM: \(settings.memoryGB) GB · CPU: \(settings.cores)
        Player: \(playerStatus) · Video-Frames/s: \(Int(streamFPS.rounded()))
        Windows: \(windowsAcceleration)
        Windows-Player-Bilder: \(windowsFrameCount)
        Windows-Ordner: \(windowsFolderStatus)
        Gewünschte Windows-Festplatte: \(windowsDiskSize) GB · Geprüfte Größe in Bytes: \(windowsDiskBytes.map { String($0) } ?? "Noch nicht ermittelt")
        Festplattenstatus: \(windowsDiskStatus)
        Windows-Gerätekennung: \(windowsIdentityStatus)
        ISO-Prüfsumme: \(windowsISOHashStatus) · \(windowsISOHashDigest)
        Windows-Einrichtung: \(settings.installWindows) · lokales Konto: \(settings.localWindowsAccount)
        Benutzername-Länge: \(settings.localWindowsUser.count)
        Kennwortlänge: \(localPassword.count) · Wiederholungslänge: \(localPasswordConfirmation.count) · Übereinstimmung: \(localPassword == localPasswordConfirmation)
        Kontoprüfung (nur Eingabefelder): \(localAccountIssue ?? "Gültig")
        Kennwort merken: \(rememberWindowsCredential)
        Schlüsselbund-Status: \(credentialStatus)
        SDK: \(sdk ?? "Fehlt")
        QEMU: \(qemu ?? "Fehlt")
        swtpm: \(swtpm ?? "Fehlt")
        Firmware: \(firmware ?? "Fehlt")
        Windows-ISO: \(settings.iso)
        DVD-Dateiprüfung: \(windowsISODetail)
        DVD bei QEMU: \(windowsBootMediaStatus)
        Treiber-ISO: \(settings.driversISO)
        Letzte Meldung: \(errorMessage ?? "Keine")
        """
        let check = systemCheckLog
        let events = diagnosticEvents.joined(separator: "\n")
        do {
            let file = try await Task.detached(priority: .utility) {
                try DiagnosticReport.export(storage: storage, snapshot: snapshot, systemCheck: check, recentEvents: events)
            }.value
            diagnosticStatus = "Gemeinsames Protokoll erstellt: \(file.lastPathComponent)"
            NSWorkspace.shared.activateFileViewerSelecting([file])
        } catch { diagnosticStatus = "Diagnoseexport fehlgeschlagen."; errorMessage = error.localizedDescription }
    }
    @Published private(set) var storage = GuestStorage.load()
    @Published var showStorageSetup = GuestStorage.load() == nil
    @Published var proposedStoragePath = ""
    @Published private(set) var storageStatus = "Wähle einen Datenordner, bevor Android oder Windows eingerichtet wird."
    @Published private(set) var backupPaths: [String] = []
    @Published var storageTested = false
    var storageReady: Bool { guard let storage else { return false }; return (try? storage.validate()) != nil }
    var storageFree: String {
        guard let bytes = storage?.freeBytes, storageReady else { return "Speicherort nicht erreichbar" }
        return ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file) + " frei"
    }
    @Published var localPassword = ""
    @Published var localPasswordConfirmation = ""
    @Published var rememberWindowsCredential = UserDefaults.standard.object(forKey: "Pixelkoje.rememberWindowsCredential") as? Bool ?? true {
        didSet { UserDefaults.standard.set(rememberWindowsCredential, forKey: "Pixelkoje.rememberWindowsCredential") }
    }
    @Published private(set) var credentialStatus = "Schlüsselbund noch nicht geprüft. Vorhandene Kontodaten können geladen werden."
    private func persistWindowsCredential(_ account: WindowsEdition.LocalAccount, storage: GuestStorage) async throws {
        let credential = WindowsSetupKeychain.Credential(name: account.name, password: account.password)
        do {
            try await Task.detached { try WindowsSetupKeychain.save(credential, storageID: storage.id) }.value
            credentialStatus = "Benutzername und Kennwort im macOS-Schlüsselbund gespeichert und durch erneutes Lesen geprüft."
            recordDiagnostic("Windows · Schlüsselbund", "Speichern und Leseprüfung erfolgreich")
        } catch {
            credentialStatus = error.localizedDescription
            throw error
        }
    }
    private func restoreWindowsCredentialSilently() async {
        guard rememberWindowsCredential, localPassword.isEmpty, localPasswordConfirmation.isEmpty,
              let storage, storageReady else { return }
        do {
            if let credential = try await Task.detached(operation: {
                try WindowsSetupKeychain.load(storageID: storage.id, allowInteraction: false)
            }).value {
                settings.localWindowsUser = credential.name
                localPassword = credential.password
                localPasswordConfirmation = credential.password
                credentialStatus = "Benutzername und Kennwort aus dem macOS-Schlüsselbund wiederhergestellt."
            } else { credentialStatus = "Für diesen Datenordner sind noch keine Kontodaten im Schlüsselbund gespeichert." }
        } catch { credentialStatus = error.localizedDescription }
        recordDiagnostic("Windows · Schlüsselbund", credentialStatus)
    }
    var localAccountIssue: String? {
        do {
            _ = try WindowsEdition.validateSetupAccount(name: settings.localWindowsUser, password: localPassword,
                                                       confirmation: localPasswordConfirmation)
            return nil
        } catch { return error.localizedDescription }
    }
    func saveWindowsCredential() async {
        guard !busy, !running, let storage, storageReady else { return }
        do {
            recordDiagnostic("Windows · Schlüsselbund speichern", "Benutzername-Länge \(settings.localWindowsUser.count), Kennwortlänge \(localPassword.count), Wiederholungslänge \(localPasswordConfirmation.count), Übereinstimmung \(localPassword == localPasswordConfirmation)")
            let account = try WindowsEdition.validateSetupAccount(name: settings.localWindowsUser,
                password: localPassword, confirmation: localPasswordConfirmation)
            busy = true
            defer { busy = false }
            try await persistWindowsCredential(account, storage: storage)
        } catch { errorMessage = error.localizedDescription }
    }
    func loadWindowsCredential() async {
        guard !busy, !running, let storage, storageReady else { return }
        busy = true
        defer { busy = false }
        do {
            recordDiagnostic("Windows · Schlüsselbund", "Laden angefordert")
            if let credential = try await Task.detached(operation: { try WindowsSetupKeychain.load(storageID: storage.id) }).value {
                settings.localWindowsUser = credential.name
                localPassword = credential.password
                localPasswordConfirmation = credential.password
                credentialStatus = "Kontodaten aus dem macOS-Schlüsselbund geladen."
            } else { credentialStatus = "Für diesen Datenordner sind noch keine Kontodaten gespeichert." }
            recordDiagnostic("Windows · Schlüsselbund", credentialStatus)
        } catch { credentialStatus = error.localizedDescription; errorMessage = error.localizedDescription }
    }
    @Published private(set) var playerImage: NSImage?
    @Published private(set) var playerSize = CGSize.zero
    @Published private(set) var playerStatus = "Player noch nicht gestartet"
    @Published private(set) var activeGuest = ""
    @Published private(set) var streamFPS = 0.0
    @Published private(set) var androidDroppedFrames = 0
    @Published private(set) var androidReconnectBusy = false
    @Published var androidScrollSpeed = GuestScrollSpeed.percent(UserDefaults.standard.object(forKey: "Pixelkoje.scrollSpeed.android") as? Double ?? 50) {
        didSet { UserDefaults.standard.set(GuestScrollSpeed.percent(androidScrollSpeed), forKey: "Pixelkoje.scrollSpeed.android"); resetScroll() }
    }
    @Published var windowsScrollSpeed = GuestScrollSpeed.percent(UserDefaults.standard.object(forKey: "Pixelkoje.scrollSpeed.windows") as? Double ?? 50) {
        didSet { UserDefaults.standard.set(GuestScrollSpeed.percent(windowsScrollSpeed), forKey: "Pixelkoje.scrollSpeed.windows"); resetScroll() }
    }
    @Published var androidVulkanEnabled = UserDefaults.standard.object(forKey: "Pixelkoje.androidVulkanEnabled") as? Bool ?? true {
        didSet { UserDefaults.standard.set(androidVulkanEnabled, forKey: "Pixelkoje.androidVulkanEnabled"); settings.coldBoot = true }
    }
    @Published private(set) var windowsFrameCount = 0
    @Published private(set) var googleServicesStatus = "Google-Dienste werden nach dem Android-Start geprüft."
    let h264Player = H264Player()
    let installer = SetupInstaller()
    private let playerWindows = GuestPlayerWindows()

    func showPlayer(kind: String) { playerWindows.show(kind: kind, model: self) }
    func togglePlayerFullScreen(kind: String) { playerWindows.toggleFullScreen(kind: kind) }
    func fitAndroidPlayerWindow() {
        UserDefaults.standard.set(true, forKey: "Pixelkoje.playerFit.android")
        playerWindows.fitAndroid(model: self)
    }

    var setupReady: Set<SetupComponent> {
        guard let storage, storageReady else { return [] }
        let fm = FileManager.default
        func externalFile(_ path: String) -> Bool {
            let resolved = URL(fileURLWithPath: path).resolvingSymlinksInPath().path
            let root = storage.url.resolvingSymlinksInPath().path
            return !path.isEmpty && resolved.hasPrefix(root + "/") && fm.isReadableFile(atPath: path)
        }
        var ready: Set<SetupComponent> = []
        if fm.isExecutableFile(atPath: storage.sdk.appendingPathComponent("emulator/emulator").path),
           fm.isExecutableFile(atPath: storage.sdk.appendingPathComponent("platform-tools/adb").path) {
            for system in AndroidSystem.allCases {
                let relative = "system-images/\(system.platform)/google_apis_playstore/arm64-v8a/system.img"
                if fm.isReadableFile(atPath: storage.sdk.appendingPathComponent(relative).path),
                   devices.contains(where: { androidSystem(for: $0.name) == system }) {
                    ready.insert(system == .android16 ? .android : .android17)
                }
            }
        }
        if ScrcpySession.installed { ready.insert(.streaming) }
        if externalFile(settings.iso) { ready.insert(.windowsISO) }
        if externalFile(settings.driversISO) { ready.insert(.windowsDrivers) }
        return ready
    }

    func installComponents(_ selection: Set<SetupComponent>, microsoftLink: String) async {
        guard !busy, !running, let storage, !selection.isEmpty else { return }
        busy = true
        do {
            let result = try await installer.install(selection, storage: storage, existingISO: settings.iso,
                existingDrivers: settings.driversISO, microsoftLink: microsoftLink, ready: setupReady, androidChannel: androidSDKChannel, preferredAndroidProfile: settings.selectedAVD)
            if let iso = result.iso { settings.iso = iso }
            if let drivers = result.drivers { settings.driversISO = drivers }
            // Pick up a driver ISO left by a previous interrupted setup as well.
            let drivers = storage.url.appendingPathComponent("Installationsmedien/utm-guest-tools.iso")
            if settings.driversISO.isEmpty, (try? SetupInstaller.validateISO(drivers)) != nil {
                settings.driversISO = drivers.path
            }
        } catch { errorMessage = error.localizedDescription }
        busy = false
        await refresh()
        if selection.contains(.android17), let device = devices.first(where: { androidSystem(for: $0.name) == .android17 }) {
            settings.selectedAVD = device.name
            settings.coldBoot = true
        } else if selection.contains(.android), let device = devices.first(where: { androidSystem(for: $0.name) == .android16 }) {
            settings.selectedAVD = device.name
            settings.coldBoot = true
        }
    }

    @Published var androidSDKChannel = min(3, max(0, UserDefaults.standard.integer(forKey: "Pixelkoje.androidSDKChannel"))) {
        didSet { UserDefaults.standard.set(androidSDKChannel, forKey: "Pixelkoje.androidSDKChannel") }
    }
    @Published var androidCheckUpdatesOnOpen = UserDefaults.standard.object(forKey: "Pixelkoje.androidCheckUpdatesOnOpen") as? Bool ?? true {
        didSet { UserDefaults.standard.set(androidCheckUpdatesOnOpen, forKey: "Pixelkoje.androidCheckUpdatesOnOpen") }
    }
    @Published var androidAutoUpdateBeforeStart = UserDefaults.standard.bool(forKey: "Pixelkoje.androidAutoUpdateBeforeStart") {
        didSet { UserDefaults.standard.set(androidAutoUpdateBeforeStart, forKey: "Pixelkoje.androidAutoUpdateBeforeStart") }
    }
    @Published private(set) var androidMaintenanceStatus = "Android 16 ist das Standardsystem. Android 17 wird separat eingerichtet."
    @Published private(set) var androidCleanupPlan: AndroidCleanupPlan?

    func androidSystem(for name: String) -> AndroidSystem? {
        guard let storage else { return nil }
        return AndroidSystem.detect(RuntimeDiscovery.avdConfig(name: name, environment: storage.environment))
    }
    var selectedAndroidSystem: AndroidSystem? { androidSystem(for: settings.selectedAVD) }
    var canManageAndroid: Bool { storageReady && !running && !busy && !installer.running }

    func manageAndroidUpdates(install: Bool) async {
        guard canManageAndroid, let storage, let system = selectedAndroidSystem else { return }
        busy = true
        errorMessage = nil
        do {
            try await installer.manageAndroid(system, mode: install ? "update" : "check", channel: androidSDKChannel, storage: storage)
            if install { settings.coldBoot = true; androidCleanupPlan = nil }
            androidMaintenanceStatus = installer.status
            recordDiagnostic("Android · Updates", "Android \(system.rawValue), Kanal \(androidSDKChannel), \(install ? "Abbild aktualisiert" : "Updateprüfung")")
        } catch {
            androidMaintenanceStatus = error.localizedDescription
            errorMessage = error.localizedDescription
        }
        busy = false
        if install { await refresh() }
    }

    private func requireAndroidStopped() async throws {
        let result = try await Self.capture(CommandSpec(executable: "/usr/bin/pgrep", arguments: ["-f", "/emulator/qemu/|sdk/emulator/emulator"]))
        guard result.status == 1 else {
            throw StorageMigration.failure("Bitte auch separat gestartete Android-Emulatoren vollständig beenden.")
        }
    }
    func previewAndroidCleanup() async {
        guard canManageAndroid, let storage else { return }
        androidCleanupPlan = nil
        busy = true
        let name = settings.selectedAVD
        do {
            try await requireAndroidStopped()
            let plan = try await Task.detached { try AndroidMaintenance.plan(storage: storage, keeping: name) }.value
            androidCleanupPlan = plan
            androidMaintenanceStatus = plan.paths.isEmpty ? "Keine alten Android-Daten gefunden." : "\(plan.paths.count) Einträge zur endgültigen Entfernung. Android 16 bleibt erhalten."
        } catch { androidMaintenanceStatus = error.localizedDescription; errorMessage = error.localizedDescription }
        busy = false
    }
    func cleanupOldAndroid() async {
        guard canManageAndroid, let storage, let plan = androidCleanupPlan, plan.keeping == settings.selectedAVD else { return }
        busy = true
        do {
            try await requireAndroidStopped()
            try await Task.detached { try AndroidMaintenance.cleanup(storage: storage, expected: plan) }.value
            androidCleanupPlan = nil
            settings.coldBoot = true
            androidMaintenanceStatus = "Alte Android-Profile, andere Systemabbilder und erkannte alte Android-Sicherungen entfernt. Android 16 bleibt erhalten."
            recordDiagnostic("Android · Bereinigung", "\(plan.paths.count) Einträge entfernt; Profil \(plan.keeping) erhalten")
        } catch { androidMaintenanceStatus = error.localizedDescription; errorMessage = error.localizedDescription; androidCleanupPlan = nil }
        busy = false
        await refresh()
    }

    private var process: Process?
    private var output: FileHandle?
    private var logURL: URL?
    private var sessionCommand = ""
    private var timer: Timer?
    private var bootTask: Task<Void, Never>?
    private var androidPort: Int?
    private var windowsSession: WindowsSession?
    private var opened = false
    private var androidStream: ScrcpySession?
    private var windowsPlayer: RFBClient?
    private var displayTask: Task<Void, Never>?
    private var qmpSocket: String?
    private var windowsBootProbe: Task<Void, Never>?
    private var windowsPasteTask: Task<Void, Never>?
    private var stopRequested = false

    let totalMemoryGB = Int(ProcessInfo.processInfo.physicalMemory / 1_073_741_824)
    let hostCores = ProcessInfo.processInfo.activeProcessorCount
    var maxMemoryGB: Int { max(2, min(8, totalMemoryGB / 2)) }
    var maxCores: Int { max(2, min(8, hostCores - 2)) }
    var supportedHost: Bool {
        #if arch(arm64)
        return true
        #else
        return false
        #endif
    }
    var hypervisorAvailable: Bool {
        var value: Int32 = 0
        var size = MemoryLayout<Int32>.size
        return sysctlbyname("kern.hv_support", &value, &size, nil, 0) == 0 && value == 1
    }
    var selectedDevice: AndroidDevice? { devices.first { $0.name == settings.selectedAVD } }
    var canStartAndroid: Bool {
        storageReady && supportedHost && hypervisorAvailable && androidReady && selectedDevice?.supported == true && adb != nil && ScrcpySession.installed && androidDisplayIssue == nil && !busy && !running
    }
    private var windowsHostReady: Bool {
        storageReady && storage?.windowsFolderReady == true && windowsCapacityIssue == nil && supportedHost && hypervisorAvailable && windowsReady && firmware != nil && settings.memoryGB >= 4 && !busy && !running
    }
    var canStartWindows: Bool {
        windowsHostReady && (settings.installWindows
            ? (windowsISOReady && (!settings.localWindowsAccount || localAccountIssue == nil))
            : windowsDiskBytes != nil)
    }
    var canResumeWindows: Bool { windowsHostReady && windowsDiskBytes != nil }
    var canInstallAPK: Bool { running && androidBooted && androidPort != nil && !apkBusy && !busy && !androidDisplayBusy && adb != nil }
    var adb: String? {
        guard let sdk else { return nil }
        let path = URL(fileURLWithPath: sdk).appendingPathComponent("platform-tools/adb").path
        return FileManager.default.isExecutableFile(atPath: path) ? path : nil
    }
    var resources: GuestResources { GuestResources(memoryMiB: settings.memoryGB * 1024, cores: settings.cores) }

    init() {
        if !UserDefaults.standard.bool(forKey: "Pixelkoje.performanceDefaultsApplied") {
            if settings.gpu == "auto" { settings.gpu = "host"; settings.save() }
            UserDefaults.standard.set(true, forKey: "Pixelkoje.performanceDefaultsApplied")
        }
        settings.memoryGB = min(max(2, settings.memoryGB), maxMemoryGB)
        settings.cores = min(max(2, settings.cores), maxCores)
    }

    func open() async {
        guard !opened else { return }
        opened = true
        guard storage != nil else { showStorageSetup = true; return }
        updateBackupPaths()
        await refresh()
        // Prefer the saved disk when upgrading from versions that kept DVD boot enabled.
        if windowsDiskBytes != nil { settings.installWindows = false }
        if androidCheckUpdatesOnOpen, canManageAndroid, selectedAndroidSystem != nil,
           Date().timeIntervalSince1970 - UserDefaults.standard.double(forKey: "Pixelkoje.androidLastUpdateCheck") > 86_400 {
            UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: "Pixelkoje.androidLastUpdateCheck")
            await manageAndroidUpdates(install: false)
        }
        // Launching Pixelkoje only prepares the main window. Guests always start on an explicit click.
    }

    func refresh() async {
        guard !busy, !running else { return }
        guard let storage else { showStorageSetup = true; return }
        do { try storage.validate() } catch { errorMessage = error.localizedDescription; return }
        busy = true
        defer { busy = false; systemCheckLog = log; recordDiagnostic("Systemprüfung", log) }
        refreshWindowsISO()
        refreshWindowsIdentity()
        loadWindowsDisplayChoice()
        windowsFolderStatus = storage.windowsFolderReady ? "Windows-Ordner vorhanden und beschreibbar." : "Bitte den Windows-Ordner vor dem ersten Start anlegen."
        androidReady = false
        windowsReady = false
        devices = []
        sdk = RuntimeDiscovery.sdk(preferred: storage.sdk.path, environment: storage.environment)
        qemu = RuntimeDiscovery.qemu(preferred: settings.qemu)
        swtpm = RuntimeDiscovery.swtpm(preferred: settings.swtpm)
        qemuImg = qemu.flatMap { RuntimeDiscovery.sibling(executable: $0, name: "qemu-img") }
        windowsDiskBytes = nil
        let image = storage.windows.appendingPathComponent("windows.qcow2")
        if let qemuImg, FileManager.default.fileExists(atPath: image.path) {
            do {
                windowsDiskBytes = try await Task.detached { try WindowsDiskImage.info(qemuImg: qemuImg, disk: image) }.value
                windowsDiskStatus = "Vorhandene Festplatte: \((windowsDiskBytes ?? 0) / 1_073_741_824) GB."
            } catch { windowsDiskStatus = "Festplattengröße nicht prüfbar: \(error.localizedDescription)" }
        } else { windowsDiskStatus = "Noch keine Windows-Festplatte angelegt. Sie wird mit der gewählten Größe erstellt." }
        let saved = UserDefaults.standard.integer(forKey: "OpenGuest.windowsDiskGiB.\(storage.id)")
        let currentGiB = windowsDiskBytes.map { Int(($0 + 1_073_741_823) / 1_073_741_824) }
        windowsDiskSize = String(max(saved == 0 ? (currentGiB ?? 80) : saved, currentGiB ?? 0))
        firmware = qemu.flatMap { RuntimeDiscovery.firmware(qemu: $0, preferred: settings.firmware) }
        variablesTemplate = firmware.flatMap { RuntimeDiscovery.variablesTemplate(firmware: $0) }
        androidAcceleration = sdk == nil ? "Android Emulator fehlt" : "Prüfung läuft …"
        windowsAcceleration = qemu == nil ? "QEMU fehlt" : "Prüfung läuft …"
        log = "Mac: \(supportedHost ? "Apple Silicon (nativ)" : "Architektur nicht unterstützt / Rosetta") · \(totalMemoryGB) GB RAM · \(hostCores) Kerne\nHypervisor: \(hypervisorAvailable ? "verfügbar" : "nicht verfügbar")\n"

        if let sdk {
            let engine = URL(fileURLWithPath: sdk).appendingPathComponent("emulator/emulator").path
            let environment = storage.environment
            do {
                let result = try await Self.capture(CommandSpec(executable: engine, arguments: ["-accel-check"], environment: environment))
                androidReady = result.status == 0
                androidAcceleration = androidReady ? "Hardwarebeschleunigung verfügbar" : "Beschleunigung nicht nutzbar"
                log += "\nAndroid: \(result.output)\n"
                let list = try await Self.capture(CommandSpec(executable: engine, arguments: ["-list-avds"], environment: environment))
                guard list.status == 0 else { throw GuestError.commandFailed(list.status, list.output) }
                devices = list.output.components(separatedBy: .newlines)
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty && !$0.contains(" ") && !$0.contains(":") && !$0.contains("/") }
                    .map { RuntimeDiscovery.device(name: $0, environment: environment) }
                if !devices.contains(where: { $0.name == settings.selectedAVD }) || selectedAndroidSystem == nil {
                    settings.selectedAVD = devices.first(where: { $0.supported && androidSystem(for: $0.name) == .android16 })?.name
                        ?? devices.first(where: { $0.supported && $0.googlePlay })?.name ?? devices.first(where: \.supported)?.name ?? devices.first?.name ?? ""
                }
                if devices.isEmpty { log += "Kein AVD gefunden. In Android Studio ein arm64-v8a-Gerät erstellen.\n" }
            } catch {
                androidReady = false
                androidAcceleration = "Android-Prüfung fehlgeschlagen"
                log += "\n\(error.localizedDescription)\n"
            }
        }
        if let qemu {
            do {
                let acceleration = try await Self.capture(CommandSpec(executable: qemu, arguments: ["-accel", "help"]))
                let display = try await Self.capture(CommandSpec(executable: qemu, arguments: ["-help"]))
                let hardware = try await Self.capture(CommandSpec(executable: qemu, arguments: ["-device", "help"]))
                let hasHVF = acceleration.output.components(separatedBy: .whitespacesAndNewlines).contains("hvf")
                let hasCocoa = display.output.contains("-vnc")
                let hasTPM = RuntimeDiscovery.hasDevice("tpm-tis-device", in: hardware.output)
                windowsReady = acceleration.status == 0 && display.status == 0 && hardware.status == 0 && hasHVF && hasCocoa && hasTPM && swtpm != nil && qemuImg != nil && variablesTemplate != nil
                windowsAcceleration = windowsReady ? "HVF, VNC, TPM und UEFI-Dateien gefunden · Secure Boot nicht geprüft" : "QEMU, swtpm oder passende UEFI-Dateien fehlen"
                log += "\nQEMU-Beschleuniger:\n\(acceleration.output)\nQEMU-Geräte:\n\(hardware.output)\n"
                if firmware == nil { log += "ARM64-UEFI-Firmware fehlt. Bitte eine edk2-aarch64-code.fd auswählen.\n" }
                if swtpm == nil { log += "swtpm fehlt. Für Windows wird ein dauerhaftes TPM 2.0 benötigt.\n" }
                if !hasTPM { log += "QEMU-Build enthält kein ARM-TPM (tpm-tis-device).\n" }
                var missing: [String] = []
                if !hasHVF { missing.append("HVF") }
                if !hasCocoa { missing.append("VNC") }
                if !hasTPM { missing.append("ARM-TPM (tpm-tis-device)") }
                if swtpm == nil { missing.append("swtpm") }
                if qemuImg == nil { missing.append("qemu-img") }
                if firmware == nil { missing.append("ARM64-UEFI") }
                if variablesTemplate == nil { missing.append("passende UEFI-Variablen") }
                if !missing.isEmpty { windowsAcceleration = "Fehlt: " + missing.joined(separator: ", ") }
                if variablesTemplate == nil { log += "edk2-arm-vars.fd fehlt neben der gewählten Firmware.\n" }
            } catch {
                windowsAcceleration = "QEMU-Prüfung fehlgeschlagen"
                log += "\n\(error.localizedDescription)\n"
            }
        }
        await restoreWindowsCredentialSilently()
    }

    private static func capture(_ spec: CommandSpec, timeout: TimeInterval = 12) async throws -> CommandResult {
        try await Task.detached(priority: .userInitiated) { try CommandCapture.run(spec, timeout: timeout) }.value
    }

    func startAndroid() {
        if androidAutoUpdateBeforeStart, selectedAndroidSystem != nil {
            Task {
                await manageAndroidUpdates(install: true)
                if errorMessage == nil { launchAndroid() }
            }
        } else { launchAndroid() }
    }

    private func launchAndroid() {
        guard canStartAndroid, let sdk, let storage, let device = selectedDevice else { return }
        do {
            try checkStorageSpace(minimumGB: 16)
            let port = try AndroidPorts.available()
            let base = try LaunchPlan.android(sdk: sdk, device: device, resources: resources,
                                              coldBoot: settings.coldBoot, gpu: settings.gpu, port: port, vulkan: androidVulkanEnabled)
            let spec = CommandSpec(executable: base.executable, arguments: base.arguments, environment: storage.environment)
            try start(spec, title: "Android · \(device.name)")
            activeGuest = "android"
            androidRendererStatus = "Grafikrenderer wird geprüft"; androidSoftwareRendering = false
            androidDisplayStatus = "Leistungsprofil wird angewendet, sobald Android bereit ist"
            streamFPS = 0; decoderFPS = 0; decoderRecoveries = 0
            recordDiagnostic("Android · Leistung", "Profil \(androidProfile.rawValue), Ziel \(androidTargetFPS) FPS, GPU angefordert \(settings.gpu), Vulkan \(androidVulkanEnabled ? "erlaubt" : "aus"), begrenzte Stream-Warteschlange")
            playerStatus = "Android startet …"
            androidPort = port
            androidBooted = false
            apkStatus = "Android startet …"
            showPlayer(kind: "android")
            watchAndroidBoot(port: port)
        } catch { errorMessage = error.localizedDescription }
    }

    func startWindows() {
        refreshWindowsISO()
        Task { await startWindowsVM() }
    }

    func startExistingWindows() {
        guard canResumeWindows else { return }
        settings.installWindows = false
        startWindows()
    }

    private func startWindowsVM() async {
        guard canStartWindows, let capacity = windowsCapacityGiB, let qemu, let firmware, let qemuImg, let swtpm, let variablesTemplate else { return }
        let installing = settings.installWindows
        busy = true
        defer { busy = false }
        let session = WindowsSession()
        do {
            try checkStorageSpace(minimumGB: installing ? 25 : 2)
            var account: WindowsEdition.LocalAccount?
            if installing && settings.localWindowsAccount {
                account = try WindowsEdition.validateSetupAccount(name: settings.localWindowsUser,
                    password: localPassword, confirmation: localPasswordConfirmation)
            }
            guard FileManager.default.isReadableFile(atPath: firmware) else { throw GuestError.missingFile(firmware) }
            if installing { _ = try WindowsISOInfo.check(path: settings.iso) }
            if !settings.driversISO.isEmpty, settings.driversISO == settings.iso {
                throw StorageMigration.failure("Windows-ISO und Treiber-ISO sind identisch. Bitte die Treiber-Auswahl entfernen oder eine separate ARM64-Treiber-ISO wählen.")
            }
            if !settings.driversISO.isEmpty, !FileManager.default.isReadableFile(atPath: settings.driversISO) {
                throw GuestError.missingFile(settings.driversISO)
            }
            if rememberWindowsCredential, let account, let storage {
                try await persistWindowsCredential(account, storage: storage)
            }
            let files = try await session.prepare(qemuImg: qemuImg, swtpm: swtpm, variablesTemplate: variablesTemplate,
                                                  capacityGiB: capacity, selectPro: installing && settings.selectPro, localAccount: account)
            windowsDiskBytes = Int64(capacity) * 1_073_741_824
            let spec = try LaunchPlan.windowsVM(qemu: qemu, firmware: firmware, variables: files.variables, disk: files.disk,
                                               tpmSocket: files.socket, iso: settings.iso, driversISO: settings.driversISO,
                                               proISO: files.proISO, installing: installing, resources: resources,
                                               displaySocket: files.displaySocket, network: settings.windowsNetwork, qmpSocket: files.qmpSocket, identity: files.identity,
                                               graphics: windowsGraphics, resolution: windowsResolution)
            recordDiagnostic("Windows · Grafik", windowsGraphics.title + " · bevorzugter Modus " + windowsResolution.title)
            windowsIdentity = files.identity
            windowsIdentityStatus = files.identity.summary
            recordDiagnostic("Windows · Gerätekennung", files.identity.summary)
            windowsSession = session
            try start(spec, title: "Windows 11 Pro Arm64")
            // Consume the DVD choice after a successful process launch, retaining its path.
            settings.installWindows = false
            recordDiagnostic("Windows · Startmedium", installing
                ? "Einmaliger DVD-Start; nächster Start von der gespeicherten Festplatte."
                : "Start von der gespeicherten Festplatte; keine Installations-DVD eingebunden.")
            activeGuest = "windows"
            showPlayer(kind: "windows")
            qmpSocket = files.qmpSocket
            connectWindowsPlayer(socket: files.displaySocket)
            inspectWindowsBoot(socket: files.qmpSocket, installing: installing)
        } catch {
            await session.stop()
            windowsSession = nil
            errorMessage = error.localizedDescription
        }
    }

    private func watchAndroidBoot(port: Int) {
        bootTask?.cancel()
        guard let adb else { apkStatus = "Für APK-Installation bitte Android SDK Platform-Tools installieren."; return }
        bootTask = Task { [weak self] in
            for _ in 0..<180 {
                guard !Task.isCancelled, let self, self.running, self.androidPort == port else { return }
                let result = try? await Self.capture(CommandSpec(executable: adb,
                    arguments: ["-s", "emulator-\(port)", "shell", "getprop", "sys.boot_completed"]), timeout: 8)
                guard !Task.isCancelled, self.running, self.androidPort == port else { return }
                if result?.status == 0 && result?.output.trimmingCharacters(in: .whitespacesAndNewlines) == "1" {
                    self.androidBooted = true
                    await self.applyAndroidDisplay(port: port)
                    guard !Task.isCancelled, self.running, self.androidPort == port else { return }
                    self.apkStatus = "Android bereit · APKs können installiert werden"
                    await self.connectAndroidPlayer(port: port)
                    await self.checkGoogleServices(port: port)
                    return
                }
                try? await Task.sleep(nanoseconds: 2_000_000_000)
            }
            self?.apkStatus = "Android noch nicht bereit. Gastfenster prüfen; danach Android erneut starten."
        }
    }

    private func applyAndroidDisplay(port: Int) async {
        guard let adb else { return }
        let serial = "emulator-\(port)"
        do {
            let size = try await Self.capture(CommandSpec(executable: adb, arguments: ["-s", serial, "shell", "wm", "size"]))
            let density = try await Self.capture(CommandSpec(executable: adb, arguments: ["-s", serial, "shell", "wm", "density"]))
            guard size.status == 0, density.status == 0 else { throw GuestError.commandFailed(1, "Bildschirmwerte nicht lesbar") }
            let plan = try AndroidDisplayPlan(sizeOutput: size.output, densityOutput: density.output, profile: androidProfile,
                                             custom: requestedAndroidDisplay())
            do {
                for command in plan.commands {
                    try Task.checkCancellation()
                    guard running, androidPort == port else { return }
                    let result = try await Self.capture(CommandSpec(executable: adb, arguments: ["-s", serial, "shell"] + command))
                    guard result.status == 0, !result.output.lowercased().contains("error:") else {
                        throw GuestError.commandFailed(result.status, result.output)
                    }
                }
                androidDisplayStatus = plan.summary + " · Stream bis \(androidProfile.streamMaxSize) px"
            } catch {
                if running, androidPort == port {
                    for command in plan.rollback {
                        _ = try? await Self.capture(CommandSpec(executable: adb, arguments: ["-s", serial, "shell"] + command))
                    }
                }
                throw error
            }
        } catch { androidDisplayStatus = "Auflösung nicht angepasst; bisherige Werte bleiben soweit möglich erhalten: \(error.localizedDescription)" }
        recordDiagnostic("Android · Bildschirm", androidDisplayStatus)
    }

    private func connectAndroidPlayer(port: Int) async {
        guard let adb, running, androidPort == port else { return }
        h264Player.reset()
        let stream = ScrcpySession()
        h264Player.onSize = { [weak self, weak stream] size in
            self?.playerSize = size; stream?.setSize(size)
        }
        h264Player.onStatistics = { [weak self] fps, recoveries in
            self?.decoderFPS = fps; self?.decoderRecoveries = recoveries
        }
        stream.onPacket = { [weak self] data, pts, config in try await self?.h264Player.packet(data, pts: pts, configuration: config) }
        stream.onSize = { [weak self] size in self?.playerSize = size }
        stream.onStatus = { [weak self] text in self?.playerStatus = text }
        androidDroppedFrames = 0
        stream.onDiscontinuity = { [weak self] in self?.h264Player.resetReferences() }
        stream.onQueueDrops = { [weak self] count in self?.androidDroppedFrames = count }
        stream.onFPS = { [weak self] fps in
            self?.streamFPS = fps
            if fps == 0 { self?.decoderFPS = 0 }
        }
        androidStream = stream
        do {
            try await stream.start(adb: adb, serial: "emulator-\(port)", profile: androidProfile, fps: androidTargetFPS)
            if Task.isCancelled || !running { await stream.stop() }
        } catch {
            await stream.stop()
            if !Task.isCancelled { playerStatus = "Android-Anzeige konnte nicht starten: \(error.localizedDescription)" }
        }
    }

    var canReconnectAndroidDisplay: Bool {
        running && activeGuest == "android" && androidBooted && !busy && !androidReconnectBusy
    }
    func reconnectAndroidDisplay() async {
        guard canReconnectAndroidDisplay, let port = androidPort else { return }
        androidReconnectBusy = true
        defer { androidReconnectBusy = false }
        playerStatus = "Android-Anzeige wird neu verbunden …"
        if let stream = androidStream { await stream.stop() }
        guard running, androidPort == port else { return }
        androidStream = nil
        await connectAndroidPlayer(port: port)
        recordDiagnostic("Android · Anzeige", "Stream auf Benutzerwunsch neu verbunden; Gast nicht neu gestartet")
    }

    private func inspectWindowsBoot(socket: String, installing: Bool) {
        windowsBootProbe?.cancel()
        windowsBootMediaStatus = installing ? "Installations-DVD wird mit QEMU verbunden …" : "Start von gespeicherter Windows-Festplatte angefordert"
        windowsBootProbe = Task { [weak self] in
            let deadline = ProcessInfo.processInfo.systemUptime + 10
            while !FileManager.default.fileExists(atPath: socket), ProcessInfo.processInfo.systemUptime < deadline {
                guard !Task.isCancelled, self?.running == true else { return }
                try? await Task.sleep(nanoseconds: 100_000_000)
            }
            guard let self, self.running, !Task.isCancelled else { return }
            do {
                let evidence = try await QMPClient.inspect(socket: socket)
                guard self.running, !Task.isCancelled else { return }
                if installing {
                    self.windowsBootMediaStatus = evidence.machineStatus + (evidence.dvdConnected
                        ? " · Installations-DVD verbunden: " + (evidence.dvdPath ?? self.settings.iso)
                        : " · QEMU meldet keine eingelegte, schreibgeschützte Installations-DVD")
                } else { self.windowsBootMediaStatus = evidence.machineStatus + " · Start von gespeicherter Festplatte" }
            } catch {
                guard !Task.isCancelled else { return }
                self.windowsBootMediaStatus = "DVD-/Startstatus konnte nicht von QEMU gelesen werden: \(error.localizedDescription)"
            }
            self.recordDiagnostic("Windows · Startmedium", self.windowsBootMediaStatus)
            do {
                let actual = try await QMPClient.machineUUID(socket: socket)
                guard self.running, !Task.isCancelled else { return }
                let expected = self.windowsIdentity?.uuid ?? "00000000-0000-0000-0000-000000000000"
                self.windowsIdentityStatus = actual == expected
                    ? "QEMU bestätigt VM-UUID: " + actual + (self.windowsIdentity?.mode == .legacy ? " · bisherige Standardkennung" : " · eigene Gerätekennung")
                    : "VM-UUID weicht von der gespeicherten Kennung ab: " + actual
            } catch {
                guard !Task.isCancelled else { return }
                self.windowsIdentityStatus = "VM-UUID nicht bei QEMU bestätigt: " + error.localizedDescription
            }
            self.recordDiagnostic("Windows · Gerätekennung geprüft", self.windowsIdentityStatus)
        }
    }

    private func connectWindowsPlayer(socket: String) {
        playerStatus = "Warte auf Windows-Bildschirmanschluss …"
        windowsFrameCount = 0
        displayTask = Task { [weak self] in
            let deadline = ProcessInfo.processInfo.systemUptime + 20
            while ProcessInfo.processInfo.systemUptime < deadline {
                guard let self, self.running, !Task.isCancelled else { return }
                if !FileManager.default.fileExists(atPath: socket) {
                    try? await Task.sleep(nanoseconds: 100_000_000)
                    continue
                }
                let client = RFBClient()
                self.windowsPlayer = client
                client.onFrame = { [weak self] image in
                    guard let self else { return }
                    self.playerImage = image; self.playerSize = image.size
                    self.windowsFrameCount += 1
                    if self.windowsFrameCount == 1 {
                        self.recordDiagnostic("Windows · Anzeige", "Erstes Bild empfangen: \(Int(image.size.width)) × \(Int(image.size.height))")
                    }
                }
                client.onStatus = { [weak self] text in
                    self?.playerStatus = text
                    self?.recordDiagnostic("Windows · Anzeige", text)
                }
                let firstFrameTimeout = Task {
                    try? await Task.sleep(nanoseconds: 15_000_000_000)
                    if !Task.isCancelled, self.windowsFrameCount == 0 { client.stop() }
                }
                do {
                    try await client.run(socket: socket)
                    firstFrameTimeout.cancel()
                    return
                } catch {
                    firstFrameTimeout.cancel()
                    if client.initialized {
                        if !Task.isCancelled {
                            self.playerStatus = self.windowsFrameCount == 0
                                ? "QEMU liefert kein erstes Bild. Bitte Gesamtprotokoll exportieren."
                                : "Windows-Anzeige: \(error.localizedDescription)"
                            self.recordDiagnostic("Windows · Anzeige", self.playerStatus)
                        }
                        return
                    }
                    self.recordDiagnostic("Windows · Anzeigeverbindung", error.localizedDescription)
                }
                try? await Task.sleep(nanoseconds: 200_000_000)
            }
            self?.playerStatus = "Windows-Bildschirm nicht erreichbar. DVD-/Startstatus und Gesamtprotokoll prüfen."
            if let self { self.recordDiagnostic("Windows · Anzeige", self.playerStatus) }
        }
    }

    func pointer(x: Int, y: Int, mask: UInt8) {
        if activeGuest == "windows", windowsPasteBusy { return }
        if activeGuest == "android" { androidStream?.pointer(x: x, y: y, mask: mask) }
        else if activeGuest == "windows" { windowsPlayer?.pointer(x: x, y: y, mask: mask) }
    }

    func scroll(x: Int, y: Int, horizontal: Double, vertical: Double, mask: UInt8) {
        let speed = activeGuest == "windows" ? windowsScrollSpeed : androidScrollSpeed
        let h = GuestScrollSpeed.scale(horizontal, percent: speed)
        let v = GuestScrollSpeed.scale(vertical, percent: speed)
        if activeGuest == "windows", !windowsPasteBusy { windowsPlayer?.scroll(x: x, y: y, vertical: v, mask: mask) }
        else if activeGuest == "android" { androidStream?.scroll(x: x, y: y, horizontal: h, vertical: v, mask: mask) }
    }
    func resetScroll() { windowsPlayer?.resetScroll() }

    func openWindowsDisplaySettings() {
        guard running, activeGuest == "windows", !windowsPasteBusy,
              windowsPlayer?.sendKeySequence(WindowsKeyboard.settings) == true else { return }
        playerStatus = "Windows + I gesendet · Unter System → Anzeige Auflösung und Windows-Skalierung wählen."
    }

    func keyboard(code: UInt16, text: String, down: Bool) {
        if activeGuest == "windows", windowsPasteBusy { return }
        if activeGuest == "android" {
            let special: [UInt16: UInt32] = [36: 66, 51: 67, 48: 61, 53: 111, 123: 21, 124: 22, 125: 20, 126: 19,
                117: 112, 115: 122, 119: 123, 116: 92, 121: 93, 56: 59, 60: 60, 59: 113, 62: 114, 58: 57, 61: 58, 55: 117, 54: 118]
            if let key = special[code] { androidStream?.key(key, down: down) }
            else if down && !text.isEmpty { androidStream?.text(text) }
        } else if activeGuest == "windows" {
            if let symbol = WindowsKeyboard.symbol(code: code, text: text) { windowsPlayer?.key(symbol, down: down) }
        }
    }

    func openWindowsSetupConsole() {
        guard running, activeGuest == "windows", !windowsPasteBusy,
              windowsPlayer?.sendKeySequence(WindowsKeyboard.setupConsole) == true else { return }
        playerStatus = "Shift + F10 an Windows gesendet · Zum Tippen in das Windows-Bild klicken."
    }

    func pasteWindowsText(_ input: WindowsTextInput) {
        guard running, activeGuest == "windows", !windowsPasteBusy, let socket = qmpSocket else { return }
        windowsPasteBusy = true
        windowsPasteStatus = "Text wird eingefügt: 0 / \(input.count) Zeichen …"
        windowsPasteTask = Task { [weak self] in
            guard let self else { return }
            var completed = 0
            defer { self.windowsPasteBusy = false; self.windowsPasteTask = nil }
            do {
                try await QMPClient.typeText(input, socket: socket) { count in
                    completed = count
                    self.windowsPasteStatus = "Text wird eingefügt: \(count) / \(input.count) Zeichen …"
                }
                self.windowsPasteStatus = "\(input.count) Zeichen an Windows übertragen. Bei einem Befehl jetzt Enter im Windows-Fenster drücken."
            } catch {
                self.windowsPasteStatus = Task.isCancelled
                    ? "Einfügen abgebrochen. Bereits übertragener Text bleibt im Windows-Feld stehen."
                    : "Einfügen unterbrochen (\(completed) / \(input.count) Zeichen bestätigt). \(error.localizedDescription)"
            }
        }
    }

    func cancelWindowsPaste() { windowsPasteTask?.cancel() }

    func androidNavigation(_ code: UInt32) { androidStream?.key(code, down: true); androidStream?.key(code, down: false) }

    private func checkGoogleServices(port: Int) async {
        guard let adb, running, androidPort == port else { return }
        do {
            let packages = try await Self.capture(CommandSpec(executable: adb, arguments: ["-s", "emulator-\(port)", "shell", "pm", "list", "packages"]))
            let names = Set(packages.output.components(separatedBy: .newlines))
            let services = names.contains("package:com.google.android.gms")
            let store = names.contains("package:com.android.vending")
            let games = names.contains("package:com.google.android.play.games")
            googleServicesStatus = "Play-Dienste: \(services ? "vorhanden" : "fehlen") · Play Store: \(store ? "vorhanden" : "fehlt") · Play Spiele: \(games ? "installiert" : "im Store verfügbar")"
        } catch { googleServicesStatus = "Google-Dienste konnten nicht geprüft werden." }
    }

    func openPlayGames() { androidIntent(["-a", "android.intent.action.VIEW", "-d", "market://details?id=com.google.android.play.games"]) }
    func openSyncSettings() { androidIntent(["-a", "android.settings.SYNC_SETTINGS"]) }
    func openBackupSettings() { androidIntent(["-a", "android.settings.BACKUP_SETTINGS"]) }
    private func androidIntent(_ arguments: [String]) {
        guard canInstallAPK, let adb, let port = androidPort else { return }
        Task {
            do {
                let result = try await Self.capture(CommandSpec(executable: adb, arguments: ["-s", "emulator-\(port)", "shell", "am", "start"] + arguments))
                if result.status != 0 || result.output.contains("Error:") { throw GuestError.commandFailed(result.status, result.output) }
            } catch { errorMessage = error.localizedDescription }
        }
    }

    func shutdownGuest() {
        windowsPasteTask?.cancel()
        guard running else { return }
        playerStatus = "Geordnetes Herunterfahren angefordert …"
        Task {
            do {
                if let adb, let port = androidPort {
                    _ = try await Self.capture(CommandSpec(executable: adb, arguments: ["-s", "emulator-\(port)", "shell", "reboot", "-p"]))
                } else if let qmpSocket { try await QMPClient.shutdown(socket: qmpSocket) }
            } catch { errorMessage = "Herunterfahren konnte nicht angefordert werden: \(error.localizedDescription)" }
        }
    }

    func chooseAndInstallAPK() {
        guard canInstallAPK, let path = chooseFile(title: "APK installieren · einzelne .apk-Datei auswählen") else { return }
        Task { await installAPK(path) }
    }

    private func installAPK(_ path: String) async {
        guard canInstallAPK, let port = androidPort, let adb else { return }
        apkBusy = true
        apkStatus = "APK wird installiert …"
        defer { apkBusy = false }
        do {
            let spec = try LaunchPlan.installAPK(adb: adb, port: port, apk: path)
            let result = try await Self.capture(spec, timeout: 120)
            guard result.status == 0 else { throw GuestError.commandFailed(result.status, result.output) }
            apkStatus = "\(URL(fileURLWithPath: path).lastPathComponent) installiert"
        } catch {
            apkStatus = "APK-Installation fehlgeschlagen"
            errorMessage = error.localizedDescription
        }
    }

    func openGoogleInMacBrowser() {
        // Use the normal browser and its existing profile; no embedded web view or private session.
        let url = URL(string: "https://accounts.google.com/AccountChooser?continue=https%3A%2F%2Fmyaccount.google.com%2F")!
        if !NSWorkspace.shared.open(url) {
            errorMessage = "Der Mac-Standardbrowser konnte nicht geöffnet werden. Bitte einen Standardbrowser in macOS festlegen."
        }
    }

    func openGoogleAccountSettings() {
        guard canInstallAPK, let port = androidPort, let adb else { return }
        Task {
            do {
                let result = try await Self.capture(CommandSpec(executable: adb, arguments: [
                    "-s", "emulator-\(port)", "shell", "am", "start", "-a", "android.settings.ADD_ACCOUNT_SETTINGS"
                ]))
                if result.status != 0 { throw GuestError.commandFailed(result.status, result.output) }
            } catch { errorMessage = error.localizedDescription }
        }
    }

    private func start(_ spec: CommandSpec, title: String) throws {
        guard process == nil else { return }
        guard FileManager.default.isExecutableFile(atPath: spec.executable) else { throw GuestError.missingFile(spec.executable) }
        guard let storage else { throw StorageMigration.failure("Bitte zuerst einen Speicherort wählen.") }
        try storage.validate()
        let directory = storage.logs
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let kind = title.hasPrefix("Android") ? "android" : "windows"
        let url = directory.appendingPathComponent("\(kind)-session-\(UUID().uuidString).log")
        let header = DiagnosticReport.redact("Pixelkoje · \(title)\nStart: \(ISO8601DateFormatter().string(from: Date()))\n\(spec.display)\n\n")
        guard FileManager.default.createFile(atPath: url.path, contents: Data(header.utf8), attributes: [.posixPermissions: 0o600]) else { throw GuestError.missingFile(url.path) }
        let handle = try FileHandle(forWritingTo: url)
        _ = try handle.seekToEnd()
        let child = Process()
        child.executableURL = URL(fileURLWithPath: spec.executable)
        child.arguments = spec.arguments
        child.environment = ProcessInfo.processInfo.environment.merging(spec.environment) { _, new in new }
        child.standardInput = FileHandle.nullDevice
        child.standardOutput = handle
        child.standardError = handle
        child.terminationHandler = { [weak self] finished in
            let code = finished.terminationStatus
            Task { @MainActor [weak self] in await self?.didExit(code: code) }
        }
        do { try child.run() }
        catch { try? handle.close(); try? FileManager.default.removeItem(at: url); throw error }
        process = child
        output = handle
        logURL = url
        sessionName = title
        lastCommand = spec.display
        sessionCommand = spec.display
        running = true
        recordDiagnostic("Gaststart", "\(title) · \(url.lastPathComponent)")
        stopRequested = false
        playerImage = nil
        playerSize = .zero
        streamFPS = 0
        log = "Prozess gestartet. Der Gast ist erst bereit, wenn sein Startbildschirm sichtbar ist.\n\n\(sessionCommand)\n"
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.readLog() }
        }
    }

    private func readLog() {
        guard let logURL, let reader = try? FileHandle(forReadingFrom: logURL) else { return }
        defer { try? reader.close() }
        let size = (try? reader.seekToEnd()) ?? 0
        try? reader.seek(toOffset: size > 60_000 ? size - 60_000 : 0)
        let data = (try? reader.read(upToCount: 60_000)) ?? Data()
        let text = String(decoding: data, as: UTF8.self)
        log = "\(sessionCommand)\n\n" + text
        if activeGuest == "android" {
            // Renderer selection is near the beginning even when the live log is long.
            try? reader.seek(toOffset: 0)
            let head = (try? reader.read(upToCount: 96_000)) ?? Data()
            let renderer = AndroidRenderer.inspect(String(decoding: head, as: UTF8.self) + text)
            if renderer.kind != .unknown, renderer.summary != androidRendererStatus {
                androidRendererStatus = renderer.summary
                androidSoftwareRendering = renderer.kind == .software
                recordDiagnostic("Android · Grafik", renderer.summary)
            }
        }
    }

    private func didExit(code: Int32) async {
        recordDiagnostic("Gast beendet", "\(sessionName) · Exit-Code \(code) · Beenden angefordert: \(stopRequested)")
        busy = true
        defer { busy = false }
        bootTask?.cancel()
        bootTask = nil
        displayTask?.cancel(); displayTask = nil
        windowsBootProbe?.cancel(); windowsBootProbe = nil
        windowsPasteTask?.cancel()
        await windowsPasteTask?.value
        windowsPasteTask = nil
        windowsPlayer?.stop(); windowsPlayer = nil
        if let androidStream { await androidStream.stop() }
        androidStream = nil
        h264Player.reset()
        androidPort = nil
        androidBooted = false
        timer?.invalidate()
        timer = nil
        readLog()
        log += "\n\nProzess beendet · Exit-Code \(code)\n"
        if let logURL { log += "Protokoll: \(logURL.path)\n" }
        try? output?.close()
        output = nil
        process = nil
        running = false
        if let windowsSession { await windowsSession.stop() }
        windowsSession = nil
        qmpSocket = nil
        activeGuest = ""
        playerStatus = "Gast beendet · Daten bleiben gespeichert"
        sessionName = "Kein Gast gestartet"
        if code != 0 && !stopRequested { errorMessage = "Der Gastprozess wurde mit Code \(code) beendet. Details stehen im Protokoll." }
    }

    func terminateGuest() {
        // Only this app's retained Process receives SIGTERM. No killall or global cleanup.
        guard let process, process.isRunning else { return }
        stopRequested = true
        process.terminate()
        log += "\nBeenden angefordert. Warte auf den Gastprozess …\n"
    }

    func revealLogs() {
        if let logURL { NSWorkspace.shared.activateFileViewerSelecting([logURL]) }
    }

    func openSetupScript(_ name: String) {
        guard storageReady else { showStorageSetup = true; return }
        guard ["Android_einrichten.command", "Android_Streaming_einrichten.command", "Windows_Treiber_einrichten.command"].contains(name) else { return }
        let bundled = Bundle.main.resourceURL?.appendingPathComponent(name)
        let development = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().appendingPathComponent(name)
        guard let script = [bundled, development].compactMap({ $0 }).first(where: { FileManager.default.isReadableFile(atPath: $0.path) }) else {
            errorMessage = "Einrichtungsskript fehlt im App-Paket."
            return
        }
        NSWorkspace.shared.open([script], withApplicationAt: URL(fileURLWithPath: "/System/Applications/Utilities/Terminal.app"),
                                configuration: NSWorkspace.OpenConfiguration())
    }

    func chooseStorageFolder() {
        let panel = NSOpenPanel()
        panel.title = "Speicherort für Android, Windows und Downloads"
        panel.prompt = "Diesen Ort verwenden"
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.directoryURL = URL(fileURLWithPath: FileManager.default.fileExists(atPath: "/Volumes/Extern") ? "/Volumes/Extern" : NSHomeDirectory())
        if panel.runModal() == .OK, let parent = panel.url {
            proposedStoragePath = (["Pixelkoje", "OpenGuest"].contains(parent.lastPathComponent) ? parent : parent.appendingPathComponent("Pixelkoje")).path
        }
    }

    func configureStorage() {
        guard !busy, !running, !proposedStoragePath.isEmpty else { return }
        let root = URL(fileURLWithPath: proposedStoragePath, isDirectory: true)
        let downloads = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Downloads").path + "/"
        let media = [settings.iso, settings.driversISO].filter { $0.hasPrefix(downloads) && $0.lowercased().hasSuffix(".iso") }
        busy = true
        errorMessage = nil
        storageStatus = "Prüfe laufende Programme …"
        Task {
            do {
                try await assertNoStorageWriters()
                let result = try await Task.detached(priority: .userInitiated) { [weak self] in
                    try StorageMigration.prepare(root: root, mediaSources: media) { status in
                        Task { @MainActor [weak self] in self?.storageStatus = status }
                    }
                }.value
                try result.save()
                storage = result
                settings.sdk = result.sdk.path
                if media.contains(settings.iso) { settings.iso = result.url.appendingPathComponent("Installationsmedien").appendingPathComponent(URL(fileURLWithPath: settings.iso).lastPathComponent).path }
                if media.contains(settings.driversISO) { settings.driversISO = result.url.appendingPathComponent("Installationsmedien").appendingPathComponent(URL(fileURLWithPath: settings.driversISO).lastPathComponent).path }
                settings.selectedAVD = ""
                storageTested = false
                updateBackupPaths()
                storageStatus = "Speicherort eingerichtet. Vorhandene Daten sind kopiert und per SHA-256 geprüft. Interne Sicherungen bleiben bis zur Bereinigung erhalten."
                showStorageSetup = false
            } catch { errorMessage = error.localizedDescription; storageStatus = error.localizedDescription }
            busy = false
            if storageReady { await refresh() }
        }
    }

    func updateBackupPaths() {
        backupPaths = storage.flatMap { try? StorageMigration.backupPaths($0) } ?? []
    }

    func confirmStorageCleanup() {
        guard storageTested, !busy, !running, !backupPaths.isEmpty else { return }
        let alert = NSAlert()
        alert.messageText = "Geprüfte interne Sicherungen endgültig entfernen?"
        alert.informativeText = backupPaths.joined(separator: "\n") + "\n\nDie aktiven Daten im gewählten Datenordner bleiben erhalten. Diese Kopien werden ohne Papierkorb entfernt und geben dadurch Speicherplatz frei."
        alert.addButton(withTitle: "Interne Sicherungen entfernen")
        alert.addButton(withTitle: "Abbrechen")
        if alert.runModal() == .alertFirstButtonReturn { cleanupInternalCopies() }
    }

    func cleanupInternalCopies() {
        guard !busy, !running, storageTested, let storage else { return }
        busy = true
        Task {
            do {
                try await assertNoStorageWriters()
                try await Task.detached(priority: .userInitiated) { [weak self] in
                    try StorageMigration.cleanup(storage) { status in
                        Task { @MainActor [weak self] in self?.storageStatus = status }
                    }
                }.value
                updateBackupPaths()
                storageStatus = "Geprüfte interne Sicherungen entfernt. Die aktiven Daten bleiben im gewählten Speicherordner."
            } catch { errorMessage = error.localizedDescription; storageStatus = error.localizedDescription }
            busy = false
        }
    }

    private func assertNoStorageWriters() async throws {
        let result = try await Self.capture(CommandSpec(executable: "/bin/ps", arguments: ["-axo", "pid=,comm="]))
        guard result.status == 0 else { throw StorageMigration.failure("Laufende Programme konnten nicht geprüft werden.") }
        for line in result.output.components(separatedBy: .newlines) {
            let parts = line.trimmingCharacters(in: .whitespaces).split(maxSplits: 1, whereSeparator: { $0.isWhitespace })
            guard parts.count == 2, let pid = Int32(parts[0]), pid != getpid() else { continue }
            let name = String(parts[1])
            if name.contains("/emulator/") || name.hasSuffix("/qemu-system-aarch64") ||
                name.contains("Android Studio.app/") || (name.hasSuffix("/OpenGuest") || name.hasSuffix("/Pixelkoje")) {
                throw StorageMigration.failure("Bitte Android/Windows herunterfahren, Android Studio und weitere Pixelkoje-Fenster beenden. Noch aktiv: \(name)")
            }
        }
    }

    private func checkStorageSpace(minimumGB: Int64) throws {
        guard let storage else { throw StorageMigration.failure("Speicherort fehlt.") }
        try storage.validate()
        if let free = storage.freeBytes, free < minimumGB * 1_000_000_000 {
            throw StorageMigration.failure("Am gewählten Speicherort \(storage.root) sind nur \(ByteCountFormatter.string(fromByteCount: free, countStyle: .file)) frei. Für diesen Start sind mindestens \(minimumGB) GB Reserve vorgesehen.")
        }
    }

    func revealStorage() {
        if let storage, storageReady { NSWorkspace.shared.open(storage.url) }
    }

    func chooseFolder() -> String? {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "SDK auswählen"
        return panel.runModal() == .OK ? panel.url?.path : nil
    }

    func chooseFile(title: String) -> String? {
        let panel = NSOpenPanel()
        panel.title = title
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false
        panel.showsHiddenFiles = true
        return panel.runModal() == .OK ? panel.url?.path : nil
    }
}
