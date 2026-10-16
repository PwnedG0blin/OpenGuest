import Foundation

/// Bounded H.264 reference chains. After overflow, resume only on a keyframe;
/// dropping an arbitrary P-frame would corrupt subsequent frames.
public struct H264FrameQueue {
    public struct Frame {
        public let data: Data
        public let pts: UInt64
        public let configuration: Bool
        public let resetDecoder: Bool
    }
    private var frames: [Frame] = []
    private var configuration: Frame?
    private var configurationPending = false
    private var waitingForKeyframe = true
    private var discontinuity = false
    public private(set) var droppedFrames = 0
    private let maxFrames: Int
    private let maxBytes: Int
    private let maxSpan: UInt64
    public init(maxFrames: Int = 8, maxBytes: Int = 8_388_608, maxSpan: UInt64 = 150_000) {
        self.maxFrames = max(1, maxFrames); self.maxBytes = max(1, maxBytes); self.maxSpan = maxSpan
    }
    public var count: Int { frames.count }
    public mutating func append(data: Data, pts: UInt64, configuration isConfiguration: Bool, keyframe: Bool) {
        if isConfiguration {
            guard data.count <= 1_048_576 else { return }
            configuration = Frame(data: data, pts: pts, configuration: true, resetDecoder: false)
            configurationPending = true
            droppedFrames += frames.count
            frames.removeAll(keepingCapacity: true)
            waitingForKeyframe = true
            discontinuity = true
            return
        }
        guard data.count <= maxBytes else {
            droppedFrames += frames.count + 1; frames.removeAll(keepingCapacity: true)
            waitingForKeyframe = true; discontinuity = true
            return
        }
        let span = frames.first.map { pts >= $0.pts ? pts - $0.pts : UInt64.max } ?? 0
        if frames.count >= maxFrames || frames.reduce(0, { $0 + $1.data.count }) + data.count > maxBytes || span > maxSpan {
            droppedFrames += frames.count
            frames.removeAll(keepingCapacity: true)
            waitingForKeyframe = true; discontinuity = true
        }
        if waitingForKeyframe && !keyframe { droppedFrames += 1; return }
        if waitingForKeyframe { configurationPending = configuration != nil }
        let reset = discontinuity && keyframe
        frames.append(Frame(data: data, pts: pts, configuration: false, resetDecoder: reset))
        waitingForKeyframe = false; discontinuity = false
    }
    public mutating func pop() -> Frame? {
        guard !frames.isEmpty else { return nil }
        if configurationPending, let configuration { configurationPending = false; return configuration }
        return frames.removeFirst()
    }
}
