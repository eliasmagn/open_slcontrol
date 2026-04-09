# open_slcontrol

OpenWrt/LuCI-App für Lindner & Sommerauer SL über CAN.

## Aktueller Stand (2026-04-09)
Stabiler Read-only-Betrieb mit Runtime-Konfiguration und Security-Gate plus **M2-v0.1 Parser/Mappings**:
- LuCI-Seite sichtbar und funktionsfähig.
- CAN-Raw- und State-Bridge laufen mit Retry-Schleifen inkl. CAN-Reinitialisierung nach Bridge-Exit.
- State wird lokal gecacht (`/tmp/heizungpanel/state.json`) und per MQTT retained publiziert.
- Cache wird nur bis `state_max_age` verwendet (Default 15s).
- Polling-Intervall ist via UCI konfigurierbar (`poll_interval_ms`, Clamp 250..10000).
- LuCI pollt mit dem aus UCI geladenen Intervall (inkl. Clamp 250..10000).
- LuCI zeigt den rekonstruierten LCD-Inhalt jetzt explizit als „LCD 2x16 (emuliert aus CAN 0x320)“ mit gedimmtem Fallback bei No-Data/Fehlern, sodass die Panel-Emulation klar vom Debug-Block getrennt ist.
- LuCI meldet bei formal `status=ok`, aber komplett leerem Payload (`line1/line2` leer, `flags16=----`) nun explizit einen Warnzustand („verbunden, aber noch keine decodierbaren Paneldaten“) statt irreführendem `Status: OK`.
- Write-Mode ist via UCI standardmäßig aus (`write_mode=0`) und in `press.sh` allowlist-gesichert.
- Parser reassembliert LCD-Zeilen aus `0x320` offsets, dekodiert `0x321` in `active_bits`/`bit_roles`, paart `0x258/0x259` über Index + Fenster und liefert Confidence-/Invariant-Metadaten inkl. UTF-8-Mapping für beobachtete Sonderbytes (`DF/E2/F5/E1/EF -> °/ß/ü/ä/ö`).
- Für strukturierte Einzelaktions-Captures steht `usr/libexec/heizungpanel/m2_capture.sh` bereit.
- Für schnelle Mapping-Checks aus Candump-Dateien steht `usr/libexec/heizungpanel/mapping_validate.sh` bereit (0x321- und 0x258/0x259-Validierung).
- Für eine schnelle Terminal-/Offline-Sicht auf das emulierte 2x16-Display steht `usr/libexec/heizungpanel/display_emulator.sh` bereit (liest MQTT-Raw, Candump-Dateien oder STDIN; optional mit `--show-flags` für 0x321-Markertrace).
- Deploy-Helper-Fix: `tools/device_ssh_deploy.sh` hält den lokalen Stage-Ordner jetzt korrekt bis nach dem Upload (Fix für `scp .../etc: No such file or directory`).
- Deploy-Helper-Fix: Upload nutzt erzwungen den klassischen SCP-Modus (`scp -O`) für OpenWrt/Dropbear-Ziele ohne SFTP-Server (Fix für `ash: /usr/libexec/sftp-server: not found`).
- Deploy-Helper-Fix: LuCI-Menüeintrag wird jetzt mit ausgerollt (`/usr/share/luci/menu.d/luci-app-heizungpanel.json`), damit die Ansicht nach Router-Reset/Neuinstallation wieder unter **Services** erscheint.
- Deploy-Helper-Fix: LuCI-Caches (`/tmp/luci-indexcache`, `/tmp/luci-modulecache`) werden beim Deploy bereinigt, damit neue Menüeinträge sofort sichtbar sind.

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
   - `option state_max_age '15'`
   - `option poll_interval_ms '1000'`
   - `option write_mode '0'`
2. Service starten: `/etc/init.d/heizungpanel start`.
3. LuCI öffnen und Status prüfen.

## Deploy auf Zielgerät via SSH/SCP
Voraussetzungen lokal: `ssh`, `scp`.

- Install/Push:
  - `tools/device_ssh_deploy.sh install root@192.168.1.10`
  - Alias: `tools/device_ssh_deploy.sh push root@192.168.1.10`
  - Enthält jetzt automatisch den LuCI-Menüeintrag in `/usr/share/luci/menu.d/` und einen Cache-Refresh.
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
