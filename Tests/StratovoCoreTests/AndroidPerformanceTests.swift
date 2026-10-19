import XCTest
@testable import StratovoCore

final class AndroidPerformanceTests: XCTestCase {
    func testSmoothScalesDisplayDensityAndPreservesPreviousOverrideForRollback() throws {
        let plan = try AndroidDisplayPlan(sizeOutput: "Physical size: 1080x2400\nOverride size: 900x2000",
            densityOutput: "Physical density: 420\nOverride density: 350", profile: .smooth)
        XCTAssertEqual(plan.commands, [["wm", "size", "720x1600"], ["wm", "density", "280"]])
        XCTAssertEqual(plan.rollback, [["wm", "size", "900x2000"], ["wm", "density", "350"]])
    }
    func testLandscapeAndSmallDisplayAreNotUpscaled() throws {
        let landscape = try AndroidDisplayPlan(sizeOutput: "Physical size: 2400x1080", densityOutput: "Physical density: 420", profile: .smooth)
        XCTAssertEqual(landscape.commands[0], ["wm", "size", "1600x720"])
        let small = try AndroidDisplayPlan(sizeOutput: "Physical size: 800x600", densityOutput: "Physical density: 160", profile: .balanced)
        XCTAssertEqual(small.commands, [["wm", "size", "800x600"], ["wm", "density", "160"]])
        XCTAssertEqual(small.rollback, [["wm", "size", "reset"], ["wm", "density", "reset"]])
    }
    func testNativeRestoresPhysicalDisplayAndRejectsMalformedValues() throws {
        let native = try AndroidDisplayPlan(sizeOutput: "Physical size: 1080x2400", densityOutput: "Physical density: 420", profile: .native)
        XCTAssertEqual(native.commands, [["wm", "size", "reset"], ["wm", "density", "reset"]])
        for output in ["Override size: 720x1600", "Physical size: 0x2400", "Physical size: 1080;badx2400", "Physical size: 999999x2400"] {
            XCTAssertThrowsError(try AndroidDisplayPlan(sizeOutput: output, densityOutput: "Physical density: 420", profile: .smooth))
        }
        XCTAssertThrowsError(try AndroidDisplayPlan(sizeOutput: "Physical size: 1080x2400", densityOutput: "Physical density: -1", profile: .smooth))
    }
    func testRendererNeverTreatsRequestedHostOrGenericCompatibilityCheckAsHardware() {
        XCTAssertEqual(AndroidRenderer.inspect("-gpu host\nChecking: hasSufficientHwGpu\nGL_APPLE_texture").kind, .unknown)
        XCTAssertEqual(AndroidRenderer.inspect("Graphics Adapter Apple M4\nAPI level 35 requires GLES 3.1, forcing software rendering for GLES.").kind, .software)
        XCTAssertEqual(AndroidRenderer.inspect("Graphics Adapter Android Emulator (SwiftShader Device)").kind, .software)
        XCTAssertEqual(AndroidRenderer.inspect("Selecting Vulkan device: llvmpipe (LLVM 21.1.4)").kind, .software)
        XCTAssertEqual(AndroidRenderer.inspect("Graphics Adapter Android Emulator OpenGL ES Translator (Apple M4)").kind, .hardware)
    }
    func testStreamProfilesAndFPSCannotEscapeSupportedBounds() {
        XCTAssertEqual(AndroidPerformance.smooth.streamOptions(fps: 60), ["max_size=1280", "max_fps=60", "video_bit_rate=8000000"])
        XCTAssertTrue(AndroidPerformance.balanced.streamOptions(fps: 30).contains("max_fps=30"))
        for (value, limit) in [(-1,1), (0,1), (45,45), (90,90), (120,90), (999,90)] {
            XCTAssertTrue(AndroidPerformance.native.streamOptions(fps: value).contains("max_fps=\(limit)"))
        }
    }
}
