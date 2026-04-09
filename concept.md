# Konzept – open_slcontrol

## Ziel
Eine robuste OpenWrt/LuCI-App für Lindner & Sommerauer SL über CAN, mit stabilem Read-only-Betrieb als Standard und optionalem, abgesichertem Write-Modus.

## Ausgangslage
Die App ist bereits teilweise funktional:
- LuCI-WebGUI ist sichtbar und nutzbar.
- CAN-Interface startet.
- `candump` liefert Daten.

## Architektur (Soll)
1. Erfassung: `candump` auf `can_if`.
2. Parsing: `parser.uc` erzeugt JSON-State.
3. Verteilung: MQTT retain + lokaler Cache (`/tmp/heizungpanel/state.json`).
4. UI: LuCI liest `state.sh`, zeigt Status/Fallback sauber an.

## Leitlinien
- Bestehende Funktionalität erhalten.
- Safety-first (read-only default, minimale ACL).
- Schrittweise Härtung vor Feature-Ausbau.
- Dokumentation bleibt synchron: Protokoll-/Feature-Änderungen werden in `concept.md`, `checklist.md`, `roadmap.md` und `readme.md` nachgeführt.
