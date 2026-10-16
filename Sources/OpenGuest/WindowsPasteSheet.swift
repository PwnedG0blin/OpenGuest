import SwiftUI
import OpenGuestCore

@MainActor
struct WindowsPasteSheet: View {
    @ObservedObject var model: AppModel
    @Binding var text: String
    @State private var allowLineBreaks = false
    @FocusState private var editorFocused: Bool
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
        VStack(spacing: 0) {
            header
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Prüfe oder bearbeite deinen Text. Er wird in das zuletzt angeklickte Eingabefeld in Windows geschrieben.")
                        .font(.subheadline).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    editor
                    keyboardSettings
                    if hasLineBreaks {
                        VStack(alignment: .leading, spacing: 6) {
                            Toggle("Zeilenumbrüche als Enter übertragen", isOn: $allowLineBreaks)
                            Label("In einer Konsole können enthaltene Befehlszeilen dadurch ausgeführt werden.", systemImage: "exclamationmark.triangle.fill")
                                .font(.caption).foregroundStyle(.orange)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(14)
                        .background(Color.orange.opacity(0.10), in: RoundedRectangle(cornerRadius: 12))
                    }
                    Label("Kein zusätzliches Enter. Abschließende Zeilenumbrüche werden weggelassen.", systemImage: "return")
                        .font(.caption).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    validationStatus
                }.padding(22)
            }.frame(maxHeight: 500)
            footer
        }
        .frame(width: 600)
        .background(Color(nsColor: .windowBackgroundColor))
        .tint(.teal)
    }

    private var header: some View {
        HStack(spacing: 14) {
            Image(systemName: "doc.on.clipboard.fill")
                .font(.system(size: 25, weight: .semibold))
                .foregroundStyle(.teal)
                .frame(width: 54, height: 54)
                .background(Color.teal.opacity(0.16), in: RoundedRectangle(cornerRadius: 14))
            VStack(alignment: .leading, spacing: 5) {
                Label("Pixelkoje · Windows Player", systemImage: "square.stack.3d.up.fill")
                    .font(.caption.weight(.semibold)).foregroundStyle(.teal)
                Text("Text einfügen").font(.title2.bold())
                Text("Vom Mac direkt in Windows").font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.teal.opacity(0.09))
        .overlay(alignment: .bottom) { Rectangle().fill(Color.teal.opacity(0.18)).frame(height: 1) }
    }

    private var editor: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Dein Text", systemImage: "text.alignleft").font(.subheadline.bold())
                Spacer()
                Text("Bearbeitbare Vorschau").font(.caption.weight(.medium)).foregroundStyle(.teal)
            }
            TextEditor(text: $text)
                .font(.system(size: 14, design: .monospaced))
                .foregroundStyle(.primary)
                .scrollContentBackground(.hidden)
                .padding(8)
                .frame(height: 150)
                .background(Color.teal.opacity(0.06), in: RoundedRectangle(cornerRadius: 9))
                .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(Color.teal.opacity(editorFocused ? 0.85 : 0.35), lineWidth: editorFocused ? 2 : 1))
                .focused($editorFocused)
                .accessibilityLabel("Text für Windows")
        }
        .padding(14)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.teal.opacity(0.18)))
    }

    private var keyboardSettings: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 12) {
                Label("Windows-Tastatur", systemImage: "keyboard").font(.subheadline.bold())
                Spacer(minLength: 0)
                Picker("Tastaturbelegung in Windows", selection: $model.windowsTextLayout) {
                    ForEach(WindowsTextLayout.allCases) { layout in Text(layout.title).tag(layout) }
                }
                .labelsHidden().frame(width: 220)
            }
            Text("Wähle die Belegung in Windows, unabhängig von deiner Mac-Tastatur. Caps Lock muss in Windows ausgeschaltet sein.")
                .font(.caption).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .background(Color.teal.opacity(0.06), in: RoundedRectangle(cornerRadius: 14))
    }

    private var validationStatus: some View {
        Group {
            switch input {
            case .success(let plan):
                Label("\(plan.count) Zeichen bereit · \(plan.layout.title)", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.teal)
            case .failure(let error):
                Label(error.localizedDescription, systemImage: text.isEmpty ? "info.circle" : "exclamationmark.triangle.fill")
                    .foregroundStyle(text.isEmpty ? Color.secondary : Color.orange)
            }
        }
        .font(.caption.weight(.medium))
        .fixedSize(horizontal: false, vertical: true)
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background((canSend ? Color.teal : Color.orange).opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
        .accessibilityElement(children: .combine)
    }

    private var footer: some View {
        HStack {
            Button("Abbrechen") { text = ""; dismiss() }.keyboardShortcut(.cancelAction)
            Spacer()
            Button {
                guard case .success(let plan) = input else { return }
                model.pasteWindowsText(plan)
                text = ""
                dismiss()
            } label: {
                Label("In Windows einfügen", systemImage: "arrow.right.doc.on.clipboard")
            }
            .buttonStyle(.borderedProminent).disabled(!canSend)
        }
        .controlSize(.large)
        .padding(.horizontal, 22).padding(.vertical, 16)
        .background(Color.teal.opacity(0.07))
        .overlay(alignment: .top) { Rectangle().fill(Color.teal.opacity(0.18)).frame(height: 1) }
    }
}
