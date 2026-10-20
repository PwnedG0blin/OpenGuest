# Stratovo · Android, Windows und Ubuntu auf dem Mac

Entwickelt von **PwnedG0blin** · **1.0 Beta 4** · macOS 14+ · Apple Silicon.

Eine Oberfläche für Android ARM64, Windows mit 3D über Metal und Ubuntu ARM.
Die Systeme laufen im Stratovo-Player mit Tastatur, Text einfügen und Trackpad-Steuerung.
Gäste und Werkzeuge liegen auf deinem selbst gewählten Datenträger.

- Android 16 mit Google Play, optional Android 17; persistente Apps und Spielstände.
- Ein Windows-Bereich mit 3D auf deiner bisherigen Installation, ohne neue Testkopie.
- Ubuntu 26.04.1 LTS ARM64 mit geprüftem Download und eigener 64-GiB-Festplatte.
- Systemabhängige App-Sprache, 14 Sprachordner; technische Texte teilweise mit Ersatztexten.
- Austauschordner im gewählten Datenordner: Windows/Ubuntu über SMB, Android über Datei-Senden und Abholen.
- GitHub-Updates mit Prüfungen vor der Installation.

[Download](https://github.com/PwnedG0blin/OpenGuest/releases) · [Schritt-für-Schritt-Anleitung](LIES_MICH_ZUERST.md) ·
[Neu in Beta 3](docs/RELEASE_1.0_BETA4.md) · [Aufräumen](docs/AUFRAEUMEN.md)

3D und Gastkompatibilität bleiben experimentell. Für den ersten Grafikbau werden
vollständiges Xcode mit Metal-Werkzeugen und mindestens 30 GiB benötigt. Die App
wird lokal signiert; Developer-ID-Signatur und Notarisierung sind noch nicht enthalten.

[GitHub Sponsors](https://github.com/sponsors/PwnedG0blin) · [Patreon](https://www.patreon.com/cw/PwnedG0blinApp) · [X](https://x.com/PwnedG0blin)

Copyright © 2026 PwnedG0blin und Mitwirkende · [Lizenz](LICENSE)

[Dateiaustausch zwischen Mac, Windows, Ubuntu und Android einrichten](docs/DATEIAUSTAUSCH.md).

Windows Arm startet standardmäßig im eigenen Cocoa-/Metal-Grafikfenster ohne VNC-Bildkopien. Die eingebettete Ansicht bleibt experimentell. Text einfügen und Dateiaustausch findest du in der Windows-Steuerung.
