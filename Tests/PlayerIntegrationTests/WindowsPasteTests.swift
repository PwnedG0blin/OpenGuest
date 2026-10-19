import AppKit
import Foundation
import StratovoCore
import XCTest
@testable import Stratovo

final class WindowsPasteTests: XCTestCase {
    @MainActor
    func testCommandVDoesNotSendWindowsKeyOrVToGuest() throws {
        let view = GuestSurface(frame: .zero)
        var events = [UInt16]()
        var pastes = 0
        view.configure(image: nil, video: nil, size: .zero, pointer: { _, _, _ in },
                       key: { code, _, _ in events.append(code) }, paste: { pastes += 1 })
        view.flagsChanged(with: try event(.flagsChanged, code: 55, flags: .command))
        XCTAssertTrue(view.performKeyEquivalent(with: try event(.keyDown, code: 9, text: "v", flags: .command)))
        // Key-up can go to the new paste sheet instead of this surface.
        view.flagsChanged(with: try event(.flagsChanged, code: 55))
        XCTAssertEqual(pastes, 1)
        XCTAssertTrue(events.isEmpty, "Command+V must not open Start or type a V into Windows")
        view.keyDown(with: try event(.keyDown, code: 9, text: "v"))
        view.keyUp(with: try event(.keyUp, code: 9, text: "v"))
        XCTAssertEqual(events, [9, 9], "A subsequent V must still get its key-up")
    }

    @MainActor
    func testCommandAloneStillActsAsWindowsKey() throws {
        let view = GuestSurface(frame: .zero)
        var events = [Bool]()
        view.configure(image: nil, video: nil, size: .zero, pointer: { _, _, _ in }, key: { _, _, down in events.append(down) }, paste: {})
        view.flagsChanged(with: try event(.flagsChanged, code: 55, flags: .command))
        view.flagsChanged(with: try event(.flagsChanged, code: 55))
        XCTAssertEqual(events, [true, false])
    }

    @MainActor
    func testOtherCommandChordsStillReachGuest() throws {
        let view = GuestSurface(frame: .zero)
        var events = [String]()
        view.configure(image: nil, video: nil, size: .zero, pointer: { _, _, _ in },
                       key: { code, _, down in events.append("\(code):\(down)") }, paste: {})
        view.flagsChanged(with: try event(.flagsChanged, code: 55, flags: .command))
        view.keyDown(with: try event(.keyDown, code: 15, text: "r", flags: .command))
        view.keyUp(with: try event(.keyUp, code: 15, text: "r", flags: .command))
        view.flagsChanged(with: try event(.flagsChanged, code: 55))
        XCTAssertEqual(events, ["55:true", "15:true", "15:false", "55:false"])
    }

    @MainActor
    func testTextSenderUsesGuestLayoutAndBoundedSelfReleasingChords() async throws {
        let input = try WindowsTextInput(text: "@\\Yz:\r\n", layout: .german)
        let peer = try QMPTextPeer(expected: input.chordCount)
        defer { peer.stop() }
        try await peer.waitUntilReady()
        var progress = [Int]()
        try await QMPClient.typeText(input, socket: peer.socket.path) { progress.append($0) }
        XCTAssertEqual(progress, [1, 2, 3, 4, 5])
        let requests = try peer.requests()
        let chords = requests.compactMap { $0["arguments"] as? [String: Any] }
        XCTAssertEqual(chords.count, 5)
        XCTAssertTrue(chords.allSatisfy { $0["hold-time"] as? Int == 20 })
        let keys = chords.map { ($0["keys"] as? [[String: String]] ?? []).compactMap { $0["data"] } }
        XCTAssertEqual(keys, [["alt_r", "q"], ["alt_r", "minus"], ["shift", "z"], ["y"], ["shift", "dot"]])
        XCTAssertFalse(keys.joined().contains("ret"), "A copied command must not run automatically")
    }

    @MainActor
    func testCancelStopsBeforeSendingRemainingText() async throws {
        let peer = try QMPTextPeer(expected: 0)
        defer { peer.stop() }
        try await peer.waitUntilReady()
        let input = try WindowsTextInput(text: "ABC", layout: .us)
        var task: Task<Void, Error>?
        task = Task {
            try await QMPClient.typeText(input, socket: peer.socket.path) { count in
                if count == 1 { task?.cancel() }
            }
        }
        do { try await task?.value; XCTFail("Typing must stop after cancellation") }
        catch { }
        let deadline = ProcessInfo.processInfo.systemUptime + 2
        while !FileManager.default.fileExists(atPath: peer.result.path), ProcessInfo.processInfo.systemUptime < deadline {
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        XCTAssertEqual(try peer.requests().filter { $0["execute"] as? String == "send-key" }.count, 1)
    }

    @MainActor
    private func event(_ type: NSEvent.EventType, code: UInt16, text: String = "", flags: NSEvent.ModifierFlags = []) throws -> NSEvent {
        try XCTUnwrap(NSEvent.keyEvent(with: type, location: .zero, modifierFlags: flags, timestamp: 0,
            windowNumber: 0, context: nil, characters: text, charactersIgnoringModifiers: text, isARepeat: false, keyCode: code))
    }
}

@MainActor
private final class QMPTextPeer {
    let root = URL(fileURLWithPath: "/tmp/og-paste-\(UUID().uuidString.prefix(8))")
    var socket: URL { root.appendingPathComponent("qmp.sock") }
    var result: URL { root.appendingPathComponent("keys.json") }
    private let process = Process()

    init(expected: Int) throws {
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let script = #"""
        import json, pathlib, socket, sys
        listener = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        listener.settimeout(10)
        listener.bind(sys.argv[1])
        listener.listen(1)
        conn, _ = listener.accept()
        conn.settimeout(10)
        conn.sendall(b'{"QMP":{"version":{"qemu":{"major":11,"minor":1,"micro":0}},"capabilities":[]}}\n')
        stream = conn.makefile('rb')
        requests = []
        expected = int(sys.argv[3])
        while True:
            line = stream.readline()
            if not line: break
            request = json.loads(line)
            requests.append(request)
            assert request['execute'] in ('qmp_capabilities', 'send-key')
            conn.sendall((json.dumps({'return': {}, 'id': request['id']}) + '\n').encode())
            if expected and len(requests) == expected + 1: break
        pathlib.Path(sys.argv[2]).write_text(json.dumps(requests))
        stream.close()
        conn.close()
        listener.close()
        """#
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["python3", "-c", script, socket.path, result.path, String(expected)]
        process.standardInput = FileHandle.nullDevice
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.standardError
        try process.run()
    }
    func waitUntilReady() async throws {
        let deadline = ProcessInfo.processInfo.systemUptime + 5
        while !FileManager.default.fileExists(atPath: socket.path), process.isRunning, ProcessInfo.processInfo.systemUptime < deadline {
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        XCTAssertTrue(FileManager.default.fileExists(atPath: socket.path))
    }
    func requests() throws -> [[String: Any]] {
        try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: result)) as? [[String: Any]])
    }
    func stop() {
        if process.isRunning { process.terminate() }
        process.waitUntilExit()
        try? FileManager.default.removeItem(at: root)
    }
}
