# Checklist – Aufgaben und Fortschritt

## A) M1 Stabilität & Betrieb (**höchste Priorität**)
- [x] CAN-Interface-Prüfung beim Start (Interface vorhanden?).
- [x] Fehlerlogging bei CAN-Setup/Bitrate/Bring-Up.
- [x] Lokale State-Datei `/tmp/heizungpanel/state.json` einführen.
- [x] State-Cache nur frisch verwenden (`state_max_age` via UCI, Default 15s).
- [ ] **Reconnect-Strategie bei CAN-Ausfall ergänzen** (Bus/Interface-Failure behandeln).
- [ ] **Restart-/Long-run-Stresstest dokumentieren** (Ablauf + Ergebnisse).

## B) Runtime-Knobs / LuCI-UI
- [x] Polling auf 1000ms erhöht.
- [x] Statusanzeige für Fehler/No-Data/OK ergänzt.
- [x] Sendebuttons im Safe-Mode deaktiviert.
- [x] Anzeige „letzte Aktualisierung“ ergänzt.
- [ ] **Polling-Intervall per UCI konfigurierbar machen** (inkl. UI-Übernahme).

## C) Sicherheits-Gate (vor Write-Pfad)
- [x] ACL von Wildcard auf explizite Skripte reduziert.
- [ ] **Optionalen Write-Mode über UCI-Flag einführen** (Default: aus).
- [ ] **Strikte Command-Allowlist für Write-Operationen**.

## D) M2 Protokoll-Engineering
- [ ] **Strukturierte Referenzdumps erfassen** (Idle + kontrollierte Aktionen).
- [ ] **Mapping-Tabelle versionieren** für `0x320/0x321/0x258/0x259/0x1F5`.
- [ ] **Hypothesen-Validierung in Parser-Workflow einbauen**.

## E) M3 Packaging/Distribution
- [ ] **Feed-Paketstruktur vervollständigen**.
- [ ] **Reproduzierbaren Install-/Upgradepfad dokumentieren**.
- [x] README/readme um aktuellen Stand ergänzt.
- [x] Roadmap mit M1-Progress gepflegt.
