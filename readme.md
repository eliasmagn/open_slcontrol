# open_slcontrol

OpenWrt/LuCI-App für Lindner & Sommerauer SL über CAN.

## Aktueller Stand (2026-04-09)
Stabiler Read-only-Betrieb mit Runtime-Konfiguration und Security-Gate plus **M2-v0.1 Parser/Mappings**:
- LuCI-Seite sichtbar und funktionsfähig.
- CAN-Raw- und State-Bridge laufen mit Retry-Schleifen.
- State wird lokal gecacht (`/tmp/heizungpanel/state.json`) und per MQTT retained publiziert.
- Cache wird nur bis `state_max_age` verwendet (Default 15s).
- Polling-Intervall ist via UCI konfigurierbar (`poll_interval_ms`, Clamp 250..10000).
- LuCI pollt mit dem aus UCI geladenen Intervall (inkl. Clamp 250..10000).
- Write-Mode ist via UCI standardmäßig aus (`write_mode=0`) und in `press.sh` allowlist-gesichert.
- Parser reassembliert LCD-Zeilen aus `0x320` offsets, dekodiert `0x321` in `active_bits`/`bit_roles`, paart `0x258/0x259` über Index + Fenster und liefert Confidence-/Invariant-Metadaten.
- Für strukturierte Einzelaktions-Captures steht `usr/libexec/heizungpanel/m2_capture.sh` bereit.
- Deploy-Helper-Fix: `tools/device_ssh_deploy.sh` hält den lokalen Stage-Ordner jetzt korrekt bis nach dem Upload (Fix für `scp .../etc: No such file or directory`).
- Deploy-Helper-Fix: Upload nutzt erzwungen den klassischen SCP-Modus (`scp -O`) für OpenWrt/Dropbear-Ziele ohne SFTP-Server (Fix für `ash: /usr/libexec/sftp-server: not found`).

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
