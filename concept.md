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

## Umsetzungsreihenfolge (aktuell)
1. **M1 Stabilität abschließen:** CAN-Reconnect und Restart/Long-run-Stresstest als Gate vor weiteren Features.
2. **Runtime-Knobs vollständig machen:** verbleibende UCI/UI-Konfiguration (v. a. Polling-Intervall).
3. **Sicherheits-Gate vor Write-Pfad:** optionaler UCI-Write-Mode (default off) + strikte Allowlist.
4. **M2 Protokoll-Engineering:** strukturierte Dumps, versioniertes Mapping, Hypothesenvalidierung.
5. **M3 Packaging/Distribution:** Feed-Struktur und reproduzierbarer Install-/Upgradepfad.
