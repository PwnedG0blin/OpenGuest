import XCTest
@testable import StratovoCore

final class ScrollSpeedTests: XCTestCase {
    func testHalfSpeedPreservesDirectionAndFractionalWindowsWheelSteps() {
        var wheel = WindowsWheelScroll()
        let delta = GuestScrollDelta(deltaX: 20, deltaY: 40, precise: true)
        XCTAssertEqual(GuestScrollSpeed.scale(delta.horizontal, percent: 50), -0.25)
        XCTAssertEqual(wheel.consume(GuestScrollSpeed.scale(delta.vertical, percent: 50)), 0)
        XCTAssertEqual(wheel.consume(GuestScrollSpeed.scale(delta.vertical, percent: 50)), 1)
        wheel.reset()
        XCTAssertEqual(wheel.consume(GuestScrollSpeed.scale(-1, percent: 200)), -2)
    }
    func testInvalidSettingsAndDeltasStayBounded() {
        XCTAssertEqual(GuestScrollSpeed.percent(.nan), 50)
        XCTAssertEqual(GuestScrollSpeed.percent(-10), 10)
        XCTAssertEqual(GuestScrollSpeed.percent(900), 200)
        XCTAssertEqual(GuestScrollSpeed.scale(.infinity, percent: 100), 0)
        XCTAssertEqual(GuestScrollSpeed.scale(1000, percent: 200), 16)
        XCTAssertEqual(GuestScrollSpeed.scale(1, percent: 100), 1)
    }
}
