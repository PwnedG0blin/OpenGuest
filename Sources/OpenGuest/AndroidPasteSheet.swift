import SwiftUI
import OpenGuestCore

@MainActor
struct AndroidPasteSheet: View {
    @ObservedObject var model: AppModel
    @Binding var text: String
    @State private var allowLineBreaks = false
    @State private var sending = false
    @Environment(\.dismiss) private var dismiss
    private var input: AndroidClipboardText? { try? AndroidClipboardText(text, allowLineBreaks: allowLineBreaks) }
    private var issue: String? {
        do { _ = try AndroidClipboardText(text, allowLineBreaks: allowLineBreaks); return nil }
        catch { return error.localizedDescription }
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Text in Android einfügen", systemImage: "doc.on.clipboard").font(.title2.bold()).foregroundStyle(.teal)
            Text("Zuerst das gewünschte Eingabefeld in Android antippen. Bestätigter Text wird in die Android-Zwischenablage übertragen und eingefügt.")
                .font(.subheadline).foregroundStyle(.secondary)
            TextEditor(text: $text).font(.body).frame(height: 160).padding(6)
                .background(.teal.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(.teal.opacity(0.35)))
            Toggle("Zeilenumbrüche innerhalb des Textes erlauben", isOn: $allowLineBreaks)
            Text(issue ?? "Bereit · Unicode wird unterstützt. Am Ende wird kein Enter gesendet.")
                .font(.caption).foregroundStyle(issue == nil ? Color.teal : Color.orange)
                .fixedSize(horizontal: false, vertical: true)
            Text("Erst mit deiner Bestätigung wird der Text an Android übertragen. Die Android-Zwischenablage enthält ihn anschließend wie beim normalen Kopieren.")
                .font(.caption).foregroundStyle(.secondary)
            HStack {
                Button("Abbrechen") { dismiss() }.keyboardShortcut(.cancelAction).disabled(sending)
                Spacer()
                if sending { ProgressView().controlSize(.small) }
                Button("In Android einfügen") {
                    guard let input else { return }
                    sending = true
                    Task {
                        let sent = await model.pasteAndroidText(input)
                        sending = false
                        if sent { dismiss() }
                    }
                }
                    .buttonStyle(.borderedProminent).disabled(input == nil || sending).keyboardShortcut(.defaultAction)
            }
            if !model.androidPasteStatus.isEmpty { Text(model.androidPasteStatus).font(.caption) }
        }.padding(24).frame(width: 560).background(Color(nsColor: .windowBackgroundColor)).tint(.teal)
    }
}
