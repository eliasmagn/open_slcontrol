# open_slcontrol (Slim Panel)

Schlanke OpenWrt/LuCI-App für ein stark reduziertes Heizungs-Panel:

- **Panel** (Live-Ansicht + Tasten senden bei aktivem Write-Mode)
- **Konfiguration** (nur Kern-Parameter)
- **Raw-first Runtime** (ein Bridge-Prozess + Bootstrap-Datei)

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
- `www/cgi-bin/heizungpanel_stream` – SSE-Stream (`raw` + `bootstrap`)
- `usr/libexec/heizungpanel/raw_bridge.sh` – CAN->MQTT raw + Bootstrap-Datei
- `usr/libexec/heizungpanel/state.sh` – Bootstrap-Antwort
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

### Aktueller LED-/Modus-Stand (Panel)

- Die Modus-/Power-LEDs im Panel werden jetzt **direkt aus CAN `0x320 83xx`** abgeleitet.
- Es gibt **kein persistentes Frontend-Latch** mehr, das länger als der eingehende `0x320 83xx`-Rhythmus hält.
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
