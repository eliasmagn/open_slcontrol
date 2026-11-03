# open_slcontrol — LuCI-App für Lindner & Sommerauer CAN-Heizungen

Schlanke OpenWrt/LuCI-Anwendung zur Anzeige und Steuerung einer
Lindner-&-Sommerauer-Heizung über den CAN-Bus.

## Funktionen

### WPS / Ethernet-Wartung (optional, standardmäßig aus)

Die Konfigurationsseite enthält einen Tab **WPS / Ethernet-Wartung**. Dort ein
Muster mit vier bis sechzehn kurzen WPS-Betätigungen direkt am Router anlernen,
denselben Rhythmus wiederholen und anschließend über den normalen LuCI-Footer
speichern. Die Abstände sind zusätzlich als Millisekundenliste bearbeitbar.
Relative Toleranz (5–40 %) und Mindesttoleranz (20–250 ms) sind konfigurierbar;
Entprellung beträgt 120 ms. Das Lernfenster beträgt je Durchgang 60 Sekunden,
einzelne Abstände dürfen höchstens zehn Sekunden dauern. Beim Lernen wird kein
Zugang geöffnet und keine normale WPS-Anmeldung ausgelöst.

**Zuerst anlernen, dann die Sperre aktivieren.** Benötigt wird ein bereits
eingerichtetes, separates Ethernet-Wartungsnetz mit eigenem L3-Gerät, etwa
`br-maint`. Bis zu acht Geräte sind möglich. Netzwerktopologie, IP-Adressen und
DHCP-Konfiguration werden nicht automatisch verändert. WLAN-Geräte, Bridges
mit konfiguriertem WLAN und Bridge-Mitglieder werden abgelehnt. Eine mit dem
Sensor-WLAN gemeinsame `br-lan` darf nicht verwendet werden. Firewall-Flow-
Offloading muss deaktiviert sein. Das normale Firewall-Regelwerk muss die
Verwaltungsdienste im Wartungsnetz erlauben; die zusätzliche Sperre kann keine
bestehende Firewall-Ablehnung aufheben.

Bei aktivierter Funktion gilt für die ausgewählten Geräte:

- Geschlossen: IPv4-/IPv6-Eingang zum Router gesperrt, auch bestehender Verkehr.
- Geöffnet: nur TCP 22/80/443, DHCP UDP 67/547 und notwendige eingehende IPv6-
  Nachbarschaftsnachrichten passieren die zusätzliche Sperre. MQTT bleibt zu.
- Geroutete Weiterleitung in beide Richtungen bleibt gesperrt. ARP ist kein
  IP-Port und wird durch diese inet-Regeln nicht abgeschaltet.
- Sequenz öffnet für 30–3600 konfigurierbare Sekunden. Jede gültige LuCI-Sitzung
  hält eine bereits geöffnete Freigabe offen, unabhängig vom Zugangsinterface.
  Dafür wird rpcd nur abgefragt; der vorhandene Sitzungstimeout wird nicht
  verlängert. Nach Logout/Timeout beginnt der volle konfigurierte Nachlauf.
- Ein weiterer kurzer WPS-Druck oder **Zugang schließen** sperrt sofort,
  unabhängig von LuCI-Sitzungen. Der letzte Druck der Öffnungssequenz schließt
  nicht gleichzeitig. Neustart öffnet niemals automatisch.
- Eine kurzlebige nftables-Freigabe wird vom Dienst erneuert. Bei dessen Ausfall
  verfällt sie spätestens nach drei Sekunden; ein Dienstneustart beginnt
  geschlossen. Die Sperre wird beim Boot vor den normalen Verwaltungsdiensten
  eingerichtet. Firewall-Neuladen löscht die eigene Tabelle nicht.

Eine vorhandene LED kann ausgewählt werden, vorzugsweise rot. Sie leuchtet bei
Freigabe und blinkt beim Lernen. Trigger und Helligkeit werden anschließend
wiederhergestellt. Ohne geeignete LED funktioniert die Sperre ebenfalls. Die
Anzeige ist keine elektrische Funktionskontrolle des Routers.

Die Sequenz ersetzt kein starkes Passwort beziehungsweise SSH-Schlüssel. Ein
physisch zugänglicher Reset oder Failsafe kann die normale Betriebs-Firewall
umgehen. Vor dem Aktivieren einen unabhängigen Wiederherstellungsweg vorsehen.
Deaktivieren oder Deinstallieren der Funktion entfernt ihre Zusatzsperre und
stellt die darunterliegende Firewall-Policy wieder her. Keine CAN-Sendefunktion
ist mit dem WPS-Knopf verknüpft.

Entwicklerprüfung: `sh tools/test_access.sh` prüft Rhythmus, Toleranz, langes
Uptime-Zeitformat, Lernen, Timeout und manuelles Schließen ohne Routerzugriff.

### Heizungsfunktionen

Das Panel enthält **V+Z: nächste Zusatzseite** mit Hinweisen zu Verbrennung,
Service, Fühlerabgleich, Hausanlage, Fehlerspeicher und Prüfparametern.
Die Hilfe öffnet rechts neben dem Panel mit eigenem Scrollbereich; bei wenig
Platz unterhalb der Live-Anzeige. Kopf und Schließen bleiben sichtbar, der
Hilfetext verlängert die Seite nicht. Escape schließt das Hilfefenster.
Ein Klick entspricht einer über UCI konfigurierten Betätigung, nicht einem
absoluten Seitenaufruf. Belege und Handbuchstellen: [Panel-Befehle](docs/panel-commands.md).

- **Live-Panel**: Zweizeiliges Display, Betriebsmodus und LEDs — ausschließlich
  aus frischen CAN-Frames (`0x320`), kein Snapshot, kein Fallback
- **Schreibgeschützter Default**: Senden nur nach bewusster Aktivierung von
  `write_mode=1` im Konfigurations-Tab
- **Konfigurierbare Mappings**: Alle Tasten-/Betriebsarten-Codes als UCI-Optionen
  (`mapping_*`), keine festverdrahteten Sendecodes
- **Passiver Lernassistent**: Erkennt Tasten-Mappings automatisch aus dem
  Live-CAN-Stream (zwei Fenster, Bestätigung, Kollisionsschutz)
- **Router-lokaler Alarm**: Überwacht auf
  Fehlertexte, eingefrorenes Display und CAN-Ausfall — meldet per Telegram
  mit Quittier-Button
- **LED-/Modus-Anzeige**: Aus `0x320 83xx`-Statusbytes, konfigurierbares Mapping

## Architektur

```
CAN can0 → candump → raw_bridge.sh → MQTT ${mqtt_base}/raw
                                        → heizungpanel_stream (CGI) → SSE → panel.js
                                        → alarm_watchdog.sh → Telegram/HTTPS

LuCI config.js → UCI heizungpanel
LuCI panel.js  → rpcd/fs.exec → press.sh → cansend 321#XXXX
```

## Voraussetzungen

- Prüfziel dieser Release-Prüfung: OpenWrt 25.12.5 mit LuCI. Andere Releases
  sind nicht allein durch einen erfolgreichen Syntaxcheck als unterstützt belegt.
- CAN-Interface (`kmod-can`, `kmod-can-raw`)
- `can-utils` (`candump`, `cansend`)
- `mosquitto-client` (`mosquitto_pub`, `mosquitto_sub`)
- USB-CAN-Adapter (getestet mit gs_usb) oder eingebettetes CAN

## Installation

### Als Feed

```sh
# Feed hinzufügen (feeds.conf bzw. feeds.conf.default):
src-git heizungpanel https://github.com/eliasmagn/open_slcontrol.git

# Feeds aktualisieren und Paket installieren:
./scripts/feeds update heizungpanel
./scripts/feeds install -a -p heizungpanel
make menuconfig   # LuCI → Applications → luci-app-heizungpanel
make package/luci-app-heizungpanel/compile
```

### Ein selbst gebautes Paket installieren

Ein Git-Feed ist eine Quelle für das OpenWrt-Buildsystem, kein automatisch
eingerichtetes Binärpaket-Repository auf dem Router. Erst das zum Zielrelease
gebaute Paket auf das Gerät übertragen und mit dessen Paketmanager installieren.
Ältere Releases verwenden `.ipk`/`opkg`, aktuelle Releases `.apk`/`apk`.
Diese Veröffentlichung stellt bislang kein signiertes Binärpaket-Repository bereit.

### Fertige APKs und automatische Veröffentlichung

Die GitHub-Releases enthalten nach erfolgreichem Paketbau eine APK für die
jeweils aktuelle stabile OpenWrt-Version, dazu `SHA256SUMS` und `BUILDINFO.json`.
Die APK ist architekturunabhängig; Paketabhängigkeiten müssen zum OpenWrt-Release
des Routers passen. GitHub-Releases sind kein signiertes APK-Repository.

Der Workflow **Build and publish OpenWrt APK** prüft täglich die offizielle
`stable_version`, zusätzlich bei Änderungen am Paket und auf manuellen Aufruf.
RCs und Snapshots werden nicht ausgewählt. Existiert das passende veröffentlichte
Paket bereits, wird kein SDK heruntergeladen und nichts neu gebaut.

Ein Release-Entwurf speichert jeden begonnenen Versuch dauerhaft. Fehlgeschlagene
oder unterbrochene Builds werden mit unveränderten Eingaben nicht täglich erneut
gestartet. Ein bewusster manueller Aufruf mit `retry=true` oder geänderte
Build-Eingaben erlaubt einen neuen Versuch. Parallel laufen keine Paketbauten;
ein Job endet spätestens nach 30 Minuten.

Release-Tags haben das Format `v0.2.0-r2-openwrt-25.12.5`. Veröffentlichte Pakete
werden nie überschrieben und Tags nie verschoben. Bei Änderungen an App-Dateien
muss `PKG_RELEASE` erhöht werden, bei einer neuen App-Version `PKG_VERSION`.
Ein neuer OpenWrt-Release darf unveränderten App-Code als separates Paket erhalten.

Die Erstveröffentlichung bleibt zunächst ein geprüfter Entwurf. Veröffentlichung
wird durch `.github/apk-publication-enabled` mit dem Inhalt `true` freigeschaltet;
die Repository-Variable `APK_RELEASES_ENABLED` kann dies ausdrücklich überschreiben.
Ein bereits fertiger Entwurf wird dabei nur verifiziert und veröffentlicht,
nicht erneut gebaut.

Der öffentliche Build verwendet ausschließlich Git-getrackte Quelldateien,
prüft alle 16 Paketdateien, Rechte und Konfigurationserhalt und verlangt
Read-only-Defaults ohne Zugangsdaten. Private Firmware-Images, Router-Backups
und lokale Overlays werden niemals als Release-Anhang hochgeladen.

### Nach der Installation

```sh
/etc/init.d/heizungpanel enable
/etc/init.d/heizungpanel start
```

LuCI öffnen: **Dienste → Heizungpanel → Panel**

## Erste Konfiguration

1. **CAN-Interface** einstellen (Standard: `can0`, Bitrate `69144`)
2. **MQTT** konfigurieren (Standard: localhost, Port 1883)
3. **Tasten-Mappings** prüfen oder über den **Lernassistenten** ermitteln
4. **Alarm** aktivieren (Telegram-Token + Chat-ID eintragen)

Senden ist standardmäßig **deaktiviert** (`write_mode=0`).
Zum Aktivieren: Konfiguration → Write-Mode → `1`.

## Sicherheit

- CAN-Schreibzugriffe steuern reale Heizhardware
- Read-only ist der Default (`write_mode=0`)
- Befehle nur über eine Whitelist mit validierten 4-stelligen Hex-Payloads
- Leere Mappings deaktivieren Senden — keine Ersatz-Sendecodes
- Ein beobachteter Status ist eine Zustandsbeobachtung, kein kausaler Nachweis

### Vertrauensgrenzen und Alarmbetrieb

- Der MQTT-Raw-Topic muss vor fremden Publishern geschützt sein. Wer dort
  schreiben darf, kann Anzeige und Alarmauswertung beeinflussen. Ein privater
  lokaler Broker oder passende Broker-ACLs sind Teil der Installation.
- Die konfigurierbare CAN-Bitrate und Mappings gehören zum konkreten
  Steuerungsstand. Die gleiche SL-Modellbezeichnung ist kein Beleg für gleiche
  Tastencodes. Vor Freigabe des Schreibmodus Zuordnungen am passenden Gerät
  überprüfen; fehlende Zuordnungen nicht durch vermutete Werte ersetzen.
- Telegram-Benachrichtigungen sind Nachrichten, keine Telefonanrufe. Ob sie
  laut ertönen oder eine Stummschaltung umgehen, hängt vom Telefon und dessen
  Berechtigungen ab. Das muss mit einem bewusst ausgelösten Test am tatsächlich
  verwendeten Telefon geprüft werden. Eine API-Annahme ist kein Nachweis,
  dass das Telefon geweckt hat.
- Die reguläre Alarmwiederholung beträgt zehn Minuten. Eine Quittierung
  bestätigt nur, dass der Nutzer den Alarm zur Kenntnis genommen hat; sie
  bestätigt keine Reparatur und darf keine Heizungsbefehle senden.
- Der Display-Ausfallalarm prüft ausbleibende `0x320`-Antworten bei weiter
  aktivem Bus. Ein unveränderter Text bei frischen Statusframes löst ihn
  nicht aus. Fehlende Antworten sind kein Beweis für eine abgestürzte
  Steuerung. Sensorwerte, Betriebszustand und Fehlerspeicher separat prüfen.
- Quittierung erfordert den konfigurierten Chat und einen autorisierten
  Absender. Im privaten Chat ist dies standardmäßig die Chat-ID; in Gruppen
  muss `alarm_telegram_ack_user` als numerische Nutzer-ID gesetzt werden.
  Ohne diese Zuordnung bleibt die Gruppen-Quittierung deaktiviert. Nur neue
  Textnachrichten oder der Button der aktuellen Alarmepisode quittieren;
  alte Nachrichten und Buttons anderer Episoden werden ignoriert.
  Kann der Telegram-Backlog zu Beginn der Episode nicht zuverlässig bestimmt
  werden, bleibt die Textquittierung für diese Episode deaktiviert. Die
  Alarmmeldung weist dann auf den weiterhin nutzbaren aktuellen Button hin.
- Telegram-Antworten werden mit `ucode` und `ucode-mod-fs` geparst. Der Helper
  `telegram_json.uc` gehört zum Paket und zum SSH-Deploy; fehlt er, wird
  eine Telegram-Zustellung nicht als Erfolg gewertet.
- Alarm-URLs werden als einzelne UCI-Listeneinträge gelesen. Pro Versand
  werden höchstens fünf URL-Kanäle aufgerufen; der Test meldet überzählige
  Einträge als Fehler statt sie als zugestellt zu zählen.
- Watchdog-Laufzeitdateien liegen in einem privaten Verzeichnis mit Modus
  `0700` und werden atomar mit Modus `0600` geschrieben. Unsichere vorhandene
  Verzeichnisse oder veröffentlichte Symlinks werden abgewiesen; der
  Watchdog startet in diesem Fall nicht.
- Ohne Strom oder nutzbare Internetverbindung kann der Router keine
  externen Benachrichtigungen zustellen. Ein unabhängiger Ausfallmelder ist
  nötig, wenn auch der Router selbst überwacht werden soll.
- Zugangsdaten ausschließlich auf dem eigenen Gerät konfigurieren.
  Private Firmware mit eingebetteten Netzwerk- oder VPN-Schlüsseln sowie
  Konfigurationsbackups niemals als öffentliche Release-Artefakte verteilen.

## Protokoll-Details

Der hier implementierte Bedienpfad verwendet CAN-ID `0x321` mit zwei
Datenbytes und `0x320` für Display und Status. Das ist keine vollständige
oder universelle Spezifikation aller SL-Steuerungen. Aussagen zu weiteren
Frames, Temperaturen oder Fehlerursachen müssen ihren Beobachtungs- und
Versionsstand nennen; unbestätigte Interpretationen bleiben Hypothesen.

## Beitragen

Modellkonfigurationen (erkannte Tasten-Payloads je Heizungsvariante) können
über den eingebauten Export als JSON beigesteuert werden. Siehe Tab
**Lernen & Beitrag** in der LuCI-Konfiguration.

## Lizenz

[MIT](LICENSE)
