import Combine
import Foundation
import SwiftUI
import XCTest
@testable import Stratovo

final class AndroidFPSBindingTests: XCTestCase {
    /// Reproduces the write path from the FPS text field, not just the range helper.
    /// The old @Published didSet recursed here even for an already valid value.
    @MainActor
    func testRealObservedObjectBindingDoesNotReenterWhenChangingOrRepeatingFPS() throws {
        let suite = "Pixelkoje.FPSRegression.\(UUID().uuidString)"
        let preferences = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { preferences.removePersistentDomain(forName: suite) }
        preferences.set(60, forKey: "Pixelkoje.androidFPS")
        let model = AppModel(frameRateDefaults: preferences, applyPerformanceDefaults: false)
        let observed = ObservedObject(wrappedValue: model)
        let binding = observed.projectedValue.androidTargetFPS
        var changes = 0
        let subscription = model.objectWillChange.sink { changes += 1 }
        defer { subscription.cancel() }

        // A text field may write its initial value during layout. This was enough to crash.
        binding.wrappedValue = 60
        XCTAssertEqual(changes, 0)
        for value in [30, 45, 75, 90, 90, 60] {
            binding.wrappedValue = value
            XCTAssertEqual(model.androidTargetFPS, value)
            XCTAssertEqual(preferences.integer(forKey: "Pixelkoje.androidFPS"), value)
        }
        XCTAssertEqual(changes, 5, "Only actual changes publish, without recursive assignments")
        XCTAssertFalse(model.running)
    }

    @MainActor
    func testOutOfRangeInputIsClampedOnceAndSavedAndReloaded() throws {
        let suite = "Pixelkoje.FPSBounds.\(UUID().uuidString)"
        let preferences = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { preferences.removePersistentDomain(forName: suite) }
        let model = AppModel(frameRateDefaults: preferences, applyPerformanceDefaults: false)
        let binding = ObservedObject(wrappedValue: model).projectedValue.androidTargetFPS
        var changes = 0
        let subscription = model.objectWillChange.sink { changes += 1 }
        defer { subscription.cancel() }
        binding.wrappedValue = -50
        XCTAssertEqual(model.androidTargetFPS, 1)
        XCTAssertEqual(preferences.integer(forKey: "Pixelkoje.androidFPS"), 1)
        binding.wrappedValue = 999
        XCTAssertEqual(model.androidTargetFPS, 90)
        XCTAssertEqual(preferences.integer(forKey: "Pixelkoje.androidFPS"), 90)
        binding.wrappedValue = 100
        XCTAssertEqual(changes, 2)
        let reloaded = AppModel(frameRateDefaults: preferences, applyPerformanceDefaults: false)
        XCTAssertEqual(reloaded.androidTargetFPS, 90)
    }
}
