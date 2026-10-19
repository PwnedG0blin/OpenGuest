import AppKit
import Foundation
import StratovoCore
import XCTest
@testable import Stratovo

final class WindowsKeyboardIntegrationTests: XCTestCase {
    @MainActor
    func testSetupConsoleChordReachesRFBPeerWithModifierReleases() async throws {
        let fm = FileManager.default
        let root = URL(fileURLWithPath: "/tmp/og-keys-\(UUID().uuidString.prefix(8))")
        try fm.createDirectory(at: root, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        defer { try? fm.removeItem(at: root) }
        let socket = root.appendingPathComponent("display.sock")
        let result = root.appendingPathComponent("keys.bin")
        let output = root.appendingPathComponent("peer.log")
        fm.createFile(atPath: output.path, contents: nil)
        let log = try FileHandle(forWritingTo: output)
        defer { try? log.close() }
        // A loopback RFB peer records the actual bytes sent by the production client.
        let script = #"""
        import pathlib, socket, struct, sys
        listener = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        listener.settimeout(10)
        listener.bind(sys.argv[1])
        listener.listen(1)
        connection, _ = listener.accept()
        connection.settimeout(10)
        def read(count):
            data = b''
            while len(data) < count:
                chunk = connection.recv(count - len(data))
                if not chunk:
                    raise RuntimeError('Client closed before all key events arrived')
                data += chunk
            return data
        connection.sendall(b'RFB 003.008\n')
        assert read(12) == b'RFB 003.008\n'
        connection.sendall(bytes([1, 1]))
        assert read(1) == bytes([1])
        connection.sendall(bytes(4))
        assert read(1) == bytes([1])
        pixel_format = struct.pack('>BBBBHHHBBBxxx', 32, 24, 0, 1, 255, 255, 255, 16, 8, 0)
        connection.sendall(struct.pack('>HH', 1, 1) + pixel_format + struct.pack('>I', 4) + b'keys')
        assert read(20)[0] == 0
        encodings = read(4)
        assert encodings[0] == 2
        read(struct.unpack('>H', encodings[2:])[0] * 4)
        assert read(10)[0] == 3
        connection.sendall(struct.pack('>BBHHH HHi', 0, 0, 1, 0, 0, 1, 1, 0) + bytes(4))
        events = read(32)
        pathlib.Path(sys.argv[2]).write_bytes(events)
        connection.close()
        listener.close()
        """#
        let peer = Process()
        peer.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        peer.arguments = ["python3", "-c", script, socket.path, result.path]
        peer.standardInput = FileHandle.nullDevice
        peer.standardOutput = log; peer.standardError = log
        try peer.run()
        defer { if peer.isRunning { peer.terminate() }; peer.waitUntilExit() }
        let readyDeadline = ProcessInfo.processInfo.systemUptime + 5
        while !fm.fileExists(atPath: socket.path), peer.isRunning, ProcessInfo.processInfo.systemUptime < readyDeadline {
            try await Task.sleep(nanoseconds: 20_000_000)
        }
        XCTAssertTrue(fm.fileExists(atPath: socket.path), (try? String(contentsOf: output)) ?? "RFB peer absent")
        let client = RFBClient()
        XCTAssertFalse(client.sendKeySequence(WindowsKeyboard.setupConsole), "Never send before a connection is ready")
        var sent = false
        client.onFrame = { _ in
            guard !sent else { return }
            sent = client.sendKeySequence(WindowsKeyboard.setupConsole)
        }
        let timeout = Task {
            try? await Task.sleep(nanoseconds: 10_000_000_000)
            if !Task.isCancelled { client.stop() }
        }
        defer { timeout.cancel(); client.stop() }
        do { try await client.run(socket: socket.path) }
        catch { if !sent { XCTFail("Shortcut was not sent: \(error)") } }
        XCTAssertTrue(sent)
        let actual = try Data(contentsOf: result)
        // RFB KeyEvent (type 4), Shift down, F10 down/up, Shift up.
        XCTAssertEqual(actual, Data([
            4, 1, 0, 0, 0, 0, 255, 225,
            4, 1, 0, 0, 0, 0, 255, 199,
            4, 0, 0, 0, 0, 0, 255, 199,
            4, 0, 0, 0, 0, 0, 255, 225
        ]))
        XCTAssertFalse(client.sendKeySequence(WindowsKeyboard.setupConsole), "Never send to a disconnected peer")
    }
}
