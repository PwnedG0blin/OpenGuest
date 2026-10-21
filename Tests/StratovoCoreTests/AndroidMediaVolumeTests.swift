import XCTest
@testable import StratovoCore

final class AndroidMediaVolumeTests: XCTestCase {
    func testReadsActualMediaRangeAndMapsPercentWithoutAssumingFifteenSteps() throws {
        let volume = try AndroidMediaVolume(output: "[v] will control stream=3 (STREAM_MUSIC)\n[v] volume is 12 in range [0..25]\n")
        XCTAssertEqual(volume.percent, 48, accuracy: 0.01)
        XCTAssertEqual(volume.index(forPercent: 100), 25)
        XCTAssertEqual(volume.index(forPercent: -10), 0)
        XCTAssertEqual(volume.index(forPercent: 500), 25)
        XCTAssertEqual(volume.index(forPercent: .nan), 12)
        XCTAssertEqual(volume.index(forPercent: .infinity), 12)
        XCTAssertFalse(volume.muted)
        XCTAssertTrue(try AndroidMediaVolume(output: "volume is 0 in range [0..15]").muted)
    }
    func testRejectsShellErrorsAndImpossibleReportedVolume() {
        for text in ["Error: volume is unavailable", "volume is 16 in range [0..15]",
                     "volume is 5 in range [5..5]", "volume is 3 in range [5..15]", "volume is 1 in range [20..15]"] {
            XCTAssertThrowsError(try AndroidMediaVolume(output: text))
        }
    }
}
