import SwiftUI
import StratovoCore

@MainActor
struct AndroidFrameRateControls: View {
    @ObservedObject var model: AppModel
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Dynamische Android-Bildrate", systemImage: "speedometer").font(.headline)
            HStack {
                Text("Obergrenze")
                TextField("FPS", value: $model.androidTargetFPS, format: .number).frame(width: 60).textFieldStyle(.roundedBorder)
                Text("FPS · 1–90").monospacedDigit()
                Stepper("FPS", value: $model.androidTargetFPS, in: 1...90).labelsHidden()
            }
            Slider(value: Binding(get: { Double(model.androidTargetFPS) }, set: { model.androidTargetFPS = Int($0.rounded()) }), in: 1...90, step: 1)
            HStack {
                ForEach([30, 60, 90], id: \.self) { value in
                    Button("\(value) FPS") { model.androidTargetFPS = value }.buttonStyle(.bordered)
                }
            }
            Text("Die Bildrate richtet sich nach dem Bildinhalt: ruhige Szenen benötigen weniger Bilder, Bewegung bis zur gewählten Obergrenze. Dies ist ein Limit, keine erzwungene oder garantierte Spiel-Bildrate.")
                .font(.system(size: 13)).fixedSize(horizontal: false, vertical: true)
            if model.running && model.activeGuest == "android" {
                Button("Limit jetzt übernehmen") { Task { await model.reconnectAndroidDisplay() } }
                    .buttonStyle(.borderedProminent).disabled(!model.canReconnectAndroidDisplay)
                Text("Verbindet nur die Anzeige neu. Für eine höhere virtuelle Displayfrequenz über \(model.androidGuestRefreshHz) Hz Android einmal neu starten; Apps und Daten bleiben gespeichert.")
                    .font(.system(size: 13)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            } else {
                Text("Wird beim nächsten Android-Start angewendet.").font(.system(size: 13)).foregroundStyle(.secondary)
            }
        }.disabled(model.busy || model.androidReconnectBusy || (model.running && model.activeGuest != "android"))
    }
}
