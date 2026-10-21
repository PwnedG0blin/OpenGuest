import SwiftUI
import StratovoCore

@MainActor
struct GuestPlayerSummary: View {
    @ObservedObject var model: AppModel
    let kind: String
    let title: String
    var body: some View {
        let active = model.activeGuest == kind
        return WorkspaceCard {
            HStack(spacing: 16) {
                Image(systemName: kind == "android" ? "apps.iphone" : "desktopcomputer")
                    .font(.title).foregroundStyle(.teal)
                VStack(alignment: .leading, spacing: 5) {
                    Text(title).font(.headline)
                    Text(active ? model.playerStatus : L10n.text("Eigenes Fenster · frei skalierbar · Vollbild möglich"))
                        .font(.subheadline).foregroundStyle(.secondary)
                    if active && kind == "android" {
                        Text(L10n.message("Stream: \(Int(model.streamFPS.rounded())) FPS · Decoder-Zuführung: \(Int(model.decoderFPS.rounded())) FPS · Ziel \(model.androidTargetFPS)"))
                            .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                        Text(L10n.text("Empfangene und an den Decoder übergebene Bilder; keine Messung der Spiel-FPS."))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 0)
                if kind == "android" && !model.running {
                    Button(L10n.text("Android starten"), action: model.startAndroid)
                        .buttonStyle(.borderedProminent).disabled(!model.canStartAndroid)
                } else {
                    Button(L10n.text("Player öffnen")) { model.showPlayer(kind: kind) }
                        .disabled(!active || !model.running)
                }
            }
        }
    }

}
