import SwiftUI
import StratovoCore

struct LanguageSettingsView: View {
    @ObservedObject var model: AppModel
    @AppStorage(L10n.preferenceKey) private var preference = "system"
    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                Label(L10n.text("Sprache"), systemImage: "globe").font(.headline)
                Picker(L10n.text("App-Sprache"), selection: $preference) {
                    Text(L10n.text("Wie macOS")).tag("system")
                    ForEach(L10n.languages, id: \.code) { language in
                        Text(language.name).tag(language.code)
                    }
                }.disabled(model.running || model.busy || model.graphicsLab.active)
                Text(L10n.text("Die App übernimmt beim Start automatisch die bevorzugte macOS-Sprache. Du kannst hier eine andere Sprache wählen. Gastsysteme behalten ihre eigene Sprache."))
                    .font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                Text(L10n.text("Beta: Einige technische Hinweise erscheinen auf Englisch. Protokolle bleiben in ihrer ursprünglichen Sprache."))
                    .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }.frame(maxWidth: .infinity, alignment: .leading).padding(12)
        }
    }
}
