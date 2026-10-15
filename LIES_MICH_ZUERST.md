# OpenGuest 0.1.0 – erster Quellcode-Prototyp

Eine kostenlose Mac-App mit eigenem Android Player und Windows Player. Open Source unter MIT, ohne Abo. Zielplattform: Apple Silicon, macOS 14 oder neuer. Das ist ein Entwicklungsstand, keine bereits auf einem Mac geprüfte, fertig veröffentlichte Alternative zu MuMu oder VMware.

## Android zum ersten Mal einrichten

1. Xcode und **Android Studio für Apple Silicon** installieren. Android Studio einmal starten und den SDK einrichten. Im SDK Manager unter SDK Tools auch **Android SDK Command-line Tools (latest)** installieren.
2. **Android_einrichten.command** ausführen. Die Google-/SDK-Lizenzen selbst bestätigen. Das Skript lädt ein offizielles Android-15-ARM64-Abbild mit Google Play und erstellt das Gerät `OpenGuest_GooglePlay`. Bestehende Geräte werden nicht überschrieben.
3. **Android_Streaming_einrichten.command** ausführen. Es bezieht den genau passenden scrcpy-4.0-Server aus dem offiziellen Release und prüft den dort veröffentlichten SHA-256-Wert. Fehlt dieser, bricht es ab. Keine Installation eines beliebigen Ersatzpakets.
4. **Start.command** ausführen. Es führt zunächst die Swift-Tests aus, baut die lokale Test-App und öffnet sie. Sobald alle Voraussetzungen gefunden sind, startet Android im Android Player. Weitere Starts können über `dist/OpenGuest.app` erfolgen.

Alternativ kannst du `Package.swift` in Xcode öffnen und das Schema OpenGuest auf deinem Mac starten. Werden `.command`-Dateien nicht direkt gestartet, lassen sie sich im Terminal mit `bash ` und ihrem hineingezogenen Pfad ausführen. Gatekeeper oder andere Mac-Schutzfunktionen nicht abschalten.

## Google und APKs

Im Android Player: **Google-Konto hinzufügen**. Die Anmeldung erfolgt direkt bei Google im Android-Gast. Danach **Play Spiele** öffnen/installieren und dort dasselbe Konto wählen, das deine Spiele verwenden. Die Buttons **Kontosynchronisierung** und **Android-Sicherung** öffnen die entsprechenden Android-Einstellungen; du bestätigst selbst, was synchronisiert wird.

**APK installieren …** installiert eine einzelne APK in genau dem gestarteten Android-Gerät. Die Schaltfläche wird erst nach dem Android-Boot aktiv. Split-Pakete wie XAPK/APKS werden noch nicht unterstützt.

Apps, Konten, Dateien und Spielstände bleiben lokal im AVD gespeichert. Google-Cloud-Spielstände und Backups sind zusätzlich möglich, **wenn das jeweilige Spiel, die App und das Systemabbild sie unterstützen**. Kein Emulator kann für jede App eine Synchronisierung erzwingen. Google-Anmeldung, Gerätezertifizierung, Play Integrity und Spielekompatibilität müssen auf dem Zielsystem getestet werden.

## Windows 11 Pro Arm64

Windows ist eine eigene, dauerhaft gespeicherte VM im Windows Player. Beim ersten Start installierst du Windows aus einer selbst bezogenen offiziellen **Arm64-ISO**. Die Pro-Edition wird über ein zusätzliches Einrichtungsmedium vorausgewählt; falls Setup trotzdem fragt, Windows 11 Pro wählen. Eine passende Windows-Lizenz ist separat erforderlich.

- QEMU und swtpm separat installieren, beispielsweise mit `brew install qemu swtpm`, wenn Homebrew bereits eingerichtet ist.
- In OpenGuest unter Einrichtung QEMU und die passende ARM64-UEFI-Firmware auswählen. Für Windows 11 sind geeignete Secure-Boot-fähige Firmware und dazu passende UEFI-Variablen erforderlich. **Die normale QEMU-Datei `edk2-aarch64-code.fd` ist nicht automatisch ein geeigneter Secure-Boot-Build.** Eine existierende passende Firmware kann ausgewählt werden; dieses Paket enthält und erzeugt sie nicht. Das ist vor einem vollständigen Windows-Test noch zu klären.
- Windows-Arm64-ISO und optional eine ARM64-Gasttreiber-ISO wählen. Bei Netzwerkbedarf den VirtIO-Netzwerktreiber laden. Die Treiber-ISO allein installiert in OpenGuest noch keine Treiber automatisch.
- Optional **Lokales Windows-Konto** aktivieren, eigenen Benutzernamen und Passwort eingeben. Kein vorgeschriebenes Microsoft-Konto. Region, Tastatur und weitere Ersteinrichtung bleiben interaktiv.
- **Windows einrichten** starten. OpenGuest erstellt eine zunächst kleine, mit der Nutzung wachsende virtuelle 80-GB-Festplatte. Es wird keine echte Mac-Festplatte an Windows durchgereicht.
- Nach abgeschlossener Installation **Windows installieren · ISO einlegen** ausschalten. Künftige Starts verwenden die gespeicherte Windows-Festplatte.

Bei Ende einer normalen Sitzung wird nur das temporäre Einrichtungsmedium mit den Kontoangaben entfernt. Windows-Festplatte, UEFI-Variablen und TPM bleiben erhalten. Nach einem Absturz können temporäre Setup-Dateien zurückbleiben. Während einer unterbrochenen Installation können die Angaben beim nächsten Installationsstart erneut nötig sein.

## Stabilität und Tempo

Bitte zuerst **Herunterfahren** verwenden. **Prozess beenden** ist die bestätigungspflichtige Notlösung und kann ungespeicherte Änderungen verlieren. Die App überschreibt keine bestehenden Geräte und enthält keine automatische Datenbereinigung.

Android: ARM64-CPU mit Hypervisor.framework, Grafikmodus auto/host, H.264-Stream mit Ziel 60 FPS über scrcpy und native Mac-Videodarstellung. Die Anzeige zählt empfangene Videoframes pro Sekunde, keine intern berechneten Spiele-FPS. Das tatsächliche Tempo wurde noch nicht gemessen. Ton kann aktuell über den Android Emulator ausgegeben werden, wird aber nicht im Streaming-Modul transportiert; das ist noch zu testen.

Windows: ARM64-CPU mit HVF, einfacher Framebuffer und eigener lokaler Player. Beschleunigte Windows-3D-Grafik, Audio, komfortable Treiberinstallation, Zwischenablage, Multitouch und Spiele-Tastenbelegung sind noch nicht implementiert. Auf dem 16-GB-Mac startet jeweils ein Gast; für den Wechsel den bisherigen Gast herunterfahren.

**Prüfstand:** Swift-Dateien wurden syntaktisch geprüft, Shell-Skripte geprüft und Paketmetadaten kontrolliert. In dieser Arbeitsumgebung gibt es kein macOS/Xcode: Der native Build, Swift-Tests, Android-Start, Google-Anmeldung, Windows-Installation/OOBE und Leistungstests sind **noch nicht ausgeführt**. Ein macOS-CI-Workflow und ein Testplan liegen bei. Keine Behauptung „absturzfrei“ oder „so schnell wie MuMu“.

## Frei verfügbar

Der komplette eigene Quellcode liegt im ZIP und darf nach MIT weitergegeben und verändert werden. OpenGuest kostet nichts und hat kein Abo. Dieses Paket ist noch kein öffentlich angelegtes GitHub-Repository und keine signierte/notarisierte Download-App. Google-/Microsoft-Systemdateien und fremde Engines behalten ihre eigenen Lizenzbedingungen; Windows selbst wird dadurch nicht kostenlos.

Der vorbereitete GitHub-Workflow „Build macOS test app“ kann nach Einrichtung eines Repositorys auf einem Apple-Silicon-Mac testen, kompilieren und eine `.app.zip` als Build-Artefakt bereitstellen. Er wurde noch nicht gestartet. Das wäre zunächst die kompilierte Test-App; Engines und Betriebssysteme müssten weiterhin separat eingerichtet werden. Ein vollständiger Installer mit komfortabler Ersteinrichtung ist noch nicht fertig.
