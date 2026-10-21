import SwiftUI
import StratovoCore

@MainActor
struct GuestResourceControls: View {
    @ObservedObject var model: AppModel
    var body: some View {
        HStack(spacing: 24) {
            Picker(L10n.text("RAM"), selection: $model.settings.memoryGB) {
                ForEach(2...model.maxMemoryGB, id: \.self) { Text("\($0) GB").tag($0) }
            }
            Picker(L10n.text("CPU"), selection: $model.settings.cores) {
                ForEach(2...model.maxCores, id: \.self) { Text("\($0) Kerne").tag($0) }
            }
        }.disabled(model.running || model.busy)
    }

}
