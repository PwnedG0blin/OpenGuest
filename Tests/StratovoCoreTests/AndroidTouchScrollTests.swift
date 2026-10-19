import XCTest
@testable import StratovoCore

final class AndroidTouchScrollTests: XCTestCase {
    func testGestureProducesTouchDownMoveAndUpInsteadOfWheelEvents() {
        var swipe = AndroidTouchScroll()
        let down = swipe.packets(x: 500, y: 600, horizontal: 0, vertical: 0, width: 1000, height: 2000, phase: .began)
        XCTAssertEqual(down.count, 1)
        XCTAssertEqual(Array(down[0].prefix(2)), [2, 0])
        let move = swipe.packets(x: 500, y: 600, horizontal: 0.5, vertical: 1, width: 1000, height: 2000, phase: .changed)
        XCTAssertEqual(move, [ScrcpyWire.touch(x: 450, y: 700, width: 1000, height: 2000, action: 2)])
        let up = swipe.end()
        XCTAssertEqual(up, [ScrcpyWire.touch(x: 450, y: 700, width: 1000, height: 2000, action: 1)])
        XCTAssertTrue(swipe.end().isEmpty)
    }
    func testCancellationAndDisplayChangeReleasePreviousTouch() {
        var swipe = AndroidTouchScroll()
        _ = swipe.packets(x: 100, y: 200, horizontal: 0, vertical: 0, width: 1000, height: 2000, phase: .began)
        let changed = swipe.packets(x: 50, y: 60, horizontal: 0, vertical: 0, width: 500, height: 1000, phase: .began)
        XCTAssertEqual(changed.count, 2)
        XCTAssertEqual(changed[0], ScrcpyWire.touch(x: 100, y: 200, width: 1000, height: 2000, action: 1))
        let cancelled = swipe.packets(x: 0, y: 0, horizontal: 0, vertical: 0, width: 500, height: 1000, phase: .cancelled)
        XCTAssertEqual(cancelled.first?[1], 1)
        XCTAssertTrue(swipe.end().isEmpty)
    }
    func testEdgeLiftsFingerAndNextDeltaStartsFreshStroke() {
        var swipe = AndroidTouchScroll()
        _ = swipe.packets(x: 50, y: 95, horizontal: 0, vertical: 0, width: 100, height: 100, phase: .began)
        let edge = swipe.packets(x: 50, y: 95, horizontal: 0, vertical: 1, width: 100, height: 100, phase: .changed)
        XCTAssertEqual(edge.map { $0[1] }, [2, 1])
        let next = swipe.packets(x: 50, y: 95, horizontal: 0, vertical: -1, width: 100, height: 100, phase: .changed)
        XCTAssertEqual(next.map { $0[1] }, [0, 2])
        XCTAssertEqual(next.last, ScrcpyWire.touch(x: 50, y: 85, width: 100, height: 100, action: 2))
    }
}
