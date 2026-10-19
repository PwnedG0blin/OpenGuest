import Foundation
import CoreGraphics
import XCTest
@testable import StratovoCore

final class GuestDisplayTests: XCTestCase {
    func testPreciseScrollRetainsFractionsDirectionAndBounds() {
        let delta = GuestScrollDelta(deltaX: 10, deltaY: -20, precise: true)
        XCTAssertEqual(delta.horizontal, -0.25)
        XCTAssertEqual(delta.vertical, -0.5)
        let wheel = GuestScrollDelta(deltaX: -3, deltaY: 3, precise: false)
        XCTAssertEqual(wheel.horizontal, 1); XCTAssertEqual(wheel.vertical, 1)
        XCTAssertEqual(GuestScrollDelta(deltaX: .infinity, deltaY: .nan, precise: true).vertical, 0)
        XCTAssertEqual(GuestScrollDelta(deltaX: -1e100, deltaY: -1e100, precise: true).vertical, -8)
    }
    func testWindowsWheelAccumulatesTinyMotionReversesAndResets() {
        var wheel = WindowsWheelScroll()
        var count = 0
        for _ in 0..<40 { count += wheel.consume(0.025) }
        XCTAssertEqual(count, 1, "A slow trackpad gesture must not disappear through rounding")
        XCTAssertEqual(wheel.consume(0.75), 0)
        XCTAssertEqual(wheel.consume(-0.25), 0)
        XCTAssertEqual(wheel.consume(-0.75), -1)
        XCTAssertEqual(wheel.consume(0.75), 0)
        wheel.reset()
        XCTAssertEqual(wheel.consume(0.5), 0)
        XCTAssertEqual(wheel.consume(.infinity), 0)
        XCTAssertEqual(wheel.consume(0.5), 0)
        XCTAssertEqual(wheel.consume(1e100), 8)
    }
    func testAndroidScrollMatchesPinnedScrcpyProtocolAndPreservesFractionalDeltas() {
        let official = ScrcpyWire.scroll(x: 260, y: 1026, width: 1080, height: 1920, horizontal: 16, vertical: -16, buttons: 1)
        XCTAssertEqual(official, Data([3, 0,0,1,4, 0,0,4,2, 4,56,7,128, 127,255,128,0, 0,0,0,1]))
        let fractional = ScrcpyWire.scroll(x: -1, y: 9999, width: 720, height: 1600, horizontal: 0.125, vertical: -0.5)
        XCTAssertEqual(fractional.count, 21)
        XCTAssertEqual(Array(fractional[1..<9]), [0,0,0,0, 0,0,6,63])
        XCTAssertEqual(Array(fractional[13..<17]), [1,0,252,0])
        XCTAssertTrue(ScrcpyWire.scroll(x: 0, y: 0, width: 0, height: 10, horizontal: 1, vertical: 1).isEmpty)
        XCTAssertTrue(ScrcpyWire.scroll(x: 0, y: 0, width: 10, height: 10, horizontal: .nan, vertical: 1).isEmpty)
    }
    func testFitMappingExcludesLetterboxAndKeepsClickCoordinates() throws {
        let g = GuestDisplayGeometry(source: CGSize(width: 1080, height: 2400), viewport: CGSize(width: 1000, height: 500))
        XCTAssertEqual(g.imageRect.width, 225, accuracy: 0.001)
        XCTAssertEqual(g.imageRect.minX, 387.5, accuracy: 0.001)
        let center = try XCTUnwrap(g.point(at: CGPoint(x: 500, y: 250), clamped: false))
        XCTAssertEqual(center.0, 540); XCTAssertEqual(center.1, 1200)
        XCTAssertNil(g.point(at: CGPoint(x: 10, y: 250), clamped: false))
        XCTAssertEqual(g.point(at: CGPoint(x: 10, y: 250), clamped: true)?.0, 0)
    }
    func testZoomUsesBackingPixelsAndRemainsCorrectWhenCropped() {
        let native = GuestDisplayGeometry(source: CGSize(width: 1920, height: 1080), viewport: CGSize(width: 500, height: 400), zoomPercent: 100, backingScale: 2)
        XCTAssertEqual(native.documentSize, CGSize(width: 960, height: 540))
        XCTAssertEqual(native.point(at: CGPoint(x: 900, y: 500), clamped: false)?.0, 1800)
        let doubled = GuestDisplayGeometry(source: CGSize(width: 1920, height: 1080), viewport: CGSize(width: 500, height: 400), zoomPercent: 200, backingScale: 2)
        XCTAssertEqual(doubled.documentSize, CGSize(width: 1920, height: 1080))
        XCTAssertEqual(doubled.point(at: CGPoint(x: 900, y: 500), clamped: false)?.0, 900)
        XCTAssertNil(GuestDisplayGeometry(source: .zero, viewport: .zero).point(at: .zero, clamped: true))
    }
    func testCustomAndroidDisplayPreservesRollbackAndRejectsUnsafeSizes() throws {
        let custom = try AndroidCustomDisplay(width: 1200, height: 1920, density: 320)
        let plan = try AndroidDisplayPlan(sizeOutput: "Physical size: 1080x2400\nOverride size: 720x1600",
            densityOutput: "Physical density: 420\nOverride density: 280", profile: .smooth, custom: custom)
        XCTAssertEqual(plan.commands, [["wm", "size", "1200x1920"], ["wm", "density", "320"]])
        XCTAssertEqual(plan.rollback, [["wm", "size", "720x1600"], ["wm", "density", "280"]])
        for (w,h,d) in [(0,1600,280), (721,1600,280), (4096,4096,320), (720,1600,0), (720,1600,Int.max), (Int.max,Int.max,280)] {
            XCTAssertThrowsError(try AndroidCustomDisplay(width: w, height: h, density: d))
        }
    }
}
