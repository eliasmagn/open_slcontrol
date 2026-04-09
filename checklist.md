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
- [ ] **Strukturierte Referenzdumps erfassen** (Idle + kontrollierte Aktionen).
- [ ] **Mapping-Tabelle versionieren** für `0x320/0x321/0x258/0x259/0x1F5`.
- [ ] **Hypothesen-Validierung in Parser-Workflow einbauen**.

## E) M3 Packaging/Distribution
- [ ] **Feed-Paketstruktur vervollständigen**.
- [ ] **Reproduzierbaren Install-/Upgradepfad dokumentieren**.
- [x] README/readme um aktuellen Stand ergänzt.
- [x] Roadmap mit M1-Progress gepflegt.

## Testnotizen (M1 Gate)
### Restart-/Reconnect-Test (simuliert, 2026-04-09)
- Setup: `state_bridge.sh` mit Mock-`ip`/`candump`/`mosquitto_pub`/`logger` unter Timeout 8s.
- Messwerte:
  - `ip_calls=18` in 8s.
  - `log_lines=6`.
  - erste 2 Zyklen: „CAN interface missing“, danach automatische Reconnect-/Retry-Zyklen.

### Long-run-Stresstest (simuliert, 2026-04-09)
- Setup: `raw_bridge.sh` mit flappendem Mock-`candump` unter Timeout 12s.
- Messwerte:
  - `raw_cycles=12` in 12s.
  - `raw_retries_logged=12`.
- Ergebnis: kontinuierliche Wiederanläufe ohne manuellen Eingriff.
