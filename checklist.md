# Checklist – Aufgaben und Fortschritt

## A) Stabilität & Betrieb
- [x] CAN-Interface-Prüfung beim Start (Interface vorhanden?).
- [x] Fehlerlogging bei CAN-Setup/Bitrate/Bring-Up.
- [x] Lokale State-Datei `/tmp/heizungpanel/state.json` einführen.
- [x] State-Cache nur frisch verwenden (`state_max_age` via UCI, Default 15s).
- [ ] Reconnect-Strategie bei CAN-Ausfall ergänzen.
- [ ] Restart-/Stress-Test dokumentieren.

## B) LuCI/UI
- [x] Polling auf 1000ms erhöht.
- [x] Statusanzeige für Fehler/No-Data/OK ergänzt.
- [x] Sendebuttons im Safe-Mode deaktiviert.
- [x] Anzeige „letzte Aktualisierung“ ergänzt.
- [ ] Polling per UCI konfigurierbar machen.

## C) Sicherheit
- [x] ACL von Wildcard auf explizite Skripte reduziert.
- [ ] Optionalen Write-Mode über UCI-Flag einführen.
- [ ] Command-Allowlist für Write-Mode.

## D) Protokoll-Engineering
- [ ] Strukturierte Referenzdumps (Idle + definierte Aktionen).
- [ ] Mapping-Tabelle für 0x320/0x321/0x258/0x259/0x1F5 versionieren.
- [ ] Validierungslogik für Hypothesen einbauen.

## E) Packaging/Docs
- [ ] Feed-Paketstruktur vervollständigen.
- [x] README/readme um aktuellen Stand ergänzt.
- [x] Roadmap mit M1-Progress gepflegt.

## F) PR-Dokumentationspflicht
- [ ] Jede PR enthält eine kurze **Doc-Impact-Note**: welche der vier Dateien (`concept.md`, `checklist.md`, `roadmap.md`, `readme.md`) wurden aktualisiert – und warum.

