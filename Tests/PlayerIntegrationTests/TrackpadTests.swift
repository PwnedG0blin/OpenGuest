import AppKit
import Foundation
import OpenGuestCore
import XCTest
@testable import OpenGuest

final class TrackpadTests: XCTestCase {
    @MainActor
    func testActualViewportZoomUsesSameGeometryForDrawingAndPointerMapping() {
        let viewport = GuestViewport(frame: NSRect(x: 0, y: 0, width: 400, height: 300))
        viewport.configure(image: nil, video: nil, size: CGSize(width: 200, height: 100),
            pointer: { _,_,_ in }, key: { _,_,_ in }, paste: nil, scroll: { _,_,_,_,_ in }, resetScroll: nil, zoomPercent: 300)
        viewport.layoutSubtreeIfNeeded()
        XCTAssertEqual(viewport.surface.imageRect.size, CGSize(width: 600, height: 300))
        XCTAssertEqual(viewport.surface.frame.width, 600)
        XCTAssertEqual(viewport.surface.sourcePoint(at: CGPoint(x: 300, y: 150), clamped: false)?.0, 100)
        viewport.configure(image: nil, video: nil, size: CGSize(width: 200, height: 100),
            pointer: { _,_,_ in }, key: { _,_,_ in }, paste: nil, scroll: { _,_,_,_,_ in }, resetScroll: nil, zoomPercent: nil)
        viewport.layoutSubtreeIfNeeded()
        XCTAssertEqual(viewport.surface.imageRect.width, 400)
        XCTAssertEqual(viewport.surface.sourcePoint(at: CGPoint(x: 200, y: 150), clamped: false)?.0, 100)
    }
    @MainActor
    func testRealAppKitScrollEventReachesSurfaceWithoutMouseClick() throws {
        let cg = try XCTUnwrap(CGEvent(scrollWheelEvent2Source: nil, units: .pixel, wheelCount: 2, wheel1: 10, wheel2: 20, wheel3: 0))
        cg.location = CGPoint(x: 100, y: 100)
        let event = try XCTUnwrap(NSEvent(cgEvent: cg))
        XCTAssertTrue(event.hasPreciseScrollingDeltas)
        let view = GuestSurface(frame: NSRect(x: 0, y: 0, width: 4000, height: 4000))
        var received = [(Double, Double)]()
        var clicks = 0
        view.configure(image: nil, video: nil, size: CGSize(width: 1000, height: 1000),
                       pointer: { _,_,_ in clicks += 1 }, key: { _,_,_ in },
                       scroll: { _,_,h,v,_ in received.append((h,v)) })
        view.scrollWheel(with: event)
        XCTAssertEqual(received.count, 1)
        XCTAssertEqual(received.first?.0, -0.5)
        XCTAssertEqual(received.first?.1, 0.25)
        XCTAssertEqual(clicks, 0, "Two-finger scrolling must not inject a tap")
    }
    @MainActor
    func testMomentumStaysAtGestureAnchorAndCancelOrFocusLossResetsIt() {
        let view = GuestSurface(frame: NSRect(x: 0, y: 0, width: 400, height: 400))
        var points = [(Int, Int)]()
        var resets = 0
        view.configure(image: nil, video: nil, size: CGSize(width: 400, height: 200),
                       pointer: { _,_,_ in }, key: { _,_,_ in },
                       scroll: { x,y,_,_,_ in points.append((x,y)) }, resetScroll: { resets += 1 })
        let delta = GuestScrollDelta(deltaX: 0, deltaY: -10, precise: true)
        view.scrollInput(at: CGPoint(x: 50, y: 150), delta: delta, phase: .began, momentum: [])
        view.scrollInput(at: CGPoint(x: 900, y: 900), delta: delta, phase: [], momentum: .began)
        XCTAssertEqual(points.count, 2)
        XCTAssertTrue(points.allSatisfy { $0.0 == 50 && $0.1 == 50 })
        view.scrollInput(at: .zero, delta: delta, phase: .cancelled, momentum: [])
        XCTAssertEqual(points.count, 2)
        _ = view.resignFirstResponder()
        XCTAssertGreaterThanOrEqual(resets, 3)
        view.scrollInput(at: CGPoint(x: 20, y: 10), delta: delta, phase: .began, momentum: [])
        XCTAssertEqual(points.count, 2, "A gesture begun in the black margin must not scroll the guest")
    }
    @MainActor
    func testPrecisionModeIgnoresMomentumButPreservesFingerAndMouseWheelInput() {
        let view = GuestSurface(frame: NSRect(x: 0, y: 0, width: 400, height: 400))
        var received = [Double]()
        view.configure(image: nil, video: nil, size: CGSize(width: 400, height: 400),
                       pointer: { _,_,_ in }, key: { _,_,_ in },
                       scroll: { _,_,_,v,_ in received.append(v) }, allowsScrollMomentum: false)
        let delta = GuestScrollDelta(deltaX: 0, deltaY: 20, precise: true)
        view.scrollInput(at: CGPoint(x: 100, y: 100), delta: delta, phase: .began, momentum: [])
        view.scrollInput(at: CGPoint(x: 100, y: 100), delta: delta, phase: [], momentum: .began)
        view.scrollInput(at: CGPoint(x: 100, y: 100), delta: delta, phase: [], momentum: .changed)
        XCTAssertEqual(received, [0.5])
        view.scrollInput(at: CGPoint(x: 100, y: 100), delta: delta, phase: [], momentum: [])
        XCTAssertEqual(received, [0.5, 0.5])
    }
    @MainActor
    func testWindowsWheelSendsPairedPressReleaseAndPreservesHeldButton() async throws {
        let fm = FileManager.default
        let root = URL(fileURLWithPath: "/tmp/og-wheel-\(UUID().uuidString.prefix(8))")
        try fm.createDirectory(at: root, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        defer { try? fm.removeItem(at: root) }
        let socket = root.appendingPathComponent("display.sock")
        let result = root.appendingPathComponent("wheel.bin")
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
        connection.sendall(struct.pack('>HH', 640, 480) + pixel_format + struct.pack('>I', 4) + b'keys')
        assert read(20)[0] == 0
        encodings = read(4)
        assert encodings[0] == 2
        read(struct.unpack('>H', encodings[2:])[0] * 4)
        assert read(10)[0] == 3
        connection.sendall(struct.pack('>BBHHH HHi', 0, 0, 1, 0, 0, 1, 1, 0) + bytes(4))
        events = read(48)
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
        client.scroll(x: 120, y: 200, vertical: 1, mask: 1) // Ignored before connection.
        var sent = false
        client.onFrame = { _ in
            guard !sent else { return }
            sent = true
            client.pointer(x: 120, y: 200, mask: 1)
            client.scroll(x: 120, y: 200, vertical: 0.25, mask: 1)
            client.scroll(x: 120, y: 200, vertical: 0.25, mask: 1)
            client.scroll(x: 120, y: 200, vertical: 0.5, mask: 1)
            client.scroll(x: 120, y: 200, vertical: -2, mask: 1)
            client.pointer(x: 120, y: 200, mask: 0)
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
        let expected = Data([UInt8(1), 9, 1, 17, 1, 17, 1, 0].flatMap { mask in
            [UInt8(5), mask, 0, 120, 0, 200]
        })
        XCTAssertEqual(actual, expected, "Each wheel press must release while keeping the held left button")
        XCTAssertFalse(client.initialized)
    }

}
