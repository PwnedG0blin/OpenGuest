import Foundation

/// Presentation path; the emulator still translates Android graphics APIs.
public enum AndroidOutputMode: String, CaseIterable, Identifiable, Sendable {
    case player, direct
    public var id: String { rawValue }
    public var usesStream: Bool { self == .player }
    public var title: String {
        self == .direct ? L10n.text("Direkt · Spiele (Mac-GPU)") : L10n.text("Integrierter Player")
    }
    public func gpu(requested: String) -> String { self == .direct ? "host" : requested }
    public func canLaunch(streamInstalled: Bool) -> Bool { !usesStream || streamInstalled }
}
