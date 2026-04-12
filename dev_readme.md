# open_slcontrol – Development Readme

## Zielbild (vereinfacht)

- OpenWrt bleibt klein und billig zur Laufzeit.
- Browser bleibt primärer Decoder/Interpreter.
- Raw-first ist der Standardpfad.

## Runtime-Modell

### Standardpfad
- `etc/init.d/heizungpanel` startet genau einen regulären Bridgeprozess: `raw_bridge.sh`.
- `raw_bridge.sh`:
  - liest CAN einmal (`candump`)
  - publiziert Raw einmal auf `<mqtt_base>/raw`
  - aktualisiert parallel das kleine Bootstrap-File `/tmp/heizungpanel/bootstrap.json`
  - schreibt dieses nur bei relevanten Commit-Ereignissen (`0x321` Latch-Wechsel, `0x320 83xx`)

### Optionaler Legacypfad
- `state_bridge.sh` nur bei `publish_state=1`.
- Dient Kompatibilität/Debug, nicht dem normalen UI-Pfad.

## Bootstrap-Modell

- `www/cgi-bin/heizungpanel_stream?mode=bootstrap` ruft `state.sh` auf.
- `state.sh` liest primär `/tmp/heizungpanel/bootstrap.json`.
- Fallback: `/tmp/heizungpanel/state.json` (wenn Legacy-State aktiv ist).
- Ergebnis ist eine kleine JSON-Antwort für schnellen Panel-Start.

## Stream-API

- `?mode=raw` (Default)
- `?mode=bootstrap`
- `?mode=state` (legacy/debug)

## Konfiguration (relevant)

- `publish_raw=1` (Standard)
- `publish_state=0` (Standard)
- `write_mode` steuert weiterhin CAN listen-only/off zentral über Init.

## Wichtige Dateien

- `etc/init.d/heizungpanel`
- `usr/libexec/heizungpanel/raw_bridge.sh`
- `usr/libexec/heizungpanel/state.sh`
- `usr/libexec/heizungpanel/state_bridge.sh` (optional)
- `www/cgi-bin/heizungpanel_stream`
