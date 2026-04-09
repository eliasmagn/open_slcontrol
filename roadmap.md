# Roadmap – open_slcontrol

## M1 – Betriebsstabilität (**abgeschlossen am 2026-04-09**)
**Ziel:** Solider 24/7-Read-only-Betrieb als Freigabe-Gate für Folgephasen.

### Erledigt
- CAN-Start prüft Interface und loggt Fehler.
- State-Cache via `/tmp/heizungpanel/state.json` aktiv.
- Frischeprüfung für Cache (`state_max_age`) aktiv.
- UI-Status für `OK` / `keine Daten` / `Fehler` vorhanden.
- „Letzte Aktualisierung“ im UI sichtbar.
- ACL auf notwendige Skripte eingeschränkt.
- Reconnect bei CAN-Ausfall (Retry-Loops + CAN-Reinit im State-Bridge-Prozess).
- Restart-/Long-run-Stresstest durchgeführt und dokumentiert.

## M1.5 – Runtime-Knobs in Config/UI (**abgeschlossen am 2026-04-09**)
- Polling-Intervall in UCI modelliert (`poll_interval_ms`).
- LuCI übernimmt Polling-Wert aus UCI statt Hardcode.

## Security Gate vor Write-Pfad (**abgeschlossen am 2026-04-09**)
- UCI-Write-Flag (`write_mode`, Default aus).
- Strikte Command-Allowlist in `press.sh`.
- UI bleibt default read-only, Write nur bei aktivem Flag.

## M2 – Datenqualität & Mapping (**nächster Fokus**)
- Strukturierte Dump-Kampagne (Idle + kontrollierte Aktionen).
- Versionierte Mappingtabellen für `0x320/0x321/0x258/0x259/0x1F5`.
- Hypothesenvalidierung in Parser-Workflow integrieren.

## M3 – Packaging/Distribution
- Feed/ImageBuilder-reife Paketstruktur.
- Reproduzierbare Installation und definierter Upgradepfad.

## M4 – Optionaler Write-Mode (nach Mapping/Validierung)
- Mappingbasierter Sendepfad auf Basis Allowlist.
- Optional: Audit-Logging für Write-Aktionen.
