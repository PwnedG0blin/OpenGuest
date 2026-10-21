import Foundation

/// Transport quality is independent of the guest's resolution and resource profile.
public enum AndroidStreamQuality: String, CaseIterable, Identifiable, Sendable {
    case sharp, balanced, fast
    public var id: String { rawValue }
    public var title: String {
        switch self {
        case .sharp: return L10n.text("Scharf · volle Auflösung")
        case .balanced: return L10n.text("Ausgewogen · bis 1920 px")
        case .fast: return L10n.text("Schnell · bis 1280 px")
        }
    }
    public var maxSize: Int {
        switch self { case .sharp: return 0; case .balanced: return 1920; case .fast: return 1280 }
    }
    public var bitRate: Int {
        switch self { case .sharp: return 32_000_000; case .balanced: return 16_000_000; case .fast: return 8_000_000 }
    }
    public func options(fps: Int) -> [String] {
        ["max_size=\(maxSize)", "max_fps=\(AndroidFrameRate.limit(fps))", "video_bit_rate=\(bitRate)"]
    }
}
