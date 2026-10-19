import Foundation

public enum GuestTouchScrollPhase: Equatable { case began, changed, ended, cancelled }

/// A trackpad gesture becomes one guest touch. Reaching an edge lifts the
/// finger; the next delta starts a fresh stroke at the same gesture anchor.
public struct AndroidTouchScroll {
    private struct Touch { var x: Double; var y: Double; let width: Int; let height: Int }
    private var touch: Touch?
    public init() { }
    public mutating func end() -> [Data] {
        guard let point = touch else { return [] }
        touch = nil
        return [ScrcpyWire.touch(x: Int(point.x), y: Int(point.y), width: point.width, height: point.height, action: 1)]
    }
    public mutating func packets(x: Int, y: Int, horizontal: Double, vertical: Double,
                                 width: Int, height: Int, phase: GuestTouchScrollPhase) -> [Data] {
        if phase == .ended || phase == .cancelled { return end() }
        guard (1...8192).contains(width), (1...8192).contains(height), horizontal.isFinite, vertical.isFinite else { return end() }
        var result: [Data] = []
        if phase == .began || touch?.width != width || touch?.height != height { result += end() }
        if touch == nil {
            touch = Touch(x: Double(max(0, min(width - 1, x))), y: Double(max(0, min(height - 1, y))), width: width, height: height)
            result.append(ScrcpyWire.touch(x: Int(touch!.x), y: Int(touch!.y), width: width, height: height, action: 0))
        }
        guard phase == .changed, var point = touch else { return result }
        let distance = Double(min(width, height)) / 10
        let nextX = point.x - max(-16, min(16, horizontal)) * distance
        let nextY = point.y + max(-16, min(16, vertical)) * distance
        point.x = max(0, min(Double(width - 1), nextX)); point.y = max(0, min(Double(height - 1), nextY))
        touch = point
        result.append(ScrcpyWire.touch(x: Int(point.x), y: Int(point.y), width: width, height: height, action: 2))
        if point.x != nextX || point.y != nextY { result += end() }
        return result
    }
}
