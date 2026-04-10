# Checklist – Aufgaben und Fortschritt

## Update 2026-04-10 – Bootstrap/Livedecode-Härtung
- [x] Bootstrap-Hydration im LuCI-Decoder ergänzt: Snapshot-Zeilen werden in den internen `lcd[]`-Puffer übernommen (nicht nur ins DOM gerendert).
- [x] Retained Bootstrap setzt beim Initialzustand zusätzlich `mode_flags16` und `mode_code`, sodass der erste `renderLive()` konsistent bleibt.
- [x] Frühes Leer-Rendern verhindert: erste `0x321`-/`0x83`-Frames überschreiben den Snapshot nicht mehr mit Blankwerten.

## Update 2026-04-10 – Runtime-Trim (True Raw-first)
- [x] `state.sh` so angepasst, dass der optionale Legacy-Topicabruf (`<mqtt_base>/state`) erst bei fehlendem `mode`/`snapshot` ausgeführt wird.
- [x] `state_bridge.sh` als Legacy-Vollstatepfad im Startlog klar gekennzeichnet.
- [x] Doku-Korrektur in `concept.md`/`roadmap.md`/`readme.md`: Produktionspfad bleibt browserseitiges Raw-Decoding.

## Update 2026-04-10 – Raw-first Architekturshift
- [x] SSE-Default auf Raw umgestellt (`/cgi-bin/heizungpanel_stream` -> `<mqtt_base>/raw`).
- [x] Neue retained Nebenkanäle eingeführt: `<mqtt_base>/mode` und `<mqtt_base>/snapshot`.
- [x] Neue Lightweight-Dienste ergänzt: `mode_bridge.sh` und `snapshot_bridge.sh`.
- [x] Init-Runtime per UCI-Schalter aufteilbar gemacht (`publish_raw/publish_mode/publish_snapshot/publish_state`).
- [x] Default-Runtime auf raw-first gesetzt (`publish_state=0` als Debug-Opt-in).
- [x] LuCI-Panel auf Raw-Livedecode + Bootstrap (`state.sh`) umgestellt.
- [x] Begriffstrennung geschärft: raw stream vs mode retain vs snapshot retain vs optional full state.


## A) M1 Stabilität & Betrieb (**höchste Priorität**)
- [x] CAN-Interface-Prüfung beim Start (Interface vorhanden?).
- [x] Fehlerlogging bei CAN-Setup/Bitrate/Bring-Up.
- [x] Lokale State-Datei `/tmp/heizungpanel/state.json` einführen.
- [x] State-Cache nur frisch verwenden (`state_max_age` via UCI, Default 15s).
- [x] **LuCI-Stateabruf auf MQTT-Stream umgestellt** (kein Dateicache mehr im `state.sh`; reduziert Latenz und vermeidet Stale-Reads).
- [x] **Init-/Bridge-Aufruf entschlackt** (`state_bridge.sh` wird ohne obsoletes Statefile-Argument gestartet).
- [x] **Reconnect-Strategie bei CAN-Ausfall ergänzt** (interne Retry-Loops in den Bridges; CAN-Setup bleibt ausschließlich im Init-Skript).
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
- [x] **Default-Polling für geringere Latenz gesenkt** (Default jetzt 500ms in UCI/`config.sh`/LuCI-Fallback).
- [x] **Push-Transport für LuCI ergänzt** (SSE-Bridge via `/www/cgi-bin/heizungpanel_stream`, EventSource im Frontend statt Intervall-Polling).
- [x] **Clientseitiges Frame-Decoding ergänzt** (`panel.js` parst `0x320/0x321/0x1F5` direkt aus Raw-Stream, reduziert Parser-/State-Last auf dem Router für die UI-Anzeige).
- [x] **LuCI-Statuslogik bei leeren Nutzdaten verbessert** (`Status: verbunden, aber noch keine decodierbaren Paneldaten` statt irreführendem `OK` bei komplett leerem Payload).
- [x] **LuCI-Zeitstempel gegen Parser-Drift gehärtet** (bei >5 Min Abweichung wird Browserzeit als „Letzte Aktualisierung“ genutzt).
- [x] **0x321-LED/Modus-Mapping im LuCI aktiviert** (Mode-LEDs + Klartext-Hinweis je `flags16`).
- [x] **Konfigurations-Switch im LuCI ergänzt** (unter dem Read-only-Hinweis: `Send mode`, persistiert via UCI + Service-Restart).
- [x] **Parser-Inputformat erweitert** (zusätzliche timestampbasierte Candump-Variante mit `[len] bytes` wird korrekt geparst; Fix für fehlende LCD-Texte trotz sichtbarer 0x320-Frames).
- [x] **Bridge-Eingabeformat auf `candump -a -t a -x` vereinheitlicht** (Raw-/State-Bridge nutzen jetzt dasselbe Format wie Feld-Debugdumps; optional über `CANDUMP_ARGS` übersteuerbar).
- [x] **Parser gegen ASCII-Suffixe aus `candump -x` gehärtet** (quoted Textspalte wird vor Byte-Extraktion abgeschnitten, um Fehlmatches in der Hex-Erkennung zu vermeiden).
- [x] **LCD-Zeichenrendering für deutsches Panel gesetzt** (ASCII `0x20..0x7E` + `0xDF -> °`, `0xE2 -> ß`, `0xF5 -> ü`, `0xE1 -> ä`, `0xEF -> ö`).
- [x] **UI-Fehlermeldung für noch offene Send-Mappings entschärft** (`press.sh` Exitcode 4 wird als Hinweis statt als „Send failed“ angezeigt).
- [x] **Redundante `listen_only`-Konfig entfernt** (wird zur Laufzeit aus `write_mode` abgeleitet).

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
- [x] **Sonderzeichen-Mapping auf deutsches Panel gesetzt** (`0xDF/0xE2/0xF5/0xE1/0xEF -> °/ß/ü/ä/ö`), damit LuCI/Emulator Feldtexte inklusive Umlaute darstellen.
- [ ] **Kontrollierte Einzelaktions-Dumps auf Zielgerät ausführen** (`+`, `-`, `Z`, `V`, mode enter/exit).
- [x] **Mapping-Validierungs-Helper ergänzt** (`usr/libexec/heizungpanel/mapping_validate.sh`) für 0x321-Ratio und 0x258/0x259-Pairing-Checks aus Candump-Logs.
- [x] **0x321-Isolations-Helper ergänzt** (`usr/libexec/heizungpanel/isolate_321.sh`) zur Auswertung „welche Flags16-Werte treten auf“ inkl. Kontextframes pro Wert.
- [ ] **Likely -> Confirmed Promotion** nach reproduzierbaren Mini-Captures.

## E) M3 Packaging/Distribution
- [x] **Feed-Paketstruktur begonnen** (`package/luci-app-heizungpanel/Makefile` als Buildroot-Feed-Stub).
- [x] **Install-/Upgradepfad dokumentiert** (`docs/packaging_install.md`).
- [x] **SSH/SCP Deploy-Helper erstellt** (`tools/device_ssh_deploy.sh`, Actions: `install|push` und `uninstall|remove`).
- [x] **Deploy-Helper Stage-Lifetime-Bug behoben** (temporärer Upload-Baum bleibt bis nach `scp` erhalten; Fix für `scp: .../etc: No such file or directory`).
- [x] **Deploy-Helper für Dropbear/OpenWrt ohne SFTP-Subsystem gehärtet** (`scp -O`; Fix für `ash: /usr/libexec/sftp-server: not found`).
- [x] **Deploy-Helper fragt Passwort pro Lauf nur einmal ab** (SSH-Multiplexing via `ControlMaster/ControlPersist`, optional deaktivierbar mit `--no-mux`).
- [x] **LuCI-Menü-Deployment ergänzt** (`/usr/share/luci/menu.d/luci-app-heizungpanel.json`) damit der Menüpunkt unter `Services` nach Neuinstallation sichtbar ist.
- [x] **Deploy-Menükompatibilität erweitert** (`/usr/share/luci-app-heizungpanel.json` wird beim Install/Uninstall ebenfalls mitgeführt), damit unterschiedliche LuCI-Menüladepfade auf Zielgeräten unterstützt bleiben.
- [x] **Deploy-Menüquelle entkoppelt** (Legacy-Menüpfad wird aus kanonischem `menu.d`-JSON gespiegelt), damit kein Inhalts-Drift zwischen zwei separaten Repo-Dateien entsteht.
- [x] **LuCI-Dispatcher-Cache-Refresh beim Deploy ergänzt** (`/tmp/luci-indexcache`, `/tmp/luci-modulecache`).
- [x] **First-Install-Start nach Device-Reset gehärtet** (Deploy nutzt jetzt `stop || true` + `start` statt `restart`, damit der Dienst nach frischem Flash nicht erst beim zweiten Push sauber anläuft).
- [x] **Deploy-Fileliste ergänzt** (`set_mode.sh` und `isolate_321.sh` werden vom Install-Tool mit ausgerollt).
- [x] **Deploy-CLI gehärtet** (Pflichtwerte für `--port/--identity/--stage` werden validiert; klare Fehlermeldung bei fehlendem Argument).
- [x] **Config-Overwrite kontrollierbar gemacht** (`install|push` überschreibt `/etc/config/heizungpanel` nur noch mit `--overwrite-config`).
- [x] **Deploy-SCP-Aufrufargumente repariert** (`run_scp` reicht Source/Target wieder korrekt an `scp` durch; Fix für `scp usage`-Abbruch direkt nach `[2/4] Upload files via scp`).
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

### Zeichensatz-/Zeitanzeige-Hotfix (2026-04-09)
- [x] Parser/Display-Emulator: deutsches Panel-Mapping aktiv (`0xDF/0xE2/0xF5/0xE1/0xEF -> °/ß/ü/ä/ö`).
- [x] LuCI-Panel: „Letzte Aktualisierung“ fällt bei unplausibler `ts_ms`-Abweichung (>5 Min) auf Browserzeit zurück (`... (Browserzeit)`).

### 0x321-Clusteranalyse (2026-04-09)
- [x] `usr/libexec/heizungpanel/isolate_321.sh` hinzugefügt (Summary + Kontextblöcke pro `flags16`-Wert aus Candump-Logs).
- [x] Mapping aus Feldzuordnung in LuCI eingehängt (`FFFB/FF7F` Navigation, `7FFF/BFFF/DFFF/EFFF/F7FF/FBFF/FDFF` Mode-/Funktionshinweise).

### Candump-Format-Härtung (2026-04-10)
- [x] `sh -n usr/libexec/heizungpanel/raw_bridge.sh` (ok).
- [x] `sh -n usr/libexec/heizungpanel/state_bridge.sh` (ok).
- [x] `node --check www/luci-static/resources/view/heizungpanel/panel.js` (ok, unverändert aber Gegencheck für UI-Syntax).

### MQTT-only Stateabruf (2026-04-10)
- [x] `sh -n usr/libexec/heizungpanel/state.sh` (ok).
- [x] `sh -n usr/libexec/heizungpanel/state_bridge.sh` (ok, `tee` auf State-Datei entfernt).

### Entschlackung/Latency-Tuning (2026-04-10)
- [x] `sh -n etc/init.d/heizungpanel` (ok, obsolete Statefile-Pfade entfernt).
- [x] `sh -n usr/libexec/heizungpanel/config.sh` (ok, JSON-Ausgabe auf benötigte Felder reduziert).
- [x] `sh -n www/cgi-bin/heizungpanel_stream` (ok, SSE-CGI für Raw-MQTT-Frames).

## Update 2026-04-10 – Write-Mapping + dedizierte Config + MQTT-Safety
- [x] `press.sh`: echtes Send-Mapping für `v/z/boiler/uhr/dauer/uhr_boiler/aussen_reg/hand/pruef/quit` auf `0x321`-Payloads implementiert; unmappte erlaubte Codes liefern weiter Exitcode `4` (Hinweis statt Blindsendung).
- [x] TX-Audit ergänzt: erfolgreicher Send wird via `logger` protokolliert und optional nach `<mqtt_base>/tx` publiziert (`mosquitto_pub`, best effort).
- [x] Dedizierte LuCI-Konfig-Seite ergänzt: `Services -> Heizungpanel -> Konfiguration` mit App-/MQTT-/Safety-Feldern.
- [x] Serverseitige Config-Validierung ergänzt (`config_set.sh`) inkl. Range/Format-Checks für MQTT-/App-Parameter.
- [x] MQTT-Schutzmechanismus umgesetzt: `mqtt_protect_existing=1` blockiert Änderungen an MQTT-Kernfeldern, bis `mqtt_change_unlock=1` explizit gesetzt wurde; Unlock wird nach erfolgreicher Änderung automatisch auf `0` zurückgesetzt.
- [x] Commit-Scope-Schutz ergänzt: Konfig-Commit bricht ab, wenn ausstehende Änderungen außerhalb `heizungpanel.main.*` erkannt werden (kein versehentliches Mitschreiben anderer Instanzen/Sektionen).

## Update 2026-04-10 – MQTT-Schutzlogik zurückgebaut
- [x] `config_set.sh`: MQTT-Protection/Unlock-Logik entfernt (`mqtt_protect_existing`, `mqtt_change_unlock` entfallen).
- [x] Commit-Scope-Guard entfernt; Konfig-Flow nutzt wieder schlanken UCI-Standard-Commit für `heizungpanel`.
- [x] LuCI-Konfigseite vereinfacht (kein Safety-Block mehr, nur App/MQTT-Felder).

## Update 2026-04-10 – Send-Mode/Listen-Only Fix
- [x] CAN-Rekonfiguration setzt jetzt explizit `listen-only off`, wenn `write_mode=1` (statt implizit leerem Argument).
- [x] Fix zentral im Init-Startpfad (`etc/init.d/heizungpanel`) umgesetzt; Bridges bleiben reine Consumer/Publisher ohne eigenes CAN-Reconfigure.

## Update 2026-04-10 – Deploy-/Netzwerk-Schutz bei falschem `can_if`
- [x] CAN-Setup-Härtung: `etc/init.d/heizungpanel`, `raw_bridge.sh` und `state_bridge.sh` verweigern aktiv Nicht-CAN-Interfaces (`can*|vcan*|slcan*`), um versehentliches `ip link set <lan_if> down` zu verhindern.
- [x] Deploy-Härtung: `tools/device_ssh_deploy.sh` startet den Dienst bei `can_setup=1` nicht automatisch neu, falls `can_if` unsicher ist; stattdessen Warnung im Deploy-Output.
## Update 2026-04-10 – Feldabgleich Display/LED-Persistenz
- [x] LuCI-Display auf 2x20 umgestellt (Offset-/Reassembly-Pfade in Parser + Frontend angepasst), damit reale Zeilenlänge korrekt dargestellt wird.
- [x] Virtuelles Display-Blanking bei Textänderung ergänzt (kurzer Full-Clear vor Neurender), damit das Verhalten näher am echten Panel liegt.
- [x] Betriebsart-LEDs auf latched `mode_flags16` umgestellt (persistenter Modusstatus statt flüchtiger Tastenflags).
- [x] `state_bridge.sh` schreibt den letzten Parser-State wieder in `/tmp/heizungpanel/state.json` (`tee`), `state.sh` liest primär aus diesem Cache und fällt auf MQTT zurück.
- [x] Korrektur nach Feldfeedback: Display-Blanking wieder entfernt; Push-Rendering bleibt aktiv, nur Betriebsart-LEDs bleiben persistent (Latch).
- [x] JS-Renderer schreibt pro 0x320-Frame-Burst das komplette 2x20-Display neu (Start immer mit leerem 40-Char-Buffer), damit keine alten Zeichenreste/Ziffern sichtbar bleiben.

## Update 2026-04-10 – LuCI-Alerts entschärft (UX)
- [x] Wiederholte globale LuCI-Toastmeldungen bei Tastenklicks entfernt (kein „OK: v“-Stacking mehr am Seitenanfang).
- [x] Lokale Inline-Statusmeldung im Panel ergänzt (`hp-inline-msg`) mit reservierter Höhe, damit das Panel beim Feedback nicht springt.
- [x] Feedback ist jetzt kurzlebig je Schweregrad (OK ~1.2s, Hinweis ~2.2s, Fehler ~3.5s).

## Update 2026-04-10 – Display-Reassembly/Mode-Latch korrigiert
- [x] 0x320-Decoder in LuCI auf Markersteuerung umgestellt: `0x81` startet neuen Zyklus (Buffer-Clear), adressierte Segmente bauen den Frame auf, `0x83 <mode_byte>` schließt den Zyklus ab.
- [x] Segment-„Abhacken“ behoben: Buffer wird nicht mehr pro Teilsegment geleert, sondern nur bei explizitem `0x81` oder nach Fallback-Timeout.
- [x] `mode_code` (`0x83 EF/FB`) als zusätzlicher Diagnosehinweis aus dem Display-Protokoll verfügbar gemacht (ohne Vorrang gegenüber `0x321`).
- [x] Parser (`parser.uc`) liefert `mode_code` im JSON-State und übernimmt dieselbe `0x81`/`0x83`-Semantik für Polling-Fallback.
- [x] Feldfix `mode_code`-Deutung: `EF/FB` werden als Display-/Screenklasse behandelt (nicht als Anlagenmodus), damit Diagnosehinweise keine Betriebsarten vortäuschen.
- [x] Priorität korrigiert: LuCI bewertet zuerst `mode_flags16` (0x321-Latch) und nutzt `mode_code` nur noch als Fallback, damit bekannte Modi nicht durch Abschlussbytes übersteuert werden.
- [x] CAN-Priorität verschärft: Aktive Betriebsarten-LEDs werden ausschließlich aus `0x321 mode_flags16` gesetzt; `0x320 mode_code` dient nur noch als diagnostischer Hinweis.
- [x] Moduswechsel-Bestätigung ergänzt: Nach Sendebefehl wartet LuCI bis zu 8s auf passendes `0x321`-Flag und zeigt explizit „CAN-Bestätigung“ bzw. Timeout-Warnung.
- [x] 0x320-Deutung präzisiert: `83 EF`/`83 FB` werden im UI als Screen-/Displayklasse bezeichnet („kein Anlagenmodus“) statt als Modusname.
- [x] Build-Tag im Syslog ergänzt: `etc/init.d/heizungpanel`, `raw_bridge.sh` und `state_bridge.sh` loggen beim Start ein Commit-Label (`BUILD_TAG`), damit die laufende Version auf dem Zielgerät nachvollziehbar ist.

## Update 2026-04-10 – /tmp-Wachstum durch State-Cache gestoppt
- [x] `state_bridge.sh` schreibt den Cache nicht mehr per `tee` als Endlosdatei, sondern hält `/tmp/heizungpanel/state.json` strikt auf **eine** JSON-Zeile (latest state).
- [x] Atomares Cache-Update (`.tmp` + `mv`) ergänzt, damit `state.sh` keine halben Schreibzustände liest.
- [x] Start-Truncate für `state_cache_file` ergänzt, damit vorhandene Altdateien beim Dienststart sofort freigegeben werden.

## Update 2026-04-10 – Parser-RegEx-Kompatibilitätsfix (Crash-Loop)
- [x] `parser.uc`: Candump-Format-RegEx auf ucode-kompatible Variante ohne `(?:...)` umgestellt.
- [x] Capture-Group-Indices angepasst (`id/want/tail`), damit Parsing auf Zielsystemen ohne Regex-Feature-Support wieder stabil läuft.
- [x] Folgewirkung: State-Bridge-Exit-Loop durch Parser-Syntaxfehler beendet (kein permanentes Reconnect-Stakkato mehr).

## Update 2026-04-10 – Konsolidierung offene Strukturpunkte
- [x] Deploy-Dateiliste vervollständigt (`tools/device_ssh_deploy.sh` liefert jetzt `config.js`, `config_get.sh`, `config_set.sh` mit aus und entfernt sie beim Uninstall wieder).
- [x] Konfig-Flow atomar gemacht (`config.js` -> ein Batch-Request; `config_set.sh` -> Validierung aller Felder, genau ein Commit + ein Restart).
- [x] CAN-Ownership auf Init-Skript reduziert (CAN-(Re)Setup aus `raw_bridge.sh` und `state_bridge.sh` entfernt).
- [x] Parser-Env-Vererbung stabilisiert (`state_bridge.sh` exportiert `CAN_IF`/`CAN_BITRATE` für `parser.uc`).
- [x] 2x20-Drift im Terminal-Emulator bereinigt (`display_emulator.sh` von 2x16 auf 2x20 umgestellt).


## Update 2026-04-10 – Konsolidierung Restpunkte (2. Runde)
- [x] Bridge-Startparameter entschlackt: `raw_bridge.sh` erhält nur noch `CAN_IF + MQTT-*`; `state_bridge.sh` nur `CAN_IF/CAN_BITRATE + MQTT-*` (kein totes `CAN_SETUP`/`LISTEN_ONLY` mehr).
- [x] Parser-Umgebungsübergabe gehärtet: `state_bridge.sh` setzt `CAN_IF`/`CAN_BITRATE` direkt am `ucode`-Aufruf in der Pipeline (prozesslokal, explizit).
- [x] Doku-Drift zwischen `README.md` und `readme.md` entschärft: `README.md` verweist nur noch auf `readme.md` als kanonische Quelle.
- [x] LuCI-Konfigcode bereinigt: tote Hilfsfunktion `inputRow()` und ungenutztes `require ui` aus `config.js` entfernt.

## F) Architektur-Konsolidierung (neu)
- [ ] **Decoder-Single-Source-of-Truth**: Browser-/Emulator-Decoder auf kanonische Backend-Decoderdaten umstellen.
- [ ] **Konfig-API vereinheitlichen**: `config.sh`/`config_get.sh`/`config_set.sh`/`set_mode.sh` hinter einer kanonischen API konsolidieren.
- [ ] **CAN-Ownership weiter härten**: genau ein Prozess darf `ip link ... can ...` steuern.
- [x] **State-Semantik stärken**: `state.sh` validiert jetzt JSON strukturell (jshn), ergänzt `schema_version`, `source`, `age_ms`, `seq` und fällt bei Ungültigkeit robust auf MQTT/`no_data` zurück.
- [ ] **Capability-Handshake einführen**: UI rendert Kommandos aus Backend-`supported_commands` statt statischer Annahmen.
- [ ] **Packaging als Install-Quelle**: Dateiliste zwischen Paket und SSH-Deploy aus einer Quelle erzeugen.
- [ ] **Stream-Auth in LuCI/rpcd integrieren**: Query-Token mittelfristig durch Session-gebundene Auth ersetzen.
- [ ] **Doku konsolidieren**: Doppelpflege zwischen `README.md`/`readme.md` abbauen.
- [x] **PR1 Teilschritt korrigiert auf Zielarchitektur:** LuCI-EventSource bleibt Raw-Decode-Produktionspfad; Backend-State ist optionaler Legacy-/Debugpfad.
