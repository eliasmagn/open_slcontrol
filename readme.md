# open_slcontrol

OpenWrt/LuCI-App für Lindner & Sommerauer SL über CAN.

## Aktueller Stand
Teilweise funktional und im Einsatz:
- LuCI-Seite ist sichtbar.
- CAN + `candump` funktionieren.
- Parser erzeugt State.
- State wird lokal gecacht (`/tmp/heizungpanel/state.json`).
- Cache wird nur bis zur konfigurierten Maximaldauer genutzt (`state_max_age`, Default 15s).

## Aktuelle Priorisierung
1. **M1 Stabilität finalisieren:** CAN-Reconnect + dokumentierter Restart/Long-run-Stresstest.
2. **Runtime-Knobs schließen:** Polling-Intervall per UCI/LuCI konfigurierbar machen.
3. **Sicherheits-Gate vor Write:** UCI-Write-Flag (default off) + strikte Write-Allowlist.
4. **M2 starten:** strukturierte Dumps, versioniertes Mapping, Hypothesenvalidierung.
5. **M3 vorbereiten:** Feed-Struktur und reproduzierbarer Install-/Upgradepfad.

## Betrieb
1. UCI prüfen (`/etc/config/heizungpanel`).
   - Optional: `option state_max_age '15'` (Sekunden für Cache-Frische).
2. Service starten: `/etc/init.d/heizungpanel start`.
3. LuCI öffnen und Status prüfen.

## Sicherheit
- Standard: Safe Read-only.
- Sendefunktionen in UI deaktiviert.
- ACL nur für benötigte Skripte (`state.sh`, `press.sh`).
- Write-Pfad bleibt gesperrt, bis UCI-Write-Flag + Allowlist umgesetzt sind.

## Relevante Dateien
- `concept.md` – Zielbild/Architektur + Umsetzungsreihenfolge.
- `checklist.md` – operative Aufgaben und Status.
- `roadmap.md` – Milestones und Fortschritt.
- `readme.md` – aktueller Betriebs-/Deploy-Stand.
