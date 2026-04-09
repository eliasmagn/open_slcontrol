# Checklist – Aufgaben und Fortschritt

## A) M1 Stabilität & Betrieb (**höchste Priorität**)
- [x] CAN-Interface-Prüfung beim Start (Interface vorhanden?).
- [x] Fehlerlogging bei CAN-Setup/Bitrate/Bring-Up.
- [x] Lokale State-Datei `/tmp/heizungpanel/state.json` einführen.
- [x] State-Cache nur frisch verwenden (`state_max_age` via UCI, Default 15s).
- [x] **Reconnect-Strategie bei CAN-Ausfall ergänzt** (interne Retry-Loops + CAN-Reinit im State-Bridge-Prozess).
- [x] **Restart-/Long-run-Stresstest dokumentiert** (Ablauf + Messwerte unter „Testnotizen“).

## B) Runtime-Knobs / LuCI-UI
- [x] Polling auf 1000ms erhöht.
- [x] Statusanzeige für Fehler/No-Data/OK ergänzt.
- [x] Sendebuttons im Safe-Mode deaktiviert.
- [x] Anzeige „letzte Aktualisierung“ ergänzt.
- [x] **Polling-Intervall per UCI konfigurierbar gemacht** (`poll_interval_ms`, Fallback 1000ms, Clamp 250..10000).
- [x] **LuCI liest Polling-Wert aus UCI** (via `config.sh`, statt Hardcode).

## C) Sicherheits-Gate (vor Write-Pfad)
- [x] ACL von Wildcard auf explizite Skripte reduziert.
- [x] **Optionalen Write-Mode über UCI-Flag eingeführt** (`write_mode`, Default: aus).
- [x] **Strikte Command-Allowlist für Write-Operationen** in `press.sh`.

## D) M2 Protokoll-Engineering
- [x] **Mapping-Tabelle v0 versioniert** (`docs/mapping_v0.md`).
- [x] **Parser read-only erweitert**:
  - 0x320 LCD-Reassembly (Offsets + Sonderzeichen `DF`).
  - 0x321 `flags16` + `active_bits[]` + `bit_roles`.
  - 0x258/0x259 Index-Pairing im Zeitfenster.
  - strukturierter JSON-Output mit `confidence`, `source_frame`, `invariants`, `anomalies`.
- [x] **Invariants/Validation ergänzt** (Warnungen statt Parser-Abbruch).
- [ ] **Kontrollierte Einzelaktions-Dumps** (v0 aus vorhandenem Dump extrahiert, echte Kampagne noch offen).
- [ ] **Likely -> Confirmed Promotion** nach reproduzierbaren Mini-Captures.

## E) M3 Packaging/Distribution
- [ ] **Feed-Paketstruktur vervollständigen**.
- [ ] **Reproduzierbaren Install-/Upgradepfad dokumentieren**.
- [x] README/readme um aktuellen Stand ergänzt.
- [x] Roadmap mit M1/M2-Progress gepflegt.

## Testnotizen
### Parser-Syntaxcheck (2026-04-09)
- `ucode -c usr/libexec/heizungpanel/parser.uc` nicht ausführbar in dieser Container-Umgebung (`ucode` fehlt).

