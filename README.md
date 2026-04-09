# open_slcontrol

OpenWrt/LuCI-App für Lindner & Sommerauer SL über CAN.

## Aktueller Stand (2026-04-09)
Stabiler Read-only-Betrieb mit Runtime-Konfiguration und Security-Gate plus **M2-v0 Parser/Mappings**:
- LuCI-Seite sichtbar und funktionsfähig.
- CAN-Raw- und State-Bridge laufen mit Retry-Schleifen.
- State wird lokal gecacht (`/tmp/heizungpanel/state.json`) und per MQTT retained publiziert.
- Cache wird nur bis `state_max_age` verwendet (Default 15s).
- Polling-Intervall ist via UCI konfigurierbar (`poll_interval_ms`, Clamp 250..10000).
- Write-Mode ist via UCI standardmäßig aus (`write_mode=0`) und in `press.sh` allowlist-gesichert.
- LuCI spiegelt den rekonstruierten Display-Zustand als klaren „LCD 2x16 (emuliert aus CAN 0x320)“-Block; Debugdaten bleiben zusätzlich sichtbar.
- Parser reassembliert jetzt LCD-Zeilen aus `0x320` offsets, dekodiert `0x321` in `active_bits`/`bit_roles`, paart `0x258/0x259` über Index + Fenster und liefert Confidence-/Invariant-Metadaten; beobachtete LCD-Sonderbytes (`DF/E2/F5/E1/EF`) werden für UI/Parser auf UTF-8 (`°/ß/ü/ä/ö`) gemappt.
- Zusätzlicher Terminal-Emulator `usr/libexec/heizungpanel/display_emulator.sh` zeigt das rekonstruierte 2x16-LCD live aus MQTT-Raw oder offline aus Candump-Dateien/STDIN (`--file`/`--stdin`) an; optional mit `--show-flags` für 0x321-Markertrace.

## Neue Telemetrie-Felder (Parser v0)
Zusätzlich zu `line1`, `line2`, `flags16`, `last_1f5`:
- `source_frame`: laufende Parser-Frame-ID.
- `active_bits`: aktive (low) Bits aus `0x321`.
- `bit_roles`: pro Bit tentative Klassifikation (`event_button` / `status_latch` / `unknown`) inkl. Confidence.
- `pairing_258_259`: `observed_indices` und `latest_pairs` mit Index-Pairing.
- `confidence`: Confidence auf Block-Ebene (`lcd_320`, `flags_321`, `pairing_258_259`).
- `invariants`: Laufzeit-Validierung (`flags_single_active_low_ratio`, `offsets_outside_expected`, `unmatched_258`).
- `anomalies`: ringförmige Warnliste (Parser bleibt read-only und robust).

## M2-Artefakte (v0)
- `docs/mapping_v0.md` – eingefrorene Mapping-Tabelle mit Confidence.
- `docs/campaign_v0.md` – v0 Session-Protokoll aus dem gelieferten Dump + klare Next-Steps für echte Einzelaktions-Captures.
- `tools/device_ssh_deploy.sh` – SSH/SCP-Helper für Install/Push und Uninstall/Remove auf laufenden OpenWrt-Geräten (inkl. LuCI-Menü-Deployment und Cache-Refresh).

## Priorisierung
1. **M2 validieren:** echte Ein-Aktions-Dumps (Idle, +, -, Z, V, Mode enter/exit) und `likely -> confirmed`.
2. **M3 vorbereiten:** Feed-Struktur und reproduzierbarer Install-/Upgradepfad.

## Betrieb
1. UCI prüfen (`/etc/config/heizungpanel`):
   - `option state_max_age '15'`
   - `option poll_interval_ms '1000'`
   - `option write_mode '0'`
2. Service starten: `/etc/init.d/heizungpanel start`.
3. LuCI öffnen und Status prüfen (Menü: **Services → Heizungpanel**).

### Display emulieren (ohne physisches Panel)
- Standard (MQTT live):
  - `usr/libexec/heizungpanel/display_emulator.sh`
- Mit explizitem Broker/Topic:
  - `usr/libexec/heizungpanel/display_emulator.sh --host 192.168.1.10 --port 1883 --topic heizungpanel/raw`
- Offline aus Candump-Datei:
  - `usr/libexec/heizungpanel/display_emulator.sh --file /tmp/candump_sample.txt`
- Offline via STDIN:
  - `cat /tmp/candump_sample.txt | usr/libexec/heizungpanel/display_emulator.sh --stdin`
- Mit 0x321-Flags-/Markertrace:
  - `usr/libexec/heizungpanel/display_emulator.sh --file /tmp/candump_sample.txt --show-flags`

Hinweis: Fragmentierte `0x320`-Markerblöcke werden offset-basiert zusammengesetzt, bis ein vollständiger 2x16-Zustand vorliegt.

## Deploy auf Zielgerät via SSH/SCP
- Install/Push:
  - `tools/device_ssh_deploy.sh install root@192.168.1.10`
  - `tools/device_ssh_deploy.sh push root@openwrt.local -i ~/.ssh/id_ed25519`
- Uninstall/Remove:
  - `tools/device_ssh_deploy.sh uninstall root@192.168.1.10`
  - `tools/device_ssh_deploy.sh remove root@192.168.1.10 -p 2222`
- Passwortabfrage-Verhalten:
  - Standardmäßig nutzt das Deploy-Skript jetzt SSH-Multiplexing (`ControlMaster/ControlPersist`) und fragt das Passwort pro Lauf nur **einmal** ab.
  - Mit `--no-mux` kann das alte Verhalten (mehrfache Passwortabfragen) erzwungen werden.
  - Für komplett passwortlosen Betrieb wird weiterhin SSH-Key-Login empfohlen (`-i ~/.ssh/id_ed25519` oder Key in `~/.ssh/config`).

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
