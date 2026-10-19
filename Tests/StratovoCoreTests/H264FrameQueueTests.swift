import XCTest
@testable import StratovoCore

final class H264FrameQueueTests: XCTestCase {
    func testReferenceFramesRemainOrderedWithoutBacklog() {
        var q = H264FrameQueue()
        q.append(data: Data([7, 8]), pts: 0, configuration: true, keyframe: false)
        q.append(data: Data([5]), pts: 1, configuration: false, keyframe: true)
        q.append(data: Data([1]), pts: 16_667, configuration: false, keyframe: false)
        XCTAssertTrue(q.pop()!.configuration)
        let key = q.pop()!
        XCTAssertTrue(key.resetDecoder)
        XCTAssertEqual(key.data, Data([5]))
        XCTAssertEqual(q.pop()!.pts, 16_667)
        XCTAssertNil(q.pop())
    }
    func testOverflowWaitsForNewKeyframeRatherThanCorruptingReferenceChain() {
        var q = H264FrameQueue(maxFrames: 2)
        q.append(data: Data([7]), pts: 0, configuration: true, keyframe: false)
        q.append(data: Data([5]), pts: 1, configuration: false, keyframe: true)
        q.append(data: Data([1]), pts: 2, configuration: false, keyframe: false)
        q.append(data: Data([1]), pts: 3, configuration: false, keyframe: false)
        XCTAssertEqual(q.count, 0)
        XCTAssertEqual(q.droppedFrames, 3)
        XCTAssertNil(q.pop())
        q.append(data: Data([5]), pts: 4, configuration: false, keyframe: true)
        XCTAssertTrue(q.pop()!.configuration)
        XCTAssertTrue(q.pop()!.resetDecoder)
    }
    func testTimeAndByteBoundsPreventGrowingLatencyAndMemory() {
        var q = H264FrameQueue(maxBytes: 4, maxSpan: 100)
        q.append(data: Data([5]), pts: 0, configuration: false, keyframe: true)
        q.append(data: Data([1]), pts: 101, configuration: false, keyframe: false)
        XCTAssertNil(q.pop())
        q.append(data: Data(repeating: 5, count: 5), pts: 102, configuration: false, keyframe: true)
        XCTAssertEqual(q.count, 0)
        q.append(data: Data([5]), pts: 103, configuration: false, keyframe: true)
        XCTAssertTrue(q.pop()!.resetDecoder)
    }
    func testNewConfigurationDiscardsOldResolutionFrames() {
        var q = H264FrameQueue()
        q.append(data: Data([5]), pts: 1, configuration: false, keyframe: true)
        q.append(data: Data([7, 8]), pts: 0, configuration: true, keyframe: false)
        q.append(data: Data([1]), pts: 2, configuration: false, keyframe: false)
        XCTAssertNil(q.pop())
        q.append(data: Data([5]), pts: 3, configuration: false, keyframe: true)
        XCTAssertEqual(q.pop()!.data, Data([7, 8]))
        XCTAssertEqual(q.pop()!.pts, 3)
    }
    func testOpenGLCompatibilitySwitchIsExplicitAndDefaultRetainsVulkan() throws {
        let device = AndroidDevice(name: "Working16", abi: "arm64-v8a", googlePlay: true)
        let resources = GuestResources(memoryMiB: 4096, cores: 4)
        let normal = try LaunchPlan.android(sdk: "/sdk", device: device, resources: resources, coldBoot: false, gpu: "host")
        let compatibility = try LaunchPlan.android(sdk: "/sdk", device: device, resources: resources, coldBoot: false, gpu: "host", vulkan: false)
        XCTAssertFalse(normal.arguments.contains("-Vulkan"))
        XCTAssertEqual(Array(compatibility.arguments.suffix(2)), ["-feature", "-Vulkan"])
        XCTAssertFalse(compatibility.arguments.contains("-wipe-data"))
    }
}
