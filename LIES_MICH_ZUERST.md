# Stratovo 1.0 Beta 5 einrichten

Entwickelt von **PwnedG0blin** · macOS 14+ · Apple Silicon.

## App und Datenordner

1. Alle Gäste herunterfahren und die bisherige App schließen.
2. Die neue Stratovo.app unter Programme installieren und dort starten.
3. Beim ersten Start SSD oder Datenordner wählen. Bestehende Installationen verwenden
   denselben Ordner weiter; ein Update verschiebt oder löscht keine Gastdaten.
4. Der gewählte Datenträger muss während der Nutzung angeschlossen bleiben.

Kleine Einstellungen, der Speicherort-Verweis und der Schlüsselbund bleiben intern.
SDKs, Gastdatenträger, Grafikwerkzeuge und Ubuntu liegen im gewählten Datenordner.
Homebrew, Xcode und macOS können zusätzlich internen Speicher benötigen.

## Android

Unter **Android** die Werkzeuge und den Videostream einrichten, Google-Lizenzen
bestätigen und Android 16 installieren oder ein bestehendes ARM64-Profil wählen.
Android 17 ist ein getrenntes optionales Profil. Android starten öffnet den Player.

Im Player findest du Auflösung, Dichte, Bildrate bis 90 FPS, Scrolltempo,
Touch-Wischen und Text einfügen. Apps, Konten und lokale Spielstände bleiben gespeichert.
Android-17-Datenübernahme erstellt eine eigene Kopie; es gibt keine laufende Synchronisierung.
Google-Beta-Programme für physische Pixel-Geräte sind davon getrennt.

## Windows – jetzt mit 3D im bisherigen Player

1. QEMU, qemu-img und swtpm einrichten; **System prüfen** verwenden.
2. Unter **Windows → 3D-Player vorbereiten / aktualisieren** die Grafiklaufzeit vorbereiten.
   Der erste Bau benötigt vollständiges Xcode mit Metal-Werkzeugen und weitere
   angezeigte Bibliotheken. Der Grafikbau unterstützt derzeit Datenpfade ohne Leerzeichen.
3. Eine bereits funktionierende Grafiklaufzeit wird gezielt um den eingebetteten Player
   ergänzt. ANGLE und LLVM werden dabei weiterverwendet; es entsteht keine Windows-Kopie.
4. **Vorhandenes Windows starten** verwendet dieselbe bisherige Windows-Festplatte,
   Konten, Dateien, NVRAM, TPM und Gerätekennung. Der Grafikmodus ist nun 3D über Metal.
5. Falls der Grafiktreiber noch fehlt: **Explorer → Dieser PC → DVD PKGRAPHICS →
   INSTALL_GRAPHICS.cmd** innerhalb von Windows ausführen, herunterfahren und erneut starten.

Für eine neue Installation den Windows-Ordner anlegen, eine offizielle ARM64-ISO wählen,
Festplattengröße und RAM/CPU einstellen und **Nächster Start: Windows von DVD einrichten**
aktivieren. Pro-Vorauswahl, lokales Konto und Netzwerk bleiben verfügbar. Eine passende
Windows-Lizenz ist erforderlich. Die Installations- und Treiber-ISOs sind verschiedene Dateien.

Im Player bleiben **Text einfügen / ⌘V**, Tastaturbelegung, Scrolltempo, Vollbild,
Ansicht und Einrichtungskonsole verfügbar. Auflösung und Windows-Skalierung unter
**System → Anzeige** ändern. **Esc beim Einschalten** öffnet das **UEFI-/BIOS-Menü**.
Das erkannte Firmwarelogo wird ausschließlich im Player ersetzt; die Firmware bleibt unverändert.

Die frühere GraphicsLab/TestVM bleibt erhalten. Sie wird nicht automatisch mit der
bisherigen Hauptinstallation zusammengeführt. Vor deren Entfernung eigene Dateien prüfen.

## Ubuntu ARM

1. **Ubuntu ARM → 1 · Ubuntu ARM herunterladen** wählen. Das offizielle Ubuntu
   26.04.1-LTS-ARM64-Abbild wird geladen und mit der festen SHA-256-Prüfsumme geprüft.
2. **2 · Ubuntu installieren** wählen. Der Installer läuft im Stratovo-Player.
3. Im Installer ausschließlich die virtuelle 64-GiB-Festplatte verwenden. Sie liegt
   im eigenen Unterordner Ubuntu; Android und Windows sind nicht mit dieser VM verbunden.
4. Nach der Installation Ubuntu herunterfahren und **Ubuntu starten** wählen.
   Dieser Start verwendet die Festplatte ohne Installations-ISO.
5. Auflösung und Skalierung unter Ubuntu **Einstellungen → Anzeigegeräte** ändern.
   Text einfügen und Scrolltempo findest du im Player. Die gewählte Tastaturbelegung
   für Texteingaben muss mit der im Gast übereinstimmen.

## Speicherbedarf

| System / Werkzeuge | Einplanen |
| --- | --- |
| Android 16 | etwa 80 GiB |
| Android 17 | zusätzlich etwa 80 GiB |
| Windows | gewählte Festplattengröße + etwa 20 GiB |
| 3D-Werkzeuge | mindestens 30 GiB einmalig; keine zweite Windows-Festplatte |
| Ubuntu ARM | etwa 80 GiB; mindestens 40 GiB vor Installation, 6–8 GiB RAM |

Spiele, Sicherungen und Downloads benötigen zusätzlichen Platz. Virtuelle Festplatten
wachsen mit ihren Daten. Jeweils ein Gastsystem starten.

## Update, Aufräumen und Diagnose

Updates werden unter **Updates** ausdrücklich über GitHub geprüft und installiert.
Gäste vorher herunterfahren. Datenordner und Schlüsselbund bleiben erhalten.
[Aufräumliste](docs/AUFRAEUMEN.md) · [Änderungen](docs/RELEASE_1.0_BETA2.md)

Das Schließen des Players beendet den Gast nicht. Erst im Gast herunterfahren;
Prozess beenden ist eine Notlösung. Bei Problemen das Gesamtprotokoll exportieren
und vor Veröffentlichung auf persönliche Inhalte prüfen.

Die App ist lokal signiert, noch nicht Developer-ID-signiert oder notarisiert:
[SIGNIERUNG.md](SIGNIERUNG.md). Der neue eingebettete 3D-Pfad bleibt experimentell;
automatische Tests ersetzen keine längere Prüfung von Gast, Spielen und FPS auf dem M4.

[Projekt](README.md) · [Entwickler](AUTHORS.md) · [Fehler melden](https://github.com/PwnedG0blin/OpenGuest/issues/new/choose)

## Dateiaustausch · alle drei Gäste

Links **Dateiaustausch** wählen oder im Player oben auf **Dateiaustausch** klicken. Der Ordner **Austausch** liegt im gewählten Datenordner. Windows und Ubuntu nutzen nach einmaliger macOS-SMB-Freigabe denselben Ordner. Android kann ausgewählte Dateien senden und Dateien aus Downloads/Stratovo-Austausch in neue Importordner auf dem Mac abholen. Anleitung: [Dateiaustausch](docs/DATEIAUSTAUSCH.md).

## Schwarzes Windows-Bild nach dem Startlogo

Beta 3 ergänzt den klassischen OpenGL-Bildpfad und einen separaten CPU-Bildpuffer für VNC. Einmal **3D-Player vorbereiten / aktualisieren** ausführen. Es wird nur QEMU neu gebaut; die vorhandenen ANGLE-/LLVM-Bauten und Gastdatenträger bleiben erhalten. Falls der Fehler weiter auftritt, das aktuelle Windows-Startprotokoll beifügen. Ein erfolgreicher App-Bau allein bestätigt keinen funktionierenden Grafiktreiber im Gast.

## Windows Arm: direkte Grafik als Standard

Unter **Windows Arm → Windows-Bildausgabe** ist **Direktes Grafikfenster · Metal (Standard)** voreingestellt. Es öffnet dasselbe Windows im eigenen Grafikfenster ohne VNC-Bildkopien. Zum Einfügen von Text, zum Dateiaustausch und für UEFI-Tasten die Windows-Steuerung im Stratovo-Hauptfenster nutzen. Das Grafikfenster übernimmt seine eigene Maus-, Trackpad- und Vollbildsteuerung. Die eingebettete Ansicht bleibt eine experimentelle Option und kann bei ausgeschaltetem Windows gewählt werden. Für die neuen Fensterkorrekturen in Beta 5 einmal „3D-Player vorbereiten / aktualisieren“ wählen; nur QEMU wird neu gebaut.

## Beta 5: direktes Windows-Fenster aktualisieren

Windows herunterfahren und einmal **Windows Arm → 3D-Player vorbereiten / aktualisieren** wählen. Nur QEMU wird neu gebaut; ANGLE, LLVM und deine Gastsysteme bleiben erhalten. Danach lässt sich das direkte Fenster frei ziehen, maximieren und als Vollbild öffnen. Das Bild passt vollständig hinein; das Seitenverhältnis bleibt erhalten. Die Mausposition wird entsprechend umgerechnet. Das bekannte Firmware-Startlogo wird ausschließlich im Bild überdeckt.

## Steam download comparison (optional)

Under **Windows Arm → Steam-Download testen**, the **Windows-Schreiblimit** is
**Off** by default. Shut down Windows, select **40 MiB/s**, then start Windows
and resume the same download for comparison. Available limits: 20, 40, 80 MiB/s.
The limit affects **all writes to the Windows system disk**, not just Steam;
installations may take longer. Changes apply on the next Windows start. Return
to **Off** before testing game performance, or if responsiveness does not improve.
This is an experiment, not a measured Steam or gaming performance improvement.
It does not alter the disk image format, cache or flush policy.

## Beta 5: Icon und Aufräumen

Das ausgewählte S-Icon erscheint im Finder und Dock. Nach einem erfolgreichen Test alle Gäste herunterfahren und Stratovo schließen. Dann `Aufraeumen.command` starten: Es zeigt nur bekannte ältere Installer und Bauordner an. Erst die Eingabe `BETA5 GETESTET` verschiebt diese Liste in den Papierkorb. Die aktuelle Version, VM-Daten und GraphicsLab bleiben erhalten. Eigene Quellcodeänderungen vorher sichern. Im Papierkorb kannst du „Zurücklegen“ verwenden; er wird nicht automatisch geleert. `SSD_Uebersicht.command` im privaten Paket bleibt eine reine Größenübersicht.
