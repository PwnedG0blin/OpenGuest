import SwiftUI
import StratovoCore

struct DashboardView: View {
    @ObservedObject var model: AppModel
    var navigate: (WorkspaceTab) -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            GroupBox {
                HStack(spacing: 20) {
                    Image(systemName: "externaldrive.fill").font(.system(size: 36)).foregroundStyle(.teal)
                    VStack(alignment: .leading, spacing: 6) {
                        Text(L10n.text("Willkommen bei Stratovo")).font(.title2.bold())
                        Text(model.storage?.root ?? L10n.text("SSD oder Datenordner selbst wählen"))
                            .textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
                        if model.storage != nil { Text(model.storageFree).font(.callout).foregroundStyle(.secondary) }
                    }
                    Spacer(minLength: 12)
                    VStack(spacing: 8) {
                        Button(model.storage == nil ? L10n.text("Speicherort auswählen …") : L10n.text("Speicherort verwalten")) {
                            if model.storage == nil { model.showStorageSetup = true } else { navigate(.setup) }
                        }.buttonStyle(.borderedProminent).controlSize(.large).disabled(model.busy || model.running)
                        Text(L10n.text("Wird beim ersten Start abgefragt und gespeichert."))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }.frame(maxWidth: .infinity, alignment: .leading).padding(16)
            }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 330), alignment: .top)], alignment: .leading, spacing: 20) {
                GroupBox {
                    VStack(alignment: .leading, spacing: 22) {
                        Text(L10n.text("In drei Schritten startklar")).font(.title2.bold())
                        step(1, L10n.text("Speicherort wählen"))
                        step(2, L10n.text("Android, Windows oder Ubuntu einrichten"))
                        step(3, L10n.text("System starten"))
                        HStack {
                            Button(L10n.text("Android einrichten")) { navigate(.android) }.buttonStyle(.borderedProminent)
                            Button(L10n.text("Windows einrichten")) { navigate(.windows) }.buttonStyle(.bordered)
                        }.controlSize(.large)
                    }.frame(maxWidth: .infinity, minHeight: 250, alignment: .topLeading).padding(16)
                }
                GroupBox {
                    VStack(alignment: .leading, spacing: 16) {
                        Text(L10n.text("Speicherbedarf je VM")).font(.title2.bold())
                        budget("Android 16", "ca. 80 GiB")
                        budget("Android 17", L10n.text("zusätzlich ca. 80 GiB"))
                        budget("Windows ARM64", "ca. \(model.windowsCapacityGiB.map { $0 + 20 } ?? 100) GiB")
                        budget("3D-Werkzeuge", "einmalig ab 30 GiB")
                        budget("Ubuntu ARM", "ca. 80 GiB")
                        Text(L10n.text("Richtwerte · Spiele und Sicherungen zusätzlich")).font(.caption).foregroundStyle(.secondary)
                    }.frame(maxWidth: .infinity, minHeight: 250, alignment: .topLeading).padding(16)
                }
            }
            GroupBox {
                HStack(spacing: 20) {
                    Image(systemName: "desktopcomputer").font(.system(size: 32)).foregroundStyle(.teal)
                    VStack(alignment: .leading, spacing: 6) {
                        Text(L10n.text("Windows mit 3D nutzen")).font(.title2.bold())
                        Text(L10n.text("Vorhandene Installation · VirtIO / Neptune / DXMT")).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button(L10n.text("Windows öffnen")) { navigate(.windows) }
                        .buttonStyle(.borderedProminent).controlSize(.large)
                }.padding(16)
            }
            GitHubUpdatesView(model: model, compact: true)
            DisclosureGroup(L10n.text("Ausführliche Einrichtung und Speicherplanung")) {
                VStack(alignment: .leading, spacing: 16) {
                    Text(L10n.text("Speicherort: Wähle eine SSD oder einen lokalen Ordner. Der Laufwerksname ist frei. Bei abgezogener SSD wird kein Ersatzordner intern angelegt."))
                    Text(L10n.text("Android: Im Bereich Android die Version auswählen und installieren. Android 16 ist der bewährte Ausgangspunkt. Android 17 nutzt ein separates Profil; Datenübernahme erstellt eine unabhängige Kopie ohne laufende Synchronisierung."))
                    Text(L10n.text("Windows: Windows-Ordner anlegen, Festplattengröße wählen und eine offizielle Windows-11-ARM64-ISO auswählen. Beim DVD-Start gegebenenfalls im Gast eine Taste drücken. Windows benötigt eine gültige Lizenz."))
                    Text(L10n.text("Bedienung: Erst Android starten bzw. Windows starten anklicken. Die Playerfenster sind frei skalierbar. Text einfügen überträgt Mac-Text in den Gast. Scrollgeschwindigkeit und Android-Touchscrollen findest du im Player."))
                    Text(L10n.text("Windows: Die 3D-Grafik läuft standardmäßig im eigenen Metal-Grafikfenster auf der bisherigen Windows-Festplatte. Die eingebettete Ansicht ist experimentell. Einmalig den 3D-Player vorbereiten beziehungsweise aktualisieren. Bereits gebaute ANGLE-/LLVM-Werkzeuge werden wiederverwendet. In Windows die DVD PKGRAPHICS öffnen und INSTALL_GRAPHICS.cmd starten; danach herunterfahren und neu starten. 3D bleibt experimentell. Der Bau benötigt vollständiges Xcode mit Metal-Werkzeugen und derzeit einen Datenpfad ohne Leerzeichen."))
                    Text(L10n.text("Ubuntu: ARM64-LTS-Abbild herunterladen, Prüfsumme abwarten, installieren und anschließend Ubuntu starten wählen. Die eigene 64-GiB-Festplatte liegt unter Ubuntu im gewählten Datenordner. Ubuntu verwendet denselben Player mit Trackpad-Regler und Text einfügen."))
                    StorageBudgetView(windowsGiB: model.windowsCapacityGiB ?? 80)
                }.padding(.top, 12)
            }.font(.body)
            GroupBox {
                HStack(spacing: 18) {
                    Image(systemName: "folder.fill").font(.title).foregroundStyle(.teal)
                    VStack(alignment: .leading, spacing: 5) {
                        Text(L10n.text("Dateien zwischen Mac und Gästen austauschen")).font(.headline)
                        Text(L10n.text("Austausch im Datenordner · Windows · Ubuntu · Android"))
                    }
                    Spacer()
                    Button(L10n.text("Dateiaustausch öffnen")) { navigate(.exchange) }.buttonStyle(.borderedProminent)
                }.padding(16)
            }
        }
    }
    private func step(_ number: Int, _ text: String) -> some View {
        HStack(spacing: 12) {
            Text(String(number)).font(.headline).frame(width: 34, height: 34)
                .background(Color.teal.opacity(0.2), in: Circle())
            Text(text).font(.body)
        }
    }
    private func budget(_ title: String, _ value: String) -> some View {
        VStack(spacing: 10) {
            HStack { Text(title); Spacer(); Text(value).foregroundStyle(.secondary) }
            Divider()
        }
    }
}

struct StorageBudgetView: View {
    var windowsGiB: Int = 80
    var body: some View {
        GroupBox(L10n.text("Speicherbedarf je VM · Planungswerte")) {
            VStack(alignment: .leading, spacing: 12) {
                budget("Android 16", "64 GiB virtuelle Nutzerdaten + etwa 8–12 GiB SDK/Systemabbild. Empfehlung: 80 GiB freier SSD-Platz.")
                budget("Android 17", L10n.text("Eigenes 64-GiB-Profil + etwa 8–12 GiB Werkzeuge/Systemabbild. Zusätzlich etwa 80 GiB einplanen; bei Datenkopie zählt der kopierte Inhalt ebenfalls."))
                budget("Windows 11 ARM64", "\(windowsGiB) GiB virtuelle Festplatte + ISO/Treiber und Update-Reserve. Empfehlung: \(windowsGiB + 20) GiB freier SSD-Platz. Mindestens 64 GiB virtuelle Festplatte.")
                budget("Windows 3D-Werkzeuge", L10n.text("Einmalig mindestens 30 GiB für Quellen, Werkzeuge und Grafikbau. Deine vorhandene Windows-Festplatte wird weiterverwendet; keine weitere Windows-Kopie ist erforderlich."))
                budget("Ubuntu ARM64", L10n.text("64 GiB virtuelle Festplatte plus ISO und Update-Reserve. Empfehlung: 80 GiB freier SSD-Platz, mindestens 40 GiB vor der Installation. 6–8 GiB RAM."))
                Text(L10n.text("1 GiB ≈ 1,07 GB. Virtuelle Platten wachsen mit ihren Daten; 64 GiB werden nicht sofort vollständig belegt. Große Spiele, Snapshots und Sicherungen brauchen weiteren Platz. macOS, Xcode, Homebrew-Werkzeuge und Auslagerung können zusätzlich internen Speicher benötigen."))
                    .font(.callout).foregroundStyle(.secondary)
            }.frame(maxWidth: .infinity, alignment: .leading).padding(12)
        }
    }
    private func budget(_ title: String, _ detail: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.headline)
            Text(detail).fixedSize(horizontal: false, vertical: true)
        }
    }
}
