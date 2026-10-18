import Foundation

/// Wheel units: positive horizontal scrolls right, positive vertical scrolls up.
public struct GuestScrollDelta: Equatable, Sendable {
    public let horizontal: Double
    public let vertical: Double
    public init(deltaX: Double, deltaY: Double, precise: Bool) {
        // AppKit has already applied the user's natural-scrolling preference.
        // Precise deltas are points; ordinary wheel deltas are lines.
        let divisor = precise ? 40.0 : 3.0
        func normalized(_ value: Double) -> Double {
            value.isFinite ? max(-8, min(8, value / divisor)) : 0
        }
        horizontal = normalized(-deltaX)
        vertical = normalized(deltaY)
    }
}

/// RFB / QEMU's USB tablet accepts whole vertical wheel steps, not pixel deltas.
public struct WindowsWheelScroll: Sendable {
    private var remainder = 0.0
    public init() { }
    public mutating func reset() { remainder = 0 }
    public mutating func consume(_ vertical: Double) -> Int {
        guard vertical.isFinite else { reset(); return 0 }
        if vertical * remainder < 0 { remainder = 0 }
        remainder += max(-8, min(8, vertical))
        let whole = (abs(remainder) + 1e-9).rounded(.down)
        let steps = Int(remainder < 0 ? -whole : whole)
        remainder -= Double(steps)
        if abs(remainder) < 1e-9 { remainder = 0 }
        return steps
    }
}

/// Persisted per guest; 50 percent slows the former trackpad behavior by half.
public enum GuestScrollSpeed {
    public static func percent(_ value: Double) -> Double {
        value.isFinite ? max(10, min(200, value)) : 50
    }
    public static func scale(_ delta: Double, percent value: Double) -> Double {
        guard delta.isFinite else { return 0 }
        return max(-16, min(16, delta * percent(value) / 100))
    }
}
