# Neu in 0.3.4: Hauptfenster ohne Gast-Autostart

Beim Öffnen von OpenGuest erscheint nur das Hauptfenster. Android und Windows starten ausschließlich über ihre Start-Schaltflächen. Auch eine früher gespeicherte Android-Autostart-Einstellung wird nicht mehr verwendet; die Option wurde entfernt. Erst der manuelle Gaststart öffnet das eigene frei skalierbare Playerfenster. Playerfenster werden nicht über die macOS-Fensterwiederherstellung automatisch geöffnet. Die neue Google-Kontoauswahl im externen Mac-Browser aus 0.3.3 ist enthalten.

# Neu in 0.3.3: Google im normalen Mac-Browser

Im Android-Bereich öffnet „Google im Mac-Browser öffnen“ die offizielle Google-Kontoauswahl über den macOS-Standardbrowser. Der Browser verwendet seine normale Sitzung und sein vorhandenes Profil; OpenGuest öffnet keine eingebettete Webseite oder private Anmeldesitzung. Gespeicherte Konten und Zugangsdaten stehen nur zur Verfügung, soweit sie im geöffneten Browserprofil vorhanden sind. OpenGuest liest keine Browserpasswörter, Cookies oder Google-Tokens aus und erkennt den Browser-Anmeldestatus nicht.

Diese Funktion ist eine externe Google-Webanmeldung, keine Übergabe eines Kontos an den Android-Emulator. Für Google Play, Kontosynchronisierung und Cloud-Spielstände weiterhin „Google-Konto in Android hinzufügen“ verwenden und die Anmeldung im Gastsystem abschließen. Eine automatische Übernahme einer Mac-Browser-Anmeldung in Android ist nicht implementiert. Google beschreibt Desktop-OAuth und Android-Systemkonten als eigene Abläufe: https://developers.google.com/identity/protocols/oauth2/native-app ; https://developer.android.com/reference/android/accounts/AccountManager .

# Neu in 0.3.2: Windows-Kontodaten

Windows-Benutzername, Passwortlänge und Passwortwiederholung werden unmittelbar im Formular getrennt geprüft. Die Zeichenanzahl beider Passwortfelder ist sichtbar; das Passwort bleibt verdeckt. „Windows einrichten“ wird erst mit gültigen Kontodaten freigegeben. Bei Start- und Vorbereitungsfehlern bleiben beide Eingaben erhalten. Nach erfolgreichem Prozessstart werden sie aus dem Formular entfernt.

Der Benutzername bleibt wie bisher in den App-Einstellungen erhalten. Mit „Im Schlüsselbund speichern“ speicherst du auf Wunsch Benutzername und Passwort im macOS-Schlüsselbund, getrennt nach OpenGuest-Datenordner. „Aus Schlüsselbund laden“ stellt beide Passwortfelder wieder her, auch nach erneutem App-Start. OpenGuest liest nur seinen eigenen Schlüsselbund-Eintrag auf ausdrücklichen Klick; macOS kann um Zugriffserlaubnis bitten. Das ist eine lokale Einrichtungshilfe: Das eigentliche Windows-Konto entsteht während der Windows-Installation und bleibt danach im Gastsystem bestehen. Eine spätere Änderung des gespeicherten Eintrags ändert kein bereits eingerichtetes Windows-Konto. Die kleine Schlüsselbund-Ablage liegt auf dem Mac, die VM bleibt am gewählten Datenort.

# Neu in 0.3.1: Downloads direkt im Programm

Unter Einrichtung die gewünschten Komponenten auswählen und „Auswahl laden und einrichten“ starten. Ziel ist ausschließlich der eingerichtete OpenGuest-Datenordner. Android SDK-Werkzeuge, Java falls nötig, Emulator, Android-15-Google-Play-ARM64-Systemabbild, Streaming-Modul und Windows-Treiber-ISO werden dort heruntergeladen und eingerichtet. Entpackdateien und Java-Temporärdateien liegen ebenfalls dort. Die App verweigert den Download bei fehlendem Datenträger oder zu wenig freiem Platz. Vorhandene Komponenten werden wiederverwendet; eigene ISO-Dateien werden bei Bedarf kopiert und byteweise geprüft, ihre Originale bleiben erhalten.

Google-SDK-Bedingungen vor dem Download der Werkzeuge lesen und bestätigen. Weitere Android-SDK-Lizenzen erscheinen im integrierten Protokoll und werden mit den dort eingeblendeten Schaltflächen beantwortet. Kein Terminal nötig. SDK-Tools und Java werden gegen offizielle SHA-256-Prüfwerte geprüft; scrcpy gegen den Digest des offiziellen Releases. Downloads laufen über HTTPS. Windows- und Treiber-ISOs werden zusätzlich auf ein ISO-Format geprüft; eine solche Formatprüfung ist kein Echtheits- oder Architekturbeweis.

Windows-ISO: Vorhandene ARM64-ISO im Windows-Bereich auswählen oder auf der verlinkten Microsoft-Seite Sprache und ARM64-Download wählen, den direkten Downloadlink kopieren und in die App einfügen. OpenGuest lädt direkt auf den gewählten Datenträger und übernimmt den Pfad. Der Microsoft-Link ist zeitlich befristet. Windows-Lizenz und Ersteinrichtung bleiben erforderlich.

QEMU und swtpm werden weiterhin aus einer vorhandenen Mac-Installation verwendet; ihr automatischer Download/ihre Installation sind noch nicht implementiert. Die Einrichtungsseite zeigt Status, Quellenlinks und Auswahlschaltflächen. Eine geeignete Secure-Boot-fähige ARM64-Firmware muss weiterhin vorhanden sein. Android Studio ist für den neuen SDK-Download nicht mehr nötig; sein vorhandenes Java wird wiederverwendet. Python 3 aus den Xcode Command Line Tools wird für die Prüfung der scrcpy-/Java-Release-Metadaten benötigt. Kleine App-Einstellungen und Betriebssystemdateien können weiterhin intern liegen.

Offizielle Quellen: https://developer.android.com/studio ; https://developer.android.com/tools/sdkmanager ; https://adoptium.net/temurin/releases/ ; https://github.com/Genymobile/scrcpy ; https://docs.getutm.app/guest-support/windows/ ; https://www.microsoft.com/de-de/software-download/windows11arm64

# Neu in 0.3.0

Android und Windows öffnen beim Start jeweils ein eigenes Playerfenster. Du kannst es frei vergrößern, verkleinern und als Vollbild anzeigen; das Bild und die Eingabekoordinaten passen sich mit erhaltenem Seitenverhältnis an. „Player öffnen“ zeigt ein geschlossenes Fenster erneut. Das Schließen eines Playerfensters lässt den Gast weiterlaufen; zum Ausschalten „Herunterfahren“ verwenden. Beide Player bleiben getrennte Bereiche; weiterhin kann ein Gastsystem gleichzeitig laufen. Die Fenstergröße ändert die Darstellung, nicht automatisch die Auflösung im Gastsystem.

Die Windows-Prüfung und der Startbefehl verwenden jetzt das von QEMU für ARM-virt dokumentierte TPM-Gerät `tpm-tis-device` anstelle von `tpm-crb-device`. Das behebt die fälschliche TPM-Sperre bei passenden QEMU-Builds. Quelle: https://www.qemu.org/docs/master/specs/tpm.html . Ein vollständiger Windows-Installationsdurchlauf ist weiterhin auf dem Ziel-Mac zu prüfen.

# Lesbarkeit in 0.2.2

Der Speicherort-Dialog zeigt Texte, Pfad und Status mit größerer Schrift und hohem Kontrast. Fehler werden in einem farblich abgesetzten Bereich mit eigener Überschrift angezeigt. Lange Meldungen lassen sich scrollen und kopieren. Die Korrektur der Kopierprüfung aus 0.2.1 ist enthalten.

# Korrektur in 0.2.1

Bei „Kopierprüfung fehlgeschlagen: sdk“ in 0.2.0: alte App beenden, 0.2.1 installieren und denselben Datenordner (Extern/OpenGuest) erneut wählen. Bereits passende Dateien werden geprüft und wiederverwendet. Zusätzliche Zieldateien, etwa AppleDouble-/Finder-Metadaten, bleiben erhalten und blockieren die Prüfung nicht mehr. Jede Datei aus der Quelle wird weiterhin auf Typ und SHA-256-Inhalt geprüft; echte Unterschiede werden mit Dateipfad gemeldet. Originale werden beim Kopieren nicht gelöscht.

# OpenGuest 0.2.0 – Speicherort und Umzug

Beim ersten Start dieser Version (auch nach 0.1) wählst du den Datenordner. Wähle auf dem Mac im Dialog die externe SSD **Extern**. OpenGuest legt dort **OpenGuest** an.

1. Android/Windows herunterfahren, die alte OpenGuest-App und Android Studio sowie laufende Einrichtungsskripte beenden.
2. Neue App nach Programme kopieren und von dort öffnen. Die DMG danach auswerfen.
3. Ordner **Extern** wählen → **Speicherort einrichten und Daten übernehmen**. Kopieren und SHA-256-Prüfung können bei großen Geräten dauern. SSD währenddessen angeschlossen lassen.
4. Bisherige Standardordner für SDK, Android-Geräte, Windows-Festplatte/TPM, Streaming und Protokolle werden übernommen. In OpenGuest ausgewählte Windows-/Treiber-ISOs aus Downloads werden ebenfalls übernommen. Kompatibilitäts-Verknüpfungen halten bisherige Android-Studio- und AVD-Pfade gültig.
5. Unter Einrichtung **System prüfen**, dann bei Android bevorzugt **OpenGuest_GooglePlay** wählen. Falls es fehlt: **Android vorbereiten …**, anschließend **Videostream einrichten …**.
6. Nach erfolgreichem Test Gast herunterfahren und Android Studio beenden. Unter **Einrichtung → Daten und Speicherplatz** die gelisteten internen Sicherungen kontrollieren, den Test bestätigen und **Geprüfte interne Kopien endgültig entfernen …** wählen. Erst dabei wird interner Platz frei; die aktiven SSD-Daten bleiben erhalten. Geänderte Sicherungen oder fehlende Ziele blockieren die Bereinigung.

Auf Extern liegen SDK/Systemabbilder, Android-Apps/Spielstände, Windows-Datenträger/TPM, Streaming, Protokolle sowie die ausgewählten Installations-ISOs. Ein kleiner Pfadzeiger und App-Einstellungen bleiben intern. Die Mac-App, Android Studio, Homebrew/QEMU und macOS-Caches/Auslagerungsdateien werden nicht automatisch verschoben oder gelöscht. Keine pauschale Bereinigung von Downloads, Xcode oder Homebrew.

### Windows-Treiber

Unter Einrichtung **Windows-Treiber laden …**. Das Skript lädt die offizielle UTM-Guest-Tools-ISO direkt nach **OpenGuest/Installationsmedien/utm-guest-tools.iso**. Diese ISO bei **ARM64-Treiber-ISO** auswählen. Bei **Windows-Arm64-ISO** die echte Microsoft-ISO verwenden. Identische Dateien in beiden Feldern werden als Fehler erkannt. Die Treiber enthalten ARM64-Unterstützung; Einbindung, Installation und Kompatibilität mit OpenGuest müssen weiterhin im Gast getestet werden. Die vollständige SPICE-Integration von UTM ist nicht Bestandteil von OpenGuest.

QEMU, swtpm, qemu-img und geeignete ARM64-UEFI-Firmware samt passenden Variablen werden weiterhin separat benötigt. Die Systemprüfung nennt fehlende Komponenten genauer. Normale Homebrew-UEFI-Dateien garantieren kein Secure Boot; Windows-Installation bleibt ein noch nicht vollständig getesteter Prototyp. Windows-Lizenz erforderlich. Nicht behauptet: fertiges Windows-System oder MuMu-Leistung.

### Grenzen und Sicherheit

SDK und virtuelle Geräte sind getrennte Datenbereiche. Eine SDK-Auswahl allein lagert Spielstände nicht aus. Bei fehlender SSD werden Gäste und Einrichtungsskripte gesperrt; es wird kein interner Ersatzordner angelegt. Bei Konflikten bleiben Quellen erhalten. Vorhandene Daten außerhalb der Standardpfade werden nicht automatisch übernommen; dafür zuerst eine gesonderte Migration planen.

Google-Konto, Synchronisierung und Cloud-Spielstände funktionieren nur, soweit offizielles Abbild und jeweilige App sie unterstützen. Keine Garantie für jedes Spiel oder Play Integrity. Die App ist ad-hoc signiert und nicht Apple-notarisiert.

## Hinweise aus Version 0.1

# OpenGuest 0.1.0 – erster Quellcode-Prototyp

Eine kostenlose Mac-App mit eigenem Android Player und Windows Player. Open Source unter MIT, ohne Abo. Zielplattform: Apple Silicon, macOS 14 oder neuer. Das ist ein Entwicklungsstand, keine fertig veröffentlichte Alternative zu MuMu oder VMware. Der native Mac-Build und die 13 Unit-Tests sind inzwischen im GitHub-Build erfolgreich.

## Android zum ersten Mal einrichten

1. Xcode und **Android Studio für Apple Silicon** installieren. Android Studio einmal starten und den SDK einrichten. Im SDK Manager unter SDK Tools auch **Android SDK Command-line Tools (latest)** installieren.
2. **Android_einrichten.command** ausführen. Die Google-/SDK-Lizenzen selbst bestätigen. Das Skript lädt ein offizielles Android-15-ARM64-Abbild mit Google Play und erstellt das Gerät `OpenGuest_GooglePlay`. Bestehende Geräte werden nicht überschrieben.
3. **Android_Streaming_einrichten.command** ausführen. Es bezieht den genau passenden scrcpy-4.0-Server aus dem offiziellen Release und prüft den dort veröffentlichten SHA-256-Wert. Fehlt dieser, bricht es ab. Keine Installation eines beliebigen Ersatzpakets.
4. **Start.command** ausführen. Es führt zunächst die Swift-Tests aus, baut die lokale Test-App und öffnet sie. Danach Android oder Windows auswählen und ausdrücklich über die Start-Schaltfläche starten. Weitere Starts können über `dist/OpenGuest.app` erfolgen.

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

**Prüfstand:** Swift-Dateien wurden syntaktisch geprüft, Shell-Skripte geprüft und Paketmetadaten kontrolliert. In dieser Arbeitsumgebung gibt es kein macOS/Xcode: Der native ARM64-Mac-Build und alle 13 Swift-Tests sind im GitHub-Build **erfolgreich ausgeführt**. Android-Start, Google-Anmeldung, Windows-Installation/OOBE und Leistungstests sind weiterhin offen. Ein macOS-CI-Workflow und ein Testplan liegen bei. Keine Behauptung „absturzfrei“ oder „so schnell wie MuMu“.

## Frei verfügbar

Der komplette eigene Quellcode liegt im ZIP und darf nach MIT weitergegeben und verändert werden. OpenGuest kostet nichts und hat kein Abo. Der Quellcode liegt öffentlich auf https://github.com/PwnedG0blin/OpenGuest. Die Test-App ist lokal/ad-hoc signiert, aber noch nicht mit Developer ID signiert oder Apple-notarisiert. Google-/Microsoft-Systemdateien und fremde Engines behalten ihre eigenen Lizenzbedingungen; Windows selbst wird dadurch nicht kostenlos.

Der vorbereitete GitHub-Workflow „Build macOS test app“ kann nach Einrichtung eines Repositorys auf einem Apple-Silicon-Mac testen, kompilieren und eine `.app.zip` als Build-Artefakt bereitstellen. Der erste Build ist erfolgreich abgeschlossen. Das wäre zunächst die kompilierte Test-App; Engines und Betriebssysteme müssten weiterhin separat eingerichtet werden. Ein vollständiger Installer mit komfortabler Ersteinrichtung ist noch nicht fertig.
