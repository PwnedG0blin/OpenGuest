import AppKit
import Foundation
import Network

// A minimal local RFB 3.8 client. Requests only Raw and DesktopSize encodings.
// No dependency on a web viewer, clipboard synchronization or a public listener.
@MainActor
final class RFBClient {
    private var connection: NWConnection?
    private var buffer = Data()
    private var pixels = Data()
    private var width = 0
    private var height = 0
    private(set) var initialized = false
    var onFrame: ((NSImage) -> Void)?
    var onStatus: ((String) -> Void)?

    func run(socket: String) async throws {
        let connection = NWConnection(to: .unix(path: socket), using: .tcp)
        self.connection = connection
        connection.start(queue: DispatchQueue(label: "OpenGuest.RFB.transport"))
        defer { connection.cancel(); self.connection = nil }
        let version = try await read(12)
        guard String(decoding: version, as: UTF8.self).hasPrefix("RFB 003.008") else { throw failure("RFB 3.8 benötigt.") }
        send(Data("RFB 003.008\n".utf8))
        let count = Int(try await read(1)[0])
        guard count > 0, count <= 64 else { throw failure("Keine unterstützte Player-Verbindung.") }
        let security = try await read(count)
        guard security.contains(1) else { throw failure("Lokale RFB-Sicherheitsart nicht verfügbar.") }
        send(Data([1]))
        let result = try await read(4)
        guard u32(result, 0) == 0 else { throw failure("Lokaler Player-Zugriff abgelehnt.") }
        send(Data([1])) // Shared session.
        let header = try await read(24)
        try resize(Int(u16(header, 0)), Int(u16(header, 2)))
        let nameLength = Int(u32(header, 20))
        guard nameLength <= 1_048_576 else { throw failure("Ungültiger Player-Name.") }
        _ = try await read(nameLength)
        // 32bpp, 24-bit true color, little endian, red/green/blue shifts 16/8/0.
        send(Data([0, 0, 0, 0, 32, 24, 0, 1, 0, 255, 0, 255, 0, 255, 16, 8, 0, 0, 0, 0]))
        send(Data([2, 0, 0, 2, 0, 0, 0, 0, 255, 255, 255, 33]))
        initialized = true
        onStatus?("Windows-Player verbunden · Maus und Tastatur aktiv")
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
                        try resize(w, h)
                        fullRefresh = true
                    } else if encoding == 0 {
                        guard w > 0, h > 0, x + w <= width, y + h <= height else { throw failure("Ungültiges Player-Bildrechteck.") }
                        let bytes = try await read(w * h * 4)
                        for row in 0..<h {
                            let target = ((y + row) * width + x) * 4
                            let source = row * w * 4
                            pixels.replaceSubrange(target..<(target + w * 4), with: bytes[source..<(source + w * 4)])
                        }
                    } else { throw failure("Nicht angefordertes Bildformat: \(encoding)") }
                }
                publish()
                try await Task.sleep(nanoseconds: 33_000_000)
                request(incremental: !fullRefresh)
            case 1:
                let colors = try await read(5)
                _ = try await read(Int(u16(colors, 3)) * 6)
            case 2: break // Bell.
            case 3:
                let clipboard = try await read(7)
                let count = Int(u32(clipboard, 3))
                guard count <= 1_048_576 else { throw failure("Zwischenablagedaten zu groß.") }
                _ = try await read(count) // Never import to the host clipboard.
            default: throw failure("Unbekannte Player-Nachricht: \(type)")
            }
        }
    }

    func stop() { connection?.cancel() }

    func pointer(x: Int, y: Int, mask: UInt8) {
        guard initialized, width > 0, height > 0 else { return }
        let x = UInt16(max(0, min(width - 1, x))), y = UInt16(max(0, min(height - 1, y)))
        send(Data([5, mask, UInt8(x >> 8), UInt8(x & 255), UInt8(y >> 8), UInt8(y & 255)]))
    }

    func key(_ symbol: UInt32, down: Bool) {
        guard initialized else { return }
        send(Data([4, down ? 1 : 0, 0, 0, UInt8((symbol >> 24) & 255), UInt8((symbol >> 16) & 255),
                   UInt8((symbol >> 8) & 255), UInt8(symbol & 255)]))
    }

    private func resize(_ w: Int, _ h: Int) throws {
        guard w > 0, h > 0, w <= 4096, h <= 4096, w * h <= 16_777_216 else { throw failure("Player-Auflösung nicht unterstützt (maximal 4096 × 4096).") }
        width = w; height = h
        pixels = Data(count: w * h * 4)
    }

    private func publish() {
        guard let provider = CGDataProvider(data: pixels as CFData),
              let image = CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32,
                                  bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGBitmapInfo.byteOrder32Little.union(CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipFirst.rawValue)),
                                  provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent) else { return }
        onFrame?(NSImage(cgImage: image, size: NSSize(width: CGFloat(width), height: CGFloat(height))))
    }

    private func request(incremental: Bool) {
        send(Data([3, incremental ? 1 : 0, 0, 0, 0, 0, UInt8(width >> 8), UInt8(width & 255), UInt8(height >> 8), UInt8(height & 255)]))
    }

    private func send(_ data: Data) {
        connection?.send(content: data, completion: .contentProcessed { _ in })
    }

    private func read(_ count: Int) async throws -> Data {
        guard count >= 0, count <= 67_108_864 else { throw failure("Ungültige Player-Nachrichtenlänge.") }
        while buffer.count < count {
            try Task.checkCancellation()
            guard let connection else { throw failure("Player-Verbindung geschlossen.") }
            let chunk: Data = try await withCheckedThrowingContinuation { continuation in
                connection.receive(minimumIncompleteLength: 1, maximumLength: 1_048_576) { data, _, complete, error in
                    if let error { continuation.resume(throwing: error) }
                    else if let data, !data.isEmpty { continuation.resume(returning: data) }
                    else { continuation.resume(throwing: NSError(domain: "OpenGuest.RFB", code: 1,
                        userInfo: [NSLocalizedDescriptionKey: complete ? "Player-Verbindung beendet." : "Keine Player-Daten."])) }
                }
            }
            buffer.append(chunk)
        }
        let result = Data(buffer.prefix(count))
        buffer = Data(buffer.dropFirst(count))
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
