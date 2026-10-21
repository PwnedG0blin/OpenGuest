import SwiftUI
import StratovoCore

extension WorkspaceTab {
    var subtitle: String {
        switch self {
        case .dashboard: return "Deine Systeme. Dein Speicherort."
        case .android: return "Geräte, Apps und Leistung verwalten."
        case .windows: return "Windows starten und gezielt konfigurieren."
        case .ubuntu: return "Dein Linux-Arbeitsplatz auf dem Mac."
        case .exchange: return "Dateien zwischen Mac und Gästen austauschen."
        case .setup: return "Speicher, Werkzeuge und App-Einstellungen."
        case .updates: return "Versionen prüfen und Aktualisierungen verwalten."
        }
    }
}

struct WorkspaceGuide: View {
    let tab: WorkspaceTab
    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            switch tab {
            case .dashboard, .setup:
                section("Speicherort", icon: "externaldrive", text: "Speicherort: Wähle eine SSD oder einen lokalen Ordner. Der Laufwerksname ist frei. Bei abgezogener SSD wird kein Ersatzordner intern angelegt.")
                section("Android", icon: "apps.iphone", text: "Android: Im Bereich Android die Version auswählen und installieren. Android 16 ist der bewährte Ausgangspunkt. Android 17 nutzt ein separates Profil; Datenübernahme erstellt eine unabhängige Kopie ohne laufende Synchronisierung.")
                section("Windows Arm", icon: "desktopcomputer", text: "Windows: Windows-Ordner anlegen, Festplattengröße wählen und eine offizielle Windows-11-ARM64-ISO auswählen. Beim DVD-Start gegebenenfalls im Gast eine Taste drücken. Windows benötigt eine gültige Lizenz.")
                section("Bedienung", icon: "cursorarrow", text: "Bedienung: Erst Android starten bzw. Windows starten anklicken. Die Playerfenster sind frei skalierbar. Text einfügen überträgt Mac-Text in den Gast. Scrollgeschwindigkeit und Android-Touchscrollen findest du im Player.")
                StorageBudgetView()
            case .android:
                section("Android einrichten", icon: "apps.iphone", text: "Noch kein Android eingerichtet. Wähle oben Android 16 oder Android 17 und klicke auf „Laden und installieren …“.")
                section("Grafik", icon: "display", text: "Mac-GPU nutzt die Grafikübersetzung des Android Emulators. Vulkan aus: OpenGL-ES-Kompatibilitätstest für Spiele ohne Vulkan-Pflicht. Ein Wechsel gilt beim nächsten Start und kann je nach Spiel helfen oder die Kompatibilität einschränken.")
                section("Leistungsprofile", icon: "speedometer", text: "Flüssig reduziert die Android-Auflösung und Streamgröße. Änderungen gelten beim nächsten Android-Start. Originalauflösung hebt die Bildschirm-Anpassung wieder auf.")
                section("Verbindung reparieren", icon: "wrench.and.screwdriver", text: "Bei „device offline“: Gastsystem herunterfahren, dann hier ADB neu starten und Kaltstart aktivieren. Apps, Konten und Spielstände bleiben erhalten. Der ADB-Neustart trennt auch andere ADB-Debugverbindungen auf diesem Mac.")
            case .windows:
                section("3D-Player vorbereiten", icon: "display", text: "Windows: Die 3D-Grafik läuft standardmäßig im eigenen Metal-Grafikfenster auf der bisherigen Windows-Festplatte. Die eingebettete Ansicht ist experimentell. Einmalig den 3D-Player vorbereiten beziehungsweise aktualisieren. Bereits gebaute ANGLE-/LLVM-Werkzeuge werden wiederverwendet. In Windows die DVD PKGRAPHICS öffnen und INSTALL_GRAPHICS.cmd starten; danach herunterfahren und neu starten. 3D bleibt experimentell. Der Bau benötigt vollständiges Xcode mit Metal-Werkzeugen und derzeit einen Datenpfad ohne Leerzeichen.")
                section("Bildwiederholrate", icon: "speedometer", text: "Gilt nach vollständigem Herunterfahren beim nächsten Windows-Start. Windows übernimmt die gewählte Frequenz für seine Auflösungen. Das FPS-Limit stellst du separat im Spiel ein; hohe Hz-Werte garantieren keine entsprechende Spieleleistung.")
                section("Virtuelle Festplatte", icon: "internaldrive", text: "„Größe anwenden“ prüft die Kapazität der virtuellen Festplatte. Die Größe des Windows-Laufwerks C: wird dadurch noch nicht geändert.")
                section("Speicher in Windows zuordnen", icon: "rectangle.expand.vertical", text: "Nur wenn der freie Platz direkt rechts neben C: liegt: Rechtsklick auf C: → Volume erweitern. Ist die Option ausgegraut oder liegt eine Wiederherstellungspartition dazwischen, zuerst die Aufteilung prüfen lassen. Keine Partition löschen oder formatieren.")
            case .ubuntu:
                section("Ubuntu einrichten", icon: "terminal", text: "Ubuntu: ARM64-LTS-Abbild herunterladen, Prüfsumme abwarten, installieren und anschließend Ubuntu starten wählen. Die eigene 64-GiB-Festplatte liegt unter Ubuntu im gewählten Datenordner. Ubuntu verwendet denselben Player mit Trackpad-Regler und Text einfügen.")
                section("Installation abschließen", icon: "checkmark.circle", text: "Im Installer die virtuelle 64-GiB-Festplatte auswählen. Nach der Installation herunterfahren und hier Ubuntu starten wählen; dann wird die ISO nicht erneut eingelegt.")
            case .exchange:
                section("Austauschordner", icon: "folder", text: "Dateien hineinlegen oder herauskopieren. Windows und Ubuntu greifen nach der Freigabe direkt darauf zu. Android verwendet die Senden-/Abholen-Schritte weiter unten.")
                section("Freigabe einrichten", icon: "network", text: "Für Windows und Ubuntu muss der Austauschordner in den macOS-Freigabeeinstellungen freigegeben werden. Die Schritt-für-Schritt-Anleitungen stehen direkt bei der jeweiligen Plattform.")
            case .updates:
                section("Updates", icon: "arrow.triangle.2.circlepath", text: "Prüfe vor einem App-Update, ob Android und Windows vollständig heruntergefahren sind. Deine Systeme bleiben auf dem gewählten Datenlaufwerk gespeichert.")
            }
        }
    }
    private func section(_ title: String, icon: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(L10n.text(title), systemImage: icon).font(.headline).foregroundStyle(.teal)
            Text(L10n.text(text)).fixedSize(horizontal: false, vertical: true)
        }
    }
}
