import Foundation

/// Consumes small wire headers without copying the remaining video payload each time.
public struct StreamByteBuffer: Sendable {
    private var storage = Data()
    private var offset = 0
    public init() {}
    public var count: Int { storage.count - offset }
    public mutating func append(_ data: Data) {
        if offset > 0 && (offset >= 262_144 || offset >= storage.count / 2) {
            storage = Data(storage.dropFirst(offset)); offset = 0
        }
        storage.append(data)
    }
    public mutating func read(_ count: Int) -> Data? {
        guard count >= 0, count <= self.count else { return nil }
        let result = storage.subdata(in: offset..<(offset + count))
        offset += count
        if offset == storage.count { storage.removeAll(keepingCapacity: true); offset = 0 }
        return result
    }
}

/// Network and render time count toward the frame interval; never add a fixed delay on top.
public struct FrameRequestCadence: Sendable {
    private var lastRequest: TimeInterval?
    private let interval: TimeInterval
    public init(fps: Int = 60) { interval = 1 / Double(max(1, min(120, fps))) }
    public func delay(at now: TimeInterval) -> TimeInterval {
        guard now.isFinite, let lastRequest, now >= lastRequest else { return 0 }
        return max(0, interval - (now - lastRequest))
    }
    public mutating func requested(at now: TimeInterval) { lastRequest = now.isFinite ? now : nil }
}

public struct RawFramebuffer: Sendable {
    public private(set) var width = 0
    public private(set) var height = 0
    public private(set) var bytes = Data()
    public init() {}
    public mutating func resize(width: Int, height: Int) throws {
        guard (1...4096).contains(width), (1...4096).contains(height) else { throw Self.invalid() }
        self.width = width; self.height = height; bytes = Data(count: width * height * 4)
    }
    public mutating func apply(x: Int, y: Int, width: Int, height: Int, data: Data) throws {
        guard x >= 0, y >= 0, width > 0, height > 0, width <= self.width, height <= self.height,
              x <= self.width - width, y <= self.height - height, data.count == width * height * 4 else { throw Self.invalid() }
        let stride = self.width * 4, rowBytes = width * 4
        bytes.withUnsafeMutableBytes { target in
            data.withUnsafeBytes { source in
                let dst = target.baseAddress!, src = source.baseAddress!
                if x == 0 && rowBytes == stride {
                    dst.advanced(by: y * stride).copyMemory(from: src, byteCount: data.count)
                } else {
                    for row in 0..<height {
                        dst.advanced(by: (y + row) * stride + x * 4).copyMemory(from: src.advanced(by: row * rowBytes), byteCount: rowBytes)
                    }
                }
            }
        }
    }
    private static func invalid() -> NSError {
        NSError(domain: "Pixelkoje.Framebuffer", code: 1, userInfo: [NSLocalizedDescriptionKey: "Ungültige Auflösung oder Bilddaten."])
    }
}

public struct SessionLogSnapshot: Sendable {
    public let size: UInt64
    public let tail: String
    public let header: String
}
public enum SessionLogReader {
    public static func read(url: URL, previousSize: UInt64?, includeHeader: Bool) throws -> SessionLogSnapshot? {
        let file = try FileHandle(forReadingFrom: url)
        defer { try? file.close() }
        let size = try file.seekToEnd()
        guard size != previousSize else { return nil }
        try file.seek(toOffset: size > 60_000 ? size - 60_000 : 0)
        let tail = try file.read(upToCount: 60_000) ?? Data()
        var header = Data()
        if includeHeader { try file.seek(toOffset: 0); header = try file.read(upToCount: 96_000) ?? Data() }
        return SessionLogSnapshot(size: size, tail: String(decoding: tail, as: UTF8.self), header: String(decoding: header, as: UTF8.self))
    }
}
