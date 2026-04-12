## Update 2026-04-12 – Neues Minimal-Runtime-Modell
- `runtime_bridge.sh` ist jetzt der einzige Always-on-Ingestpfad: CAN -> Raw-MQTT + lokale Bootstrap-Datei.
- `state.sh` liest primär `/tmp/heizungpanel/bootstrap.json` statt pro Request mehrere MQTT-Retained-Reads.
- Alte Einzelbrücken (`raw_bridge.sh`, `mode_bridge.sh`, `snapshot_bridge.sh`) sind entfernt.

## Update 2026-04-12 – Statusmodell im Operator-Panel präzisiert
- `panel.js` meldet jetzt explizit den Übergangszustand „Live verbunden, nutze Bootstrap bis erster Textblock“.
- Nach dem ersten echten `0x320`-Textchunk wechselt der Status auf „Raw-Stream aktiv“.

## Update 2026-04-12 – Panel-Startpfad stabilisiert

- Bootstrap-Displayinhalt bleibt aktiv, bis der Browser den ersten echten Live-Textchunk aus `0x320` verarbeitet.
- `0x320 81` wird im Bootstrapfenster nur als *pending clear* behandelt; der tatsächliche Clear passiert erst direkt vor dem ersten Live-Text.
- `0x320 83xx` bleibt ein separater Statuskanal (kein Mode-Latch) und wird mit `confidence=unknown` gekennzeichnet.

# open_slcontrol – Development Readme

OpenWrt/LuCI-App für Lindner & Sommerauer SL über CAN.

## Runtime-Modell (aktuell, raw-first)

- **Primärpfad:** Browser dekodiert Live-Anzeige direkt aus `<mqtt_base>/raw` (`0x320/0x321`).
- **Single bridge:** `runtime_bridge.sh` liest CAN einmal und publiziert nur `raw` auf MQTT.
- **Bootstrap minimal:** dieselbe Bridge schreibt zusätzlich einen kleinen lokalen Snapshot nach `/tmp/heizungpanel/bootstrap.json`.
- **Embedded bleibt leichtgewichtig:** keine always-on derived MQTT-Fanout-Stufen für `mode`/`snapshot`.
- **Legacy-Vollstate bleibt optional:** `<mqtt_base>/state` nur für Debug/Kompatibilität.

## MQTT-Topic-Modell

- `<mqtt_base>/raw` – Live-Rawframes, unretained (Default-Stream).
- `<mqtt_base>/state` – optionaler Legacy-Vollstate (`publish_state=0` per Default).

## Bootstrap-Semantik

`state.sh` hydriert den UI-Startzustand primär direkt aus lokaler Datei `/tmp/heizungpanel/bootstrap.json`.

Fallback (Kompatibilität):
1. retained `<mqtt_base>/mode` + `<mqtt_base>/snapshot` (falls aus älteren Setups noch vorhanden)
1. optional retained `<mqtt_base>/state` nur Legacy/Debug

## Stream-API (`/cgi-bin/heizungpanel_stream`)

- `?mode=raw` (Default)
- `?mode=bootstrap` (liefert on-demand aus `state.sh`; Aliasse `mode`, `mode_durable`, `mode_current`, `current`, `mode/current`, `snapshot`)
- `?mode=state` (legacy)

## Defaults

- `publish_raw=1`
- `publish_mode` und `publish_snapshot` bleiben nur als Legacy-Konfigfelder ohne eigenen Runtime-Fanout
- `publish_bootstrap` bleibt nur als Legacy-Konfigfeld ohne Runtime-Prozessfunktion
- `publish_state=0`

## Deployment / Betrieb

- CAN-Setup nur im Init-Skript: `etc/init.d/heizungpanel`.
- LuCI-Panel nutzt Bootstrap aus `state.sh` und wechselt dann auf Raw-SSE.
- `state_bridge.sh` bleibt optionaler Legacy-Debugpfad.

## Projektdateien

- `concept.md` – Architekturkonzept
- `checklist.md` – Aufgaben-/Statusliste
- `roadmap.md` – Fortschritts-/Meilensteinplanung
- `README.md` – kurze öffentliche Einstiegsversion
