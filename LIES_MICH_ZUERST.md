Entwickelt von **PwnedG0blin** · Copyright (c) 2026 PwnedG0blin.

Projektentwicklung und Lizenzen: [AUTHORS.md](AUTHORS.md) · [LICENSE](LICENSE).

# Neu in Pixelkoje 0.3.19: S26-Ultra-Displayprofil und Telefonfenster

Unter Android-Auflösung das Profil „Galaxy S26 Ultra · 1440 × 3120 · 500 dpi“ wählen und „Jetzt in Android anwenden“ anklicken. 500 dpi sind eine anpassbare Skalierungsvorgabe. „Bild einpassen“ setzt die Darstellung auf die verfügbare Bildfläche zurück. „Telefonfenster“ passt das Mac-Fenster an das Seitenverhältnis des Streams und die verfügbare Monitorhöhe an; frei vergrößern/verkleinern bleibt möglich. Im Vollbild wird nur Einpassen aktiviert. Ein von einem Spiel selbst erzeugter schwarzer Rand wird nicht automatisch abgeschnitten. Apps und Daten bleiben erhalten.

# Neu in Pixelkoje 0.3.17: Android-Verbindung reparieren

Falls Android bei „device offline“ hängen bleibt: Gastsystem herunterfahren, im Android-Bereich „Android-Verbindung reparieren“ wählen und danach Android starten. Die Funktion startet ADB neu und aktiviert den Kaltstart. Apps, Konten und Spielstände bleiben erhalten. Dabei werden auch andere ADB-Debugverbindungen auf diesem Mac getrennt. Die Reparatur startet keinen Gast automatisch und ist nur bei ausgeschalteten Gästen verfügbar.

# Neu in Pixelkoje 0.3.16: Mac-Text in Android einfügen

Am Mac Text mit ⌘C kopieren. In Android das gewünschte Eingabefeld antippen. Im Android-Player „Text einfügen …“ anklicken oder im Gastbild ⌘V drücken. Die Vorschau prüfen und „In Android einfügen“ bestätigen. Umlaute und Unicode werden übertragen. Kein zusätzliches Enter; Zeilenumbrüche innerhalb des Texts müssen ausdrücklich erlaubt werden. Maximal 64 KiB Text. Kein automatischer Abgleich und keine Speicherung des Textes in Protokollen oder Einstellungen. Manche Apps erlauben kein Einfügen.

Für Windows gibt es nun die optionale Virtio-GPU unter „Windows-Grafik und Auflösung“. Zuerst bei noch aktiver Basisgrafik die ARM64-Gasttreiber von der eingelegten Treiber-CD in Windows installieren. „Treiber-CD in Windows suchen“ öffnet den Explorer; unter „Dieser PC“ die CD und deren Installer öffnen. Windows danach vollständig herunterfahren, Virtio-GPU sowie einen bevorzugten Modus wählen und das vorhandene Windows starten. Die verfügbaren Auflösungen und die Skalierung in Windows hängen vom Gasttreiber ab. Bei schwarzem Bild ausgeschaltet wieder Basisgrafik wählen. Diese Version ergänzt keine 3D-Beschleunigung. Ein vollständiger Treibertest auf deinem Ziel-Mac steht noch aus.

Zum Aktualisieren beide Gastsysteme herunterfahren und Pixelkoje schließen. Dann die App ersetzen und den bisherigen Datenordner auf Extern weiterverwenden.

# Neu in Pixelkoje 0.3.15: Trackpad, Auflösung und Skalierung

Mit zwei Fingern über dem Gastbild hoch/runter scrollen. Die macOS-Scrollrichtung und der macOS-Nachlauf werden übernommen. Android unterstützt außerdem seitliches Scrollen. Windows nutzt mit dem aktuellen VNC-/USB-Tablet-Pfad Mausradschritte; kleine Trackpad-Bewegungen werden dafür gesammelt. Seitliches Windows-Scrollen und native Windows-Pixelgesten sind damit noch nicht verfügbar. Beim Scrollen wird kein zusätzlicher Klick ausgelöst.

Im Player „An Fenster anpassen“ wählen oder ausschalten und „Ansicht“ zwischen 25 und 300 Prozent einstellen. 100 Prozent entspricht einem empfangenen Bildpixel pro Mac-Bildpixel. Vergrößerte Bilder lassen sich über die Scrollleisten verschieben. Zwei-Finger-Gesten bleiben Eingaben für den Gast. Android und Windows merken sich ihre Ansichtsgröße getrennt.

„Android-Auflösung …“ bietet eigene Breite, Höhe und dpi. Bei gleicher Pixelauflösung machen größere dpi die Android-Schrift und Bedienelemente größer. Nach dem Android-Start „Jetzt in Android anwenden“ wählen; sonst gelten die gemerkten Werte beim nächsten Start. „Originalauflösung und Dichte wiederherstellen“ setzt beide Android-Überschreibungen zurück. Das Leistungsprofil begrenzt weiterhin Streamgröße und Bitrate; eine hohe Gastauflösung garantiert daher kein entsprechend großes übertragenes Bild.

Bei Windows „Windows-Einstellungen …“ wählen, danach im Gast System → Anzeige öffnen. Dort lassen sich die vom Gasttreiber angebotene Auflösung und Windows-Skalierung wählen. Die Player-Ansichtsgröße ist davon unabhängig; diese Version ergänzt keinen Grafiktreiber und keine neuen Windows-Anzeigemodi.

Vor dem Ersetzen Windows regulär herunterfahren und Pixelkoje schließen. Vorhandene Systeme auf dem gewählten Datenträger weiterverwenden. Es gibt weiterhin keinen automatischen Gaststart beim Öffnen der App.

# Neu in Pixelkoje 0.3.14: Windows-Gerätekennung und ISO-Prüfung

Windows vollständig herunterfahren. Im Windows-Bereich zeigt „Windows-Gerätekennung“ die bisherige oder eigene Kennung. Bestehende VMs behalten zunächst unverändert ihre frühere virtuelle Hardware. Über „Eigene Gerätekennung einrichten …“ lässt sich nach dem Hinweis eine eigene UUID, Seriennummer und Netzwerk-MAC dauerhaft einrichten. Die ursprüngliche Kennung wird unter Windows/Machine gesichert und lässt sich dort über die App wiederherstellen. Windows-Festplatte, UEFI-Dateien und TPM bleiben erhalten. Bei aktivierter Verschlüsselung den BitLocker-Wiederherstellungsschlüssel bereithalten; auch eine erneute Windows-Aktivierung kann nötig sein. Die Kennung wird nicht bei jedem Start gewechselt.

Anschließend „Vorhandenes Windows starten“ wählen. Beim Öffnen der App wird bei vorhandener Festplatte der normale Festplattenstart voreingestellt. „Nächster Start: Windows von DVD einrichten“ gilt einmalig; nach dem Prozessstart schaltet die App für den nächsten Start auf die gespeicherte Festplatte zurück. Die ISO-Auswahl bleibt gespeichert. Eine erneute Installation wird dadurch nicht automatisch angestoßen. Ein bereits in Windows gespeichertes BMW-/Autopilot-Profil wird mit der Änderung allein nicht entfernt. Die feste alte Seriennummer und fehlende eigene UUID sind korrigierte Fehler im Starter; ob sie die konkrete Firmenzuordnung verursacht haben, muss anhand des Gastzustands noch bestätigt werden. Es werden keine Firmenrichtlinien gelöscht oder Microsoft-Registrierungen verändert. Das Gesamtprotokoll enthält die von QEMU bestätigte UUID.

Bei „Installations-DVD“ liest „ISO mit Microsoft-Prüfsumme vergleichen“ die vorhandene Datei und berechnet SHA-256. Ein exakter Treffer bestätigt die deutsche Microsoft-Windows-11-26H2-ARM64-ISO. Abweichungen können auch durch andere Versionen oder Sprachen entstehen. Die Funktion lädt und kopiert keine ISO. Diese Version liefert noch keine geprüfte Secure-Boot-Firmware; eine entsprechende Setup-Meldung ist gesondert zu beheben.

# Neu in Pixelkoje 0.3.13: Entwicklerhinweis und Profil-Links

Unten in der Seitenleiste steht jetzt „Entwickelt von PwnedG0blin“. Die Links „X · @PwnedG0blin“ und „Patreon · Unterstützen“ öffnen das jeweilige Profil im normalen Mac-Browser. Beide Links werden nur auf deinen Klick geöffnet.

# Neu in Pixelkoje 0.3.12: Einfügefenster im Stil der App

„Text einfügen“ hat jetzt die türkisen Akzente von Pixelkoje: eine farbige Kopfzeile, ein klar umrandetes Textfeld, einen eigenen Bereich für die Windows-Tastatur und die hervorgehobene Schaltfläche „In Windows einfügen“. Der Dialog passt sich an den hellen und dunklen macOS-Modus an. Der Inhalt lässt sich scrollen; Abbrechen und Einfügen bleiben erreichbar. Eingabeprüfung und Übertragung funktionieren wie bisher.

Zum Aktualisieren Windows herunterfahren und Pixelkoje schließen, dann die App ersetzen. Den bereits eingerichteten Datenordner auf Extern weiterverwenden.

# Neu in Pixelkoje 0.3.11: Text vom Mac in Windows einfügen

Im Windows-Fenster zuerst das gewünschte Eingabefeld anklicken. Text auf dem Mac kopieren und im Player „Text einfügen …“ anklicken oder bei fokussiertem Windows-Bild ⌘V drücken. Die Vorschau lässt sich bearbeiten. Unter „Tastaturbelegung in Windows“ Deutsch oder Englisch (US) entsprechend der tatsächlich in Windows aktiven Belegung wählen. Die Beschriftung der Apple-Tastatur ist dafür nicht entscheidend. Caps Lock muss in Windows ausgeschaltet sein. Anschließend „In Windows einfügen“ anklicken; Fortschritt und Abbrechen erscheinen im Player. Bei einem Diagnosebefehl zum Ausführen danach selbst Enter im Windows-Bild drücken.

Der Text wird ohne zusätzliche Windows-Treiber als Tastatureingabe übertragen. Druckbare ASCII-Zeichen werden in beiden Belegungen unterstützt, bei Deutsch zusätzlich Umlaute, ß, €, § und ausgewählte Akzentzeichen. Nicht unterstützte Zeichen, Steuerzeichen wie Tabulator oder Texte mit mehr als 4096 Zeichen werden vor der ersten Eingabe abgelehnt. Es erfolgt keine stille Kürzung. Abschließende Zeilenumbrüche werden entfernt, damit ein kopierter Befehl nicht automatisch startet. Innere Zeilenumbrüche benötigen die Option „Zeilenumbrüche als Enter übertragen“; in einer Konsole können sie Befehle ausführen. Laufende Texteingabe ist abbrechbar, bereits eingegebener Text bleibt im Windows-Feld erhalten.

Die Mac-Zwischenablage wird ausschließlich beim Anklicken der Einfügen-Funktion oder bei ⌘V gelesen. Die Vorschau wird beim Schließen geleert. Übertragener Text wird nicht in Einstellungen, Dateien oder Diagnoseprotokollen gespeichert. Diese Funktion überträgt Text vom Mac nach Windows; Dateien und Kopieren von Windows zurück zum Mac gehören noch nicht dazu. Während der Übertragung sind manuelle Player-Eingaben gesperrt, damit sie sich nicht mit dem eingefügten Text vermischen. Die Kontoeinrichtung und unerwartete BMW-Firmenanmeldung werden dadurch nicht verändert.

# Neu in Pixelkoje 0.3.10: Windows-Konsole ohne Funktionstaste

Im Windows-Player öffnet „Einrichtungskonsole öffnen“ normalerweise die Windows-Setup-Konsole. Die Schaltfläche sendet Shift + F10 direkt an den verbundenen Gast, einschließlich Loslassen beider Tasten. Anschließend in das Windows-Bild klicken, um dort zu tippen. Der Hinweis bestätigt die Übertragung der Tastenkombination; ein durch Windows-Richtlinien gesperrter Konsolenzugriff wird dadurch nicht aufgehoben.

F1 bis F12 werden nun als Funktionstasten an Windows übertragen. Auf einer Apple-Tastatur bei aktiven Medienfunktionen fn beziehungsweise die Globus-Taste zusammen mit der gewünschten Funktionstaste drücken. Für F10 ist das die Stumm-Taste. Die vorherige Übertragung von AppKits Sonderzeichen statt der eigentlichen Funktionstaste war ein Fehler im Player.

Zum Aktualisieren den Gast herunterfahren, die App schließen, Pixelkoje ersetzen und das vorhandene Windows wieder starten. VM-Daten bleiben am bisherigen Speicherort. Diese Version behebt die Tastaturübertragung; die unerwartete BMW-Firmenanmeldung und die nicht angewandte lokale Kontoeinrichtung müssen anhand der Gastdiagnose gesondert untersucht werden.

# Neu in Pixelkoje 0.3.9: Installations-DVD selbst auswählen

Im Windows-Bereich unter „Installations-DVD · Windows ARM64“ auf „DVD-ISO manuell auswählen …“ klicken und die vorhandene ISO auf Extern auswählen. Der vollständige Pfad bleibt gespeichert und sichtbar. Die Auswahl aktiviert „Windows installieren · von DVD starten“. Vor dem Start werden ISO-Endung, Lesbarkeit, reguläre Zieldatei und Größe geprüft. Diese Dateiprüfung bestätigt nicht automatisch ARM64-Architektur oder Bootfähigkeit. Eine Verknüpfung auf eine lesbare ISO bleibt zulässig. Der ISO-Pfad kann bei ausgeschaltetem Gast jederzeit geändert werden. Es erfolgt kein erneuter Download und keine automatische Änderung vorhandener VM-Daten.

Nach dem Start fragt Pixelkoje den tatsächlichen QEMU-Zustand und die eingelegte Installations-DVD ab. Der Bereich zeigt damit getrennt „ausgewählte Datei“ und „von QEMU verbundene DVD“. Im Player ersetzen konkrete Verbindungsschritte oder Fehler die bisher unbegrenzte Startanzeige. Der Bildschirmclient wartet auf den lokalen Socket und begrenzt Verbindungsaufbau und ersten Bildempfang. Diese Korrektur adressiert eine mögliche Startrennbedingung; sie beweist ohne aktuellen Ziel-Mac-Test noch nicht, dass die Windows-Installation erfolgreich bootet. Festplatte, UEFI-Variablen, TPM und Kontodaten bleiben erhalten.

# Neu in Pixelkoje 0.3.8: Android-Leistungsprofile

„Flüssig · empfohlen“ ist voreingestellt. Nach dem Android-Start wird die längste Seite auf höchstens 1600 Pixel verkleinert, mit proportionaler gerader Bildgröße und angepasster Pixeldichte. Beim bisherigen 1080×2400-Gerät ergibt das 720×1600 bei 280 dpi. „Ausgewogen“ begrenzt die lange Seite auf 2000 Pixel; „Originalauflösung“ setzt die Android-Größe und Pixeldichte wieder auf die physischen AVD-Werte zurück. Android-Apps, Konten und Spielstände werden nicht gelöscht. Fehler beim Anwenden führen zu einem Wiederherstellungsversuch der vorherigen Anzeigeüberschreibungen.

Der H.264-Stream verwendet je nach Profil maximal 1280/1600/1920 Pixel und 8/10/12 Mbit/s. Stream-Ziel ist wahlweise 60 oder 30 FPS. Änderungen am Profil gelten nach dem nächsten Android-Start. Beim ersten Start dieser Version wird eine bisherige automatische Grafik-Auswahl einmalig auf „Mac-GPU bevorzugen“ gestellt; eine ausdrücklich gewählte Softwaregrafik bleibt erhalten. Das fordert die GPU lediglich an: Der Emulator kann weiterhin wegen seiner Grafik-Anforderungen Software erzwingen. Die neue Rendereranzeige wertet die tatsächlichen Grafikmeldungen aus und meldet diesen Fall ausdrücklich. Diese Version ersetzt keinen Emulator und installiert kein neues Android-Systemabbild.

Kurze Decoder-Überlast führt nicht mehr sofort zum Verwerfen der Bildfolge: Der Empfang wartet bis zu 60 ms auf freie Decoder-Kapazität. Erst bei längerer Überlast wird geleert und auf ein neues Schlüsselbild gewartet. Es gibt keinen unbegrenzt wachsenden zusätzlichen App-Framepuffer. Stream-Empfang, Decoder-Zuführung und Wiederanläufe werden getrennt erfasst. Diese Zahlen sind keine tatsächlichen Spiel-FPS und keine Bestätigung, dass jedes übergebene Bild angezeigt wurde. Diagnoseexport enthält Profil, Bildschirmwerte und Rendererstatus; keine Bildschirmbilder.

Ziel ist eine messbare Entlastung und flüssigere Wiedergabe. Ein Vergleich auf dem Ziel-Mac mit derselben Spielsituation ist noch erforderlich; stabile 60 FPS oder MuMu-Leistung werden durch diese Änderungen nicht garantiert.

# Windows-Installation und gemerktes Kennwort in 0.3.7

Die Windows-ISO sowie Treiber- und Einrichtungs-ISO werden jetzt ausdrücklich als schreibgeschützte CD/DVD-Laufwerke über USB-BOT eingebunden. Der bisherige generische USB-Speicher gab den ISO-Abbildern keinen ausdrücklichen CD-ROM-Gerätetyp. Die Windows-DVD erhält Bootpriorität 1; die bestehende Systemfestplatte behält Priorität 2 und ihre Gerätekennung. Das ist eine Korrektur der Medienkonfiguration, noch kein Nachweis eines vollständigen Windows-Installationsdurchlaufs. Quelle: https://www.qemu.org/docs/master/system/devices/usb.html . Bei der Aufforderung zum Start von CD/DVD im Player eine Taste drücken.

„Benutzername und Kennwort sicher merken“ ist voreingestellt. Vor dem Windows-Start wird das eingegebene Konto im macOS-Schlüsselbund gespeichert und erneut gelesen, bevor Erfolg gemeldet wird. Beim nächsten App-Start stellt Pixelkoje die Felder wieder her, sofern macOS den Zugriff ohne weitere Freigabe erlaubt. Andernfalls „Aus Schlüsselbund laden“ anklicken und im macOS-Dialog den Zugriff freigeben. Das dort verlangte Kennwort ist das des Mac-Anmeldeschlüsselbunds (normalerweise das Mac-Anmeldekennwort). Ein abgebrochener Zugriff wird als solcher angezeigt; er bedeutet nicht, dass vorher nichts gespeichert wurde. Die Passwortfelder werden beim Gaststart nicht mehr geleert. Keine Klartextablage in App-Einstellungen oder Diagnoseprotokollen. Gespeicherte App-Einträge sind in Schlüsselbundverwaltung verwaltet; sie sind keine Web-Anmeldungen der separaten Passwörter-App. Ohne „sicher merken“ wird vor dem Start nicht automatisch gespeichert. Eine Änderung dieser Einrichtungshilfe ändert kein bereits angelegtes Windows-Konto.

Im Diagnoseexport stehen jetzt auch die Zahl empfangener Windows-Bilder sowie Anzeigeverbindung und erster Bildempfang. Die Bildschirmbilder selbst werden nicht exportiert.

# Pixelkoje 0.3.7 – neuer Name, vorhandene Daten weiterverwenden

OpenGuest heißt ab sofort Pixelkoje. Oberfläche, Playerfenster, App und DMG tragen den neuen Namen. Beende die alte App, kopiere `Pixelkoje.app` nach Programme und starte sie. Der bisher eingerichtete Datenordner auf Extern wird übernommen. Vorhandene Ordner wie `/Volumes/Extern/OpenGuest` und Android-Profile werden nicht umbenannt oder erneut heruntergeladen. Einstellungen, Schlüsselbund-Zugangsdaten und virtuelle Festplatten verwenden dieselben internen Kennungen. Bei komplett neuen Installationen heißt der vorgeschlagene Datenordner `Pixelkoje`. Beide App-Versionen nicht gleichzeitig für denselben Gast verwenden. Nach der Übernahme kann die alte App aus Programme entfernt werden; die Datenordner behalten.

Die Windows-Startkorrektur aus 0.3.6 ist enthalten. Die App bleibt Open Source, kostenlos und ohne Abo.

# Neu in 0.3.6: Windows-Start mit TPM und Hardwarebeschleunigung

Der im Gesamtprotokoll sichtbare Abbruch `tpm-tis-device: HV_BAD_ARGUMENT` passt zu QEMU-Fehler #4587. Pixelkoje startet das TPM jetzt mit `ppi=off`. Nur die optionale Physical-Presence-Schnittstelle des virtuellen TPM wird deaktiviert. Das TPM 2.0, seine gespeicherten Daten und die HVF-Hardwarebeschleunigung bleiben aktiv. Windows-Festplatte, UEFI-Variablen und Kontodaten werden nicht gelöscht. Es wird kein Windows-Prüfmechanismus umgangen. Quelle und technische Erklärung: https://gitlab.com/qemu-project/qemu/-/work_items/4587 .

Die neue App nach Programme kopieren und die alte Version ersetzen. Danach Windows mit demselben Datenordner auf Extern starten. Falls die Kennwortfelder leer sind, zuvor „Aus Schlüsselbund laden“ anklicken. Im Diagnoseprotokoll der betroffenen Sitzung war das Speichern erfolgreich; der Windows-Prozess brach erst danach ab. Ein vollständiger Windows-Installationsdurchlauf auf dem Ziel-Mac ist weiterhin zu prüfen. Androids Softwaregrafik wird durch diese Windows-Korrektur nicht verändert.

macOS-Freigabe: Diese Test-DMG bleibt ad hoc signiert und benötigt gegebenenfalls weiterhin eine Freigabe. Der korrekte Developer-ID- und Notarisierungsweg ist in SIGNIERUNG.md und scripts/notarize-app.sh vorbereitet. Ohne Herausgeber-Zertifikat und Apple-Notarisierung ist diese Hürde nicht behoben.

Windows-Festplattengröße: Im Windows-Speicherbereich eine ganze Größe zwischen 64 und 4096 GB eingeben. Der Wert wird pro Datenordner gespeichert. „Größe anwenden“ erstellt die zunächst kleine QCOW2-Datei oder vergrößert eine vorhandene Festplatte. Auch der nächste Windows-Start übernimmt die gewählte Größe. Die vorhandene Kapazität wird geprüft und angezeigt; die Datei belegt nur mit der Nutzung zusätzlichen realen SSD-Speicher. Verkleinern wird verweigert. Änderungen sind nur ohne laufenden Gast möglich und werden über dieselbe VM-Sperre gegen andere Pixelkoje-Instanzen geschützt. Neu hinzugekommene Kapazität muss anschließend in Windows einem Volume zugeordnet werden. Quelle: https://www.qemu.org/docs/master/tools/qemu-img.html .

# Neu in 0.3.5: Gemeinsames Diagnoseprotokoll und Windows-Ordner

Unter dem Protokollbereich „Gesamtprotokoll exportieren“ anklicken. Pixelkoje erstellt eine gemeinsame .log-Datei für Android und Windows in `<Datenordner>/Logs/Diagnose` und zeigt sie im Finder. Enthalten sind Systemprüfung, Komponentenstatus, die letzten vier Sitzungen pro System, ältere nicht eindeutig zuordenbare Sitzungen, Einrichtung, Android-Videostream, Windows-TPM sowie App-Fehler auch vor dem Gaststart. Bei der Kontodiagnose werden nur Zeichenanzahlen, Übereinstimmung und Prüfhinweise aufgenommen. Schlüsselbunddaten, Einstellungen, Antwortdateien und Gastdateisysteme werden nicht gelesen. Bekannte Schlüssel-, E-Mail-, Benutzerpfad-, Token- und Passwortangaben werden gefiltert. Protokolle werden begrenzt; große Dateien enthalten Anfang und Ende. Vor dem Teilen kannst du die Datei selbst ansehen. Es wird nichts automatisch versendet.

Ein gemeinsames App-Diagnosejournal zeichnet ab dieser Version Prüfungen, Fehlermeldungen, Gaststarts/-enden und Schlüsselbund-Ergebnisse auf dem gewählten Datenträger auf. Alte fehlgeschlagene Starts ohne vorhandene Logdatei lassen sich nicht nachträglich rekonstruieren; den Fehler erneut auslösen und anschließend exportieren.

Im Windows-Bereich wird der feste Ordner `<Datenordner>/Windows` angezeigt. „Windows-Ordner anlegen / prüfen“ legt ihn bei Bedarf an und prüft die Schreibbarkeit. Bestehende VM-Daten bleiben erhalten. Vor dem Windows-Start muss der Ordner erreichbar sein. Die VM prüft ihn noch einmal und verwendet dort ihre Festplatte, UEFI-Variablen und TPM-Daten. Ohne den gewählten Datenträger gibt es keine interne Ausweichinstallation. Der frühere orange Prototyp-Hinweis ist jetzt ein aufklappbarer Abschnitt mit Voraussetzungen und Entwicklungsstand, keine Fehlermeldung.

# Neu in 0.3.4: Hauptfenster ohne Gast-Autostart

Beim Öffnen von Pixelkoje erscheint nur das Hauptfenster. Android und Windows starten ausschließlich über ihre Start-Schaltflächen. Auch eine früher gespeicherte Android-Autostart-Einstellung wird nicht mehr verwendet; die Option wurde entfernt. Erst der manuelle Gaststart öffnet das eigene frei skalierbare Playerfenster. Playerfenster werden nicht über die macOS-Fensterwiederherstellung automatisch geöffnet. Die neue Google-Kontoauswahl im externen Mac-Browser aus 0.3.3 ist enthalten.

# Neu in 0.3.3: Google im normalen Mac-Browser

Im Android-Bereich öffnet „Google im Mac-Browser öffnen“ die offizielle Google-Kontoauswahl über den macOS-Standardbrowser. Der Browser verwendet seine normale Sitzung und sein vorhandenes Profil; Pixelkoje öffnet keine eingebettete Webseite oder private Anmeldesitzung. Gespeicherte Konten und Zugangsdaten stehen nur zur Verfügung, soweit sie im geöffneten Browserprofil vorhanden sind. Pixelkoje liest keine Browserpasswörter, Cookies oder Google-Tokens aus und erkennt den Browser-Anmeldestatus nicht.

Diese Funktion ist eine externe Google-Webanmeldung, keine Übergabe eines Kontos an den Android-Emulator. Für Google Play, Kontosynchronisierung und Cloud-Spielstände weiterhin „Google-Konto in Android hinzufügen“ verwenden und die Anmeldung im Gastsystem abschließen. Eine automatische Übernahme einer Mac-Browser-Anmeldung in Android ist nicht implementiert. Google beschreibt Desktop-OAuth und Android-Systemkonten als eigene Abläufe: https://developers.google.com/identity/protocols/oauth2/native-app ; https://developer.android.com/reference/android/accounts/AccountManager .

# Neu in 0.3.2: Windows-Kontodaten

Windows-Benutzername, Passwortlänge und Passwortwiederholung werden unmittelbar im Formular getrennt geprüft. Die Zeichenanzahl beider Passwortfelder ist sichtbar; das Passwort bleibt verdeckt. „Windows einrichten“ wird erst mit gültigen Kontodaten freigegeben. Bei Start- und Vorbereitungsfehlern bleiben beide Eingaben erhalten. Nach erfolgreichem Prozessstart werden sie aus dem Formular entfernt.

Der Benutzername bleibt wie bisher in den App-Einstellungen erhalten. Mit „Im Schlüsselbund speichern“ speicherst du auf Wunsch Benutzername und Passwort im macOS-Schlüsselbund, getrennt nach Pixelkoje-Datenordner. „Aus Schlüsselbund laden“ stellt beide Passwortfelder wieder her, auch nach erneutem App-Start. Pixelkoje liest nur seinen eigenen Schlüsselbund-Eintrag auf ausdrücklichen Klick; macOS kann um Zugriffserlaubnis bitten. Das ist eine lokale Einrichtungshilfe: Das eigentliche Windows-Konto entsteht während der Windows-Installation und bleibt danach im Gastsystem bestehen. Eine spätere Änderung des gespeicherten Eintrags ändert kein bereits eingerichtetes Windows-Konto. Die kleine Schlüsselbund-Ablage liegt auf dem Mac, die VM bleibt am gewählten Datenort.

# Neu in 0.3.1: Downloads direkt im Programm

Unter Einrichtung die gewünschten Komponenten auswählen und „Auswahl laden und einrichten“ starten. Ziel ist ausschließlich der eingerichtete Pixelkoje-Datenordner. Android SDK-Werkzeuge, Java falls nötig, Emulator, Android-15-Google-Play-ARM64-Systemabbild, Streaming-Modul und Windows-Treiber-ISO werden dort heruntergeladen und eingerichtet. Entpackdateien und Java-Temporärdateien liegen ebenfalls dort. Die App verweigert den Download bei fehlendem Datenträger oder zu wenig freiem Platz. Vorhandene Komponenten werden wiederverwendet; eigene ISO-Dateien werden bei Bedarf kopiert und byteweise geprüft, ihre Originale bleiben erhalten.

Google-SDK-Bedingungen vor dem Download der Werkzeuge lesen und bestätigen. Weitere Android-SDK-Lizenzen erscheinen im integrierten Protokoll und werden mit den dort eingeblendeten Schaltflächen beantwortet. Kein Terminal nötig. SDK-Tools und Java werden gegen offizielle SHA-256-Prüfwerte geprüft; scrcpy gegen den Digest des offiziellen Releases. Downloads laufen über HTTPS. Windows- und Treiber-ISOs werden zusätzlich auf ein ISO-Format geprüft; eine solche Formatprüfung ist kein Echtheits- oder Architekturbeweis.

Windows-ISO: Vorhandene ARM64-ISO im Windows-Bereich auswählen oder auf der verlinkten Microsoft-Seite Sprache und ARM64-Download wählen, den direkten Downloadlink kopieren und in die App einfügen. Pixelkoje lädt direkt auf den gewählten Datenträger und übernimmt den Pfad. Der Microsoft-Link ist zeitlich befristet. Windows-Lizenz und Ersteinrichtung bleiben erforderlich.

QEMU und swtpm werden weiterhin aus einer vorhandenen Mac-Installation verwendet; ihr automatischer Download/ihre Installation sind noch nicht implementiert. Die Einrichtungsseite zeigt Status, Quellenlinks und Auswahlschaltflächen. Eine geeignete Secure-Boot-fähige ARM64-Firmware muss weiterhin vorhanden sein. Android Studio ist für den neuen SDK-Download nicht mehr nötig; sein vorhandenes Java wird wiederverwendet. Python 3 aus den Xcode Command Line Tools wird für die Prüfung der scrcpy-/Java-Release-Metadaten benötigt. Kleine App-Einstellungen und Betriebssystemdateien können weiterhin intern liegen.

Offizielle Quellen: https://developer.android.com/studio ; https://developer.android.com/tools/sdkmanager ; https://adoptium.net/temurin/releases/ ; https://github.com/Genymobile/scrcpy ; https://docs.getutm.app/guest-support/windows/ ; https://www.microsoft.com/de-de/software-download/windows11arm64

# Neu in 0.3.0

Android und Windows öffnen beim Start jeweils ein eigenes Playerfenster. Du kannst es frei vergrößern, verkleinern und als Vollbild anzeigen; das Bild und die Eingabekoordinaten passen sich mit erhaltenem Seitenverhältnis an. „Player öffnen“ zeigt ein geschlossenes Fenster erneut. Das Schließen eines Playerfensters lässt den Gast weiterlaufen; zum Ausschalten „Herunterfahren“ verwenden. Beide Player bleiben getrennte Bereiche; weiterhin kann ein Gastsystem gleichzeitig laufen. Die Fenstergröße ändert die Darstellung, nicht automatisch die Auflösung im Gastsystem.

Die Windows-Prüfung und der Startbefehl verwenden jetzt das von QEMU für ARM-virt dokumentierte TPM-Gerät `tpm-tis-device` anstelle von `tpm-crb-device`. Das behebt die fälschliche TPM-Sperre bei passenden QEMU-Builds. Quelle: https://www.qemu.org/docs/master/specs/tpm.html . Ein vollständiger Windows-Installationsdurchlauf ist weiterhin auf dem Ziel-Mac zu prüfen.

# Lesbarkeit in 0.2.2

Der Speicherort-Dialog zeigt Texte, Pfad und Status mit größerer Schrift und hohem Kontrast. Fehler werden in einem farblich abgesetzten Bereich mit eigener Überschrift angezeigt. Lange Meldungen lassen sich scrollen und kopieren. Die Korrektur der Kopierprüfung aus 0.2.1 ist enthalten.

# Korrektur in 0.2.1

Bei „Kopierprüfung fehlgeschlagen: sdk“ in 0.2.0: alte App beenden, 0.2.1 installieren und denselben Datenordner (Extern/OpenGuest) erneut wählen. Bereits passende Dateien werden geprüft und wiederverwendet. Zusätzliche Zieldateien, etwa AppleDouble-/Finder-Metadaten, bleiben erhalten und blockieren die Prüfung nicht mehr. Jede Datei aus der Quelle wird weiterhin auf Typ und SHA-256-Inhalt geprüft; echte Unterschiede werden mit Dateipfad gemeldet. Originale werden beim Kopieren nicht gelöscht.

# Pixelkoje 0.2.0 – Speicherort und Umzug

Beim ersten Start dieser Version (auch nach 0.1) wählst du den Datenordner. Wähle auf dem Mac im Dialog die externe SSD **Extern**. Pixelkoje legt dort **Pixelkoje** an.

1. Android/Windows herunterfahren, die alte Pixelkoje-App und Android Studio sowie laufende Einrichtungsskripte beenden.
2. Neue App nach Programme kopieren und von dort öffnen. Die DMG danach auswerfen.
3. Ordner **Extern** wählen → **Speicherort einrichten und Daten übernehmen**. Kopieren und SHA-256-Prüfung können bei großen Geräten dauern. SSD währenddessen angeschlossen lassen.
4. Bisherige Standardordner für SDK, Android-Geräte, Windows-Festplatte/TPM, Streaming und Protokolle werden übernommen. In Pixelkoje ausgewählte Windows-/Treiber-ISOs aus Downloads werden ebenfalls übernommen. Kompatibilitäts-Verknüpfungen halten bisherige Android-Studio- und AVD-Pfade gültig.
5. Unter Einrichtung **System prüfen**, dann bei Android bevorzugt **Pixelkoje_Android16_64GB** wählen. Falls es fehlt: **Android vorbereiten …**, anschließend **Videostream einrichten …**.
6. Nach erfolgreichem Test Gast herunterfahren und Android Studio beenden. Unter **Einrichtung → Daten und Speicherplatz** die gelisteten internen Sicherungen kontrollieren, den Test bestätigen und **Geprüfte interne Kopien endgültig entfernen …** wählen. Erst dabei wird interner Platz frei; die aktiven SSD-Daten bleiben erhalten. Geänderte Sicherungen oder fehlende Ziele blockieren die Bereinigung.

Auf Extern liegen SDK/Systemabbilder, Android-Apps/Spielstände, Windows-Datenträger/TPM, Streaming, Protokolle sowie die ausgewählten Installations-ISOs. Ein kleiner Pfadzeiger und App-Einstellungen bleiben intern. Die Mac-App, Android Studio, Homebrew/QEMU und macOS-Caches/Auslagerungsdateien werden nicht automatisch verschoben oder gelöscht. Keine pauschale Bereinigung von Downloads, Xcode oder Homebrew.

### Windows-Treiber

Unter Einrichtung **Windows-Treiber laden …**. Das Skript lädt die offizielle UTM-Guest-Tools-ISO direkt nach **OpenGuest/Installationsmedien/utm-guest-tools.iso**. Diese ISO bei **ARM64-Treiber-ISO** auswählen. Bei **Windows-Arm64-ISO** die echte Microsoft-ISO verwenden. Identische Dateien in beiden Feldern werden als Fehler erkannt. Die Treiber enthalten ARM64-Unterstützung; Einbindung, Installation und Kompatibilität mit Pixelkoje müssen weiterhin im Gast getestet werden. Die vollständige SPICE-Integration von UTM ist nicht Bestandteil von Pixelkoje.

QEMU, swtpm, qemu-img und geeignete ARM64-UEFI-Firmware samt passenden Variablen werden weiterhin separat benötigt. Die Systemprüfung nennt fehlende Komponenten genauer. Normale Homebrew-UEFI-Dateien garantieren kein Secure Boot; Windows-Installation bleibt ein noch nicht vollständig getesteter Prototyp. Windows-Lizenz erforderlich. Nicht behauptet: fertiges Windows-System oder MuMu-Leistung.

### Grenzen und Sicherheit

SDK und virtuelle Geräte sind getrennte Datenbereiche. Eine SDK-Auswahl allein lagert Spielstände nicht aus. Bei fehlender SSD werden Gäste und Einrichtungsskripte gesperrt; es wird kein interner Ersatzordner angelegt. Bei Konflikten bleiben Quellen erhalten. Vorhandene Daten außerhalb der Standardpfade werden nicht automatisch übernommen; dafür zuerst eine gesonderte Migration planen.

Google-Konto, Synchronisierung und Cloud-Spielstände funktionieren nur, soweit offizielles Abbild und jeweilige App sie unterstützen. Keine Garantie für jedes Spiel oder Play Integrity. Die App ist ad-hoc signiert und nicht Apple-notarisiert.

## Hinweise aus Version 0.1

# Pixelkoje 0.1.0 – erster Quellcode-Prototyp

Eine kostenlose Mac-App mit eigenem Android Player und Windows Player. Open Source unter MIT, ohne Abo. Zielplattform: Apple Silicon, macOS 14 oder neuer. Das ist ein Entwicklungsstand, keine fertig veröffentlichte Alternative zu MuMu oder VMware. Der native Mac-Build und die 13 Unit-Tests sind inzwischen im GitHub-Build erfolgreich.

## Android zum ersten Mal einrichten

1. Xcode und **Android Studio für Apple Silicon** installieren. Android Studio einmal starten und den SDK einrichten. Im SDK Manager unter SDK Tools auch **Android SDK Command-line Tools (latest)** installieren.
2. **Android_einrichten.command** ausführen. Die Google-/SDK-Lizenzen selbst bestätigen. Das Skript lädt ein offizielles Android-16-ARM64-Abbild mit Google Play und erstellt das Gerät `Pixelkoje_Android16_64GB` mit 64 GiB. Bestehende Geräte werden nicht überschrieben.
3. **Android_Streaming_einrichten.command** ausführen. Es bezieht den genau passenden scrcpy-4.0-Server aus dem offiziellen Release und prüft den dort veröffentlichten SHA-256-Wert. Fehlt dieser, bricht es ab. Keine Installation eines beliebigen Ersatzpakets.
4. **Start.command** ausführen. Es führt zunächst die Swift-Tests aus, baut die lokale Test-App und öffnet sie. Danach Android oder Windows auswählen und ausdrücklich über die Start-Schaltfläche starten. Weitere Starts können über `dist/Pixelkoje.app` erfolgen.

Alternativ kannst du `Package.swift` in Xcode öffnen und das Schema OpenGuest auf deinem Mac starten. Werden `.command`-Dateien nicht direkt gestartet, lassen sie sich im Terminal mit `bash ` und ihrem hineingezogenen Pfad ausführen. Gatekeeper oder andere Mac-Schutzfunktionen nicht abschalten.

## Google und APKs

Im Android Player: **Google-Konto hinzufügen**. Die Anmeldung erfolgt direkt bei Google im Android-Gast. Danach **Play Spiele** öffnen/installieren und dort dasselbe Konto wählen, das deine Spiele verwenden. Die Buttons **Kontosynchronisierung** und **Android-Sicherung** öffnen die entsprechenden Android-Einstellungen; du bestätigst selbst, was synchronisiert wird.

**APK installieren …** installiert eine einzelne APK in genau dem gestarteten Android-Gerät. Die Schaltfläche wird erst nach dem Android-Boot aktiv. Split-Pakete wie XAPK/APKS werden noch nicht unterstützt.

Apps, Konten, Dateien und Spielstände bleiben lokal im AVD gespeichert. Google-Cloud-Spielstände und Backups sind zusätzlich möglich, **wenn das jeweilige Spiel, die App und das Systemabbild sie unterstützen**. Kein Emulator kann für jede App eine Synchronisierung erzwingen. Google-Anmeldung, Gerätezertifizierung, Play Integrity und Spielekompatibilität müssen auf dem Zielsystem getestet werden.

## Windows 11 Pro Arm64

Windows ist eine eigene, dauerhaft gespeicherte VM im Windows Player. Beim ersten Start installierst du Windows aus einer selbst bezogenen offiziellen **Arm64-ISO**. Die Pro-Edition wird über ein zusätzliches Einrichtungsmedium vorausgewählt; falls Setup trotzdem fragt, Windows 11 Pro wählen. Eine passende Windows-Lizenz ist separat erforderlich.

- QEMU und swtpm separat installieren, beispielsweise mit `brew install qemu swtpm`, wenn Homebrew bereits eingerichtet ist.
- In Pixelkoje unter Einrichtung QEMU und die passende ARM64-UEFI-Firmware auswählen. Für Windows 11 sind geeignete Secure-Boot-fähige Firmware und dazu passende UEFI-Variablen erforderlich. **Die normale QEMU-Datei `edk2-aarch64-code.fd` ist nicht automatisch ein geeigneter Secure-Boot-Build.** Eine existierende passende Firmware kann ausgewählt werden; dieses Paket enthält und erzeugt sie nicht. Das ist vor einem vollständigen Windows-Test noch zu klären.
- Windows-Arm64-ISO und optional eine ARM64-Gasttreiber-ISO wählen. Bei Netzwerkbedarf den VirtIO-Netzwerktreiber laden. Die Treiber-ISO allein installiert in Pixelkoje noch keine Treiber automatisch.
- Optional **Lokales Windows-Konto** aktivieren, eigenen Benutzernamen und Passwort eingeben. Kein vorgeschriebenes Microsoft-Konto. Region, Tastatur und weitere Ersteinrichtung bleiben interaktiv.
- **Windows einrichten** starten. Pixelkoje erstellt eine zunächst kleine, mit der Nutzung wachsende virtuelle 80-GB-Festplatte. Es wird keine echte Mac-Festplatte an Windows durchgereicht.
- Nach abgeschlossener Installation **Windows installieren · ISO einlegen** ausschalten. Künftige Starts verwenden die gespeicherte Windows-Festplatte.

Bei Ende einer normalen Sitzung wird nur das temporäre Einrichtungsmedium mit den Kontoangaben entfernt. Windows-Festplatte, UEFI-Variablen und TPM bleiben erhalten. Nach einem Absturz können temporäre Setup-Dateien zurückbleiben. Während einer unterbrochenen Installation können die Angaben beim nächsten Installationsstart erneut nötig sein.

## Stabilität und Tempo

Bitte zuerst **Herunterfahren** verwenden. **Prozess beenden** ist die bestätigungspflichtige Notlösung und kann ungespeicherte Änderungen verlieren. Die App überschreibt keine bestehenden Geräte und enthält keine automatische Datenbereinigung.

Android: ARM64-CPU mit Hypervisor.framework, Grafikmodus auto/host, H.264-Stream mit Ziel 60 FPS über scrcpy und native Mac-Videodarstellung. Die Anzeige zählt empfangene Videoframes pro Sekunde, keine intern berechneten Spiele-FPS. Das tatsächliche Tempo wurde noch nicht gemessen. Ton kann aktuell über den Android Emulator ausgegeben werden, wird aber nicht im Streaming-Modul transportiert; das ist noch zu testen.

Windows: ARM64-CPU mit HVF, einfacher Framebuffer und eigener lokaler Player. Beschleunigte Windows-3D-Grafik, Audio, komfortable Treiberinstallation, Zwischenablage, Multitouch und Spiele-Tastenbelegung sind noch nicht implementiert. Auf dem 16-GB-Mac startet jeweils ein Gast; für den Wechsel den bisherigen Gast herunterfahren.

**Prüfstand:** Swift-Dateien wurden syntaktisch geprüft, Shell-Skripte geprüft und Paketmetadaten kontrolliert. In dieser Arbeitsumgebung gibt es kein macOS/Xcode: Der native ARM64-Mac-Build und alle 13 Swift-Tests sind im GitHub-Build **erfolgreich ausgeführt**. Android-Start, Google-Anmeldung, Windows-Installation/OOBE und Leistungstests sind weiterhin offen. Ein macOS-CI-Workflow und ein Testplan liegen bei. Keine Behauptung „absturzfrei“ oder „so schnell wie MuMu“.

## Frei verfügbar

Der komplette eigene Quellcode liegt im ZIP und darf nach MIT weitergegeben und verändert werden. Pixelkoje kostet nichts und hat kein Abo. Der Quellcode liegt öffentlich auf https://github.com/PwnedG0blin/OpenGuest. Die Test-App ist lokal/ad-hoc signiert, aber noch nicht mit Developer ID signiert oder Apple-notarisiert. Google-/Microsoft-Systemdateien und fremde Engines behalten ihre eigenen Lizenzbedingungen; Windows selbst wird dadurch nicht kostenlos.

Der vorbereitete GitHub-Workflow „Build macOS test app“ kann nach Einrichtung eines Repositorys auf einem Apple-Silicon-Mac testen, kompilieren und eine `.app.zip` als Build-Artefakt bereitstellen. Der erste Build ist erfolgreich abgeschlossen. Das wäre zunächst die kompilierte Test-App; Engines und Betriebssysteme müssten weiterhin separat eingerichtet werden. Ein vollständiger Installer mit komfortabler Ersteinrichtung ist noch nicht fertig.

## Android 16, Android 17 und Updates

Android 16 mit Google Play ist der Standard. Vorhandene passende Profile werden wiederverwendet; Nutzerdaten werden bei der Einrichtung nicht überschrieben. Neue Profile erhalten 64 GiB. Unter „Downloads und Einrichtung“ lässt sich Android 17 als separates Profil installieren.

Stable ist voreingestellt. Beta, Dev und Canary schließen zusätzliche von Google angebotene SDK-Revisionen ein. Eine tägliche Updateprüfung beim Öffnen lädt nichts herunter. Optional kann das gewählte Systemabbild vor jedem Android-Start aktualisiert werden. Updates erfolgen nur bei ausgeschalteten Gästen; danach wird ein Kaltstart verwendet. Ein Wechsel der Android-Hauptversion erfordert ein eigenes Profil. Dies ist keine Pixel-Beta-Registrierung und garantiert nicht, dass jede Pixel-Beta als Google-Play-ARM64-Emulatorabbild verfügbar ist.

Für die Bereinigung das funktionierende Android 16 auswählen, alle Emulatoren beenden und unter „Alte Android-Profile und Daten bereinigen“ die Liste erstellen. Die Löschaktion entfernt ausschließlich die aufgelisteten anderen Profile im gewählten Datenordner, nicht mehr benötigte andere SDK-Systemabbilder und erkannte Android-15-Sicherungen aus der Speichervergrößerung. Apps, Konten und Spielstände dieser alten Profile sowie diese Sicherungen werden endgültig gelöscht. Das gewählte Android 16, Windows, Installationsmedien und andere Sicherungen bleiben erhalten. Extern referenzierte Systemabbilder werden vorsichtshalber behalten. Die App löscht beim Start nichts automatisch.

### Android-Bildübertragung

Die Stream-Warteschlange ist nach Bildanzahl, Datenmenge und Zeitspanne begrenzt. Bei Rückstau werden veraltete H.264-Referenzketten verworfen und erst ab einem neuen Schlüsselbild wieder angezeigt. Empfang und Decoder-Zuführung sind getrennt; FPS-Anzeigen werden sekündlich aktualisiert, auch wenn keine neuen Bilder eintreffen. „Anzeige neu verbinden“ startet nur den Videostream neu. Android und laufende Downloads werden dabei nicht neu gestartet.

Der bewährte Modus „Mac-GPU bevorzugen“ bleibt Standard. Optional lässt sich Vulkan für einen OpenGL-ES-Kompatibilitätstest ausschalten. Dies ist kein neuer BlueStacks- oder MuMu-Renderer und garantiert keine konstante Spielbildrate. Hohe Android-Auflösungen, Spiele, Encoder und Gastlast können weiterhin die Bildrate begrenzen.
