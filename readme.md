# open_slcontrol

OpenWrt/LuCI-App für Lindner & Sommerauer SL über CAN.

## Aktueller Stand (2026-04-10)
Stabiler Read-only-Betrieb mit Runtime-Konfiguration und Security-Gate plus **M2-v0.1 Parser/Mappings**:
- LuCI-Seite sichtbar und funktionsfähig.
- CAN-Raw- und State-Bridge laufen mit Retry-Schleifen inkl. CAN-Reinitialisierung nach Bridge-Exit.
- State wird per MQTT retained publiziert; LuCI liest den Zustand direkt aus dem MQTT-State-Topic.
- LuCI liest den State jetzt direkt aus MQTT (`<mqtt_base>/state`) statt aus einem Dateicache; damit folgen Anzeige-Updates unmittelbar dem Stream.
- Optionaler MQTT-Wartewert für `state.sh`: `state_mqtt_wait` (UCI, Default `1` Sekunde).
- LuCI nutzt jetzt primär **Push via SSE** (`/cgi-bin/heizungpanel_stream`) statt festem Polling; neue Frames erscheinen direkt bei Eingang.
- Polling-Intervall ist via UCI konfigurierbar (`poll_interval_ms`, Clamp 250..10000), neuer Default: `500ms`.
- LuCI pollt mit dem aus UCI geladenen Intervall (inkl. Clamp 250..10000).
- LuCI zeigt unter dem Hinweisbereich einen Konfigurations-Switch für `Send mode` (`write_mode`); Änderungen werden in UCI gespeichert und der Dienst wird neu gestartet.
- LuCI zeigt den rekonstruierten LCD-Inhalt jetzt explizit als „LCD 2x16 (emuliert aus CAN 0x320)“ mit gedimmtem Fallback bei No-Data/Fehlern, sodass die Panel-Emulation klar vom Debug-Block getrennt ist.
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
- Für eine schnelle Terminal-/Offline-Sicht auf das emulierte 2x16-Display steht `usr/libexec/heizungpanel/display_emulator.sh` bereit (liest MQTT-Raw, Candump-Dateien oder STDIN; optional mit `--show-flags` für 0x321-Markertrace).
- Deploy-Helper-Fix: `tools/device_ssh_deploy.sh` hält den lokalen Stage-Ordner jetzt korrekt bis nach dem Upload (Fix für `scp .../etc: No such file or directory`).
- Deploy-Helper-Fix: Upload nutzt erzwungen den klassischen SCP-Modus (`scp -O`) für OpenWrt/Dropbear-Ziele ohne SFTP-Server (Fix für `ash: /usr/libexec/sftp-server: not found`).
- Deploy-Helper-Fix: LuCI-Menüeintrag wird jetzt mit ausgerollt (`/usr/share/luci/menu.d/luci-app-heizungpanel.json`), damit die Ansicht nach Router-Reset/Neuinstallation wieder unter **Services** erscheint.
- Deploy-Helper-Fix: LuCI-Caches (`/tmp/luci-indexcache`, `/tmp/luci-modulecache`) werden beim Deploy bereinigt, damit neue Menüeinträge sofort sichtbar sind.
- Deploy-Helper-Fix: Service-Start nach frischem Reset/Erstinstallation gehärtet (`stop || true` + `start` statt `restart`), damit kein zweiter Push mehr nötig ist, wenn `ubus service delete ... (Not found)` beim ersten Lauf auftritt.
- Deploy-Helper-Fix: `tools/device_ssh_deploy.sh` rollt jetzt zusätzlich `usr/libexec/heizungpanel/set_mode.sh` und `usr/libexec/heizungpanel/isolate_321.sh` mit aus.

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
- Die Emulatoranzeige merged fragmentierte `0x320`-Blöcke über LCD-Offsets, bis beide 16er Zeilen konsistent aufgebaut sind.
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
