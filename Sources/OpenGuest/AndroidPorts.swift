import Darwin
import Foundation

enum AndroidPorts {
    static func available() throws -> Int {
        for port in stride(from: 5554, through: 5682, by: 2) {
            let first = reserve(port)
            guard first >= 0 else { continue }
            let second = reserve(port + 1)
            close(first)
            if second >= 0 { close(second); return port }
        }
        throw NSError(domain: "OpenGuest", code: 1, userInfo: [NSLocalizedDescriptionKey: "Kein freies Android-Portpaar gefunden."])
    }
    static func availableDisplay() throws -> Int {
        for port in 5900...5999 {
            let fd = reserve(port)
            if fd >= 0 { close(fd); return port }
        }
        throw NSError(domain: "OpenGuest", code: 2, userInfo: [NSLocalizedDescriptionKey: "Kein freier lokaler Player-Port gefunden."])
    }
    private static func reserve(_ port: Int) -> Int32 {
        let fd = socket(AF_INET, SOCK_STREAM, 0)
        guard fd >= 0 else { return -1 }
        var address = sockaddr_in()
        address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        address.sin_family = sa_family_t(AF_INET)
        address.sin_port = UInt16(port).bigEndian
        address.sin_addr.s_addr = INADDR_ANY
        let result = withUnsafePointer(to: &address) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                Darwin.bind(fd, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        if result != 0 { close(fd); return -1 }
        return fd
    }
}
