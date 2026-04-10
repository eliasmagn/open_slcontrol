# open_slcontrol

## Neu seit 2026-04-10 (Raw-first Architektur)
- **Primärer UI-Pfad:** Browser nutzt jetzt standardmäßig den Raw-SSE-Stream: `/cgi-bin/heizungpanel_stream?mode=raw&token=...` (ohne `mode` ebenfalls raw).
- **Embedded-Default entschlackt:** `publish_state=0` ist Default; die schwere Voll-Decodierung (`state_bridge.sh`) ist nur noch optional/debug.
- **Dauerzustand bleibt on-device:** neuer `mode_bridge.sh` hält `heizungpanel/mode` retained (latched `0x321 flags16` + Mode-Name).
- **Schneller First Paint:** neuer `snapshot_bridge.sh` hält `heizungpanel/snapshot` retained (2x20-Snapshot + `mode_code`) als Bootstrap.
- **Bootstrap-Endpoint:** `state.sh` liefert jetzt primär ein leichtes Bootstrap (`mode` + `snapshot`) und nutzt `.../state` nur als Kompat-/Debug-Fallback.
- **Saubere Topic-Trennung:**
  - live raw: `<mqtt_base>/raw`
  - retained mode/LED: `<mqtt_base>/mode`
  - retained display bootstrap: `<mqtt_base>/snapshot`
  - optional full decoded debug: `<mqtt_base>/state`
- **Neue UCI-Schalter:** `publish_raw`, `publish_mode`, `publish_snapshot`, `publish_state` (Default: `1/1/1/0`).


OpenWrt/LuCI-App für Lindner & Sommerauer SL über CAN.

## Aktueller Stand (2026-04-10)
Neu seit 2026-04-10 (Write/MQTT-Safety):
- `press.sh` enthält jetzt reale Send-Mappings für bestätigte Kommandos (u.a. `v/z/boiler/uhr/dauer/uhr_boiler/aussen_reg/hand/pruef/quit`) auf CAN `0x321`.
- Erfolgreiche TX-Sends werden als Audit nach Syslog und optional nach MQTT `<mqtt_base>/tx` publiziert.
- Dedizierte LuCI-Konfigseite unter **Services → Heizungpanel → Konfiguration** für App + MQTT + Safety wurde ergänzt.
- Neue serverseitige Konfig-Validierung und Schutzmechanismus gegen unbeabsichtigte MQTT-Umstellungen: `mqtt_protect_existing` + `mqtt_change_unlock` (One-shot).
- Commit-Scope-Guard: Konfigurationsänderungen werden nur übernommen, wenn keine ausstehenden UCI-Änderungen außerhalb `heizungpanel.main.*` vorhanden sind; dadurch werden andere MQTT-/UCI-Instanzen nicht mit verändert.

Stabiler Read-only-Betrieb mit Runtime-Konfiguration und Security-Gate plus **M2-v0.1 Parser/Mappings**:
- LuCI-Seite sichtbar und funktionsfähig.
- CAN-Raw- und State-Bridge laufen mit Retry-Schleifen ohne zusätzliche Bridge-seitige CAN-Rekonfiguration (Ownership im Init-Skript).
- State wird per MQTT retained publiziert; LuCI liest den Zustand direkt aus dem MQTT-State-Topic.
- LuCI liest den State jetzt direkt aus MQTT (`<mqtt_base>/state`) statt aus einem Dateicache; damit folgen Anzeige-Updates unmittelbar dem Stream.
- Optionaler MQTT-Wartewert für `state.sh`: `state_mqtt_wait` (UCI, Default `1` Sekunde).
- LuCI nutzt jetzt primär **Push via SSE** (`/cgi-bin/heizungpanel_stream`) statt festem Polling; neue Frames erscheinen direkt bei Eingang.
- Polling-Intervall ist via UCI konfigurierbar (`poll_interval_ms`, Clamp 250..10000), neuer Default: `500ms`.
- LuCI pollt mit dem aus UCI geladenen Intervall (inkl. Clamp 250..10000).
- LuCI zeigt unter dem Hinweisbereich einen Konfigurations-Switch für `Send mode` (`write_mode`); Änderungen werden in UCI gespeichert und der Dienst wird neu gestartet.
- LuCI zeigt den rekonstruierten LCD-Inhalt jetzt explizit als „LCD 2x20 (emuliert aus CAN 0x320)“ mit gedimmtem Fallback bei No-Data/Fehlern, sodass die Panel-Emulation klar vom Debug-Block getrennt ist.
- LuCI meldet bei formal `status=ok`, aber komplett leerem Payload (`line1/line2` leer, `flags16=----`) nun explizit einen Warnzustand („verbunden, aber noch keine decodierbaren Paneldaten“) statt irreführendem `Status: OK`.
- Write-Mode ist via UCI standardmäßig aus (`write_mode=0`) und in `press.sh` allowlist-gesichert.
- Parser reassembliert LCD-Zeilen aus `0x320` offsets, dekodiert `0x321` in `active_bits`/`bit_roles`, paart `0x258/0x259` über Index + Fenster und liefert Confidence-/Invariant-Metadaten. Das Rendering nutzt ASCII (`0x20..0x7E`) plus Panel-Sonderzeichen (`0xDF -> °`, `0xE2 -> ß`, `0xF5 -> ü`, `0xE1 -> ä`, `0xEF -> ö`).
- LuCI-Zeitstempel-Härtung: Wenn `ts_ms` aus dem State unplausibel von der Browserzeit abweicht (>5 Minuten), zeigt „Letzte Aktualisierung“ automatisch Browserzeit mit Suffix `(Browserzeit)`.
- LuCI-Mapping-Härtung: bekannte `0x321 flags16` werden live als Mode-LED und Klartext-Hinweis dargestellt (z. B. `DFFF=Boilerbetrieb`, `BFFF=Uhrzeitbetrieb`, `7FFF=Dauerbetrieb`, `FFFB/FF7F` als Navigation).
- Parser-Input-Härtung: Neben `ID#HEX` verarbeitet der Parser jetzt auch timestampbasierte Candump-Zeilen mit `[len] bytes` (can-utils-abhängig); dadurch landen 0x320-Textframes wie `Kesseltemp...` zuverlässig im State/UI.
- Bridge-Input vereinheitlicht: `raw_bridge.sh` und `state_bridge.sh` lesen standardmäßig via `candump -a -t a -x can0` (übersteuerbar per `CANDUMP_ARGS`), damit Live-Pfade exakt dem Debug-Dumpformat entsprechen.
- Parser-Härtung für `-x`-ASCII: Bei timestampbasierten Candump-Zeilen entfernt `parser.uc` die angehängte ASCII-Spalte (`'....'`) vor der Hex-Byte-Extraktion, damit keine Fehltreffer aus der Textdarstellung den LCD-Parser verfälschen.
- State-Bridge schreibt den JSON-State nicht mehr zusätzlich nach Datei; die Verteilung läuft direkt/retained über MQTT.
- Service-Entschlackung: Init-Skript übergibt kein obsoletes `state_file`-Argument mehr an `state_bridge.sh`; `config.sh` liefert nur noch die tatsächlich vom LuCI-Panel genutzten Felder (`poll_interval_ms`, `write_mode`).
- Clientseitiges Parsing: `panel.js` dekodiert `candump`-Rohzeilen (`0x320/0x321/0x1F5`) direkt im Browser; damit bleibt die Routerlast für die UI-Pipeline gering.
- UI-Sendehinweise: Wenn Write-Mode aktiv ist, aber für ein Kommando noch kein CAN-Send-Mapping existiert, zeigt LuCI einen Hinweis statt einer generischen „Send failed“-Meldung.
- Für strukturierte Einzelaktions-Captures steht `usr/libexec/heizungpanel/m2_capture.sh` bereit.
- Für schnelle Mapping-Checks aus Candump-Dateien steht `usr/libexec/heizungpanel/mapping_validate.sh` bereit (0x321- und 0x258/0x259-Validierung).
- Für die Frage „welche 0x321-Werte gibt es und welche Frames gehören dazu?“ steht `usr/libexec/heizungpanel/isolate_321.sh` bereit (Unique-Flags + Kontext pro `flags16`).
- Für eine schnelle Terminal-/Offline-Sicht auf das emulierte 2x20-Display steht `usr/libexec/heizungpanel/display_emulator.sh` bereit (liest MQTT-Raw, Candump-Dateien oder STDIN; optional mit `--show-flags` für 0x321-Markertrace).
- Deploy-Helper-Fix: `tools/device_ssh_deploy.sh` hält den lokalen Stage-Ordner jetzt korrekt bis nach dem Upload (Fix für `scp .../etc: No such file or directory`).
- Deploy-Helper-Fix: Upload nutzt erzwungen den klassischen SCP-Modus (`scp -O`) für OpenWrt/Dropbear-Ziele ohne SFTP-Server (Fix für `ash: /usr/libexec/sftp-server: not found`).
- Deploy-Helper-Fix: LuCI-Menüeintrag wird jetzt mit ausgerollt (`/usr/share/luci/menu.d/luci-app-heizungpanel.json`), damit die Ansicht nach Router-Reset/Neuinstallation wieder unter **Services** erscheint.
- Deploy-Helper-Fix: Zusätzlich wird jetzt auch `/usr/share/luci-app-heizungpanel.json` ausgerollt/entfernt, damit sowohl ältere als auch aktuelle LuCI-Menüladepfade konsistent bedient werden.
- Deploy-Helper-Härtung: Menü-JSON wird im Deploy aus einer kanonischen Quelle (`/usr/share/luci/menu.d/...`) gespiegelt, um Drift zwischen Legacy-/Current-Pfad zu vermeiden.
- Deploy-Helper-Fix: LuCI-Caches (`/tmp/luci-indexcache`, `/tmp/luci-modulecache`) werden beim Deploy bereinigt, damit neue Menüeinträge sofort sichtbar sind.
- Deploy-Helper-Härtung: Optionen mit Pflichtwert (`--port`, `--identity`, `--stage`) werden jetzt vorab validiert und liefern bei fehlendem Wert eine klare Fehlermeldung statt eines unsauberen `set -u`-Abbruchs.
- Deploy-Helper-Härtung: Install überschreibt `/etc/config/heizungpanel` standardmäßig nicht mehr; mit `--overwrite-config` kann ein erzwungenes Überschreiben aktiviert werden.
- Deploy-Helper-Fix: Service-Start nach frischem Reset/Erstinstallation gehärtet (`stop || true` + `start` statt `restart`), damit kein zweiter Push mehr nötig ist, wenn `ubus service delete ... (Not found)` beim ersten Lauf auftritt.
- Deploy-Helper-Fix: `tools/device_ssh_deploy.sh` rollt jetzt zusätzlich `usr/libexec/heizungpanel/set_mode.sh` und `usr/libexec/heizungpanel/isolate_321.sh` mit aus.
- Deploy-Helper-Fix: `run_scp` übergibt wieder korrekt Upload-Quellen und Ziel an `scp`; damit schlägt `install|push` bei Schritt `[2/4] Upload files via scp` nicht mehr mit der nackten `scp usage`-Ausgabe fehl.

## Neue Telemetrie-Felder (Parser v0)
Zusätzlich zu `line1`, `line2`, `flags16`, `last_1f5`:
- `source_frame`: laufende Parser-Frame-ID.
- `active_bits`: aktive (low) Bits aus `0x321`.
- `bit_roles`: pro Bit tentative Klassifikation (`event_button` / `status_latch` / `unknown`) inkl. Confidence.
- `pairing_258_259`: `observed_indices` und `latest_pairs` mit Index-Pairing.
- `confidence`: Confidence auf Block-Ebene (`lcd_320`, `flags_321`, `pairing_258_259`).
- `invariants`: Laufzeit-Validierung (`flags_single_active_low_ratio`, `offsets_outside_expected`, `unmatched_258`).
- `anomalies`: ringförmige Warnliste (Parser bleibt read-only und robust).

## M2-Artefakte (v0/v0.1)
- `docs/mapping_v0.md` – eingefrorene Mapping-Tabelle mit Confidence.
- `docs/campaign_v0.md` – Session-Protokoll aus vorhandenem Dump + Next-Steps.
- `usr/libexec/heizungpanel/m2_capture.sh` – helper für reproduzierbare Einzelaktions-Dumps inkl. Kurzsummary.
- `tools/device_ssh_deploy.sh` – SSH/SCP-Helper für Push/Install und Remove/Uninstall auf einem laufenden OpenWrt-Zielgerät.
- `docs/packaging_install.md` – aktueller Install-/Upgradepfad und Packaging-Struktur.

## Strukturierte M2-Captures ausführen (Zielgerät)
1. Zielordner vorbereiten:
   - `mkdir -p /tmp/heizungpanel/m2`
2. Je Aktion **einzeln** aufnehmen (8s Fenster, Aktion nach ~2s genau einmal drücken):
   - `usr/libexec/heizungpanel/m2_capture.sh /tmp/heizungpanel/m2 can0 8 idle`
   - `usr/libexec/heizungpanel/m2_capture.sh /tmp/heizungpanel/m2 can0 8 plus`
   - `usr/libexec/heizungpanel/m2_capture.sh /tmp/heizungpanel/m2 can0 8 minus`
   - `usr/libexec/heizungpanel/m2_capture.sh /tmp/heizungpanel/m2 can0 8 z`
   - `usr/libexec/heizungpanel/m2_capture.sh /tmp/heizungpanel/m2 can0 8 v`
   - `usr/libexec/heizungpanel/m2_capture.sh /tmp/heizungpanel/m2 can0 8 mode_enter`
   - `usr/libexec/heizungpanel/m2_capture.sh /tmp/heizungpanel/m2 can0 8 mode_exit`
3. Danach `*.summary.json` vergleichen und `docs/mapping_v0.md` von `likely` auf `confirmed` heben, sobald reproduzierbar.


## Mapping validieren (0x321 + 0x258/0x259)
- Zusammenfassung aus Candump-Log erzeugen:
  - `usr/libexec/heizungpanel/mapping_validate.sh /tmp/heizungpanel/m2/plus.log`
- Optionales Pairing-Fenster (Frames):
  - `usr/libexec/heizungpanel/mapping_validate.sh /tmp/heizungpanel/m2/plus.log 120`

Ausgabe enthält:
- `flags_321.single_active_ratio`
- `pairing_258_259.paired`, `unmatched_259`, `avg_delta_frames`
- `observed_indices`

## 0x321-Frames isolieren (gleiche Flags gruppieren)
- Summary + Kontext pro 0x321-Wert:
  - `usr/libexec/heizungpanel/isolate_321.sh /tmp/heizungpanel/m2/plus.log`
- Mit engerem Kontext und weniger Treffern pro Wert:
  - `usr/libexec/heizungpanel/isolate_321.sh /tmp/heizungpanel/m2/plus.log 10 3`

## Display emulieren (ohne physisches Panel)
Auf dem Zielgerät oder einem Host mit MQTT-Zugriff:

- Standard (lokaler Broker, Standardtopic):
  - `usr/libexec/heizungpanel/display_emulator.sh`
- Mit explizitem Broker/Topic:
  - `usr/libexec/heizungpanel/display_emulator.sh --host 192.168.1.10 --port 1883 --topic heizungpanel/raw`
- Offline aus Candump-Datei:
  - `usr/libexec/heizungpanel/display_emulator.sh --file /tmp/candump_sample.txt`
- Offline via Pipe/STDIN:
  - `cat /tmp/candump_sample.txt | usr/libexec/heizungpanel/display_emulator.sh --stdin`
- Mit 0x321-Flags-/Markertrace:
  - `usr/libexec/heizungpanel/display_emulator.sh --file /tmp/candump_sample.txt --show-flags`

Hinweise:
- Die Emulatoranzeige merged fragmentierte `0x320`-Blöcke über LCD-Offsets, bis beide 20er Zeilen konsistent aufgebaut sind.
- `--show-flags` blendet den letzten `flags16`-Wert und eine kurze `0x321`-Historie (aktive low-Bits) ein.

## Priorisierung
1. **M2 validieren:** echte Ein-Aktions-Dumps (Idle, +, -, Z, V, Mode enter/exit) und `likely -> confirmed`.
2. **M3 vorbereiten:** Feed-Struktur und reproduzierbarer Install-/Upgradepfad.

## Betrieb
1. UCI prüfen (`/etc/config/heizungpanel`):
   - `option state_mqtt_wait '1'`
   - `option poll_interval_ms '500'`
   - `option write_mode '0'`
2. Service starten: `/etc/init.d/heizungpanel start`.
3. LuCI öffnen und Status prüfen.
4. Für Push-Stream muss der SSE-Endpunkt erreichbar sein: `/cgi-bin/heizungpanel_stream?token=<stream_token>`.

## Deploy auf Zielgerät via SSH/SCP
Voraussetzungen lokal: `ssh`, `scp`.

- Install/Push:
  - `tools/device_ssh_deploy.sh install root@192.168.1.10`
  - Alias: `tools/device_ssh_deploy.sh push root@192.168.1.10`
  - Enthält jetzt automatisch den LuCI-Menüeintrag in `/usr/share/luci/menu.d/`, einen Cache-Refresh und einen robusten Erststart des Dienstes.
- Remove/Uninstall:
  - `tools/device_ssh_deploy.sh uninstall root@192.168.1.10`
  - Alias: `tools/device_ssh_deploy.sh remove root@192.168.1.10`

Optionen:
- `-p, --port <port>` SSH-Port.
- `-i, --identity <key>` SSH-Key.
- `-s, --stage <path>` Remote-Temp-Verzeichnis (Default `/tmp/open_slcontrol_deploy`).
- `--no-restart` kopiert/löscht Dateien ohne Service-Neustart.
- `--overwrite-config` überschreibt bei `install|push` die vorhandene `/etc/config/heizungpanel` explizit.
- Beim automatischen Restart wird `can_if` validiert; bei unsicherem Interface-Namen wird `heizungpanel` nicht gestartet (mit Warnmeldung statt Netzwerkausfall-Risiko).

## Security
- Standard: Safe Read-only.
- Sendefunktionen bleiben deaktiviert, solange `write_mode=0`.
- Bei `write_mode=1` akzeptiert `press.sh` ausschließlich Befehle aus einer festen Allowlist.
- Ein tatsächlicher CAN-Write erfolgt weiterhin erst nach implementierter Frame-Mapping-Logik.
- `listen_only` wird intern aus `write_mode` abgeleitet (`write_mode=0` => listen-only an, `write_mode=1` => listen-only aus), um redundante Konfiguration zu vermeiden.

## Relevante Dateien
- `concept.md` – Zielbild/Architektur + Umsetzungsreihenfolge.
- `checklist.md` – operative Aufgaben und Status.
- `roadmap.md` – Milestones und Fortschritt.
- `readme.md` – aktueller Betriebs-/Deploy-Stand.
- `docs/packaging_install.md` – Paket-/Installationsstruktur und Upgradepfad.

- Hotfix 2026-04-09: `www/luci-static/resources/view/heizungpanel/panel.js` auf ES5-kompatible String-Erzeugung umgestellt (kein Template-Literal mehr), um den Browserfehler `SyntaxError: unexpected token: identifier` beim Laden der LuCI-Seite zu eliminieren.


## Restart- und Long-run-Stabilitätstest (2026-04-09)
Lokal wurde ein Stubbed-Harness (`tools/bridge_stability_harness.sh`) gegen beide Bridges ausgeführt:
- `raw_bridge_exit_events`: 3
- `state_bridge_exit_events`: 3
- `can_setup_calls`: 6
- Ergebnis: `pass`

Hinweis: Das ist ein lokaler Reconnect-Loop-Test (ohne echte CAN-Hardware). Der 1h-Run auf Zielgerät bleibt weiterhin der Abnahmetest.

- Hotfix 2026-04-09: `www/luci-static/resources/view/heizungpanel/panel.js` ergänzt Plausibilitätsprüfung für leere Nutzdaten; Warnstatus wird angezeigt, wenn zwar Polling läuft, aber noch keine decodierbaren LCD-/Flag-Daten vorliegen.


Neu seit 2026-04-10 (Konsolidierung offener Punkte):
- SSH-Deploy-Dateisatz umfasst jetzt auch die dedizierte Konfigseite (`config.js`) sowie `config_get.sh`/`config_set.sh`; Install und Remove behandeln diese Dateien explizit.
- Konfigspeichern ist auf atomaren Batch-Flow umgestellt: LuCI sendet alle Felder in einem Request (`--batch-json`), Backend validiert alle Keys, führt genau **einen** `uci commit` und genau **einen** Service-Restart aus.
- CAN-Ownership bereinigt: Interface-Setup bleibt im Init-Skript; `raw_bridge.sh` und `state_bridge.sh` führen kein eigenes `ip link ... down/type/up` mehr aus.
- Parser-Umgebungsvariablen werden im State-Bridge-Prozess exportiert (`CAN_IF`, `CAN_BITRATE`) und damit zuverlässig an `parser.uc` vererbt.
- Display-Emulator ist auf 2x20/40 Zeichen aktualisiert und konsistent mit Parser/LuCI.

Neu seit 2026-04-10 (Vereinfachung):
- Zusätzliche MQTT-Schutz-/Unlock-Mechanik wurde entfernt; Konfigurationsänderungen laufen wieder über den normalen UCI-Flow.
- Die dedizierte LuCI-Konfigseite bleibt erhalten, ist aber auf App- und MQTT-Einstellungen reduziert.

Neu seit 2026-04-10 (Send-Mode-Fix):
- Beim CAN-(Re)Setup wird bei `write_mode=1` nun explizit `listen-only off` gesetzt (inkl. Bridge-Reinit-Pfade), damit Senden nicht an einem zuvor gesetzten Listen-only-Status hängen bleibt.

Neu seit 2026-04-10 (Deploy-/Netzwerk-Schutz):
- CAN-Setup verweigert jetzt explizit Nicht-CAN-Interfaces (`can*`, `vcan*`, `slcan*` sind erlaubt). Dadurch kann ein falsch gesetztes `can_if` nicht mehr versehentlich LAN/WAN-Interfaces herunterziehen.
- `tools/device_ssh_deploy.sh` überspringt den automatischen `heizungpanel`-Restart, wenn `can_setup=1` mit unsicherem `can_if` erkannt wird, und meldet stattdessen eine Warnung.
Neu seit 2026-04-10 (Feldabgleich Display/Status):
- Virtuelles LCD auf **2x20** erweitert (statt 2x16), inkl. angepasster Offset-Reassembly im Parser und im LuCI-Live-Decoder.
- Bei Inhaltsänderungen führt das virtuelle Display ein kurzes **Blanking** (Full-Clear) aus, damit das Umschalten sichtbarer am realen Gerät orientiert ist.
- Betriebsarten-LEDs nutzen jetzt einen **persistenten gelatchten Modusstatus** (`mode_flags16`) statt nur den letzten flüchtigen `flags16`-Eventwert.
- Der Daemon schreibt den letzten JSON-State wieder nach `/tmp/heizungpanel/state.json`; `state.sh` liest diesen Cache zuerst und nutzt MQTT als Fallback. Dadurch ist der Status beim ersten Öffnen der Weboberfläche stabil verfügbar.
- Korrektur: Das LuCI-Display rendert weiterhin direkt im Push-Betrieb ohne künstliches Blanking; persistent gelatcht werden nur die Betriebsarten-LEDs.
- Safety/Lesbarkeit: Die LuCI-Anzeige rendert 0x320 nun burstweise als vollständigen 2x20-Frame aus geleertem Buffer; dadurch bleiben keine alten Zeichenreste stehen, wenn Inhalte kürzer werden.

Neu seit 2026-04-10 (UX-Entschärfung Alerts):
- Wiederholte globale LuCI-Alarmboxen bei Tastendruck wurden im Panel-Pfad entfernt, damit die Seite nicht mit `OK: ...`-Meldungen vollläuft.
- Stattdessen gibt es eine lokale, kurzlebige Inline-Rückmeldung direkt im Panel (Erfolg/Hinweis/Fehler) mit reservierter Höhe, sodass das Frame nicht sichtbar verschoben wird.

Neu seit 2026-04-10 (Display-Reassembly-Korrektur):
- LuCI setzt das 0x320-LCD jetzt markerbasiert zusammen: `81` = neuer Bildschirminhalt/Buffer-Clear, danach adressierte Segmente, `83 <mode_byte>` = Abschlussframe.
- Dadurch bleibt der vorherige Zwischenstand während Segmentupdates erhalten; das Display wird nicht mehr pro Teilblock neu geleert und ist bei Uhrzeitbetrieb wieder lesbar.
- Der Parser (`usr/libexec/heizungpanel/parser.uc`) übernimmt dieselbe Semantik und liefert zusätzlich `mode_code` im JSON-State für Polling-Fallbacks.
- Bekannte Abschlussbytes (`83 EF`, `83 FB`) werden als Zusatzhinweis ausgewertet; die aktive Betriebsarten-LED bleibt jedoch an `0x321 mode_flags16` gebunden.
- Feldkorrektur Modus-Hinweis: `mode_code` (`83 EF`/`83 FB`) wird als Display-/Screenklasse dargestellt und nicht als Betriebsmodus benannt.
- Wichtig: Bei der LED-Entscheidung hat `mode_flags16` aus `0x321` jetzt Vorrang; `mode_code` aus `0x320` wird nur als Fallback verwendet.
- Strenger CAN-Fokus: Die Betriebsarten-LED selbst wird nur noch über `0x321 mode_flags16` aktiviert (Anlagenstatus). `mode_code` aus `0x320` wird nur als Hinweistext angezeigt und überschreibt den Latch nicht.
- Neu: Nach Modus-Sendebefehlen wartet die UI auf eine passende `0x321`-Rückmeldung der Anlage (Bestätigungsanzeige bei Treffer, Warnhinweis bei Timeout ohne passende CAN-Bestätigung).
- Präzisierung aus Feldfeedback: `83 EF`/`83 FB` werden als Display-/Screenklasse behandelt (z. B. Standardstatus vs. interaktiv/zweizeilig) und **nicht** als Heizungs-Betriebsmodus.
- Version im Syslog: Service/Bridges loggen beim Start ein `BUILD_TAG` (Commit-String), sodass die deployte Fassung im Log direkt erkennbar ist.

Neu seit 2026-04-10 (/tmp-Stabilitätsfix):
- `state_bridge.sh` nutzt für `state_cache_file` kein `tee`-Append mehr, sondern schreibt nur noch den jeweils letzten Parser-State in die Cache-Datei.
- Damit bleibt `/tmp/heizungpanel/state.json` konstant klein (eine Zeile) und kann den Router nicht mehr durch ungebremstes Dateiwachstum volllaufen lassen.
- Cache-Updates erfolgen atomar über temporäre Datei + `mv`; beim Start wird der Cache einmal truncatet.

Neu seit 2026-04-10 (Parser-Kompatibilitätsfix):
- `parser.uc` nutzt für Candump-Format-B nicht mehr die nicht überall unterstützte Regex-Form `(?:...)`.
- Dadurch verschwindet der wiederholte Laufzeitfehler `Syntax error: Repetition not preceded by valid expression` und die `state_bridge` fällt nicht mehr in einen Dauer-Restart-Loop.

Neu seit 2026-04-10 (Restkonsolidierung):
- Bridge-Parameter entschlackt: `raw_bridge.sh` und `state_bridge.sh` tragen keine toten CAN-Setup-Argumente (`CAN_SETUP`, `LISTEN_ONLY`) mehr.
- Parser-Env-Transfer gehärtet: `state_bridge.sh` setzt `CAN_IF` und `CAN_BITRATE` direkt am `ucode`-Prozess in der Pipeline.
- Doku-Doppelung entschärft: `README.md` ist jetzt bewusst nur ein Verweis auf diese Datei (`readme.md`) als Single Source of Truth.
- LuCI-Konfigcode bereinigt: ungenutztes `require ui` und tote `inputRow()` aus `config.js` entfernt.

## Neu seit 2026-04-10 (State-API-Härtung)
- `usr/libexec/heizungpanel/state.sh` validiert Cache-/MQTT-Inhalte jetzt strukturell per JSON-Parser (`jshn`) statt nur auf `{...}`-Muster.
- Jede erfolgreiche Antwort wird um versionierte Meta-Felder ergänzt:
  - `schema_version: 1`
  - `source: "cache" | "mqtt"`
  - `age_ms` (Alter relativ zu `ts_ms`, sonst `-1`)
  - `seq` (aus `source_frame`, falls vorhanden)
- Bei ungültigem Cache erfolgt sauberer Fallback auf MQTT; bei weiterhin ungültigen Daten wird ein expliziter `no_data`-State geliefert.

Diese Härtung ist die Grundlage für die nächste Konsolidierungsserie (Decoder-SSOT, API-Zusammenführung, CAN-Ownership-Zentralisierung).

## Neu seit 2026-04-10 (Decoder-SSOT Teilschritt)
- `www/cgi-bin/heizungpanel_stream` streamt standardmäßig `heizungpanel/state` (normalisierter Parser-State) statt `heizungpanel/raw`.
- Rohframes sind nur noch als Debugpfad verfügbar: `/cgi-bin/heizungpanel_stream?token=<...>&mode=raw`.
- Das LuCI-Panel konsumiert im Push-Betrieb damit primär Backend-State und führt keinen produktiven Raw-CAN-Reassembly-Pfad mehr aus.
