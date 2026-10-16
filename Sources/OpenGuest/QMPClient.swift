import Foundation
import OpenGuestCore

@MainActor
enum QMPClient {
    static func shutdown(socket: String) async throws {
        let stream = LocalStream(socket: socket)
        let timeout = watchdog(stream)
        defer { timeout.cancel(); stream.close() }
        _ = try await line(stream)
        _ = try await command("qmp_capabilities", id: 1, stream: stream)
        _ = try await command("system_powerdown", id: 2, stream: stream)
    }
    static func inspect(socket: String) async throws -> WindowsBootEvidence {
        let stream = LocalStream(socket: socket)
        let timeout = watchdog(stream)
        defer { timeout.cancel(); stream.close() }
        _ = try await line(stream)
        _ = try await command("qmp_capabilities", id: 1, stream: stream)
        let state = try await command("query-status", id: 2, stream: stream)
        let blocks = try await command("query-block", id: 3, stream: stream)
        return try WindowsBootEvidence(status: JSONSerialization.data(withJSONObject: state),
                                       blocks: JSONSerialization.data(withJSONObject: blocks))
    }
    private static func watchdog(_ stream: LocalStream) -> Task<Void, Never> {
        Task { try? await Task.sleep(nanoseconds: 5_000_000_000); if !Task.isCancelled { stream.close() } }
    }
    private static func command(_ name: String, id: Int, stream: LocalStream) async throws -> Any {
        var request = try JSONSerialization.data(withJSONObject: ["execute": name, "id": id])
        request.append(10)
        stream.send(request)
        for _ in 0..<100 {
            try Task.checkCancellation()
            let value = try JSONSerialization.jsonObject(with: await line(stream)) as? [String: Any]
            if value?["id"] as? Int == id {
                if let result = value?["return"] { return result }
                throw NSError(domain: "OpenGuest.QMP", code: 1, userInfo: [NSLocalizedDescriptionKey: "QEMU hat die Anfrage \(name) abgelehnt."])
            }
        }
        throw NSError(domain: "OpenGuest.QMP", code: 1, userInfo: [NSLocalizedDescriptionKey: "Keine QEMU-Antwort."])
    }
    private static func line(_ stream: LocalStream) async throws -> Data {
        var data = Data()
        for _ in 0..<262144 {
            let byte = try await stream.read(1)
            data += byte
            if byte[0] == 10 { return data }
        }
        throw NSError(domain: "OpenGuest.QMP", code: 1, userInfo: [NSLocalizedDescriptionKey: "QEMU-Nachricht zu lang."])
    }
}
