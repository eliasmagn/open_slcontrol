# open_slcontrol (Slim Panel)

Schlanke OpenWrt/LuCI-App für ein stark reduziertes Heizungs-Panel:

- **Panel** (Live-Ansicht + Tasten senden bei aktivem Write-Mode)
- **Konfiguration** (nur Kern-Parameter)
- **Raw-first Runtime** (ein Bridge-Prozess, nur Live-Frames)

## Was entfernt wurde

Diese Repo-Version entfernt bewusst Engineering-/Analyse-/Update-Ballast:

- Sensor-Graph-UI
- Mapping-UI
- Git-Update-UI
- Legacy-State-Bridge inkl. Parser-Pfad
- Analyse-/Capture-Helfer und umfangreiche Forschungsdokumente
- Deploy-/Stabilitäts-Hilfsskripte (Stability Harness weiterhin entfernt, SSH-Deploy-Tool wieder vorhanden)

## Verzeichnisstruktur (relevant)

- `www/luci-static/resources/view/heizungpanel/panel.js` – Hauptpanel
- `www/luci-static/resources/view/heizungpanel/config.js` – schlanke Konfigseite
- `www/cgi-bin/heizungpanel_stream` – SSE-Stream (nur `raw`)
- `usr/libexec/heizungpanel/raw_bridge.sh` – CAN->MQTT raw
- `usr/libexec/heizungpanel/press.sh` – Sende-Befehle (durch Write-Mode geschützt)
- `etc/init.d/heizungpanel` – Dienststart
- `etc/config/heizungpanel` – Default-Konfiguration

## Deployment / Installation

1. Paket bauen/installieren wie gewohnt über OpenWrt-LuCI-Feed-Workflow.
2. Sicherstellen, dass vorhanden sind:
   - `can-utils` (`candump`, `cansend`)
   - `mosquitto-client` (`mosquitto_pub`, `mosquitto_sub`)
3. Dienst starten:
   - `/etc/init.d/heizungpanel enable`
   - `/etc/init.d/heizungpanel start`


### Schnell-Deploy auf Zielgerät (Tool wiederhergestellt)

Für schnelle Iteration ohne vollständigen Paketbau steht wieder ein SSH-Deploy-Tool bereit:

- Script: `tools/device_ssh_deploy.sh`
- Aktionen: `install|push` und `uninstall|remove`

Beispiele:

```sh
# Installation/Update auf OpenWrt-Ziel
./tools/device_ssh_deploy.sh install root@192.168.1.10

# Mit SSH-Key und ohne Service-Neustart
./tools/device_ssh_deploy.sh push root@openwrt.local -i ~/.ssh/id_ed25519 --no-restart

# Entfernung aller installierten Dateien
./tools/device_ssh_deploy.sh uninstall root@192.168.1.10
```

Hinweise:

- Nutzt bewusst `scp -O` (legacy SCP), damit Deploy auch auf Dropbear/OpenWrt ohne SFTP-Subsystem funktioniert.
- `--overwrite-config` überschreibt explizit `/etc/config/heizungpanel`; ohne Flag bleibt bestehende Zielkonfiguration erhalten.

## Nutzung

1. LuCI öffnen: `Services -> Heizungpanel -> Panel`
2. Live-Daten kommen über `raw`-Topic.
3. Für Senden: auf `Services -> Heizungpanel -> Konfiguration` `write_mode=1` setzen.

### Stabilität Live-Anzeige (April 2026)

- Das Panel normalisiert eingehende CAN-IDs (z. B. `0320` und `320` werden gleich behandelt).
- Dadurch werden Display-Textframes wieder kontinuierlich erkannt, auch wenn das Quellformat variiert.
- Es gibt keinen Bootstrap-/Snapshot-Fallback: Anzeige startet leer und rendert ausschließlich aus Live-CAN-Frames.

### Aktueller LED-/Modus-Stand (Panel)

- Die Modus-LEDs im Panel werden **direkt aus CAN `0x320 83xx`** abgeleitet.
- Es gibt **kein persistentes Frontend-Latch** mehr, das länger als der eingehende `0x320 83xx`-Rhythmus hält.
- Für bekannte Betriebsstatus werden jetzt sowohl ältere als auch neue `83xx`-Varianten erkannt (z. B. `BF/3F`, `DF/5F`, `EF/6F`, `FB/7B`).
- Die Ein/Aus-LEDs werden aus **Bit 7** des `83xx`-Statusbytes abgeleitet.
- Für die Bit7-Auswertung wird das erste Status-Byte von `83xx` verwendet (nicht Folgebytes).
- Wenn keine frischen `83xx`-Frames kommen (TTL), fallen LEDs/Modus auf „unbekannt“ zurück.

## Kern-Konfigoptionen

- `can_if`
- `can_bitrate`
- `can_setup`
- `mqtt_host`
- `mqtt_port`
- `mqtt_base`
- `poll_interval_ms`
- `write_mode`
- `publish_raw`
- `stream_token`
- `led_map_83` (Mapping `83xx`-Statusbyte -> Modus-Flags, z. B. `EF:DFFF`)
- `led_power_ein_when_bit7_clear` (`1` = Ein wenn Bit7=0, `0` = invertiert)
- `mapping_*` (Tasten-/Mode-Codes für `press.sh`, jeweils 4 Hex oder leer)

### Konfigurierbares Mapping (April 2026)

- **LED-/Modus-Mapping** ist jetzt über `/etc/config/heizungpanel` konfigurierbar:
  - `led_map_83` steuert, welche `0x320 83xx`-Statusbytes welcher Betriebsart entsprechen.
  - `led_power_ein_when_bit7_clear` steuert die Ein/Aus-Ableitung aus Bit 7.
- **Button-/Mode-Sendemapping** ist ebenfalls über UCI konfigurierbar:
  - `mapping_z`, `mapping_plus`, `mapping_dauer`, `mapping_boiler`, usw.
  - Leerer Wert deaktiviert den jeweiligen Sende-Code (Write-Mode bleibt global).

### Validierungs-Fix Konfigseite (April 2026)

- Die Feldvalidierung auf der Konfigseite wurde so korrigiert, dass gültige Eingaben nicht mehr fälschlich als **"invalid field"** markiert werden.
- Hintergrund: Validatoren liefern jetzt explizit nur noch `true` (gültig) oder eine Fehlermeldung (ungültig), entsprechend dem erwarteten LuCI-Flow.

### Konfigurations-Validierung (Stand: 21. April 2026)

Die Validierung ist jetzt **Frontend (LuCI)** und **Backend (`config_set.sh`)** konsistent:

| Feld | Erwarteter Wert | Fehler bei |
|---|---|---|
| `can_if` | `^[A-Za-z0-9._-]+$` (nicht leer) | Sonderzeichen/Leerwert |
| `can_bitrate` | Zahl `10000..1000000` | Nicht numerisch / außerhalb Range |
| `poll_interval_ms` | Zahl `250..10000` | Nicht numerisch / außerhalb Range |
| `write_mode` | `0` oder `1` | andere Werte |
| `mqtt_host` | `^[A-Za-z0-9._:-]+$` (nicht leer) | unerlaubte Zeichen |
| `mqtt_port` | Zahl `1..65535` | Nicht numerisch / außerhalb Range |
| `mqtt_base` | `^[A-Za-z0-9._/-]+$`, ohne `#`/`+`, nicht führend/trailing `/` | Wildcards, Slash an Rand, Sonderzeichen |
| `stream_token` | leer **oder** Hex `^[0-9A-Fa-f]+$`, Länge `16..128`, **gerade Länge** | Sonderzeichen, ungerade Länge, außerhalb Range |
| `led_map_83` | CSV aus `HEX2:HEX4` (z. B. `EF:DFFF`) | falsches Pair-Format / Sonderzeichen |
| `mapping_*` | leer oder exakt 4 Hex (`HEX4`) | Nicht-Hex, falsche Länge, Sonderzeichen |

Damit sind insbesondere Hex-Felder strikt auf Hex beschränkt; Sonderzeichen führen sofort zu einem Validierungsfehler.

### Konfigseite / Save & Apply (April 2026)

- Die Konfigseite nutzt den **normalen LuCI Save / Save & Apply-Flow** (kein separater eigener Save-Button).
- **Wichtig:** Die Änderungen-Erkennung ist jetzt an den globalen LuCI-Footer gebunden.
  Der untere rechte **Save / Save & Apply**-Block ist der einzige aktive Speichereinstieg; ein zusätzlicher Formular-Button wird nicht mehr benötigt.
- Werte werden direkt als UCI-Konfiguration geschrieben.
- Die rpcd-ACL enthält dafür explizit UCI-Rechte auf `heizungpanel`; damit funktioniert `uci/get` und `uci/set` in LuCI ohne `ubus code 6 (Permission denied)`.
- Der frühere Batch-JSON-Speicherpfad ist weiterhin gegen Trennzeichenfehler beim Key/Value-Import abgesichert (TAB **und** Whitespace-Fallback).
- Der bekannte Fehler `Unsupported key: can_if can0` ist damit behoben.
