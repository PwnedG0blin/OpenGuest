import SwiftUI
import StratovoCore

@MainActor
struct AndroidOutputControls: View {
    @ObservedObject var model: AppModel
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Picker(L10n.text("Android-Bildausgabe"), selection: $model.androidOutputMode) {
                ForEach(AndroidOutputMode.allCases) { mode in Text(mode.title).tag(mode) }
            }.disabled(model.running || model.busy)
            Text(L10n.text("Direkt öffnet das native Emulatorfenster mit angeforderter Mac-GPU und ohne zusätzlichen Videostream. Gilt für den gesamten Android-Start, auch für Apps. Zum Wechsel Android herunterfahren und neu starten."))
                .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            if model.androidOutputMode == .direct {
                Text(L10n.text("Auflösung und Lautstärke bleiben in Stratovo steuerbar. Grafikübersetzung und tatsächlicher Renderer hängen vom Emulator ab; die Diagnose zeigt den erkannten Renderer. Das Schließen des nativen Fensters kann Android beenden."))
                    .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            if let active = model.activeAndroidOutputMode, model.running {
                Text(L10n.message("Aktive Bildausgabe: \(active.title)"))
                    .font(.caption.weight(.semibold))
            }
            if !model.androidWindowStatus.isEmpty {
                Text(model.androidWindowStatus).font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}
