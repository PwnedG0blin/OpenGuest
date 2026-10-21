import Combine
import Foundation
import StratovoCore

/// Changes guest audio only. The Mac's master volume is never modified.
@MainActor
final class GuestAudioController: ObservableObject {
    enum Connection {
        case android(adb: String, serial: String)
        case qmp(socket: String)
    }
    @Published private(set) var kind = ""
    @Published private(set) var volume: AndroidMediaVolume?
    @Published private(set) var targetPercent: Double?
    @Published private(set) var busy = false
    @Published private(set) var status = ""
    private var connection: Connection?
    private var session = UUID()
    private var worker: Task<Void, Never>?
    private var pendingIndex: Int?
    private var lastAudibleIndex: Int?
    var connected: Bool { connection != nil }

    func connect(_ connection: Connection, kind: String) {
        disconnect()
        self.connection = connection; self.kind = kind
        refresh()
    }

    func disconnect() {
        session = UUID(); worker?.cancel(); worker = nil
        connection = nil; kind = ""; volume = nil; targetPercent = nil
        pendingIndex = nil; lastAudibleIndex = nil; busy = false; status = ""
    }

    func refresh() {
        guard case .android = connection, worker == nil else { return }
        runAndroidWorker()
    }

    func setPercent(_ percent: Double) {
        guard let volume, percent.isFinite else { return }
        let index = volume.index(forPercent: percent)
        pendingIndex = index
        targetPercent = Double(index - volume.minimum) / Double(volume.maximum - volume.minimum) * 100
        if index > volume.minimum { lastAudibleIndex = index }
        if worker == nil { runAndroidWorker() }
    }

    func toggleMute() {
        if let volume {
            if volume.muted {
                let restored = lastAudibleIndex ?? volume.index(forPercent: 50)
                setPercent(Double(restored - volume.minimum) / Double(volume.maximum - volume.minimum) * 100)
            } else {
                lastAudibleIndex = volume.index
                setPercent(0)
            }
        } else { sendMediaKey("audiomute") }
    }

    func adjust(up: Bool) {
        if let volume {
            let step = 100.0 / Double(volume.maximum - volume.minimum)
            setPercent((targetPercent ?? volume.percent) + (up ? step : -step))
        } else { sendMediaKey(up ? "volumeup" : "volumedown") }
    }

    private func runAndroidWorker() {
        guard case .android(let adb, let serial) = connection else { return }
        let expected = session
        busy = true
        worker = Task { [weak self] in
            guard let self else { return }
            defer {
                if self.session == expected { self.worker = nil; self.busy = false; self.targetPercent = nil }
            }
            do {
                repeat {
                    let target = self.pendingIndex
                    self.pendingIndex = nil
                    var args = ["-s", serial, "shell", "cmd", "media_session", "volume", "--stream", "3"]
                    if let target { args += ["--set", String(target)] }
                    args += ["--get"]
                    let spec = CommandSpec(executable: adb, arguments: args)
                    let result = try await Task.detached(priority: .userInitiated) {
                        try CommandCapture.run(spec, timeout: 5)
                    }.value
                    guard self.session == expected, !Task.isCancelled else { return }
                    guard result.status == 0 else { throw GuestError.commandFailed(result.status, result.output) }
                    let actual = try AndroidMediaVolume(output: result.output)
                    self.volume = actual
                    if !actual.muted { self.lastAudibleIndex = actual.index }
                    self.status = actual.muted ? L10n.text("Medien stumm") :
                        L10n.message("Medienlautstärke: \(Int(actual.percent.rounded())) %")
                } while self.pendingIndex != nil
            } catch {
                guard self.session == expected, !Task.isCancelled else { return }
                self.pendingIndex = nil
                self.status = L10n.text("Lautstärke konnte nicht geändert werden.") + " " + error.localizedDescription
            }
        }
    }

    private func sendMediaKey(_ code: String) {
        guard case .qmp(let socket) = connection, worker == nil else { return }
        let expected = session
        busy = true
        worker = Task { [weak self] in
            guard let self else { return }
            defer { if self.session == expected { self.worker = nil; self.busy = false } }
            do {
                try await QMPClient.sendKeys([code], socket: socket)
                guard self.session == expected, !Task.isCancelled else { return }
                self.status = L10n.text("Lautstärketaste an den Gast gesendet.")
            } catch {
                guard self.session == expected, !Task.isCancelled else { return }
                self.status = error.localizedDescription
            }
        }
    }
}
