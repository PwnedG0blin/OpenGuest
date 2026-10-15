import Foundation

@MainActor
enum QMPClient {
    static func shutdown(socket: String) async throws {
        let stream = LocalStream(socket: socket)
        let timeout = Task { try? await Task.sleep(nanoseconds: 5_000_000_000); if !Task.isCancelled { stream.close() } }
        defer { timeout.cancel(); stream.close() }
        _ = try await line(stream)
        stream.send(Data("{\"execute\":\"qmp_capabilities\",\"id\":1}\n".utf8))
        try await response(stream, id: 1)
        stream.send(Data("{\"execute\":\"system_powerdown\",\"id\":2}\n".utf8))
        try await response(stream, id: 2)
    }
    private static func response(_ stream: LocalStream, id: Int) async throws {
        for _ in 0..<100 {
            let value = try JSONSerialization.jsonObject(with: await line(stream)) as? [String: Any]
            if value?["id"] as? Int == id {
                if value?["return"] != nil { return }
                throw NSError(domain: "OpenGuest.QMP", code: 1, userInfo: [NSLocalizedDescriptionKey: "QEMU hat das Herunterfahren abgelehnt."])
            }
        }
        throw NSError(domain: "OpenGuest.QMP", code: 1, userInfo: [NSLocalizedDescriptionKey: "Keine QEMU-Antwort."])
    }
    private static func line(_ stream: LocalStream) async throws -> Data {
        var data = Data()
        for _ in 0..<65536 {
            let byte = try await stream.read(1)
            data += byte
            if byte[0] == 10 { return data }
        }
        throw NSError(domain: "OpenGuest.QMP", code: 1, userInfo: [NSLocalizedDescriptionKey: "QEMU-Nachricht zu lang."])
    }
}
