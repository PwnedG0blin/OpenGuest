import Foundation

/// Optional diagnostic limit, applied on the next Windows start.
/// It caps writes to the system disk, not just Steam traffic.
public enum WindowsWriteLimit: Int, CaseIterable, Identifiable {
    case off = 0, gentle = 20, balanced = 40, fast = 80
    public var id: Int { rawValue }
    public var bytesPerSecond: Int { rawValue * 1_048_576 }
    public var title: String { self == .off ? "Aus · unbegrenzt (Standard)" : "\(rawValue) MiB/s" }
}
