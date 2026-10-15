import SwiftUI
import OpenGuestCore

@MainActor
struct SetupDownloadsView: View {
    @ObservedObject var model: AppModel
    @ObservedObject var installer: SetupInstaller
    @State private var selection: Set<SetupComponent> = []
    @State private var sdkConsent = false
    @State private var microsoftLink = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Downloads und Einrichtung", systemImage: "arrow.down.circle.fill").font(.title2.bold())
            Text("Ziel: \(model.storage?.root ?? "Zuerst einen Datenordner wählen")")
                .font(.body.monospaced()).textSelection(.enabled)
            Text("Downloads, Entpackdateien und Gastsysteme bleiben auf diesem Datenträger. Vorhandene Komponenten werden wiederverwendet. Ohne den Datenträger startet kein Ersatzdownload intern.")
                .foregroundStyle(.secondary)
            ForEach(SetupComponent.allCases) { component in
                Toggle(isOn: Binding(get: { selection.contains(component) }, set: { enabled in
                    if enabled { selection.insert(component) } else { selection.remove(component) }
                })) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(component.title).font(.headline)
                        Text(model.setupReady.contains(component) ? "Auf dem gewählten Datenträger vorhanden" : detail(component))
                            .font(.subheadline).foregroundStyle(model.setupReady.contains(component) ? Color.teal : Color.secondary)
                    }
                }.disabled(model.busy || model.running || !model.storageReady)
            }
            if selection.contains(.android) && !model.setupReady.contains(.android) {
                Link("Google SDK-Lizenz lesen ↗", destination: URL(string: "https://developer.android.com/studio#terms-and-conditions")!)
                Toggle("Ich habe die Google SDK-Lizenz gelesen und akzeptiere sie für den Download der Werkzeuge.", isOn: $sdkConsent)
                    .disabled(model.busy)
                Text("Weitere SDK-Lizenzen werden während der Einrichtung hier angezeigt und einzeln von dir bestätigt.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            if selection.contains(.windowsISO) && !model.setupReady.contains(.windowsISO) && model.settings.iso.isEmpty {
                Link("Offizielle Microsoft-Seite · ARM64 wählen ↗", destination: URL(string: "https://www.microsoft.com/de-de/software-download/windows11arm64")!)
                TextField("Direkten Microsoft-Downloadlink der ARM64-ISO einfügen", text: $microsoftLink)
                    .textFieldStyle(.roundedBorder).disabled(model.busy)
                Text("Auf der Microsoft-Seite die Sprache wählen und den erzeugten Downloadlink kopieren. Pixelkoje lädt ihn direkt auf den eingestellten Datenträger. Alternativ eine vorhandene ISO im Windows-Bereich auswählen.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Button {
                Task { await model.installComponents(selection, microsoftLink: microsoftLink) }
            } label: {
                Label(installer.running ? "Einrichtung läuft …" : "Auswahl laden und einrichten", systemImage: "arrow.down.to.line")
            }
            .buttonStyle(.borderedProminent)
            .disabled(model.running || model.busy || !model.storageReady || selection.isEmpty ||
                      (selection.contains(.android) && !model.setupReady.contains(.android) && !sdkConsent))
            if installer.running { ProgressView().controlSize(.small) }
            Text(installer.status).font(.body.weight(.medium)).textSelection(.enabled)
            if !installer.output.isEmpty {
                ScrollView {
                    Text(installer.output).font(.system(size: 13, design: .monospaced))
                        .textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading).padding(12)
                }.frame(height: 240)
                    .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 10))
            }
            if installer.licensePrompt {
                Text("Die Android-Werkzeuge warten auf deine Antwort zur oben angezeigten Lizenz.").font(.headline)
                HStack {
                    Button("Angezeigte Lizenz akzeptieren") { installer.answerLicense(accept: true) }.buttonStyle(.borderedProminent)
                    Button("Ablehnen") { installer.answerLicense(accept: false) }
                }
            }
            Divider()
            Text("Windows-Engine: \(model.qemu == nil ? "QEMU fehlt" : "QEMU vorhanden") · \(model.swtpm == nil ? "swtpm fehlt" : "swtpm vorhanden")")
                .font(.headline)
            Text("QEMU und swtpm werden aus deiner vorhandenen Mac-Installation genutzt. Sie werden hier noch nicht automatisch installiert. UEFI-Dateien und eigene Engines kannst du unten auswählen.")
                .font(.subheadline).foregroundStyle(.secondary)
            HStack {
                Link("QEMU für macOS ↗", destination: URL(string: "https://www.qemu.org/download/#macos")!)
                Link("swtpm ↗", destination: URL(string: "https://github.com/stefanberger/swtpm")!)
            }
        }
        .padding(20).frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 16))
    }

    private func detail(_ item: SetupComponent) -> String {
        switch item {
        case .android: return "SDK-Werkzeuge, Emulator, ARM64-Systemabbild und eigenes Gerät · Google"
        case .streaming: return "scrcpy 4.0 · Genymobile · mit SHA-256-Prüfung"
        case .windowsDrivers: return "UTM Guest Tools · ISO mit ARM64-Treibern"
        case .windowsISO: return model.settings.iso.isEmpty ? "Direktdownload von Microsoft oder eigene ISO auswählen" : "Vorhandene ISO wird auf den gewählten Datenträger übernommen"
        }
    }
}
