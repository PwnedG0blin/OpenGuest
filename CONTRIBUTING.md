# Zu Pixelkoje beitragen

Pixelkoje wird von **PwnedG0blin** entwickelt. Beiträge zu Quellcode, Dokumentation und nachvollziehbaren Fehlerberichten sind willkommen. Der Projektname ist vorläufig.

## Fehler und Vorschläge

Für Fehler das [Fehlerformular](https://github.com/PwnedG0blin/OpenGuest/issues/new?template=bug_report.yml) verwenden. App-Version, macOS-Version, Mac-Chip, Gastsystem und genaue Schritte angeben. Ein bereinigter Auszug aus **Gesamtprotokoll exportieren** hilft bei der Diagnose.

Für eine Funktionsidee beschreiben, welches konkrete Problem sie löst und in welchem Gast sie gebraucht wird. Größere Architekturänderungen bitte vorab als Issue besprechen. Sicherheitsrelevante Details gemäß [SECURITY.md](SECURITY.md) melden.

## Änderungen vorbereiten

1. Einen Fork und einen eigenen Arbeitsbranch erstellen.
2. Die Änderung auf ein nachvollziehbares Thema begrenzen. Vorhandene Nutzerdaten, Speicherpfade und virtuelle Gerätekennungen berücksichtigen.
3. Auf einem Apple-Silicon-Mac mit passenden Xcode-Werkzeugen `/bin/bash scripts/build-app.sh` ausführen. Für Änderungen an Android-Einrichtungsskripten zusätzlich `python3 scripts/test-android-setup.py` ausführen; diese Tests verwenden einen simulierten SDK und laden keine Systemabbilder.
4. Betroffene Funktionen im Gast prüfen, soweit möglich. Im Pull Request klar trennen, was automatisiert geprüft und was auf einem echten Mac getestet wurde.
5. Im Pull Request Problem, resultierendes Verhalten und relevante Prüfung knapp beschreiben. Ungeprüfte Gast- oder Leistungszusagen vermeiden.

CI-Builds und isolierte Tests ersetzen keine vollständige Windows-Installation, Google-Anmeldung oder Spieleprüfung. Eine reine Dokumentationsänderung benötigt keinen zusätzlichen Gasttest.

## Urheberrecht und Abhängigkeiten

Nur eigene oder rechtmäßig verwendbare Beiträge einreichen. Bestehende Urheberhinweise und die [MIT-Lizenz](LICENSE) erhalten; neue Fremdkomponenten in [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) dokumentieren. Betriebssystemabbilder, Zugangsdaten und private Protokolle gehören nicht in den Quellcode.
