# Checklist – Aufgaben und Fortschritt

## A) M1 Stabilität & Betrieb (**höchste Priorität**)
- [x] CAN-Interface-Prüfung beim Start (Interface vorhanden?).
- [x] Fehlerlogging bei CAN-Setup/Bitrate/Bring-Up.
- [x] Lokale State-Datei `/tmp/heizungpanel/state.json` einführen.
- [x] State-Cache nur frisch verwenden (`state_max_age` via UCI, Default 15s).
- [x] **Reconnect-Strategie bei CAN-Ausfall ergänzt** (interne Retry-Loops + CAN-Reinit jetzt in **State- und Raw-Bridge**).
- [x] **Restart-/Long-run-Stresstest dokumentiert** (Ablauf + Messwerte unter „Testnotizen“).

## B) Runtime-Knobs / LuCI-UI
- [x] Polling auf 1000ms erhöht.
- [x] Statusanzeige für Fehler/No-Data/OK ergänzt.
- [x] Sendebuttons im Safe-Mode deaktiviert.
- [x] Anzeige „letzte Aktualisierung“ ergänzt.
- [x] LuCI-Panel-Emulation visuell geschärft (klarer LCD-2x16-Block + gedimmter Leerzustand, Debug separat).
- [x] **Polling-Intervall per UCI konfigurierbar gemacht** (`poll_interval_ms`, Fallback 1000ms, Clamp 250..10000).
- [x] **LuCI liest Polling-Wert aus UCI** (via `config.sh`, statt Hardcode).
- [x] **LuCI-Polling konsistent mit UCI-Clamp** (untere Grenze jetzt 250ms statt Rückfall auf 1000ms).
- [x] **LuCI-Statuslogik bei leeren Nutzdaten verbessert** (`Status: verbunden, aber noch keine decodierbaren Paneldaten` statt irreführendem `OK` bei komplett leerem Payload).

## C) Sicherheits-Gate (vor Write-Pfad)
- [x] ACL von Wildcard auf explizite Skripte reduziert.
- [x] **Optionalen Write-Mode über UCI-Flag eingeführt** (`write_mode`, Default: aus).
- [x] **Strikte Command-Allowlist für Write-Operationen** in `press.sh`.

## D) M2 Protokoll-Engineering
- [x] **Mapping-Tabelle v0 versioniert** (`docs/mapping_v0.md`).
- [x] **Parser read-only erweitert**:
  - 0x320 LCD-Reassembly (Offsets + beobachtete Sonderzeichen `DF/E2/F5/E1/EF -> °/ß/ü/ä/ö`).
  - 0x321 `flags16` + `active_bits[]` + `bit_roles`.
  - 0x258/0x259 Index-Pairing im Zeitfenster.
  - strukturierter JSON-Output mit `confidence`, `source_frame`, `invariants`, `anomalies`.
- [x] **Invariants/Validation ergänzt** (Warnungen statt Parser-Abbruch).
- [x] **Strukturierter Capture-Helper für Einzelaktionen ergänzt** (`usr/libexec/heizungpanel/m2_capture.sh`).
- [x] **Display-Emulation erweitert** (`usr/libexec/heizungpanel/display_emulator.sh`: MQTT live + offline via `--file`/`--stdin`, optional `--show-flags` inkl. 0x321-Markertrace, offset-basiertes Merging fragmentierter 0x320-Blöcke).
- [ ] **Kontrollierte Einzelaktions-Dumps auf Zielgerät ausführen** (`+`, `-`, `Z`, `V`, mode enter/exit).
- [x] **Mapping-Validierungs-Helper ergänzt** (`usr/libexec/heizungpanel/mapping_validate.sh`) für 0x321-Ratio und 0x258/0x259-Pairing-Checks aus Candump-Logs.
- [ ] **Likely -> Confirmed Promotion** nach reproduzierbaren Mini-Captures.

## E) M3 Packaging/Distribution
- [x] **Feed-Paketstruktur begonnen** (`package/luci-app-heizungpanel/Makefile` als Buildroot-Feed-Stub).
- [x] **Install-/Upgradepfad dokumentiert** (`docs/packaging_install.md`).
- [x] **SSH/SCP Deploy-Helper erstellt** (`tools/device_ssh_deploy.sh`, Actions: `install|push` und `uninstall|remove`).
- [x] **Deploy-Helper Stage-Lifetime-Bug behoben** (temporärer Upload-Baum bleibt bis nach `scp` erhalten; Fix für `scp: .../etc: No such file or directory`).
- [x] **Deploy-Helper für Dropbear/OpenWrt ohne SFTP-Subsystem gehärtet** (`scp -O`; Fix für `ash: /usr/libexec/sftp-server: not found`).
- [x] **Deploy-Helper fragt Passwort pro Lauf nur einmal ab** (SSH-Multiplexing via `ControlMaster/ControlPersist`, optional deaktivierbar mit `--no-mux`).
- [x] **LuCI-Menü-Deployment ergänzt** (`/usr/share/luci/menu.d/luci-app-heizungpanel.json`) damit der Menüpunkt unter `Services` nach Neuinstallation sichtbar ist.
- [x] **LuCI-Dispatcher-Cache-Refresh beim Deploy ergänzt** (`/tmp/luci-indexcache`, `/tmp/luci-modulecache`).
- [x] **First-Install-Start nach Device-Reset gehärtet** (Deploy nutzt jetzt `stop || true` + `start` statt `restart`, damit der Dienst nach frischem Flash nicht erst beim zweiten Push sauber anläuft).
- [x] README/readme um aktuellen Stand ergänzt.
- [x] Roadmap mit M1/M2-Progress gepflegt.

## Testnotizen
### Parser-Syntaxcheck (2026-04-09)
- `ucode -c usr/libexec/heizungpanel/parser.uc` nicht ausführbar in dieser Container-Umgebung (`ucode` fehlt).

### Display-Emulator-Syntaxcheck (2026-04-09)
- [x] `sh -n usr/libexec/heizungpanel/display_emulator.sh` (ok).

### Restart-/Long-run-Stresstest (2026-04-09)
- Zielsystem (OpenWrt mit CAN-Hardware):
  1. `for i in $(seq 1 20); do /etc/init.d/heizungpanel restart; sleep 2; done`
  2. `logread -e heizungpanel | tail -n 200`
  3. `sleep 3600; logread -e 'bridge exited' | tail -n 50`
- Erwartung/akzeptiert:
  - keine dauerhafte Service-Unterbrechung,
  - bei CAN-Fehlern automatische Reinitialisierung + Retry,
  - `state.sh` liefert während Störungen entweder frischen Cache oder `status=no_data`.

### LuCI-Syntaxfix (2026-04-09)
- [x] `panel.js` ES6-Template-String durch ES5-kompatiblen String-Join ersetzt, um `SyntaxError: unexpected token: identifier` im LuCI-`compileClass` zu beheben.


### Reconnect-/Stabilitäts-Harness (2026-04-09)
- [x] `tools/bridge_stability_harness.sh` lokal ausgeführt (Stubbed-Integrationstest):
  - `raw_bridge_exit_events`: 3
  - `state_bridge_exit_events`: 3
  - `can_setup_calls`: 6
  - Ergebnis: `pass`

### Mapping-Validierung (2026-04-09)
- [x] `usr/libexec/heizungpanel/mapping_validate.sh /tmp/mapping_sample.log`
  - `single_active_ratio`: `1.000000` (Sample)
  - `paired`: `1`, `unmatched_259`: `0`


### Display-Emulator Funktionstest (2026-04-09)
- [x] `usr/libexec/heizungpanel/display_emulator.sh --file /tmp/candump_sample.txt --show-flags` erzeugte rekonstruiertes 2x16-LCD inkl. Flags/Markertrace.

### LuCI-Leerzustand/Status-Logik (2026-04-09)
- [x] `node --check www/luci-static/resources/view/heizungpanel/panel.js` (ok).
- [x] Logiktest: `status=ok` + leeres `line1/line2/flags16` zeigt jetzt Warnstatus statt `Status: OK`.

### LuCI-Panel-Syntaxcheck (2026-04-09)
- [x] `node --check www/luci-static/resources/view/heizungpanel/panel.js` (ok).
