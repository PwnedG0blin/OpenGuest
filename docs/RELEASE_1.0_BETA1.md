# Stratovo 1.0 Beta 1

Öffentliche Beta für Apple-Silicon-Macs ab macOS 14. Entwickelt von **PwnedG0blin**.

## Neu

- Dashboard mit klaren Einrichtungsschritten, Speicherplanung und direktem Grafiklabor-Zugang.
- Beim ersten Start SSD oder Datenordner frei wählen. Der Name des Laufwerks spielt keine Rolle; bestehende Speicherorte und Gastdaten werden weiterverwendet.
- Android 16 und separates Android-17-Testprofil; optionale einmalige Datenkopie, keine gemeinsame schreibbare Datenpartition.
- Android-Bildrate bis 90 FPS wählbar, ohne den bisherigen rekursiven Einstellungsfehler. Tatsächliche FPS sind abhängig von Gast, Spiel und Hardware.
- Verbesserte Player-Verarbeitung, Textübertragung und Trackpad-Steuerung.
- Experimentelles Windows-3D-Grafiklabor direkt aus der App. Die auf macOS 27 erprobten Compiler-, Abhängigkeits-, GnuTLS-, Suchpfad- und TPM-Startkorrekturen sind in den eingebetteten Ressourcen enthalten. Ein App-Start setzt sie nicht mehr auf den alten Stand zurück.
- Updateprüfung über öffentliche GitHub Releases; geprüfte Apple-Silicon-App nach Bestätigung laden, austauschen und neu starten. Keine API-Schlüssel erforderlich. Gäste und Grafikbau müssen vorher beendet sein.

## Speicherbedarf pro VM

| System | Planung auf dem gewählten Laufwerk |
| --- | --- |
| Android 16 | 64 GiB virtuelle Nutzerdaten plus etwa 8–12 GiB SDK/Systemabbild; etwa **80 GiB frei** empfohlen |
| Android 17 | Separates 64-GiB-Profil; zusätzlich etwa **80 GiB** inklusive Systemabbild/Reserve einplanen |
| Windows 11 ARM64 | Standard 80 GiB virtuelle Platte plus ISO/Treiber/Reserve: etwa **100 GiB frei** empfohlen; mindestens 64 GiB virtuelle Platte |
| Windows-3D-Test | Zusätzlich **30 GiB** Grafikbau plus belegter Inhalt der Windows-Platte und 10 GiB Reserve; bei voller 80-GiB-Platte bis zu **120 GiB zusätzlich** |

1 GiB entspricht ungefähr 1,07 GB. Virtuelle Platten wachsen mit ihren Daten; der Höchstwert wird nicht sofort belegt. Spiele, Snapshots und Backups kommen hinzu. Xcode, Homebrew und macOS-Auslagerung können weiteren internen Platz benötigen.

## Installation und Start

1. DMG laden und Stratovo.app in Programme oder einen beschreibbaren eigenen App-Ordner kopieren.
2. App starten, SSD/Datenordner auswählen und dem Dashboard folgen. Kein Gast startet automatisch.
3. Android unter Android installieren; Windows mit offizieller ARM64-ISO unter Windows Arm einrichten.
4. Für 3D: Windows Arm → Windows-Modus → 3D-Testkopie → Grafik vorbereiten. Im gestarteten Test-Windows Explorer → Dieser PC → PKGRAPHICS → INSTALL_GRAPHICS.cmd öffnen und danach die Testkopie neu starten.

Das Grafiklabor benötigt vollständiges Xcode einschließlich Metal Toolchain und native ARM64-Homebrew-Bibliotheken `glib`, `pixman`, `libslirp`, `gnutls`, `libtasn1`, `zlib` sowie QEMU und swtpm. Es lädt seine weiteren Bauwerkzeuge in den gewählten Datenordner. Es ist experimentell; für den Grafikbau werden derzeit Datenpfade ohne Leerzeichen benötigt. Ein Windows-PC außerhalb der VM ist nicht nötig.

## Grenzen der Beta

Die App ist lokal signiert (ad-hoc), noch nicht mit Apple Developer ID signiert oder notarisiert. macOS kann beim ersten Öffnen eine Freigabe verlangen. Ein Update umgeht Gatekeeper nicht. Die Updatefunktion prüft Repository/Tag, SHA-256, Paketgröße, Bundle-ID, Version und Codesignatur; eine alte App-Kopie bleibt zur manuellen Rückkehr neben der App erhalten. Update-Downloads liegen unter `Updates` im gewählten Datenordner.

Die Grafiklaufzeit wurde auf dem Mac mini M4 des Entwicklers gebaut und der Teststart dort bestätigt. Automatisierte App-Tests ersetzen keinen Hardware-/Spieletest. Windows benötigt eine eigene Lizenz; Insider-/Hardwarefreigaben werden nicht zugesichert. Private Windows-Setup-Umgehungen sind nicht Teil dieser Veröffentlichung.
