import CryptoKit
import Darwin
import Foundation
import Network
import OpenGuestCore

@MainActor
final class ScrcpySession {
    static var runtime: URL {
        (GuestStorage.load()?.runtime ?? GuestStorage.pointer.deletingLastPathComponent().appendingPathComponent("Runtime"))
            .appendingPathComponent("scrcpy-4.0", isDirectory: true)
    }
    static var installed: Bool {
        FileManager.default.isReadableFile(atPath: runtime.appendingPathComponent("scrcpy-server-v4.0").path) &&
        FileManager.default.isReadableFile(atPath: runtime.appendingPathComponent("manifest.json").path)
    }
    private var server: Process?
    private var serverOutput: FileHandle?
    private var video: LocalStream?
    private var control: LocalStream?
    private var streamTask: Task<Void, Never>?
    private var port: Int?
    private var adb = ""
    private var serial = ""
    private var remote = ""
    var onPacket: ((Data, UInt64, Bool) async throws -> Void)?
    var onSize: ((CGSize) -> Void)?
    var onStatus: ((String) -> Void)?
    var onFPS: ((Double) -> Void)?
    private(set) var width = 0
    private(set) var height = 0
    private var touchDown = false

    func start(adb: String, serial: String, profile: AndroidPerformance, fps: Int) async throws {
        guard let storage = GuestStorage.load() else { throw failure("Speicherort fehlt.") }
        try storage.validate()
        self.adb = adb; self.serial = serial
        let jar = Self.runtime.appendingPathComponent("scrcpy-server-v4.0")
        struct Manifest: Decodable { let version: String; let sha256: String }
        let manifest = try JSONDecoder().decode(Manifest.self, from: Data(contentsOf: Self.runtime.appendingPathComponent("manifest.json")))
        let bytes = try Data(contentsOf: jar, options: [.mappedIfSafe])
        let digest = SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined()
        guard manifest.version == ScrcpyWire.version, digest == manifest.sha256 else {
            throw failure("Streaming-Datei stimmt nicht mit dem geprüften Download überein. Android_Streaming_einrichten.command erneut ausführen.")
        }
        let scid = String(format: "%08x", UInt32.random(in: 1...0x7fff_ffff))
        remote = "/data/local/tmp/openguest-scrcpy-\(scid).jar"
        try await checked(["push", jar.path, remote], timeout: 30)
        try Task.checkCancellation()
        let forwarded = try await capture(["forward", "tcp:0", "localabstract:scrcpy_\(scid)"])
        guard forwarded.status == 0, let port = Int(forwarded.output.trimmingCharacters(in: .whitespacesAndNewlines)), (1...65535).contains(port) else {
            throw failure("Android-Stream-Port konnte nicht eingerichtet werden: \(forwarded.output)")
        }
        self.port = port
        try Task.checkCancellation()
        let log = Self.runtime.appendingPathComponent("server-last.log")
        guard FileManager.default.createFile(atPath: log.path, contents: nil) else { throw failure("Stream-Protokoll nicht schreibbar.") }
        let handle = try FileHandle(forWritingTo: log)
        serverOutput = handle
        let child = Process()
        child.executableURL = URL(fileURLWithPath: adb)
        child.arguments = ["-s", serial, "shell", "CLASSPATH=\(remote)", "app_process", "/", "com.genymobile.scrcpy.Server", ScrcpyWire.version,
                           "scid=\(scid)", "tunnel_forward=true", "audio=false", "control=true", "video_codec=h264",
                           "video_codec_options=i-frame-interval=1", "send_device_meta=false",
                           "send_stream_meta=false", "send_frame_meta=true", "send_dummy_byte=true", "clipboard_autosync=false", "cleanup=true"] + profile.streamOptions(fps: fps)
        child.standardInput = FileHandle.nullDevice
        child.standardOutput = handle
        child.standardError = handle
        try child.run()
        server = child
        streamTask = Task { [weak self] in
            guard let self else { return }
            do { try await self.receive(port: port) }
            catch {
                if !Task.isCancelled {
                    self.onStatus?("Android-Stream: \(error.localizedDescription) · Details: \(log.path)")
                }
            }
        }
    }

    private func receive(port: Int) async throws {
        // The dummy byte confirms that adb has reached the guest server.
        var socket: LocalStream?
        for _ in 0..<50 {
            try Task.checkCancellation()
            let candidate = LocalStream(port: port)
            video = candidate
            do {
                let dummy = try await candidate.read(1)
                if dummy[0] == 0 { socket = candidate; break }
            } catch { candidate.close() }
            if server?.isRunning != true { break }
            try await Task.sleep(nanoseconds: 100_000_000)
        }
        guard let socket else { throw failure("Stream-Server antwortet nicht. Das Server-Protokoll enthält die Ursache.") }
        control = LocalStream(port: port)
        onStatus?("H.264-Stream verbunden · Mac-Videodecoder")
        var frames = 0
        var epoch = ProcessInfo.processInfo.systemUptime
        while !Task.isCancelled {
            let header = try ScrcpyWire.header(await socket.read(12))
            switch header {
            case .session(let w, let h): width = w; height = h; onSize?(CGSize(width: CGFloat(w), height: CGFloat(h)))
            case .packet(let count, let pts, let config):
                let data = try await socket.read(count)
                try await onPacket?(data, pts, config)
                if !config { frames += 1 }
                let now = ProcessInfo.processInfo.systemUptime
                if now - epoch >= 1 {
                    onFPS?(Double(frames) / (now - epoch))
                    frames = 0; epoch = now
                }
            }
        }
    }

    func setSize(_ size: CGSize) { width = Int(size.width); height = Int(size.height) }
    func pointer(x: Int, y: Int, mask: UInt8) {
        guard width > 0, height > 0 else { return }
        let pressed = mask & 1 != 0
        if !pressed && !touchDown { return }
        let action: UInt8 = pressed ? (touchDown ? 2 : 0) : 1
        touchDown = pressed
        control?.send(ScrcpyWire.touch(x: x, y: y, width: width, height: height, action: action))
    }
    func key(_ code: UInt32, down: Bool) { control?.send(ScrcpyWire.key(code, down: down)) }
    func scroll(x: Int, y: Int, horizontal: Double, vertical: Double, mask: UInt8) {
        // A mouse-wheel event must not interfere with an in-progress synthetic touch drag.
        guard !touchDown else { return }
        let buttons = UInt32(mask & 1) | UInt32((mask & 4) >> 1) | UInt32((mask & 2) << 1)
        let data = ScrcpyWire.scroll(x: x, y: y, width: width, height: height,
                                     horizontal: horizontal, vertical: vertical, buttons: buttons)
        if !data.isEmpty { control?.send(data) }
    }
    func text(_ text: String) { control?.send(ScrcpyWire.text(text)) }

    func stop() async {
        streamTask?.cancel(); video?.close(); control?.close()
        streamTask = nil; video = nil; control = nil
        if let server {
            await Task.detached {
                if server.isRunning { server.terminate() }
                let deadline = ProcessInfo.processInfo.systemUptime + 2
                while server.isRunning && ProcessInfo.processInfo.systemUptime < deadline { try? await Task.sleep(nanoseconds: 20_000_000) }
                if server.isRunning { kill(server.processIdentifier, SIGKILL) }
                server.waitUntilExit()
            }.value
        }
        server = nil
        try? serverOutput?.close(); serverOutput = nil
        if let port { _ = try? await capture(["forward", "--remove", "tcp:\(port)"]) }
        if !remote.isEmpty { _ = try? await capture(["shell", "rm", "-f", remote]) }
        port = nil
    }
    private func capture(_ args: [String], timeout: TimeInterval = 12) async throws -> CommandResult {
        let spec = CommandSpec(executable: adb, arguments: ["-s", serial] + args)
        return try await Task.detached { try CommandCapture.run(spec, timeout: timeout) }.value
    }
    private func checked(_ args: [String], timeout: TimeInterval = 12) async throws {
        let result = try await capture(args, timeout: timeout)
        if result.status != 0 { throw GuestError.commandFailed(result.status, result.output) }
    }
    private func failure(_ text: String) -> NSError {
        NSError(domain: "OpenGuest.Stream", code: 1, userInfo: [NSLocalizedDescriptionKey: text])
    }
}

@MainActor
final class LocalStream {
    private let connection: NWConnection
    private var buffer = Data()
    init(port: Int) {
        connection = NWConnection(host: "127.0.0.1", port: NWEndpoint.Port(rawValue: UInt16(port))!, using: .tcp)
        connection.start(queue: DispatchQueue(label: "OpenGuest.Android.stream"))
    }
    init(socket: String) {
        connection = NWConnection(to: .unix(path: socket), using: .tcp)
        connection.start(queue: DispatchQueue(label: "OpenGuest.local.socket"))
    }
    func send(_ data: Data) { connection.send(content: data, completion: .contentProcessed { _ in }) }
    func close() { connection.cancel() }
    func read(_ count: Int) async throws -> Data {
        guard (0...16_777_216).contains(count) else { throw GuestError.invalidResources }
        while buffer.count < count {
            try Task.checkCancellation()
            let data: Data = try await withCheckedThrowingContinuation { continuation in
                connection.receive(minimumIncompleteLength: 1, maximumLength: 262_144) { data, _, _, error in
                    if let error { continuation.resume(throwing: error) }
                    else if let data, !data.isEmpty { continuation.resume(returning: data) }
                    else { continuation.resume(throwing: NSError(domain: "OpenGuest.Stream", code: 1,
                        userInfo: [NSLocalizedDescriptionKey: "Videostream geschlossen."])) }
                }
            }
            buffer.append(data)
        }
        let result = Data(buffer.prefix(count)); buffer = Data(buffer.dropFirst(count))
        return result
    }
}
