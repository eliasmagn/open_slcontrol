# Roadmap – open_slcontrol

## M1 – Betriebsstabilität (**in Arbeit, höchste Priorität**)
**Ziel:** Solider 24/7-Read-only-Betrieb als Freigabe-Gate für Folgephasen.

### Erledigt
- CAN-Start prüft Interface und loggt Fehler.
- State-Cache via `/tmp/heizungpanel/state.json` aktiv.
- Frischeprüfung für Cache (`state_max_age`) aktiv.
- UI-Status für `OK` / `keine Daten` / `Fehler` vorhanden.
- „Letzte Aktualisierung“ im UI sichtbar.
- ACL auf notwendige Skripte eingeschränkt.

### Offen (M1-Abschlusskriterien)
- Reconnect bei CAN-Ausfall (Bus/Interface-Failure).
- Restart-/Long-run-Stresstest mit dokumentiertem Ablauf und Ergebnissen.

## M1.5 – Runtime-Knobs in Config/UI
- Polling-Intervall in UCI modellieren.
- LuCI soll Polling-Wert aus UCI übernehmen (statt festem Wert).

## M2 – Datenqualität & Mapping (Start nach M1)
- Strukturierte Dump-Kampagne (Idle + kontrollierte Aktionen).
- Versionierte Mappingtabellen für `0x320/0x321/0x258/0x259/0x1F5`.
- Hypothesenvalidierung in Parser-Workflow integrieren.

## M3 – Packaging/Distribution
- Feed/ImageBuilder-reife Paketstruktur.
- Reproduzierbare Installation und definierter Upgradepfad.

## M4 – Optionaler Write-Mode (nur nach Security-Gate)
- UCI-Write-Flag (Default: aus).
- Strikte Command-Allowlist.
- Optional: Audit-Logging für Write-Aktionen.
