import SwiftUI
import StratovoCore

@MainActor
struct WindowsPasteSheet: View {
    @ObservedObject var model: AppModel
    @Binding var text: String
    @State private var allowLineBreaks = false
    @FocusState private var editorFocused: Bool
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    private var accent: Color {
        colorScheme == .dark ? Color(red: 0.35, green: 0.82, blue: 0.79) : Color(red: 0.03, green: 0.43, blue: 0.46)
    }

    private func guestText(_ text: String) -> String { L10n.text(text).replacingOccurrences(of: "Windows", with: model.activeGuest == "ubuntu" ? "Ubuntu" : "Windows") }
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
                    Text(guestText("Prüfe oder bearbeite deinen Text. Er wird in das zuletzt angeklickte Eingabefeld in Windows geschrieben."))
                        .font(.subheadline).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    editor
                    keyboardSettings
                    if hasLineBreaks {
                        VStack(alignment: .leading, spacing: 6) {
                            Toggle(L10n.text("Zeilenumbrüche als Enter übertragen"), isOn: $allowLineBreaks)
                            Label(L10n.text("In einer Konsole können enthaltene Befehlszeilen dadurch ausgeführt werden."), systemImage: "exclamationmark.triangle.fill")
                                .font(.caption).foregroundStyle(.orange)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(14)
                        .background(Color.orange.opacity(0.10), in: RoundedRectangle(cornerRadius: 12))
                    }
                    Label(L10n.text("Kein zusätzliches Enter. Abschließende Zeilenumbrüche werden weggelassen."), systemImage: "return")
                        .font(.caption).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    validationStatus
                }.padding(22)
            }.frame(maxHeight: 500)
            footer
        }
        .frame(width: 600)
        .background(Color(nsColor: .windowBackgroundColor))
        .tint(accent)
    }

    private var header: some View {
        HStack(spacing: 14) {
            Image(systemName: "doc.on.clipboard.fill")
                .font(.system(size: 25, weight: .semibold))
                .foregroundStyle(accent)
                .frame(width: 54, height: 54)
                .background(Color.teal.opacity(0.16), in: RoundedRectangle(cornerRadius: 14))
            VStack(alignment: .leading, spacing: 5) {
                Label(model.activeGuest == "ubuntu" ? "Stratovo · Ubuntu Player" : "Stratovo · Windows Player", systemImage: "square.stack.3d.up.fill")
                    .font(.caption.weight(.semibold)).foregroundStyle(accent)
                Text(L10n.text("Text einfügen")).font(.title2.bold())
                Text(guestText("Vom Mac direkt in Windows")).font(.subheadline).foregroundStyle(.secondary)
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
                Label(L10n.text("Dein Text"), systemImage: "text.alignleft").font(.subheadline.bold())
                Spacer()
                Text(L10n.text("Bearbeitbare Vorschau")).font(.caption.weight(.medium)).foregroundStyle(accent)
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
                .accessibilityLabel(L10n.text("Text für Windows"))
        }
        .padding(14)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.teal.opacity(0.18)))
    }

    private var keyboardSettings: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 12) {
                Label(guestText("Windows-Tastatur"), systemImage: "keyboard").font(.subheadline.bold())
                Spacer(minLength: 0)
                Picker(L10n.text("Tastaturbelegung in Windows"), selection: $model.windowsTextLayout) {
                    ForEach(WindowsTextLayout.allCases) { layout in Text(layout.title).tag(layout) }
                }
                .labelsHidden().frame(width: 220)
            }
            Text(L10n.text("Wähle die Belegung in Windows, unabhängig von deiner Mac-Tastatur. Caps Lock muss in Windows ausgeschaltet sein."))
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
                    .foregroundStyle(accent)
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
            Button(L10n.text("Abbrechen")) { text = ""; dismiss() }.keyboardShortcut(.cancelAction)
            Spacer()
            Button {
                guard case .success(let plan) = input else { return }
                model.pasteWindowsText(plan)
                text = ""
                dismiss()
            } label: {
                Label(L10n.text("In Windows einfügen"), systemImage: "arrow.right.doc.on.clipboard")
            }
            .buttonStyle(WindowsPasteActionStyle()).disabled(!canSend)
        }
        .controlSize(.large)
        .padding(.horizontal, 22).padding(.vertical, 16)
        .background(Color.teal.opacity(0.07))
        .overlay(alignment: .top) { Rectangle().fill(Color.teal.opacity(0.18)).frame(height: 1) }
    }
}

private struct WindowsPasteActionStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .padding(.horizontal, 15).padding(.vertical, 9)
            .foregroundStyle(isEnabled ? Color.white : Color.secondary)
            .background(isEnabled ? Color(red: 0.03, green: 0.43, blue: 0.46) : Color.gray.opacity(0.15), in: RoundedRectangle(cornerRadius: 8))
            .brightness(configuration.isPressed && isEnabled ? -0.08 : 0)
    }
}
