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
- Deploy-/Stabilitäts-Hilfsskripte

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

## Nutzung

1. LuCI öffnen: `Services -> Heizungpanel -> Panel`
2. Live-Daten kommen über `raw`-Topic.
3. Für Senden: auf `Services -> Heizungpanel -> Konfiguration` `write_mode=1` setzen.

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
