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
                        Text("Willkommen bei Stratovo").font(.title2.bold())
                        Text(model.storage?.root ?? "SSD oder Datenordner selbst wählen")
                            .textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
                        if model.storage != nil { Text(model.storageFree).font(.callout).foregroundStyle(.secondary) }
                    }
                    Spacer(minLength: 12)
                    VStack(spacing: 8) {
                        Button(model.storage == nil ? "Speicherort auswählen …" : "Speicherort verwalten") {
                            if model.storage == nil { model.showStorageSetup = true } else { navigate(.setup) }
                        }.buttonStyle(.borderedProminent).controlSize(.large).disabled(model.busy || model.running)
                        Text("Wird beim ersten Start abgefragt und gespeichert.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }.frame(maxWidth: .infinity, alignment: .leading).padding(16)
            }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 330), alignment: .top)], alignment: .leading, spacing: 20) {
                GroupBox {
                    VStack(alignment: .leading, spacing: 22) {
                        Text("In drei Schritten startklar").font(.title2.bold())
                        step(1, "Speicherort wählen")
                        step(2, "Android oder Windows einrichten")
                        step(3, "System starten")
                        HStack {
                            Button("Android einrichten") { navigate(.android) }.buttonStyle(.borderedProminent)
                            Button("Windows einrichten") { navigate(.windows) }.buttonStyle(.bordered)
                        }.controlSize(.large)
                    }.frame(maxWidth: .infinity, minHeight: 250, alignment: .topLeading).padding(16)
                }
                GroupBox {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Speicherbedarf je VM").font(.title2.bold())
                        budget("Android 16", "ca. 80 GiB")
                        budget("Android 17", "zusätzlich ca. 80 GiB")
                        budget("Windows ARM64", "ca. \(model.windowsCapacityGiB.map { $0 + 20 } ?? 100) GiB")
                        budget("Windows 3D-Test", "ab 30 GiB + Windows-Kopie")
                        Text("Richtwerte · Spiele und Sicherungen zusätzlich").font(.caption).foregroundStyle(.secondary)
                    }.frame(maxWidth: .infinity, minHeight: 250, alignment: .topLeading).padding(16)
                }
            }
            GroupBox {
                HStack(spacing: 20) {
                    Image(systemName: "desktopcomputer").font(.system(size: 32)).foregroundStyle(.teal)
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Windows mit 3D testen").font(.title2.bold())
                        Text("Eigene Testkopie · VirtIO / Neptune / DXMT").foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Grafiklabor öffnen") { model.windowsLabSelected = true; navigate(.windows) }
                        .buttonStyle(.borderedProminent).controlSize(.large)
                }.padding(16)
            }
            GitHubUpdatesView(model: model, compact: true)
            DisclosureGroup("Ausführliche Einrichtung und Speicherplanung") {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Speicherort: Wähle eine SSD oder einen lokalen Ordner. Der Laufwerksname ist frei. Bei abgezogener SSD wird kein Ersatzordner intern angelegt.")
                    Text("Android: Im Bereich Android die Version auswählen und installieren. Android 16 ist der bewährte Ausgangspunkt. Android 17 nutzt ein separates Profil; Datenübernahme erstellt eine unabhängige Kopie ohne laufende Synchronisierung.")
                    Text("Windows: Windows-Ordner anlegen, Festplattengröße wählen und eine offizielle Windows-11-ARM64-ISO auswählen. Beim DVD-Start gegebenenfalls im Gast eine Taste drücken. Windows benötigt eine gültige Lizenz.")
                    Text("Bedienung: Erst Android starten bzw. Windows starten anklicken. Die Playerfenster sind frei skalierbar. Text einfügen überträgt Mac-Text in den Gast. Scrollgeschwindigkeit und Android-Touchscrollen findest du im Player.")
                    Text("3D-Test: Grafik vorbereiten baut die Laufzeit und öffnet eine eigene Windows-Testkopie. Im Test-Windows: Explorer → Dieser PC → DVD PKGRAPHICS → INSTALL_GRAPHICS.cmd. Danach die Testkopie herunterfahren und neu starten. Vollständiges Xcode mit Metal Toolchain und die unter System prüfen genannten Bibliotheken werden benötigt. Der erste Bau dauert; vorhandene Ergebnisse werden wiederverwendet. 3D ist experimentell; FPS und Spielekompatibilität sind nicht garantiert. Der Datenpfad für den experimentellen Grafikbau darf derzeit keine Leerzeichen enthalten.")
                    StorageBudgetView(windowsGiB: model.windowsCapacityGiB ?? 80)
                }.padding(.top, 12)
            }.font(.body)
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
        GroupBox("Speicherbedarf je VM · Planungswerte") {
            VStack(alignment: .leading, spacing: 12) {
                budget("Android 16", "64 GiB virtuelle Nutzerdaten + etwa 8–12 GiB SDK/Systemabbild. Empfehlung: 80 GiB freier SSD-Platz.")
                budget("Android 17", "Eigenes 64-GiB-Profil + etwa 8–12 GiB Werkzeuge/Systemabbild. Zusätzlich etwa 80 GiB einplanen; bei Datenkopie zählt der kopierte Inhalt ebenfalls.")
                budget("Windows 11 ARM64", "\(windowsGiB) GiB virtuelle Festplatte + ISO/Treiber und Update-Reserve. Empfehlung: \(windowsGiB + 20) GiB freier SSD-Platz. Mindestens 64 GiB virtuelle Festplatte.")
                budget("Windows-3D-Testkopie", "Zusätzlich mindestens 30 GiB für Quellen, Werkzeuge und Grafikbau sowie der belegte Inhalt der Windows-Festplatte + 10 GiB Reserve. Für späteres Wachstum bis zu \(windowsGiB + 40) GiB zusätzlich einplanen.")
                Text("1 GiB ≈ 1,07 GB. Virtuelle Platten wachsen mit ihren Daten; 64 GiB werden nicht sofort vollständig belegt. Große Spiele, Snapshots und Sicherungen brauchen weiteren Platz. macOS, Xcode, Homebrew-Werkzeuge und Auslagerung können zusätzlich internen Speicher benötigen.")
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
