# Dateiaustausch · Mac, Windows, Ubuntu und Android

Der gemeinsame Mac-Ordner heißt `Austausch` und liegt direkt im gewählten
Datenordner. Bei `/Volumes/Extern/OpenGuest` ist das
`/Volumes/Extern/OpenGuest/Austausch`. Er wird beim Öffnen im Finder oder vor
einer Übertragung angelegt. Vorhandene Dateien werden dabei nicht gelöscht.

In Stratovo links **Dateiaustausch** wählen. In jedem Player gibt es oben
ebenfalls eine Schaltfläche **Dateiaustausch**. Beide App-Ausgaben verwenden
denselben Ablauf. Der Host bleibt ein Apple-Silicon-Mac mit macOS 14+.

## Windows und Ubuntu: denselben Ordner über SMB verwenden

Einmalig auf dem Mac:

1. In Stratovo **Austausch im Finder öffnen** wählen.
2. **macOS-Freigabeeinstellungen öffnen** wählen. Alternativ:
   Systemeinstellungen → Allgemein → Teilen → Dateifreigabe.
3. Den Ordner **Austausch** zu den geteilten Ordnern hinzufügen.
   Deinem gewünschten Mac-Benutzer **Lesen & Schreiben** erlauben.
4. Unter **Optionen** SMB einschalten und den gewünschten Mac-Benutzer für
   Windows-Dateifreigabe aktivieren. macOS fragt dessen Passwort selbst ab.
   Stratovo speichert dieses Passwort nicht.

Gib nur den vorgesehenen Austauschordner frei. SMB-Freigaben können auch im
lokalen Netzwerk erreichbar sein; Stratovo schaltet sie nicht automatisch ein.
Die Freigabe muss auf dem Mac **Austausch** heißen. Bei mehreren gleichnamigen
Freigaben zuerst deren Pfad prüfen. Gastnetzwerk und macOS-Dateifreigabe müssen
eingeschaltet sein.

### Windows

**Ordner in Windows öffnen** wählen. Alternativ im Explorer diese Adresse eingeben:

`\\10.0.2.2\Austausch`

Mit dem freigegebenen **Mac-Benutzer und dessen Mac-Passwort** anmelden.
Für ein dauerhaftes Laufwerk: Explorer → Dieser PC → Netzlaufwerk verbinden,
die Adresse eintragen und bei Bedarf die Verbindung bei der Anmeldung
wiederherstellen lassen. Die Laufwerkszuordnung ist optional und wird nicht
ungefragt durch Stratovo angelegt.

### Ubuntu

Dateien → Andere Orte → Mit Server verbinden:

`smb://10.0.2.2/Austausch`

Als registrierter Benutzer mit den freigegebenen Mac-Zugangsdaten anmelden.
Bei Bedarf ein Lesezeichen im Dateimanager anlegen. Änderungen betreffen direkt
die Dateien im Mac-Ordner; es handelt sich nicht um getrennte Kopien.

## Android: ohne zusätzlichen Dateimanager

Android starten und warten, bis es vollständig hochgefahren ist.

- **Datei zu Android senden:** eine Datei auswählen. Sie wird in einen neuen
  Unterordner unter **Downloads/Stratovo-Austausch** kopiert. Vorhandene
  Android-Dateien werden nicht überschrieben.
- **Android-Dateien abholen:** in Android Dateien unter
  **Downloads/Stratovo-Austausch** ablegen und die Schaltfläche wählen.
  Stratovo kopiert den Inhalt in einen neuen Ordner unter **Austausch/Android**
  und öffnet ihn im Finder. Vorhandene Mac-Importe bleiben erhalten.

Diese Aktionen nutzen die bereits eingerichtete ADB-Verbindung zur laufenden
Stratovo-Android-Sitzung. Es gibt keinen automatischen Löschabgleich und keine
dauerhafte Einbindung desselben Verzeichnisses in Android. Direkter SMB-Zugriff
ist zusätzlich mit einem Android-Dateimanager mit SMB-Unterstützung möglich;
Server: `10.0.2.2`, Freigabe: `Austausch`.

Die Dateien benötigen auf der jeweiligen Zielseite freien Speicher.
Unvollständige Übertragungen können bei Verbindungsabbruch erhalten bleiben;
vor dem Entfernen der Quelle die Zielkopie prüfen.

## Referenzen

- [Apple: Mac-Dateien für Windows freigeben](https://support.apple.com/guide/mac-help/mchlp1657/mac)
- [QEMU: Benutzernetzwerk](https://www.qemu.org/docs/master/system/devices/net.html)
- [Android: ADB](https://developer.android.com/tools/adb)

Entwickelt von **PwnedG0blin**.

## Anleitung direkt in der App

Unter **Dateiaustausch** sind alle Schritte nummeriert und dauerhaft sichtbar: Mac-Ordner öffnen, einmalige SMB-Freigabe, Windows Arm, Ubuntu sowie Android-Senden und Android-Abholen. Die Freigabe-Einrichtung wird getrennt von den Gast-Schritten erklärt. In der direkten Windows-Grafikansicht erreicht man denselben Bereich über **Windows Arm → Dateiaustausch** im Stratovo-Hauptfenster.
