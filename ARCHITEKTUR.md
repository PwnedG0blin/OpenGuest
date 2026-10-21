# Stratovo: Struktur und Pflege

Die Oberfläche trennt Alltagsbedienung, Einrichtung, Hilfe und Diagnose.
`ContentView` enthält Navigation und Sitzungsleiste. Android, Windows und
Einrichtung haben jeweils eine eigene Ansicht. `WorkspaceComponents` stellt
Karten, Statusanzeigen, Dateiauswahl und lesbare Hilfefenster bereit.

Controller für Grafikvorbereitung, Ubuntu und Dateiaustausch liegen getrennt
von ihren Ansichten. `AppModel` koordiniert weiterhin die gemeinsame Sitzung;
Startbedingungen und Speicherprüfungen bleiben dort zentral. Neue Funktionen
sollen möglichst in einen zuständigen Controller oder in `StratovoCore`,
statt weitere Aufgaben in `AppModel` zu sammeln.

## Grafiklaufzeit

`Packaging/GraphicsLab/runtime-policy.json` ist die gemeinsame Beschreibung
für Swift und Python: erwartete Laufzeitrevision, Abhängigkeiten und benötigte
Ressourcen. Änderungen an diesen Werten erfolgen an dieser einen Stelle.
Swift validiert die Beschreibung und liest den vollständigen Ressourcensatz,
bevor es Arbeitsdateien auf dem Datenlaufwerk ersetzt. Fehlende Dateien,
Verknüpfungen, doppelte Namen und Pfade außerhalb des Ressourcenordners werden
abgelehnt. Ein Versionsvergleich allein ersetzt keine Prüfung der Laufzeitdateien.

## UI-Konventionen

- Hauptaktionen und aktueller Status bleiben sichtbar.
- Längere Erklärungen öffnen sich über benannte Hilfeschaltflächen.
- Warnungen vor Datenverlust und Lizenzentscheidungen bleiben bei der Aktion.
- Hilfe verändert keine Einstellung und startet kein Gastsystem.
- Diagnose und ausführliche Protokolle haben eine eigene Ansicht.
- Texte verwenden die bestehenden Sprachressourcen und deren Englisch-Fallback.
- Versionsangaben stammen aus dem App-Paket statt aus festen UI-Texten.

## Prüfung

Der private macOS-Build führt Swift-Tests, Grafik-/Ressourcentests, Metal-Tests
und den Starttest der verschobenen App aus. Die neue Laufzeitbeschreibung hat
Tests für unvollständige Belege, Versionskonflikte, ungültige Pfade und fehlende
Ressourcen. Windows-Spiele, echte Gastinstallationen und die visuelle Bedienung
auf dem eigenen Mac bleiben zusätzliche Beta-Tests.
