# Stratovo einrichten

**Anleitung zur Testversion 0.3.19** · macOS 14 oder neuer · Apple Silicon

Entwickelt von **PwnedG0blin** · [Projektübersicht](README.md) · [Fehler melden](https://github.com/PwnedG0blin/OpenGuest/issues/new/choose)

## 1. App und Datenordner vorbereiten

1. Laufende Android- oder Windows-Gäste regulär herunterfahren und die bisherige App schließen.
2. Die neue `Stratovo.app` nach **Programme / Applications** kopieren und dort öffnen. Die DMG danach auswerfen.
3. Beim ersten Start den Datenordner wählen. Auf einer externen SSD einen eigenen Ordner verwenden. Eine vorhandene Installation kann zum Beispiel `/Volumes/Extern/OpenGuest` weiterverwenden; für ein Update muss der Ordner nicht umbenannt werden.
4. Den gewählten Datenträger während der Nutzung angeschlossen lassen. Fehlt er, sperrt die App Gaststarts und Downloads.

SDK, Systemabbilder, Android-Nutzerdaten, Windows-Datenträger, Streaming-Komponenten, Protokolle und ausgewählte Installationsmedien liegen im eingerichteten Datenordner. Kleine App-Einstellungen und der gespeicherte Pfad bleiben intern; macOS verwaltet außerdem seine eigenen Caches und Auslagerungsdateien. Die Auswahl verlegt nicht automatisch Android Studio oder Homebrew.

Die Test-App ist noch nicht mit Apple Developer ID signiert oder notarisiert. Hinweise zu einer gezielten macOS-Startfreigabe stehen in [SIGNIERUNG.md](SIGNIERUNG.md).

## 2. Android 16 einrichten

1. **Downloads und Einrichtung** öffnen. Die angebotenen Android-Werkzeuge im gewählten Datenordner einrichten und die erforderlichen SDK-Lizenzen selbst bestätigen.
2. **Android 16 mit Google Play** vorbereiten. Ein passendes bestehendes Profil wird wiederverwendet; ein neues Profil erhält **64 GiB** virtuellen Datenspeicher.
3. Den angebotenen **Android-Videostream** einrichten.
4. **System prüfen**, das gewünschte Android-Profil wählen und Android ausdrücklich starten. Der Player öffnet sich in einem eigenen Fenster.
5. Im Android-Gast bei Google anmelden, danach Apps über Google Play oder **APK installieren …** installieren. Einzelne APKs werden unterstützt; XAPK/APKS gehören noch nicht dazu.

Apps, Konten und Spielstände bleiben lokal gespeichert. Eine zusätzliche Google-Sicherung oder Spielstandsynchronisierung funktioniert, soweit das jeweilige Spiel, die App und das Systemabbild sie unterstützen. Der externe Google-Login im Mac-Browser überträgt keine Anmeldung in den Android-Gast.

### Android 17 und Updates

Android 17 lässt sich unter **Downloads und Einrichtung** als **separates Profil** installieren. Dieses Profil hat eigene Apps und Konten; der Wechsel ist kein Upgrade des bestehenden Android-16-Datenträgers.

**Stable** ist der voreingestellte SDK-Kanal. Beta, Dev und Canary beziehen zusätzliche von Google angebotene SDK-Revisionen ein. Die tägliche Prüfung beim Öffnen lädt nichts herunter. Eine Aktualisierung vor dem Android-Start ist optional und erfolgt nur bei ausgeschalteten Gästen, anschließend mit Kaltstart. Das ist keine Registrierung im Pixel-Betaprogramm.

### Android-Anzeige und Trackpad

- **Bild einpassen** nutzt die verfügbare Playerfläche. **Telefonfenster** passt das Fenster an Seitenverhältnis und Bildschirmhöhe an.
- Unter **Android-Auflösung …** Breite, Höhe und Dichte wählen. Das S26-Ultra-Displayprofil nutzt 1440 × 3120 Pixel mit anpassbaren 500 dpi. Es verändert die Anzeige, nicht die Gerätefirmware. Größere dpi machen Bedienelemente bei gleicher Auflösung größer.
- **Scrolltempo** und **Trackpad-Nachlauf** lassen sich im Player ändern und werden getrennt von Windows gespeichert. **Wischen wie am Handy** überträgt Zwei-Finger-Bewegungen als Touch-Wischen im Android-Gast.
- Zum Einfügen Text am Mac kopieren, im Gast das Ziel antippen und **Text einfügen …** oder **⌘V** verwenden. Die Vorschau prüfen und bestätigen. Innere Zeilenumbrüche erfordern eine eigene Freigabe; es wird kein zusätzliches Enter angehängt.

### Bei Ruckeln oder Verbindungsproblemen

Zuerst **Bild einpassen** und ein kleineres Streaming-/Leistungsprofil testen. Hohe Gastauflösung und Software-Rendering können die Last erhöhen. Im ausgeschalteten Zustand lässt sich **Mac-GPU bevorzugen** wählen und Vulkan für einen OpenGL-ES-Kompatibilitätstest ausschalten. Änderungen am Renderer gelten beim nächsten Start.

**Anzeige neu verbinden** startet nur den Videostream neu; Android und laufende Downloads bleiben aktiv. Bei `device offline` den Gast herunterfahren und **Android-Verbindung reparieren** verwenden. Die Aktion startet ADB neu und aktiviert den Kaltstart; dadurch werden auch andere ADB-Debugverbindungen auf dem Mac getrennt.

## 3. Windows ARM64 einrichten

1. QEMU, `qemu-img` und `swtpm` auf dem Mac installieren. Bei bereits eingerichtetem Homebrew ist dies beispielsweise mit `brew install qemu swtpm` möglich.
2. In Stratovo **System prüfen** und die fehlenden Komponenten ergänzen. Für Windows 11 werden geeignete ARM64-UEFI-Firmware und passende UEFI-Variablen benötigt. Eine gewöhnliche `edk2-aarch64-code.fd` ist nicht automatisch ein geeigneter Secure-Boot-Build.
3. Im Windows-Speicherbereich einen Ordner anlegen und die gewünschte virtuelle Kapazität wählen. Die QCOW2-Datei wächst mit der Nutzung. Bestehende Datenträger können bei ausgeschaltetem Gast vergrößert, aber nicht verkleinert werden; zusätzlichen Platz anschließend in Windows zuordnen.
4. **DVD-ISO manuell auswählen …** anklicken und eine eigene offizielle **Windows-ARM64-ISO** wählen. Den angezeigten vollständigen Pfad prüfen. Die Dateiprüfung allein bestätigt weder Architektur noch Bootfähigkeit.
5. Unter **Downloads und Einrichtung** die Windows-Treiber beziehen und deren eigene ISO als **ARM64-Treiber-ISO** auswählen. Windows- und Treiber-ISO sind unterschiedliche Dateien. Treiber werden anschließend im Gast installiert.
6. Die gewünschte Einrichtung wählen. Die Option **Lokales Windows-Konto** bereitet ein lokales Konto vor; das tatsächliche Verhalten hängt vom gewählten Windows-Installationsabbild und Setup ab. Die vollständige Windows-Ersteinrichtung erfolgt im Player. Eine passende Windows-Lizenz ist separat erforderlich.
7. Den ausdrücklich gewählten DVD-Start ausführen. Nach dem Prozessstart wird für den nächsten Start wieder der gespeicherte Datenträger vorgemerkt; die ISO-Auswahl bleibt erhalten. Nach der Installation **Vorhandenes Windows starten** verwenden.

Die App prüft nach dem Start den QEMU-Zustand und die tatsächlich verbundene Installations-DVD. Eine erfolgreiche Geräteprüfung ist noch kein Nachweis, dass die komplette Installation auf dem Ziel-Mac funktioniert.

### Windows-Anzeige und Eingabe

Zunächst die **Basisgrafik** verwenden. Für die optionale **Virtio-GPU** zuerst passende ARM64-Grafiktreiber von der Treiber-CD in Windows installieren, dann Windows herunterfahren und den Grafikmodus ändern. Auflösung und Skalierung hängen von den angebotenen Gasttreibermodi ab. Bei schwarzem Bild ausgeschaltet wieder Basisgrafik wählen. Beschleunigte Windows-3D-Grafik ist nicht enthalten.

Das **Scrolltempo** ist im Windows-Player separat einstellbar. Der aktuelle Windows-Pfad überträgt vertikale Mausradschritte. Zum Einfügen das Ziel im Gast anklicken, **Text einfügen …** oder **⌘V** wählen und die tatsächliche Windows-Tastaturbelegung angeben. Nicht unterstützte Zeichen werden vor der Übertragung abgelehnt. Ein kopierter Befehl wird nicht durch ein zusätzliches Enter ausgeführt.

Mit **Benutzername und Kennwort sicher merken** speichert die App ihre Einrichtungshilfe im macOS-Schlüsselbund. Falls macOS eine Freigabe verlangt, **Aus Schlüsselbund laden** verwenden. Diese Einstellung ändert kein bereits bestehendes Windows-Konto. Temporäre Einrichtungsmedien werden nach regulärem Sitzungsende entfernt; nach einem Absturz können Reste zurückbleiben. Details stehen in [SECURITY.md](SECURITY.md).

## 4. Bestehende Daten auf eine externe SSD übernehmen

1. Gäste, Stratovo, Android Studio und laufende Einrichtungsskripte beenden.
2. In der Speicherorteinrichtung den gewünschten SSD-Ordner wählen und **Speicherort einrichten und Daten übernehmen** ausführen. Die Inhaltsprüfung bei großen Datenbeständen abwarten.
3. Die App übernimmt erkannte Standardordner und ausdrücklich ausgewählte Installationsmedien. Quellen werden beim Kopieren nicht gelöscht. Konflikte oder geänderte Dateien werden gemeldet.
4. Android und gegebenenfalls Windows im neuen Datenordner testen, anschließend wieder herunterfahren.
5. Unter **Daten und Speicherplatz** die erkannten internen Sicherungen prüfen. Erst nach Bestätigung des Funktionstests **Geprüfte interne Kopien endgültig entfernen …** verwenden. Geänderte Sicherungen oder fehlende Ziele blockieren die Bereinigung.

Dateien außerhalb der erkannten Standardpfade benötigen eine gesonderte Übernahme. Keine pauschale Löschung von Downloads, Homebrew, Xcode oder anderen App-Daten durchführen.

### Alte Android-Profile entfernen

Das funktionierende Android 16 auswählen und alle Gäste beenden. Unter **Alte Android-Profile und Daten bereinigen** zuerst die Liste erstellen und prüfen. Entfernt werden nur die aufgelisteten anderen Profile, nicht mehr benötigte Systemabbilder im gewählten Datenordner und erkannte alte Android-15-Sicherungen aus der Speichervergrößerung.

**Apps, Konten und Spielstände dieser alten Profile sowie die gelisteten Sicherungen werden endgültig gelöscht.** Das ausgewählte Android 16, Windows und Installationsmedien bleiben erhalten. Beim App-Start erfolgt keine automatische Löschung.

## 5. Aktualisieren, beenden und Fehler melden

Vor einem App-Update Gäste regulär herunterfahren und Stratovo schließen. Die App ersetzen und denselben Datenordner weiterverwenden. Das Schließen eines Playerfensters beendet den Gast nicht. **Prozess beenden** ist eine Notlösung; ungespeicherte Änderungen können verloren gehen.

Bei einem Fehler **Gesamtprotokoll exportieren** verwenden. Vor dem Teilen Namen, E-Mail-Adressen und Gerätekennungen entfernen. Im [Fehlerbericht](https://github.com/PwnedG0blin/OpenGuest/issues/new/choose) App-/macOS-Version, Gastsystem, Schritte und erwartetes Verhalten angeben. Bildschirmbilder und Passwörter gehören nicht automatisch zum Diagnoseexport; eigene Anhänge trotzdem auf private Inhalte prüfen.

[Historische Anleitungen](docs/ANLEITUNGEN_ARCHIV.md) · [Versionsarchiv](docs/CHANGELOG_ARCHIVE.md) · [Lizenz](LICENSE) · [Entwickler](AUTHORS.md)
