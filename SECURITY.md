# Sicherheit und Datenhaltung

**Pixelkoje · öffentliche Testversion** · Entwickelt von **PwnedG0blin**

Diese Seite beschreibt die derzeitige Umsetzung und ihre Grenzen. Automatisierte Builds und Tests sind kein unabhängiges Sicherheitsaudit und keine Garantie gegen Abstürze oder Datenverlust.

## Gastdaten und Prozesse

Android-Nutzerdaten sowie Windows-Datenträger, UEFI-Variablen und TPM-Zustand bleiben zwischen Sitzungen gespeichert. Die App setzt diese Daten beim normalen Start nicht zurück. Reguläres Herunterfahren reduziert das Risiko ungespeicherter Änderungen; erzwungenes Beenden oder ein Host-/Gastabsturz kann Daten verlieren. Automatische vollständige Gast-Backups sind nicht enthalten.

Die Prozesse laufen mit den Rechten des angemeldeten Mac-Benutzers. Ein privilegierter Hilfsdienst, automatische Host-Ordnerfreigaben, Telemetrie und ein öffentlicher VNC-Listener sind nicht implementiert. Der Windows-Player verwendet eine lokale Verbindung. APKs werden im ausdrücklich ausgewählten Gast installiert.

## Konten, Zwischenablage und Einrichtung

Google-Zugangsdaten werden im Android-Gast eingegeben. Ein im Mac-Browser geöffnetes Google-Konto überträgt keine Gastanmeldung.

Auf Wunsch gespeicherte Windows-Einrichtungsdaten liegen im macOS-Schlüsselbund; Kennwörter werden nicht in normalen App-Einstellungen oder Diagnoseprotokollen gespeichert. Für eine Installation können sie außerdem vorübergehend in privaten Einrichtungsmedien enthalten sein. Deren Codierung ist umkehrbar und keine Verschlüsselung. Normales Sitzungsende entfernt das temporäre Medium; nach einem Absturz können Dateien zurückbleiben.

Die Mac-Zwischenablage wird beim ausdrücklichen Öffnen der Einfügefunktion beziehungsweise bei ⌘V gelesen. Textübertragungen werden nicht protokolliert oder dauerhaft gespeichert. Die Vorschau erfordert eine Bestätigung, innere Zeilenumbrüche eine zusätzliche Freigabe.

## Downloads und Verteilung

Der scrcpy-Server wird getrennt aus der festgelegten offiziellen Version bezogen, anhand der veröffentlichten SHA-256-Metadaten geprüft und vor Nutzung erneut geprüft. Das ersetzt keine Prüfung sämtlicher Abhängigkeiten. Änderungen am Server und am Protokoll müssen zusammenpassen.

Die Test-App ist ad-hoc signiert und noch nicht mit Apple Developer ID signiert oder notarisiert. [SIGNIERUNG.md](SIGNIERUNG.md) beschreibt den vorgesehenen Verteilungsweg. Gatekeeper und SIP nicht systemweit deaktivieren.

## Ein Problem melden

Allgemeine Fehler über die [Issues](https://github.com/PwnedG0blin/OpenGuest/issues/new/choose) melden. Namen, E-Mail-Adressen, Gerätekennungen, Schlüssel und Zugangsdaten vorher aus Protokollen und Anhängen entfernen.

Für eine mögliche Sicherheitslücke keine ausnutzbaren Details oder privaten Daten öffentlich posten. Falls GitHub für dieses Repository **Report a vulnerability** anbietet, diesen privaten Meldeweg verwenden. Andernfalls zunächst ohne sensible Details nach einem geeigneten privaten Meldeweg fragen. Ein eingerichteter privater Kanal oder eine feste Reaktionsfrist wird derzeit nicht zugesagt.
