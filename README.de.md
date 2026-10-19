# Stratovo · 1.0 Beta 1

[Beta-Anleitung und Speicherbedarf pro VM](docs/RELEASE_1.0_BETA1.md)

# Stratovo — Android-Emulator und Windows-ARM64-VM für Mac

[English](README.md)

<p align="center">
  <img src="docs/assets/project-header.svg" alt="Stratovo — Android und Windows auf dem Mac" width="100%">
</p>

**Ein nativer macOS-Player für Android ARM64 und Windows ARM64. Open Source, kostenlos und ohne Abo.**

Entwickelt von **[PwnedG0blin](https://github.com/PwnedG0blin)** · Testversion **0.3.20** · macOS **14+** · **Apple Silicon** · [MIT-Lizenz](LICENSE)

Stratovo verbindet zwei getrennte Gastsysteme mit einer gemeinsamen Mac-Oberfläche. Android und Windows öffnen jeweils ein eigenes, frei skalierbares Playerfenster. Apps, Konten und virtuelle Datenträger bleiben zwischen den Sitzungen gespeichert. Beim Öffnen der App wird kein Gast automatisch gestartet.

**Stratovo hieß bisher Pixelkoje.** Das Repository behält seine bisherige Adresse `OpenGuest`. Bundle-ID, Einstellungen, Gastsysteme und Datenpfade bleiben für bestehende Installationen kompatibel.

[Einrichtung](LIES_MICH_ZUERST.md) · [Test-Builds](https://github.com/PwnedG0blin/OpenGuest/actions/workflows/macos.yml) · [Fehler melden](https://github.com/PwnedG0blin/OpenGuest/issues/new/choose) · [Mitwirken](CONTRIBUTING.md)

## Funktionen

| Bereich | Aktueller Funktionsumfang |
| :--- | :--- |
| **Android** | Android 16 mit Google Play als Standard; Android 17 optional als eigenes Profil. Neue Profile mit 64 GiB, APK-Installation und Google-Anmeldung im Gast. |
| **Windows** | Dauerhaft gespeicherte ARM64-VM, manuelle ISO-Auswahl als Installations-DVD, Treiber-CD und vergrößerbarer virtueller Datenträger. |
| **Player** | Getrennte Fenster, Bild einpassen, Zoom sowie einstellbare Android-Auflösung und Dichte. Windows-Anzeigemodi hängen vom installierten Gasttreiber ab. |
| **Eingabe** | Text vom Mac in Android oder Windows übertragen; getrennt einstellbares Scrolltempo und Trackpad-Nachlauf. Android bietet zusätzlich Touch-Wischen mit zwei Fingern. |
| **Speicher** | Datenordner beim ersten Start wählen, auch auf einer externen SSD. Geführte Übernahme bestehender Standardordner mit Inhaltsprüfung. |
| **Diagnose** | Gemeinsames Protokoll für Android, Windows und Einrichtung; Status für Renderer, Bildübertragung und Startvorgang. |

Google-Synchronisierung und Cloud-Spielstände hängen von der jeweiligen App und dem offiziellen Systemabbild ab. Die Anmeldung im Mac-Browser meldet den Android-Gast nicht automatisch an.

## Installation und Einrichtung

1. **App beziehen:** Einen erfolgreichen Lauf unter [GitHub Actions](https://github.com/PwnedG0blin/OpenGuest/actions/workflows/macos.yml) öffnen und dessen Build-Artefakt herunterladen. Dafür kann eine GitHub-Anmeldung nötig sein. Alternativ auf einem Mac [aus dem Quellcode bauen](#aus-dem-quellcode-bauen).
2. **Datenordner wählen:** Beim ersten Start den gewünschten Speicherort festlegen. Für eine externe SSD empfiehlt sich ein eigener Projektordner; eine bestehende Installation kann ihren bisherigen Pfad weiterverwenden.
3. **Komponenten einrichten:** Unter **Downloads und Einrichtung** Android-Werkzeuge, Systemabbild und Videostream vorbereiten. Für Windows werden QEMU, TPM-Unterstützung, geeignete ARM64-UEFI-Firmware und eine Windows-ARM64-ISO benötigt.
4. **System prüfen und starten:** Den gewünschten Gast auswählen und ausdrücklich starten. Beim ersten Windows-Start die Installation im Gast durchführen.

Die [Schritt-für-Schritt-Anleitung](LIES_MICH_ZUERST.md) beschreibt Android, Windows, Treiber, Updates und den Umzug auf eine externe SSD.

## GitHub-API und Versionsprüfung

Unter **Einrichtung → Stratovo-Updates über GitHub** prüft Stratovo auf Wunsch öffentliche [GitHub Releases](https://github.com/PwnedG0blin/OpenGuest/releases). Die native macOS-App liest ausschließlich die offizielle REST-API für Releases (ohne API-Schlüssel oder GitHub-Anmeldung), vergleicht die veröffentlichte Version mit der lokal installierten App und zeigt Versionshinweise sowie einen Link zur offiziellen Veröffentlichung an.

- Die manuelle Prüfung ist jederzeit möglich. Automatische Prüfungen sind **standardmäßig aus** und lassen sich einschalten (höchstens eine Anforderung pro 24 Stunden).
- Vorabversionen sind optional; Entwürfe, ungültige Versionsnummern und externe Links werden nicht als Updates angeboten.
- Releases sind derzeit **noch nicht veröffentlicht**. Die separat verfügbaren [GitHub-Actions-Test-Builds](https://github.com/PwnedG0blin/OpenGuest/actions/workflows/macos.yml) sind keine Releases und werden deshalb nicht als neue Version gemeldet.
- Es erfolgt kein automatischer Download, keine Installation und keine Übermittlung von Diagnoseprotokollen oder persönlichen Daten. Beim Abruf der öffentlichen GitHub-API fallen technisch notwendige Netzwerkdaten bei GitHub an; [GitHubs Datenschutzbestimmungen](https://docs.github.com/en/site-policy/privacy-policies/github-general-privacy-statement) gelten.

Die GitHub-API-Integration wurde unabhängig vom GitHub Developer Program entwickelt. Eine Aufnahme ins Programm und das Profil-Badge entscheidet ausschließlich GitHub; sie sind nicht durch diese Funktion garantiert.

## Entwicklungsstand

Stratovo ist eine **öffentliche Testversion**. Die Mac-App, Protokolle und Eingabewege werden automatisiert geprüft; vollständige Installationen, Spielekompatibilität und dauerhaft stabile Bildraten müssen zusätzlich auf echten Zielsystemen getestet werden.

- **Android-Grafik:** Mac-GPU-Modus mit optionalem OpenGL-ES-Kompatibilitätstest durch Abschalten von Vulkan. Der Emulator kann weiterhin Software-Rendering erzwingen. Ein 60-FPS-Ziel ist keine Garantie für 60 Spielbilder pro Sekunde.
- **Windows-Grafik:** Basisgrafik oder optionale Virtio-GPU nach Installation passender ARM64-Treiber. Beschleunigte Windows-3D-Grafik ist nicht implementiert.
- **Gastsysteme:** Aktuell läuft jeweils ein Gast. Ein Wechsel erfordert das Herunterfahren des bisherigen Systems.
- **Verteilung:** Die Test-App ist ad-hoc signiert, nicht mit Apple Developer ID signiert oder notarisiert. Hinweise zum Start und zur geplanten Signierung stehen in [SIGNIERUNG.md](SIGNIERUNG.md).
- **Abhängigkeiten:** Emulator, Engines, Treiber und Betriebssystemabbilder werden separat eingerichtet. Windows benötigt eine passende eigene Lizenz; Fremdkomponenten behalten ihre Lizenzbedingungen.

Die Android- und Windows-Daten werden bei einer normalen Sitzung weiterverwendet. Vor Aktualisierungen beide Gäste regulär herunterfahren und die App schließen. Hinweise zu Zugriffsgrenzen, temporären Einrichtungsmedien und Berichten stehen in [SECURITY.md](SECURITY.md).

## Aus dem Quellcode bauen

Auf einem Apple-Silicon-Mac mit passenden Xcode-Werkzeugen im Projektordner:

```bash
/bin/bash scripts/build-app.sh
```

Das Skript führt Tests aus und erstellt `dist/Stratovo.app`. `Start.command` baut und öffnet die lokale App. Der CI-Workflow ergänzt Paket- und Startprüfungen auf macOS; er ersetzt keinen vollständigen Gasttest.

Technischer Aufbau: SwiftUI und AppKit für die Oberfläche, Android Emulator und scrcpy für Android, QEMU mit Hypervisor.framework sowie lokaler RFB-Bildübertragung für Windows. Weitere Angaben: [Drittanbieter](THIRD_PARTY_NOTICES.md) · [Testplan](docs/TESTPLAN.md).

## Mitwirken

Fehlerberichte, Dokumentationsverbesserungen und nachvollziehbare Pull Requests sind willkommen. Bitte zuerst [CONTRIBUTING.md](CONTRIBUTING.md) lesen. Bei Fehlern helfen die App-Version, macOS-Version, das betroffene Gastsystem und ein bereinigter Diagnoseauszug.

Bisherige Versionshinweise und frühere Anleitungen bleiben im [Versionsarchiv](docs/CHANGELOG_ARCHIVE.md) und [Anleitungsarchiv](docs/ANLEITUNGEN_ARCHIV.md) erhalten. Diese Archive beschreiben historische Stände.

## Entwickler und Unterstützung

**PwnedG0blin** · [GitHub](https://github.com/PwnedG0blin) · [X](https://x.com/PwnedG0blin) · [Patreon](https://www.patreon.com/cw/PwnedG0blinApp)

Copyright (c) 2026 PwnedG0blin. Quellcode unter der [MIT-Lizenz](LICENSE); [Entwickler- und Beitragshinweise](AUTHORS.md). Unterstützungsangebote sind freiwillig; Stratovo bleibt kostenlos und ohne Abo.
