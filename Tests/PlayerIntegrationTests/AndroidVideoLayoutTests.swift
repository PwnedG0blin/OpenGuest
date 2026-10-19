import AppKit
import AVFoundation
import StratovoCore
import XCTest
@testable import Stratovo

final class AndroidVideoLayoutTests: XCTestCase {
    @MainActor
    func testLiveHighResolutionVideoAndWindowResizeFillAvailableHeight() {
        let view = GuestViewport(frame: NSRect(x: 0, y: 0, width: 1200, height: 800))
        let video = AVSampleBufferDisplayLayer()
        for source in [CGSize(width: 720, height: 1600), CGSize(width: 1440, height: 3120), CGSize(width: 592, height: 1280)] {
            view.configure(image: nil, video: video, size: source, pointer: { _,_,_ in }, key: { _,_,_ in },
                paste: nil, scroll: nil, resetScroll: nil, zoomPercent: nil)
            view.layoutSubtreeIfNeeded()
            XCTAssertEqual(video.frame, view.surface.imageRect)
            XCTAssertEqual(video.frame.height, view.contentSize.height, accuracy: 1)
            let center = view.surface.sourcePoint(at: CGPoint(x: video.frame.midX, y: video.frame.midY), clamped: false)
            XCTAssertEqual(Double(center?.0 ?? -999), Double(source.width / 2), accuracy: 1)
            XCTAssertEqual(Double(center?.1 ?? -999), Double(source.height / 2), accuracy: 1)
        }
        view.setFrameSize(NSSize(width: 400, height: 1000))
        view.layoutSubtreeIfNeeded()
        XCTAssertEqual(video.frame, view.surface.imageRect)
        XCTAssertEqual(video.frame.width, view.contentSize.width, accuracy: 1)
        XCTAssertLessThanOrEqual(video.frame.height, view.contentSize.height + 1)
    }
    func testPortraitWindowUsesAvailableHeightAndStaysOnSmallScreens() {
        let size = AndroidPhoneWindow.size(source: CGSize(width: 1440, height: 3120),
            available: CGSize(width: 1900, height: 1056), chrome: CGSize(width: 0, height: 250))
        XCTAssertEqual(size.height, 1056)
        XCTAssertEqual((size.width) / (size.height - 250), 1440.0 / 3120.0, accuracy: 0.001)
        let small = AndroidPhoneWindow.size(source: .zero, available: CGSize(width: 320, height: 460), chrome: CGSize(width: 0, height: 300))
        XCTAssertLessThanOrEqual(small.width, 320); XCTAssertLessThanOrEqual(small.height, 460)
    }
}
