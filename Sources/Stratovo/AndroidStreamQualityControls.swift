import SwiftUI
import StratovoCore

@MainActor
struct AndroidStreamQualityControls: View {
    @ObservedObject var model: AppModel
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Picker(L10n.text("Bildqualität"), selection: $model.androidStreamQuality) {
                ForEach(AndroidStreamQuality.allCases) { quality in Text(quality.title).tag(quality) }
            }
            Text(L10n.text("Scharf überträgt die volle Android-Auflösung. Hohe Auflösungen benötigen mehr Grafikleistung; die Bildrate wird nicht automatisch reduziert."))
                .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            if model.running && model.activeGuest == "android" {
                Button(L10n.text("Bildqualität jetzt übernehmen")) { Task { await model.reconnectAndroidDisplay() } }
                    .disabled(!model.canReconnectAndroidDisplay)
                Text(L10n.message("Aktives Limit: \(model.appliedAndroidTargetFPS ?? model.androidTargetFPS) FPS · Bild: \(Int(model.playerSize.width)) × \(Int(model.playerSize.height)) px"))
                    .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                if let applied = model.appliedAndroidStreamQuality, applied != model.androidStreamQuality {
                    Text(L10n.text("Änderung noch nicht übernommen.")).font(.caption).foregroundStyle(.orange)
                }
            }
        }
    }
}
