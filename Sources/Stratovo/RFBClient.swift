import AppKit
import Foundation
import Network
import StratovoCore

// A minimal local RFB 3.8 client. Requests only Raw and DesktopSize encodings.
// No dependency on a web viewer, clipboard synchronization or a public listener.
@MainActor
final class RFBClient {
    private var connection: NWConnection?
    private var buffer = StreamByteBuffer()
    private let renderer = WindowsFrameRenderer()
    private var cadence = FrameRequestCadence()
    private var stopped = false
    private var width = 0
    private var height = 0
    private(set) var initialized = false
    private var wheel = WindowsWheelScroll()
    var onFrame: ((NSImage) -> Void)?
    var onStatus: ((String) -> Void)?

    func run(socket: String) async throws {
        let connection = NWConnection(to: .unix(path: socket), using: .tcp)
        self.connection = connection
        stopped = false
        onStatus?(L10n.text("Windows-Bildverbindung wird aufgebaut …"))
        connection.stateUpdateHandler = { [weak self, weak connection] state in
            switch state {
            case .waiting(let error), .failed(let error):
                Task { @MainActor [weak self] in self?.onStatus?("Windows-Bildverbindung: \(error.localizedDescription)") }
                connection?.cancel()
            default: break
            }
        }
        let handshakeTimeout = Task {
            try? await Task.sleep(nanoseconds: 8_000_000_000)
            if !Task.isCancelled { connection.cancel() }
        }
        defer { handshakeTimeout.cancel(); connection.stateUpdateHandler = nil }
        connection.start(queue: DispatchQueue(label: "OpenGuest.RFB.transport"))
        defer { connection.cancel(); self.connection = nil; initialized = false; wheel.reset() }
        let version = try await read(12)
        onStatus?(L10n.text("Windows-Bildverbindung antwortet · Anzeige wird eingerichtet …"))
        guard String(decoding: version, as: UTF8.self).hasPrefix("RFB 003.008") else { throw failure(L10n.text("RFB 3.8 benötigt.")) }
        send(Data("RFB 003.008\n".utf8))
        let count = Int(try await read(1)[0])
        guard count > 0, count <= 64 else { throw failure(L10n.text("Keine unterstützte Player-Verbindung.")) }
        let security = try await read(count)
        guard security.contains(1) else { throw failure(L10n.text("Lokale RFB-Sicherheitsart nicht verfügbar.")) }
        send(Data([1]))
        let result = try await read(4)
        guard u32(result, 0) == 0 else { throw failure("Lokaler Player-Zugriff abgelehnt.") }
        send(Data([1])) // Shared session.
        let header = try await read(24)
        try await resize(Int(u16(header, 0)), Int(u16(header, 2)))
        let nameLength = Int(u32(header, 20))
        guard nameLength <= 1_048_576 else { throw failure(L10n.text("Ungültiger Player-Name.")) }
        _ = try await read(nameLength)
        // 32bpp, 24-bit true color, little endian, red/green/blue shifts 16/8/0.
        send(Data([0, 0, 0, 0, 32, 24, 0, 1, 0, 255, 0, 255, 0, 255, 16, 8, 0, 0, 0, 0]))
        send(Data([2, 0, 0, 2, 0, 0, 0, 0, 255, 255, 255, 33]))
        initialized = true
        handshakeTimeout.cancel()
        onStatus?("Bildverbindung bereit · Firmware und Windows richten die Anzeige ein")
        request(incremental: false)
        while !Task.isCancelled {
            let type = try await read(1)[0]
            switch type {
            case 0:
                let update = try await read(3)
                let count = Int(u16(update, 1))
                guard count <= 4096 else { throw failure("Zu viele Bildrechtecke.") }
                var fullRefresh = false
                for _ in 0..<count {
                    let rect = try await read(12)
                    let x = Int(u16(rect, 0)), y = Int(u16(rect, 2))
                    let w = Int(u16(rect, 4)), h = Int(u16(rect, 6))
                    let encoding = Int32(bitPattern: u32(rect, 8))
                    if encoding == -223 {
                        try await resize(w, h)
                        fullRefresh = true
                    } else if encoding == 0 {
                        guard w > 0, h > 0, x + w <= width, y + h <= height else { throw failure(L10n.text("Ungültiges Player-Bildrechteck.")) }
                        let bytes = try await read(w * h * 4)
                        try await renderer.apply(x: x, y: y, width: w, height: h, data: bytes)
                    } else { throw failure("Nicht angefordertes Bildformat: \(encoding)") }
                }
                await publish()
                let delay = cadence.delay(at: ProcessInfo.processInfo.systemUptime)
                if delay > 0 { try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000)) }
                try Task.checkCancellation()
                guard !stopped else { return }
                request(incremental: !fullRefresh)
            case 1:
                let colors = try await read(5)
                _ = try await read(Int(u16(colors, 3)) * 6)
            case 2: break // Bell.
            case 3:
                let clipboard = try await read(7)
                let count = Int(u32(clipboard, 3))
                guard count <= 1_048_576 else { throw failure(L10n.text("Zwischenablagedaten zu groß.")) }
                _ = try await read(count) // Never import to the host clipboard.
            default: throw failure("Unbekannte Player-Nachricht: \(type)")
            }
        }
    }

    func stop() { stopped = true; wheel.reset(); connection?.cancel() }
    func resetScroll() { wheel.reset() }

    func pointer(x: Int, y: Int, mask: UInt8) {
        guard initialized, width > 0, height > 0 else { return }
        send(pointerMessage(x: x, y: y, mask: mask))
    }

    func scroll(x: Int, y: Int, vertical: Double, mask: UInt8) {
        guard initialized, connection != nil, width > 0, height > 0 else { return }
        let steps = wheel.consume(vertical)
        guard steps != 0 else { return }
        let base = mask & 7
        let button: UInt8 = steps > 0 ? 8 : 16
        var message = Data()
        for _ in 0..<abs(steps) {
            message.append(pointerMessage(x: x, y: y, mask: base | button))
            message.append(pointerMessage(x: x, y: y, mask: base))
        }
        // Keep wheel presses and releases together; never release a held mouse button.
        send(message)
    }
    private func pointerMessage(x: Int, y: Int, mask: UInt8) -> Data {
        let x = UInt16(max(0, min(width - 1, x))), y = UInt16(max(0, min(height - 1, y)))
        return Data([5, mask, UInt8(x >> 8), UInt8(x & 255), UInt8(y >> 8), UInt8(y & 255)])
    }

    func key(_ symbol: UInt32, down: Bool) {
        guard initialized else { return }
        send(keyMessage(symbol, down: down))
    }

    @discardableResult
    func sendKeySequence(_ events: [WindowsKeyboard.Event]) -> Bool {
        guard initialized, connection != nil, !events.isEmpty else { return false }
        // Keep the entire chord together, including modifier releases.
        var message = Data()
        for event in events { message.append(keyMessage(event.symbol, down: event.down)) }
        send(message)
        return true
    }

    private func keyMessage(_ symbol: UInt32, down: Bool) -> Data {
        Data([4, down ? 1 : 0, 0, 0, UInt8((symbol >> 24) & 255), UInt8((symbol >> 16) & 255),
              UInt8((symbol >> 8) & 255), UInt8(symbol & 255)])
    }

    private func resize(_ w: Int, _ h: Int) async throws {
        try await renderer.resize(width: w, height: h)
        width = w; height = h
    }

    private func publish() async {
        guard let frame = await renderer.takeFrame(), !Task.isCancelled, !stopped else { return }
        onFrame?(NSImage(cgImage: frame.image, size: NSSize(width: CGFloat(width), height: CGFloat(height))))
    }

    private func request(incremental: Bool) {
        cadence.requested(at: ProcessInfo.processInfo.systemUptime)
        send(Data([3, incremental ? 1 : 0, 0, 0, 0, 0, UInt8(width >> 8), UInt8(width & 255), UInt8(height >> 8), UInt8(height & 255)]))
    }

    private func send(_ data: Data) {
        connection?.send(content: data, completion: .contentProcessed { _ in })
    }

    private func read(_ count: Int) async throws -> Data {
        guard count >= 0, count <= 67_108_864 else { throw failure(L10n.text("Ungültige Player-Nachrichtenlänge.")) }
        while buffer.count < count {
            try Task.checkCancellation()
            guard let connection else { throw failure(L10n.text("Player-Verbindung geschlossen.")) }
            let chunk: Data = try await withCheckedThrowingContinuation { continuation in
                connection.receive(minimumIncompleteLength: 1, maximumLength: 1_048_576) { data, _, complete, error in
                    if let error { continuation.resume(throwing: error) }
                    else if let data, !data.isEmpty { continuation.resume(returning: data) }
                    else { continuation.resume(throwing: NSError(domain: "OpenGuest.RFB", code: 1,
                        userInfo: [NSLocalizedDescriptionKey: complete ? L10n.text("Player-Verbindung beendet.") : "Keine Player-Daten."])) }
                }
            }
            buffer.append(chunk)
        }
        guard let result = buffer.read(count) else { throw failure(L10n.text("Unvollständige Player-Daten.")) }
        return result
    }

    private func u16(_ bytes: Data, _ offset: Int) -> UInt16 {
        UInt16(bytes[offset]) << 8 | UInt16(bytes[offset + 1])
    }
    private func u32(_ bytes: Data, _ offset: Int) -> UInt32 {
        UInt32(bytes[offset]) << 24 | UInt32(bytes[offset + 1]) << 16 | UInt32(bytes[offset + 2]) << 8 | UInt32(bytes[offset + 3])
    }
    private func failure(_ message: String) -> NSError {
        NSError(domain: "OpenGuest.RFB", code: 1, userInfo: [NSLocalizedDescriptionKey: message])
    }
}
