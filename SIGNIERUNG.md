# Normaler macOS-Start mit Developer ID und Notarisierung

Die automatisch gebaute Test-DMG ist lokal/ad hoc signiert. Sie ist keine Developer-ID-Veröffentlichung und noch nicht von Apple notarisiert. Das erklärt den zusätzlichen Freigabeweg unter Datenschutz und Sicherheit. Dieser Zustand lässt sich ohne geeignete Signatur nicht durch eine App-Einstellung ändern.

Für eine öffentliche Veröffentlichung außerhalb des App Store braucht der Herausgeber ein **Developer ID Application**-Zertifikat mit privatem Schlüssel und Zugang zum Apple-Notarisierungsdienst. Das Zertifikat auf dem eigenen Mac über Xcode / das Apple-Developer-Konto einrichten. Ein „Apple Development“-Zertifikat genügt dafür nicht. Die App bleibt für ihre Nutzer kostenlos; dies ist die Einrichtung auf Herausgeberseite.

## Einmalig auf dem eigenen Mac

1. Developer-ID-Application-Zertifikat im lokalen Schlüsselbund einrichten. Die verfügbaren Signieridentitäten lassen sich mit `security find-identity -v -p codesigning` anzeigen.
2. Mit `xcrun notarytool store-credentials OpenGuest-Notary` ein lokales Schlüsselbundprofil anlegen und die Apple-Abfragen im eigenen Terminal beantworten. Private Schlüssel, Passwörter und App-spezifische Passwörter nicht im Chat, Repository oder in Protokollen teilen.

## Signierte Veröffentlichung erzeugen

Im Repository ausführen, mit dem tatsächlichen Namen der Signieridentität:

```bash
OPENGUEST_SIGNING_IDENTITY='Developer ID Application: Dein Name (TEAMID)' \
OPENGUEST_NOTARY_PROFILE='OpenGuest-Notary' \
bash scripts/notarize-app.sh
```

Das Skript baut und testet die App, signiert sie mit Hardened Runtime und Zeitstempel, reicht sie bei Apple ein und heftet das Notarisierungsticket an. Anschließend erstellt, signiert, notarisiert und prüft es die DMG. Es gibt nur bei erfolgreichem Abschluss eine Datei mit `_notarisiert.dmg` aus. Die Prüfungen schlagen bei fehlenden/ungültigen Anmeldedaten oder einer Ablehnung fehl. Bei einer Apple-Ablehnung zuerst das Notarisierungsprotokoll anhand der angezeigten Submission-ID prüfen.

Dieser Ablauf wurde ohne verfügbares Developer-ID-Zertifikat noch nicht vollständig ausgeführt. Eine Test-DMG wird dadurch nicht nachträglich automatisch vertrauenswürdig. Die neue signierte DMG muss verteilt werden. macOS kann bei heruntergeladenen Apps weiterhin einen normalen ersten Öffnungsdialog anzeigen; das ist etwas anderes als die Freigabe unter Datenschutz und Sicherheit. Auch Schlüsselbundzugriffe können eine eigene Benutzerfreigabe benötigen.

Apple-Quellen:
- https://developer.apple.com/developer-id/
- https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution
- https://developer.apple.com/help/account/certificates/create-developer-id-certificates/
- https://support.apple.com/102445
