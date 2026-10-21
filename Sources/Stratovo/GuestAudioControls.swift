import SwiftUI
import StratovoCore

@MainActor
struct GuestAudioControls: View {
    @ObservedObject var audio: GuestAudioController
    let kind: String
    private var available: Bool { audio.connected && audio.kind == kind }
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Label(L10n.text("Lautstärke"), systemImage: "speaker.wave.2.fill")
                    .font(.system(size: 13, weight: .semibold))
                Spacer(minLength: 0)
                if kind == "android" {
                    Button { audio.toggleMute() } label: {
                        Image(systemName: audio.volume?.muted == true ? "speaker.wave.2" : "speaker.slash")
                    }.help(L10n.text(audio.volume?.muted == true ? "Ton einschalten" : "Stummschalten"))
                        .accessibilityLabel(L10n.text(audio.volume?.muted == true ? "Ton einschalten" : "Stummschalten"))
                        .disabled(audio.volume == nil || audio.busy)
                }
            }
            if kind == "android" {
                HStack(spacing: 10) {
                    Slider(value: Binding(get: { audio.targetPercent ?? audio.volume?.percent ?? 0 },
                                          set: audio.setPercent), in: 0...100)
                        .accessibilityLabel(L10n.text("Medienlautstärke"))
                        .disabled(audio.volume == nil)
                    Text(audio.volume == nil ? "—" : "\(Int((audio.targetPercent ?? audio.volume?.percent ?? 0).rounded())) %")
                        .monospacedDigit().frame(width: 48, alignment: .trailing)
                    Button { audio.refresh() } label: { Image(systemName: "arrow.clockwise") }
                        .help(L10n.text("Lautstärke aktualisieren")).accessibilityLabel(L10n.text("Lautstärke aktualisieren"))
                        .disabled(audio.busy)
                }
            } else {
                HStack(spacing: 8) {
                    Button { audio.adjust(up: false) } label: { Label(L10n.text("Leiser"), systemImage: "speaker.wave.1") }
                    Button { audio.adjust(up: true) } label: { Label(L10n.text("Lauter"), systemImage: "speaker.wave.3") }
                    Button { audio.toggleMute() } label: { Image(systemName: "speaker.slash") }
                        .help(L10n.text("Stumm an / aus")).accessibilityLabel(L10n.text("Stumm an / aus"))
                }.disabled(audio.busy)
            }
            if !audio.status.isEmpty && available {
                Text(audio.status).font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }.disabled(!available)
            .onAppear { if available { audio.refresh() } }
    }
}
