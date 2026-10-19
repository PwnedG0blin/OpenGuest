import SwiftUI
import StratovoCore

@MainActor
struct AndroidVersionsView: View {
    @ObservedObject var model: AppModel
    @ObservedObject var installer: SetupInstaller
    @State private var installation: AndroidSystem?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(L10n.text("Android-Version wählen"), systemImage: "square.stack.3d.up.fill").font(.title2.bold())
            Text(model.selectedAndroidSystem.map { L10n.message("Ausgewählt: Android \($0.rawValue) · \(model.settings.selectedAVD)") }
                 ?? L10n.text("Wähle dein Android oder installiere eine weitere Version."))
                .font(.subheadline).textSelection(.enabled)
            ForEach(AndroidSystem.allCases) { system in versionRow(system) }
            if installer.running, let system = installer.installingAndroid {
                HStack {
                    ProgressView().controlSize(.small)
                    Text(installer.status).font(.subheadline)
                    Spacer()
                    Button(L10n.text("Installation anzeigen")) { installation = system }
                }
            }
            if !model.storageReady {
                Button(L10n.text("Datenordner auswählen …")) { model.showStorageSetup = true }
            } else if model.running {
                Text(L10n.text("Zum Wechseln oder Installieren zuerst den laufenden Gast herunterfahren."))
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            if model.settings.selectedAVD == SetupInstaller.android17DataProfile {
                Text(L10n.text("Android 17 verwendet eine eigene Kopie deiner Android-16-Daten. Änderungen werden nicht zwischen den Versionen synchronisiert."))
                    .font(.subheadline).foregroundStyle(.secondary)
            }
        }
        .padding(20).frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.teal.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Color.teal.opacity(0.35)))
        .sheet(item: $installation) { system in
            AndroidVersionInstallView(model: model, installer: installer, system: system)
        }
    }

    private func versionRow(_ system: AndroidSystem) -> some View {
        let component: SetupComponent = system == .android16 ? .android : .android17
        let installed = model.setupReady.contains(component)
        let selected = installed && model.selectedAndroidSystem == system
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Image(systemName: selected ? "checkmark.circle.fill" : "apps.iphone")
                    .font(.title).foregroundStyle(.teal)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Android \(system.rawValue)").font(.title3.bold())
                    Text(selected ? L10n.text("Ausgewählt · Google Play") : installed ? "Installiert · Google Play" : L10n.text("Zum Installieren verfügbar · Google Play · 64 GB"))
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
            }
            if installed {
                HStack {
                    Button(selected ? L10n.text("Ausgewählt") : L10n.message("Android \(system.rawValue) auswählen")) {
                        model.selectAndroidSystem(system)
                    }.buttonStyle(.borderedProminent).disabled(selected || !model.canManageAndroid)
                    if system == .android17, model.android16DataSource != nil, !model.hasAndroid17DataCopy {
                        Button(L10n.text("Daten aus Android 16 übernehmen …")) { installation = system }
                            .disabled(!model.canManageAndroid)
                    }
                }
            } else {
                Button { installation = system } label: {
                    Label(L10n.message("Android \(system.rawValue) laden und installieren …"), systemImage: "arrow.down.circle.fill")
                }.buttonStyle(.borderedProminent).disabled(!model.canManageAndroid)
            }
        }
        .padding(14).frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 12))
    }
}

@MainActor
private struct AndroidVersionInstallView: View {
    @ObservedObject var model: AppModel
    @ObservedObject var installer: SetupInstaller
    let system: AndroidSystem
    @Environment(\.dismiss) private var dismiss
    @State private var sdkConsent = false
    @State private var copyData: Bool

    init(model: AppModel, installer: SetupInstaller, system: AndroidSystem) {
        self.model = model; self.installer = installer; self.system = system
        _copyData = State(initialValue: system == .android17 && model.android16DataSource != nil && !model.hasAndroid17DataCopy)
    }
    private var component: SetupComponent { system == .android16 ? .android : .android17 }
    private var needsConsent: Bool { !model.setupReady.contains(component) || copyData }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Label(L10n.message("Android \(system.rawValue) einrichten"), systemImage: "arrow.down.circle.fill")
                        .font(.title.bold())
                    Text("Google Play · ARM64 · 64 GB").font(.headline).foregroundStyle(.teal)
                    Text(L10n.message("Ziel: \(model.storage?.root ?? "Zuerst Datenordner auswählen")"))
                        .font(.body.monospaced()).textSelection(.enabled)
                    Text(L10n.text("Downloads, temporäre Dateien und das Android-Profil bleiben auf dem eingestellten Datenträger."))
                        .foregroundStyle(.secondary)
                    if system == .android17 {
                        Toggle(L10n.text("Meine Android-16-Daten als Kopie übernehmen"), isOn: $copyData)
                            .disabled(!model.canManageAndroid || model.android16DataSource == nil || model.hasAndroid17DataCopy)
                        if let source = model.android16DataSource {
                            Text(L10n.message("Quelle: \(source)")).font(.subheadline.monospaced()).textSelection(.enabled)
                        }
                        Text(copyData
                            ? L10n.text("Experimentelle Übernahme: Apps, Dateien und Verschlüsselungsmetadaten werden in eine eigene Kopie übernommen. Android 16 bleibt erhalten. Ob alle Apps und Anmeldungen mit Android 17 funktionieren, wird erst beim ersten Start sichtbar. Spätere Änderungen werden nicht synchronisiert.")
                            : L10n.text("Ohne Datenübernahme wird ein separates leeres Profil eingerichtet beziehungsweise das vorhandene Android 17 ausgewählt."))
                            .font(.subheadline).foregroundStyle(.secondary)
                        if copyData {
                            Label(L10n.text("Der erste Start ist ein Kaltstart und kann länger dauern. Bei Problemen kannst du Android 16 weiterverwenden."), systemImage: "info.circle")
                                .font(.subheadline)
                        }
                    }
                    Picker(L10n.text("Android-SDK-Kanal"), selection: $model.androidSDKChannel) {
                        Text(L10n.text("Stable · empfohlen")).tag(0)
                        Text(L10n.text("Beta einschließen")).tag(1)
                        Text(L10n.text("Dev einschließen")).tag(2)
                        Text(L10n.text("Canary · alle Vorschaukanäle")).tag(3)
                    }.disabled(!model.canManageAndroid)
                    Text(L10n.text("Installiert ein von Google angebotenes Emulator-Abbild. Dies ist keine Anmeldung im Pixel-Betaprogramm."))
                        .font(.subheadline).foregroundStyle(.secondary)
                    if needsConsent {
                        Link("Google SDK-Lizenz lesen ↗", destination: URL(string: "https://developer.android.com/studio#terms-and-conditions")!)
                        Toggle(L10n.text("Ich habe die Google SDK-Lizenz gelesen und akzeptiere sie für den Download."), isOn: $sdkConsent)
                            .disabled(installer.running)
                    }
                    Button {
                        let dataSource = copyData ? model.android16DataSource : nil
                        Task { await model.installComponents([component, .streaming], microsoftLink: "", androidDataSource: dataSource) }
                    } label: {
                        Label(installer.running ? L10n.text("Einrichtung läuft …") : copyData ? "Android 17 mit meinen Daten einrichten" : L10n.message("Android \(system.rawValue) laden und installieren"), systemImage: "arrow.down.to.line")
                    }
                    .buttonStyle(.borderedProminent).controlSize(.large)
                    .disabled(!model.canManageAndroid || needsConsent && !sdkConsent || copyData && model.android16DataSource == nil)
                    Text(installer.status).font(.headline).textSelection(.enabled)
                    if let error = model.errorMessage {
                        Label(error, systemImage: "exclamationmark.triangle.fill")
                            .font(.subheadline).foregroundStyle(.orange).textSelection(.enabled)
                    }
                    if installer.running { ProgressView().controlSize(.small) }
                    if installer.licensePrompt {
                        Text(L10n.text("Google wartet auf deine Lizenzantwort:")).font(.headline)
                        HStack {
                            Button(L10n.text("Angezeigte Lizenz akzeptieren")) { installer.answerLicense(accept: true) }
                                .buttonStyle(.borderedProminent)
                            Button(L10n.text("Ablehnen")) { installer.answerLicense(accept: false) }
                        }
                    }
                    if !installer.output.isEmpty {
                        ScrollView {
                            Text(installer.output).font(.system(size: 13, design: .monospaced))
                                .textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading).padding(12)
                        }.frame(height: 180)
                            .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 10))
                    }
                }.fixedSize(horizontal: false, vertical: true).padding(24)
            }
            Divider()
            HStack {
                Text(L10n.text("Anschließend im Hauptfenster „Android starten“ wählen.")).font(.subheadline)
                Spacer()
                Button(L10n.text("Fertig")) { dismiss() }.keyboardShortcut(.cancelAction).disabled(installer.running)
            }.padding(16)
        }.frame(width: 740, height: 710).tint(.teal)
            .interactiveDismissDisabled(installer.running)
    }
}
