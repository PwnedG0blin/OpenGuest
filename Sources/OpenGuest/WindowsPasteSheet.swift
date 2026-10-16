import SwiftUI
import OpenGuestCore

@MainActor
struct WindowsPasteSheet: View {
    @ObservedObject var model: AppModel
    @Binding var text: String
    @State private var allowLineBreaks = false
    @Environment(\.dismiss) private var dismiss

    private var hasLineBreaks: Bool { WindowsTextInput.normalized(text).contains("\n") }
    private var input: Result<WindowsTextInput, Error> {
        Result { try WindowsTextInput(text: text, layout: model.windowsTextLayout, allowLineBreaks: allowLineBreaks) }
    }
    private var canSend: Bool {
        if case .success = input { return model.running && !model.windowsPasteBusy }
        return false
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Text in Windows einfügen").font(.title2.bold())
            Text("Der Text wird in das zuletzt angeklickte Windows-Eingabefeld geschrieben. Du kannst ihn vorher bearbeiten.")
                .fixedSize(horizontal: false, vertical: true)
            TextEditor(text: $text).font(.system(.body, design: .monospaced))
                .frame(minHeight: 130, idealHeight: 180, maxHeight: 260)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(.secondary.opacity(0.4)))
            Picker("Tastaturbelegung in Windows", selection: $model.windowsTextLayout) {
                ForEach(WindowsTextLayout.allCases) { layout in Text(layout.title).tag(layout) }
            }
            Text("Wähle die Belegung in Windows, unabhängig von deiner Mac-Tastatur. Caps Lock muss in Windows ausgeschaltet sein.")
                .font(.caption).foregroundStyle(.secondary)
            if hasLineBreaks {
                Toggle("Zeilenumbrüche als Enter übertragen", isOn: $allowLineBreaks)
                Text("In einer Konsole können dadurch bereits enthaltene Befehlszeilen ausgeführt werden.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Text("Abschließende Zeilenumbrüche werden weggelassen. Es wird kein zusätzliches Enter gesendet.")
                .font(.caption).foregroundStyle(.secondary)
            switch input {
            case .success(let plan):
                Text("\(plan.count) Zeichen bereit · \(plan.layout.title)").font(.caption)
            case .failure(let error):
                Text(error.localizedDescription).font(.caption).foregroundStyle(.orange)
            }
            HStack {
                Button("Abbrechen") { text = ""; dismiss() }.keyboardShortcut(.cancelAction)
                Spacer()
                Button("Einfügen") {
                    guard case .success(let plan) = input else { return }
                    model.pasteWindowsText(plan)
                    text = ""
                    dismiss()
                }.buttonStyle(.borderedProminent).disabled(!canSend)
            }
        }.padding(24).frame(width: 550)
    }
}
