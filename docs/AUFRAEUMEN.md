# Nach dem Update aufräumen

Erst alle Gäste herunterfahren, die neue App unter Programme starten und Android,
Windows samt Dateien sowie den neuen Player und Text einfügen testen.

Danach dürfen alte ZIPs und entpackte Versionspakete von Pixelkoje/Stratovo sowie
alte App-Builds in den Papierkorb. Die Datenordner sind davon getrennt.

App-Builds liegen im Unterordner `Builds` deines gewählten Datenordners. Entferne
sie erst, wenn die neue App unter Programme erfolgreich getestet wurde. Behalte
bei einer selbst gebauten Ausgabe den aktuellen Quellcode für spätere Bauten.
Den Papierkorb erst nach einem weiteren erfolgreichen Start leeren.

## Behalten

- Android: SDK, Profile, Systemabbilder, Benutzerdaten.
- Windows: ganze bisherige Installation einschließlich Festplatte, TPM, NVRAM und Gerätekennung.
- GraphicsLab: insbesondere Runtime, ANGLE.xcarchive, GraphicsDrivers.iso, runtime-ready.json
  und zunächst auch Sources/BuildTools für gezielte Player-Aktualisierungen.
- Ubuntu: die neue eigenständige Festplatte, NVRAM und Einstellungen.
- Backups und die kleine interne Speicherort-Konfiguration.

Eine frühere `GraphicsLab/TestVM` ist eine eigene Windows-Installation. Erst deren
Dateien und Konten prüfen und benötigte Daten sichern, bevor sie gezielt entfernt wird.
Stratovo löscht oder überschreibt diese Kopie beim Update nicht.

Andere persönliche Dateien, Homebrew oder Xcode gehören nicht zu dieser Bereinigung.
