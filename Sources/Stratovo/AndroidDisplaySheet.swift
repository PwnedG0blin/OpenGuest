import StratovoCore
import SwiftUI

@MainActor
struct AndroidDisplayControls: View {
    @ObservedObject var model: AppModel
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button("Galaxy S26 Ultra · 1440 × 3120 · 500 dpi") { model.selectGalaxyS26UltraDisplay() }
                .disabled(!model.canEditAndroidDisplay)
            Text(L10n.text("Displayprofil im Hochformat. 500 dpi sind eine anpassbare Skalierungsvorgabe. Android-System und installierte Apps bleiben erhalten."))
                .font(.caption).foregroundStyle(.secondary)
            Toggle(L10n.text("Eigene Android-Auflösung und Dichte"), isOn: $model.androidCustomDisplay)
                .disabled(!model.canEditAndroidDisplay)
            if model.androidCustomDisplay {
                HStack(alignment: .top, spacing: 12) {
                    value(L10n.text("Breite · px"), text: $model.androidDisplayWidth)
                    value(L10n.text("Höhe · px"), text: $model.androidDisplayHeight)
                    value(L10n.text("Dichte · dpi"), text: $model.androidDisplayDensity)
                }.disabled(!model.canEditAndroidDisplay)
                Text(L10n.text("Mehr Pixel erhöhen die Grafiklast. Mehr dpi machen Schrift und Bedienelemente bei gleicher Auflösung größer."))
                    .font(.caption).foregroundStyle(.secondary)
                if let issue = model.androidDisplayIssue {
                    Label(issue, systemImage: "exclamationmark.triangle").font(.caption).foregroundStyle(.orange)
                }
            } else {
                Text(L10n.text("Die Auflösung folgt dem gewählten Android-Leistungsprofil."))
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            HStack {
                Button(L10n.text("Jetzt in Android anwenden")) { Task { await model.applyAndroidDisplayNow() } }
                    .buttonStyle(.borderedProminent).disabled(!model.canApplyAndroidDisplay)
                if model.androidDisplayBusy { ProgressView().controlSize(.small) }
            }
            Button(L10n.text("Originalauflösung und Dichte wiederherstellen")) { Task { await model.restoreAndroidDisplay() } }
                .disabled(!model.canEditAndroidDisplay)
            if !model.androidUsesDirectDisplay && model.androidOutputMode.usesStream {
                Button(L10n.text("Player als Telefonfenster anpassen"), action: model.fitAndroidPlayerWindow)
            }
            Text(L10n.text("Werte werden gemerkt und beim nächsten Android-Start angewendet. Bei laufendem Android zusätzlich „Jetzt in Android anwenden“ wählen. „Ansicht“ im Player verändert nur die Darstellung auf dem Mac."))
                .font(.caption).foregroundStyle(.secondary)
            Text(model.androidDisplayStatus).font(.caption).textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
        }.tint(.teal)
    }
    private func value(_ title: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title).font(.caption.bold())
            TextField(title, text: text).textFieldStyle(.roundedBorder)
        }
    }
}

@MainActor
struct AndroidDisplaySheet: View {
    @ObservedObject var model: AppModel
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Label(L10n.text("Android-Auflösung & Größe"), systemImage: "display").font(.title2.bold()).foregroundStyle(.teal)
            AndroidDisplayControls(model: model)
            HStack { Spacer(); Button(L10n.text("Fertig")) { dismiss() }.keyboardShortcut(.defaultAction) }
        }
        .padding(24).frame(width: 500)
        .modifier(WorkspaceDialogTheme())
    }
}
