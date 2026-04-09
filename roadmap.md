# Roadmap – open_slcontrol

## M1 – Betriebsstabilität (in Arbeit)
**Ziel:** Solider 24/7-Read-only-Betrieb.

### Erledigt
- CAN-Start prüft Interface und loggt Fehler.
- State-Cache via `/tmp/heizungpanel/state.json` aktiv.
- Frischeprüfung für Cache (`state_max_age`) aktiv.
- UI-Status für `OK` / `keine Daten` / `Fehler` vorhanden.
- „Letzte Aktualisierung“ im UI sichtbar.
- ACL auf notwendige Skripte eingeschränkt.

### Offen
- Reconnect bei CAN-Ausfall.
- Belastungstest (Restart/Long-run) + Messwerte.

## M2 – Datenqualität & Mapping
- Strukturierte Dump-Kampagne.
- Versionierte Mappingtabellen.
- Parserfelder mit Qualitätsstufe (bestätigt/unbestätigt).

## M3 – Packaging/Distribution
- Feed/ImageBuilder-reife Paketstruktur.
- Reproduzierbare Installation und Upgradepfad.

## M4 – Optionaler Write-Mode
- Nur mit UCI-Freigabe.
- Allowlist + Audit-Logging.

## M5 – Dokumentationssynchronität
- Verbindliche Docs-Sync-Checkliste in der Contribution-Doku verankern.
- PR-Standard: Doc-Impact-Note mit aktualisierten Dateien und Begründung.

