import SwiftUI
import StratovoCore

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

