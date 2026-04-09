# open_slcontrol

OpenWrt/LuCI-App für Lindner & Sommerauer SL über CAN.

## Aktueller Stand (2026-04-09)
Stabiler Read-only-Betrieb mit Runtime-Konfiguration und Security-Gate:
- LuCI-Seite sichtbar und funktionsfähig.
- CAN-Raw- und State-Bridge laufen mit Retry-Schleifen.
- State wird lokal gecacht (`/tmp/heizungpanel/state.json`) und per MQTT retained publiziert.
- Cache wird nur bis `state_max_age` verwendet (Default 15s).
- Polling-Intervall ist via UCI konfigurierbar (`poll_interval_ms`, Clamp 250..10000).
- Write-Mode ist via UCI standardmäßig aus (`write_mode=0`) und in `press.sh` allowlist-gesichert.

## Priorisierung
1. **M2 starten:** strukturierte Dumps, versioniertes Mapping, Hypothesenvalidierung.
2. **M3 vorbereiten:** Feed-Struktur und reproduzierbarer Install-/Upgradepfad.

## Betrieb
1. UCI prüfen (`/etc/config/heizungpanel`):
   - `option state_max_age '15'`
   - `option poll_interval_ms '1000'`
   - `option write_mode '0'`
2. Service starten: `/etc/init.d/heizungpanel start`.
3. LuCI öffnen und Status prüfen.

## Security
- Standard: Safe Read-only.
- Sendefunktionen bleiben deaktiviert, solange `write_mode=0`.
- Bei `write_mode=1` akzeptiert `press.sh` ausschließlich Befehle aus einer festen Allowlist.
- Ein tatsächlicher CAN-Write erfolgt weiterhin erst nach implementierter Frame-Mapping-Logik.

## Restart-/Long-run-Stresstest (M1 Gate)
### 1) Restart-/Reconnect-Test (simuliert)
- Datum: **2026-04-09**
- Methode: `state_bridge.sh` mit Mock-Binaries (`ip`, `candump`, `mosquitto_pub`, `logger`) unter `timeout 8s`.
- Ergebnis:
  - `ip_calls=18`
  - `log_lines=6`
  - initiale Interface-Fehler wurden automatisch behandelt, anschließend fortlaufende Retry-Zyklen.

### 2) Long-run-Stresstest (simuliert)
- Datum: **2026-04-09**
- Methode: `raw_bridge.sh` mit flappendem `candump`-Mock unter `timeout 12s`.
- Ergebnis:
  - `raw_cycles=12`
  - `raw_retries_logged=12`
  - kontinuierlicher Selbst-Recovery-Zyklus ohne manuellen Restart.

## Relevante Dateien
- `concept.md` – Zielbild/Architektur + Umsetzungsreihenfolge.
- `checklist.md` – operative Aufgaben und Status.
- `roadmap.md` – Milestones und Fortschritt.
- `readme.md` – aktueller Betriebs-/Deploy-Stand.
