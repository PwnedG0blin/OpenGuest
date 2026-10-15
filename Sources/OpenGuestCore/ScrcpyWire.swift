import Foundation

// Wire format pinned to scrcpy 4.0. No scrcpy source code is bundled.
public enum ScrcpyWire {
    public static let version = "4.0"
    public enum Header: Equatable {
        case session(width: Int, height: Int)
        case packet(size: Int, pts: UInt64, configuration: Bool)
    }
    public static func header(_ bytes: Data) throws -> Header {
        guard bytes.count == 12 else { throw GuestError.invalidResources }
        func u32(_ i: Int) -> UInt32 {
            UInt32(bytes[i]) << 24 | UInt32(bytes[i + 1]) << 16 | UInt32(bytes[i + 2]) << 8 | UInt32(bytes[i + 3])
        }
        if bytes[0] & 0x80 != 0 {
            let w = Int(u32(4)), h = Int(u32(8))
            guard (1...8192).contains(w), (1...8192).contains(h) else { throw GuestError.invalidResources }
            return .session(width: w, height: h)
        }
        let size = Int(u32(8))
        guard (1...16_777_216).contains(size) else { throw GuestError.invalidResources }
        let flags = UInt64(u32(0)) << 32 | UInt64(u32(4))
        return .packet(size: size, pts: flags & 0x1fff_ffff_ffff_ffff, configuration: flags & (1 << 62) != 0)
    }

    public static func nalUnits(_ data: Data) -> [Data] {
        let bytes = [UInt8](data)
        var starts: [(Int, Int)] = []
        var index = 0
        while index + 3 <= bytes.count {
            if bytes[index] == 0, bytes[index + 1] == 0 {
                if bytes[index + 2] == 1 { starts.append((index, index + 3)); index += 3; continue }
                if index + 4 <= bytes.count, bytes[index + 2] == 0, bytes[index + 3] == 1 {
                    starts.append((index, index + 4)); index += 4; continue
                }
            }
            index += 1
        }
        return starts.enumerated().compactMap { i, start in
            let end = i + 1 < starts.count ? starts[i + 1].0 : bytes.count
            return start.1 < end ? Data(bytes[start.1..<end]) : nil
        }
    }

    public static func integer(_ value: UInt64, bytes: Int) -> Data {
        Data((0..<bytes).reversed().map { UInt8((value >> ($0 * 8)) & 255) })
    }
    public static func key(_ code: UInt32, down: Bool) -> Data {
        Data([0, down ? 0 : 1]) + integer(UInt64(code), bytes: 4) + Data(repeating: 0, count: 8)
    }
    public static func text(_ text: String) -> Data {
        let payload = Data(text.utf8.prefix(1024))
        return Data([1]) + integer(UInt64(payload.count), bytes: 4) + payload
    }
    public static func touch(x: Int, y: Int, width: Int, height: Int, action: UInt8) -> Data {
        guard (1...8192).contains(width), (1...8192).contains(height), action <= 2 else { return Data() }
        let x = max(0, min(width - 1, x)), y = max(0, min(height - 1, y))
        // Synthetic single-touch pointer id -2; action 0 down, 1 up, 2 move.
        return Data([2, action]) + integer(UInt64.max - 1, bytes: 8) + integer(UInt64(x), bytes: 4) +
            integer(UInt64(y), bytes: 4) + integer(UInt64(width), bytes: 2) + integer(UInt64(height), bytes: 2) +
            integer(action == 1 ? 0 : 65535, bytes: 2) + Data(repeating: 0, count: 8)
    }
}
