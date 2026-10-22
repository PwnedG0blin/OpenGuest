import Foundation
import SwiftUI
import XCTest
import StratovoCore
@testable import Stratovo

final class AndroidOutputBindingTests: XCTestCase {
    @MainActor
    func testOutputChoicePersistsWithoutChangingStreamQualityOrGPUPreference() throws {
        let suite = "Stratovo.OutputRegression.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let model = AppModel(frameRateDefaults: defaults, applyPerformanceDefaults: false)
        XCTAssertEqual(model.androidOutputMode, .player)
        let gpu = model.settings.gpu, quality = model.androidStreamQuality
        let binding = ObservedObject(wrappedValue: model).projectedValue.androidOutputMode
        binding.wrappedValue = .direct
        XCTAssertEqual(defaults.string(forKey: "Stratovo.androidOutputMode"), "direct")
        XCTAssertEqual(model.settings.gpu, gpu)
        XCTAssertEqual(model.androidStreamQuality, quality)
        XCTAssertNil(model.activeAndroidOutputMode)
        XCTAssertFalse(model.androidUsesDirectDisplay)
        XCTAssertFalse(model.canReconnectAndroidDisplay)
        let reloaded = AppModel(frameRateDefaults: defaults, applyPerformanceDefaults: false)
        XCTAssertEqual(reloaded.androidOutputMode, .direct)
        binding.wrappedValue = .player
        XCTAssertEqual(defaults.string(forKey: "Stratovo.androidOutputMode"), "player")
        defaults.set("unknown-future-mode", forKey: "Stratovo.androidOutputMode")
        XCTAssertEqual(AppModel(frameRateDefaults: defaults, applyPerformanceDefaults: false).androidOutputMode, .player)
    }
}
