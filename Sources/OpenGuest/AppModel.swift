import AppKit
import Combine
import Darwin
import Foundation
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
    var autoStartAndroid = true
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
    @Published private(set) var devices: [AndroidDevice] = []
    @Published private(set) var sdk: String?
    @Published private(set) var qemu: String?
    @Published private(set) var firmware: String?
    @Published private(set) var swtpm: String?
    @Published private(set) var qemuImg: String?
    @Published private(set) var variablesTemplate: String?
    @Published private(set) var androidAcceleration = "Noch nicht geprüft"
    @Published private(set) var windowsAcceleration = "Noch nicht geprüft"
    @Published private(set) var androidReady = false
    @Published private(set) var windowsReady = false
    @Published private(set) var busy = false
    @Published private(set) var running = false
    @Published private(set) var androidBooted = false
    @Published private(set) var apkBusy = false
    @Published private(set) var apkStatus = ""
    @Published private(set) var sessionName = "Kein Gast gestartet"
    @Published private(set) var log = "OpenGuest 0.1.0 · Entwicklungsprototyp\nSystem prüfen, dann einen Gast auswählen."
    @Published private(set) var lastCommand = ""
    @Published var errorMessage: String?
    @Published var localPassword = ""
    @Published var localPasswordConfirmation = ""
    @Published private(set) var playerImage: NSImage?
    @Published private(set) var playerSize = CGSize.zero
    @Published private(set) var playerStatus = "Player noch nicht gestartet"
    @Published private(set) var activeGuest = ""
    @Published private(set) var streamFPS = 0.0
    @Published private(set) var googleServicesStatus = "Google-Dienste werden nach dem Android-Start geprüft."
    let h264Player = H264Player()

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
        supportedHost && hypervisorAvailable && androidReady && selectedDevice?.supported == true && adb != nil && ScrcpySession.installed && !busy && !running
    }
    var canStartWindows: Bool {
        supportedHost && hypervisorAvailable && windowsReady && firmware != nil && settings.memoryGB >= 4 &&
        (!settings.installWindows || !settings.iso.isEmpty) && !busy && !running
    }
    var canInstallAPK: Bool { running && androidBooted && androidPort != nil && !apkBusy && !busy && adb != nil }
    var adb: String? {
        guard let sdk else { return nil }
        let path = URL(fileURLWithPath: sdk).appendingPathComponent("platform-tools/adb").path
        return FileManager.default.isExecutableFile(atPath: path) ? path : nil
    }
    var resources: GuestResources { GuestResources(memoryMiB: settings.memoryGB * 1024, cores: settings.cores) }

    init() {
        settings.memoryGB = min(max(2, settings.memoryGB), maxMemoryGB)
        settings.cores = min(max(2, settings.cores), maxCores)
    }

    func open() async {
        guard !opened else { return }
        opened = true
        await refresh()
        // Once dependencies and an AVD exist, opening the app boots Android directly.
        // A failed boot is reported; there is no automatic restart loop.
        if settings.autoStartAndroid && canStartAndroid { startAndroid() }
    }

    func refresh() async {
        guard !busy, !running else { return }
        busy = true
        defer { busy = false }
        androidReady = false
        windowsReady = false
        devices = []
        sdk = RuntimeDiscovery.sdk(preferred: settings.sdk)
        qemu = RuntimeDiscovery.qemu(preferred: settings.qemu)
        swtpm = RuntimeDiscovery.swtpm(preferred: settings.swtpm)
        qemuImg = qemu.flatMap { RuntimeDiscovery.sibling(executable: $0, name: "qemu-img") }
        firmware = qemu.flatMap { RuntimeDiscovery.firmware(qemu: $0, preferred: settings.firmware) }
        variablesTemplate = firmware.flatMap { RuntimeDiscovery.variablesTemplate(firmware: $0) }
        androidAcceleration = sdk == nil ? "Android Emulator fehlt" : "Prüfung läuft …"
        windowsAcceleration = qemu == nil ? "QEMU fehlt" : "Prüfung läuft …"
        log = "Mac: \(supportedHost ? "Apple Silicon (nativ)" : "Architektur nicht unterstützt / Rosetta") · \(totalMemoryGB) GB RAM · \(hostCores) Kerne\nHypervisor: \(hypervisorAvailable ? "verfügbar" : "nicht verfügbar")\n"

        if let sdk {
            let engine = URL(fileURLWithPath: sdk).appendingPathComponent("emulator/emulator").path
            let environment = ["ANDROID_HOME": sdk, "ANDROID_SDK_ROOT": sdk]
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
                    .map { RuntimeDiscovery.device(name: $0) }
                if !devices.contains(where: { $0.name == settings.selectedAVD }) {
                    settings.selectedAVD = devices.first(where: { $0.supported && $0.googlePlay })?.name ?? devices.first(where: \.supported)?.name ?? devices.first?.name ?? ""
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
                let hasTPM = hardware.output.contains("tpm-crb-device")
                windowsReady = acceleration.status == 0 && display.status == 0 && hardware.status == 0 && hasHVF && hasCocoa && hasTPM && swtpm != nil && qemuImg != nil && variablesTemplate != nil
                windowsAcceleration = windowsReady ? "HVF, VNC, TPM und UEFI gefunden" : "QEMU, swtpm oder passende UEFI-Dateien fehlen"
                log += "\nQEMU-Beschleuniger:\n\(acceleration.output)\nQEMU-Anzeige:\n\(display.output)\n"
                if firmware == nil { log += "ARM64-UEFI-Firmware fehlt. Bitte eine edk2-aarch64-code.fd auswählen.\n" }
                if swtpm == nil { log += "swtpm fehlt. Für Windows wird ein dauerhaftes TPM 2.0 benötigt.\n" }
                if !hasTPM { log += "QEMU-Build enthält kein tpm-crb-device.\n" }
                if variablesTemplate == nil { log += "edk2-arm-vars.fd fehlt neben der gewählten Firmware.\n" }
            } catch {
                windowsAcceleration = "QEMU-Prüfung fehlgeschlagen"
                log += "\n\(error.localizedDescription)\n"
            }
        }
    }

    private static func capture(_ spec: CommandSpec, timeout: TimeInterval = 12) async throws -> CommandResult {
        try await Task.detached(priority: .userInitiated) { try CommandCapture.run(spec, timeout: timeout) }.value
    }

    func startAndroid() {
        guard canStartAndroid, let sdk, let device = selectedDevice else { return }
        do {
            let port = try AndroidPorts.available()
            let spec = try LaunchPlan.android(sdk: sdk, device: device, resources: resources,
                                              coldBoot: settings.coldBoot, gpu: settings.gpu, port: port)
            try start(spec, title: "Android · \(device.name)")
            activeGuest = "android"
            playerStatus = "Android startet …"
            androidPort = port
            androidBooted = false
            apkStatus = "Android startet …"
            watchAndroidBoot(port: port)
        } catch { errorMessage = error.localizedDescription }
    }

    func startWindows() {
        Task { await startWindowsVM() }
    }

    private func startWindowsVM() async {
        guard canStartWindows, let qemu, let firmware, let qemuImg, let swtpm, let variablesTemplate else { return }
        busy = true
        defer { busy = false }
        let session = WindowsSession()
        do {
            var account: WindowsEdition.LocalAccount?
            if settings.installWindows && settings.localWindowsAccount {
                guard localPassword == localPasswordConfirmation else {
                    throw NSError(domain: "OpenGuest.Windows", code: 2, userInfo: [NSLocalizedDescriptionKey: "Die Windows-Passwörter stimmen nicht überein."])
                }
                account = WindowsEdition.LocalAccount(name: settings.localWindowsUser, password: localPassword)
                _ = try WindowsEdition.setupXML(selectPro: settings.selectPro, localAccount: account)
            }
            guard FileManager.default.isReadableFile(atPath: firmware) else { throw GuestError.missingFile(firmware) }
            if settings.installWindows, !FileManager.default.isReadableFile(atPath: settings.iso) {
                throw GuestError.missingFile(settings.iso)
            }
            if !settings.driversISO.isEmpty, !FileManager.default.isReadableFile(atPath: settings.driversISO) {
                throw GuestError.missingFile(settings.driversISO)
            }
            let files = try await session.prepare(qemuImg: qemuImg, swtpm: swtpm, variablesTemplate: variablesTemplate,
                                                  selectPro: settings.installWindows && settings.selectPro, localAccount: account)
            localPassword = ""; localPasswordConfirmation = ""
            let spec = try LaunchPlan.windowsVM(qemu: qemu, firmware: firmware, variables: files.variables, disk: files.disk,
                                               tpmSocket: files.socket, iso: settings.iso, driversISO: settings.driversISO,
                                               proISO: files.proISO, installing: settings.installWindows, resources: resources,
                                               displaySocket: files.displaySocket, network: settings.windowsNetwork, qmpSocket: files.qmpSocket)
            windowsSession = session
            try start(spec, title: "Windows 11 Pro Arm64")
            activeGuest = "windows"
            qmpSocket = files.qmpSocket
            connectWindowsPlayer(socket: files.displaySocket)
        } catch {
            localPassword = ""; localPasswordConfirmation = ""
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

    private func connectAndroidPlayer(port: Int) async {
        guard let adb, running, androidPort == port else { return }
        h264Player.reset()
        let stream = ScrcpySession()
        h264Player.onSize = { [weak self, weak stream] size in
            self?.playerSize = size; stream?.setSize(size)
        }
        stream.onPacket = { [weak self] data, pts, config in try self?.h264Player.packet(data, pts: pts, configuration: config) }
        stream.onSize = { [weak self] size in self?.playerSize = size }
        stream.onStatus = { [weak self] text in self?.playerStatus = text }
        stream.onFPS = { [weak self] fps in self?.streamFPS = fps }
        androidStream = stream
        do {
            try await stream.start(adb: adb, serial: "emulator-\(port)")
            if Task.isCancelled || !running { await stream.stop() }
        } catch {
            await stream.stop()
            if !Task.isCancelled { playerStatus = "Android-Anzeige konnte nicht starten: \(error.localizedDescription)" }
        }
    }

    private func connectWindowsPlayer(socket: String) {
        playerStatus = "Windows-Player verbindet …"
        displayTask = Task { [weak self] in
            for _ in 0..<50 {
                guard let self, self.running, !Task.isCancelled else { return }
                let client = RFBClient()
                self.windowsPlayer = client
                client.onFrame = { [weak self] image in self?.playerImage = image; self?.playerSize = image.size }
                client.onStatus = { [weak self] text in self?.playerStatus = text }
                do { try await client.run(socket: socket); return }
                catch {
                    if client.initialized {
                        if !Task.isCancelled { self.playerStatus = "Windows-Anzeige: \(error.localizedDescription)" }
                        return
                    }
                }
                try? await Task.sleep(nanoseconds: 100_000_000)
            }
            self?.playerStatus = "Windows-Player nicht erreichbar. QEMU-Protokoll prüfen."
        }
    }

    func pointer(x: Int, y: Int, mask: UInt8) {
        if activeGuest == "android" { androidStream?.pointer(x: x, y: y, mask: mask) }
        else if activeGuest == "windows" { windowsPlayer?.pointer(x: x, y: y, mask: mask) }
    }

    func keyboard(code: UInt16, text: String, down: Bool) {
        if activeGuest == "android" {
            let special: [UInt16: UInt32] = [36: 66, 51: 67, 48: 61, 53: 111, 123: 21, 124: 22, 125: 20, 126: 19,
                117: 112, 115: 122, 119: 123, 116: 92, 121: 93, 56: 59, 60: 60, 59: 113, 62: 114, 58: 57, 61: 58, 55: 117, 54: 118]
            if let key = special[code] { androidStream?.key(key, down: down) }
            else if down && !text.isEmpty { androidStream?.text(text) }
        } else if activeGuest == "windows" {
            let special: [UInt16: UInt32] = [36: 0xff0d, 51: 0xff08, 48: 0xff09, 53: 0xff1b, 123: 0xff51, 124: 0xff53,
                125: 0xff54, 126: 0xff52, 117: 0xffff, 115: 0xff50, 119: 0xff57, 116: 0xff55, 121: 0xff56,
                56: 0xffe1, 60: 0xffe2, 59: 0xffe3, 62: 0xffe4, 58: 0xffe9, 61: 0xffea, 55: 0xffeb, 54: 0xffec]
            if let symbol = special[code] { windowsPlayer?.key(symbol, down: down) }
            else if let scalar = text.unicodeScalars.first {
                windowsPlayer?.key(scalar.value <= 255 ? scalar.value : 0x0100_0000 | scalar.value, down: down)
            }
        }
    }

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
        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("OpenGuest/Logs", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent("session-\(UUID().uuidString).log")
        guard FileManager.default.createFile(atPath: url.path, contents: nil) else { throw GuestError.missingFile(url.path) }
        let handle = try FileHandle(forWritingTo: url)
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
        log = "\(sessionCommand)\n\n" + String(decoding: data, as: UTF8.self)
    }

    private func didExit(code: Int32) async {
        busy = true
        defer { busy = false }
        bootTask?.cancel()
        bootTask = nil
        displayTask?.cancel(); displayTask = nil
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
        guard ["Android_einrichten.command", "Android_Streaming_einrichten.command"].contains(name) else { return }
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
