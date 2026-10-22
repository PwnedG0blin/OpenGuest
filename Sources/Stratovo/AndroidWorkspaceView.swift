import SwiftUI
import StratovoCore

@MainActor
struct AndroidWorkspaceView: View {
    @ObservedObject var model: AppModel
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            if model.devices.isEmpty {
                AndroidVersionsView(model: model, installer: model.installer)
            } else {
                DisclosureGroup(L10n.text("Android-Versionen und Datenübernahme")) {
                    AndroidVersionsView(model: model, installer: model.installer).padding(.top, 8)
                }
            }
            GuestPlayerSummary(model: model, kind: "android", title: "Android")
            WorkspaceCard { AndroidOutputControls(model: model) }
            if model.running && model.activeGuest == "android" {
                WorkspaceCard { GuestAudioControls(audio: model.audio, kind: "android") }
            }
            WorkspaceCard {
                VStack(alignment: .leading, spacing: 18) {
                    HStack {
                        Image(systemName: "apps.iphone").font(.system(size: 32)).foregroundStyle(.teal)
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Android ARM64").font(.title2.bold())
                            Text(L10n.text("Deine Apps und Spiele auf dem Mac.")).foregroundStyle(.secondary)
                        }
                        Spacer()
                        WorkspaceStatusBadge(model.androidReady ? L10n.text("Bereit") : L10n.text("Einrichtung nötig"), ready: model.androidReady)
                    }
                    Divider()
                    if model.devices.isEmpty {
                        Text(L10n.text("Noch kein Android eingerichtet. Wähle oben Android 16 oder Android 17 und klicke auf „Laden und installieren …“."))
                            .foregroundStyle(.secondary)
                    } else {
                        Picker(L10n.text("Virtuelles Gerät"), selection: $model.settings.selectedAVD) {
                            ForEach(model.devices) { device in
                            Text("\(model.androidSystem(for: device.name).map { "Android \($0.rawValue) · " } ?? "")\(device.name)\(device.googlePlay ? " · Google Play" : "")").tag(device.name)
                            }
                        }
                        .disabled(model.running || model.busy)
                        if let device = model.selectedDevice, !device.supported {
                            Text(L10n.text("Dieses Gerät ist kein erkanntes ARM64-Gerät und wird in diesem Prototyp nicht gestartet."))
                                .font(.caption).foregroundStyle(.orange)
                        }
                    }
                    DisclosureGroup(L10n.text("Erweiterte Einstellungen")) {
                    GuestResourceControls(model: model)
                    Picker(L10n.text("Grafik"), selection: $model.settings.gpu) {
                        Text(L10n.text("Automatisch")).tag("auto")
                        Text(L10n.text("Mac-GPU bevorzugen")).tag("host")
                        Text(L10n.text("Software (Fehlersuche)")).tag("software")
                    }.disabled(model.running || model.busy || model.androidOutputMode == .direct)
                    Toggle(L10n.text("Vulkan für Android-Spiele zulassen"), isOn: $model.androidVulkanEnabled)
                        .disabled(model.running || model.busy)
                    ContextHelpButton("Grafik und Kompatibilität") {
                        Text(L10n.text("Mac-GPU nutzt die Grafikübersetzung des Android Emulators. Vulkan aus: OpenGL-ES-Kompatibilitätstest für Spiele ohne Vulkan-Pflicht. Ein Wechsel gilt beim nächsten Start und kann je nach Spiel helfen oder die Kompatibilität einschränken."))
                            .font(.body).foregroundStyle(.secondary)
                    }
                    Picker(L10n.text("Android-Leistungsprofil"), selection: $model.androidProfile) {
                        ForEach(AndroidPerformance.allCases, id: \.rawValue) { profile in
                            Text(profile.title).tag(profile)
                        }
                    }.disabled(model.running || model.busy)
                    AndroidFrameRateControls(model: model)
                    if model.androidOutputMode.usesStream {
                        AndroidStreamQualityControls(model: model)
                    }
                    ContextHelpButton("Leistungsprofile") {
                        Text(L10n.text("Flüssig reduziert die Android-Auflösung. Änderungen gelten beim nächsten Android-Start. Die Bildqualität der Übertragung wählst du separat; Originalauflösung hebt die Bildschirm-Anpassung wieder auf."))
                            .font(.body).foregroundStyle(.secondary)
                    }
                    Text(model.androidDisplayStatus).font(.caption).textSelection(.enabled)
                    DisclosureGroup(L10n.text("Auflösung und Android-Skalierung")) {
                        AndroidDisplayControls(model: model).padding(.top, 8)
                    }
                    Label(model.androidRendererStatus, systemImage: model.androidSoftwareRendering ? "exclamationmark.triangle" : "info.circle")
                        .font(.caption).foregroundStyle(model.androidSoftwareRendering ? Color.orange : Color.secondary)
                    Toggle(L10n.text("Kaltstart beim nächsten Start"), isOn: $model.settings.coldBoot)
                        .disabled(model.running || model.busy)
                    Button(L10n.text("Android-Verbindung reparieren")) { Task { await model.repairAndroidConnection() } }
                        .disabled(!model.canRepairAndroidConnection)
                    ContextHelpButton("Verbindung reparieren") {
                        Text(L10n.text("Bei „device offline“: Gastsystem herunterfahren, dann hier ADB neu starten und Kaltstart aktivieren. Apps, Konten und Spielstände bleiben erhalten. Der ADB-Neustart trennt auch andere ADB-Debugverbindungen auf diesem Mac."))
                            .font(.body).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    }
                    if !model.androidRepairStatus.isEmpty { Text(model.androidRepairStatus).font(.caption).textSelection(.enabled) }
                    if let device = model.selectedDevice {
                        Label(device.googlePlay ? "Google-Play-Systemabbild im Profil erkannt" : L10n.text("Dieses Profil enthält keinen erkannten Google Play Store"),
                              systemImage: device.googlePlay ? "checkmark.seal" : "info.circle")
                            .font(.caption).foregroundStyle(device.googlePlay ? Color.teal : Color.orange)
                    }
                    Text(model.androidAcceleration).font(.caption).foregroundStyle(.secondary)
                    }
                    HStack {
                        Button(action: model.startAndroid) { Label(L10n.text("Android starten"), systemImage: "play.fill") }
                            .buttonStyle(.borderedProminent).controlSize(.large)
                            .disabled(!model.canStartAndroid)
                        Spacer()
                        Link(L10n.text("Gerät anlegen ↗"), destination: URL(string: "https://developer.android.com/studio/run/managing-avds")!)
                    }
                    Divider()
                    HStack {
                        Button(action: model.chooseAndInstallAPK) { Label(L10n.text("APK installieren …"), systemImage: "square.and.arrow.down") }
                            .disabled(!model.canInstallAPK)
                        if model.apkBusy { ProgressView().controlSize(.small) }
                    }
                    if model.androidOutputMode.usesStream && !ScrcpySession.installed {
                        Text(L10n.text("Streaming-Modul fehlt. Unter „Einrichtung“ kannst du es vorbereiten."))
                            .font(.caption).foregroundStyle(.orange)
                    }
                    if !model.apkStatus.isEmpty { Text(model.apkStatus).font(.caption).foregroundStyle(.secondary) }
                    Divider()
                    Text(L10n.text("Google-Konto & Cloud-Spielstände")).font(.headline)
                    Button(action: model.openGoogleInMacBrowser) {
                        Label(L10n.text("Google im Mac-Browser öffnen"), systemImage: "arrow.up.forward.app")
                    }
                    ContextHelpButton("Google-Konto & Cloud-Spielstände") {
                        Text(L10n.text("Öffnet die Google-Kontoauswahl außerhalb von Stratovo in deinem normalen Standardbrowser. Dort können vorhandene Google-Anmeldungen und gespeicherte Zugangsdaten deines Browserprofils genutzt werden."))
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                    ContextHelpButton("Google-Konto & Cloud-Spielstände") {
                        Text(L10n.text("Die Browser-Anmeldung gilt für den Mac. Sie fügt kein Konto zu Android hinzu. Für Play Store und Cloud-Spielstände das Konto zusätzlich im Android-System anmelden."))
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                    Button(L10n.text("Google-Konto in Android hinzufügen"), action: model.openGoogleAccountSettings)
                        .disabled(!model.canInstallAPK || model.selectedDevice?.googlePlay != true)
                    HStack {
                        Button(L10n.text("Play Spiele"), action: model.openPlayGames)
                        Button(L10n.text("Kontosynchronisierung"), action: model.openSyncSettings)
                        Button(L10n.text("Android-Sicherung"), action: model.openBackupSettings)
                    }.disabled(!model.canInstallAPK || model.selectedDevice?.googlePlay != true)
                    Text(model.googleServicesStatus).font(.caption).foregroundStyle(.secondary)
                    ContextHelpButton("Details und Anleitung") {
                        Text(L10n.text("Melde dich in Play Spiele und im jeweiligen Spiel mit demselben Konto an. Cloud-Spielstände und Backups funktionieren nur, soweit App, Spiel und Systemabbild sie unterstützen. Lokale Apps, Daten und Anmeldungen bleiben unabhängig davon gespeichert."))
                            .font(.body).foregroundStyle(.secondary)
                    }
                }
            }
            ContextHelpButton("Android auswählen → Starten → Apps nutzen") {
                Text(L10n.text("Einmalig ein offizielles Google-Play-Gerät einrichten. Mit „Android starten“ öffnest du dein ausgewähltes Android im eigenen Playerfenster. Apps, Google-Anmeldung und Einstellungen bleiben gespeichert. Die Google-Webseite lässt sich zusätzlich im normalen Mac-Browser öffnen; die Android-Anmeldung erfolgt separat im Gastsystem."))
            }
        }
    }

}
