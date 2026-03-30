# open_slcontrol

OpenWrt/LuCI-App für Lindner & Sommerauer SL über CAN.

## Aktueller Stand
Teilweise funktional und im Einsatz:
- LuCI-Seite ist sichtbar.
- CAN + `candump` funktionieren.
- Parser erzeugt State.
- State wird jetzt zusätzlich lokal gecacht (`/tmp/heizungpanel/state.json`).
- Cache wird nur bis zur konfigurierten Maximaldauer genutzt (`state_max_age`, Default 15s).

## Betrieb
1. UCI prüfen (`/etc/config/heizungpanel`).
   - Optional: `option state_max_age '15'` (Sekunden für Cache-Frische).
2. Service starten: `/etc/init.d/heizungpanel start`.
3. LuCI öffnen und Status prüfen.

## Sicherheit
- Standard: Safe Read-only.
- Sendefunktionen in UI deaktiviert.
- ACL nur für benötigte Skripte (`state.sh`, `press.sh`).

## Relevante Dateien
- `concept.md` – Zielbild/Architektur.
- `checklist.md` – operative Aufgaben.
- `roadmap.md` – Milestones und Fortschritt.
- `readme.md` – aktueller Betriebs-/Deploy-Stand.
