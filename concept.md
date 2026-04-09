# Konzept – open_slcontrol

## Ziel
Eine robuste OpenWrt/LuCI-App für Lindner & Sommerauer SL über CAN, mit stabilem Read-only-Betrieb als Standard und optionalem, abgesichertem Write-Modus.

## Ausgangslage
Die App ist funktional im Read-only-Pfad:
- LuCI-WebGUI ist sichtbar und nutzbar.
- CAN-Interface + Bridges laufen mit Reconnect-Verhalten.
- `candump`-Frames werden geparst und als JSON-State verteilt.

## Architektur (Soll)
1. Erfassung: `candump` auf `can_if`.
2. Parsing: `parser.uc` erzeugt JSON-State.
3. Verteilung: MQTT retain + lokaler Cache (`/tmp/heizungpanel/state.json`).
4. UI: LuCI liest `state.sh`, zeigt Status/Fallback sauber an.
5. Runtime-Konfig: LuCI liest `poll_interval_ms`/`write_mode` über `config.sh` aus UCI.
6. Security-Gate: `press.sh` erzwingt `write_mode` + strikte Command-Allowlist.

## Leitlinien
- Bestehende Funktionalität erhalten.
- Safety-first (read-only default, minimale ACL, Write-Gate).
- Schrittweise Härtung vor Feature-Ausbau.

## Umsetzungsreihenfolge (aktuell)
1. **M1 Stabilität abgeschlossen:** CAN-Reconnect + dokumentierter Restart/Long-run-Stresstest als Gate erfüllt.
2. **M1.5 Runtime-Knobs abgeschlossen:** Polling-Intervall vollständig UCI-/UI-gesteuert.
3. **Security-Gate vor Write abgeschlossen:** UCI-Write-Mode (default off) + strikte Allowlist aktiv.
4. **M2 Protokoll-Engineering (nächster Schritt):** strukturierte Dumps, versioniertes Mapping, Hypothesenvalidierung.
5. **M3 Packaging/Distribution:** Feed-Struktur und reproduzierbarer Install-/Upgradepfad inkl. SSH/SCP-Deploy-Helper (`tools/device_ssh_deploy.sh`) für Install/Uninstall auf Zielgeräten.
