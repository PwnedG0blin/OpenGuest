import Foundation

/// Virtual monitor timing, applied on the next guest boot; not a game FPS cap.
public enum WindowsRefreshRate: Int, CaseIterable, Identifiable {
    case automatic = 0, hz30 = 30, hz60 = 60, hz90 = 90, hz120 = 120
    case hz144 = 144, hz165 = 165, hz240 = 240
    public var id: Int { rawValue }
    public var title: String { self == .automatic ? "Automatisch · Mac-Monitor" : "\(rawValue) Hz" }
}
