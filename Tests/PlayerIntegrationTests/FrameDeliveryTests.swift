import AppKit
import XCTest
@testable import Stratovo

final class FrameDeliveryTests: XCTestCase {
    func testOffscreenRendererPublishesOnlyChangedFramebuffer() async throws {
        let renderer = WindowsFrameRenderer()
        try await renderer.resize(width: 2, height: 2)
        let first = await renderer.takeFrame()
        XCTAssertNotNil(first)
        let unchanged = await renderer.takeFrame()
        XCTAssertNil(unchanged)
        try await renderer.apply(x: 1, y: 0, width: 1, height: 1, data: Data([12, 34, 56, 0]))
        let updated = await renderer.takeFrame()
        let image = try XCTUnwrap(updated?.image)
        let bytes = try XCTUnwrap(image.dataProvider?.data)
        XCTAssertEqual((bytes as Data).subdata(in: 4..<8), Data([12, 34, 56, 0]))
        let initial = try XCTUnwrap(first?.image.dataProvider?.data)
        XCTAssertEqual(initial as Data, Data(count: 16))
    }
    @MainActor
    func testVideoLayerIsLaidOutWhenAddedWithoutAResolutionChange() {
        let viewport = GuestViewport(frame: NSRect(x: 0, y: 0, width: 400, height: 700))
        let size = CGSize(width: 1440, height: 3120)
        viewport.configure(image: nil, video: nil, size: size, pointer: { _,_,_ in }, key: { _,_,_ in }, paste: nil, scroll: nil, resetScroll: nil, zoomPercent: nil)
        viewport.layoutSubtreeIfNeeded()
        let layer = H264Player().layer
        viewport.configure(image: nil, video: layer, size: size, pointer: { _,_,_ in }, key: { _,_,_ in }, paste: nil, scroll: nil, resetScroll: nil, zoomPercent: nil)
        viewport.layoutSubtreeIfNeeded()
        XCTAssertEqual(layer.frame, viewport.surface.imageRect)
    }
}
