# open_slcontrol – Development Readme

OpenWrt/LuCI-App für Lindner & Sommerauer SL über CAN.

## Runtime-Modell (aktuell, raw-first)

- **Primärpfad:** Browser dekodiert Live-Anzeige direkt aus `<mqtt_base>/raw` (`0x320/0x321`).
- **Embedded bleibt leichtgewichtig:** nur kleine Runtime-Topics für Bootstrap/Observability.
- **Legacy-Vollstate bleibt optional:** `<mqtt_base>/state` nur für Debug/Kompatibilität.

## MQTT-Topic-Modell

- `<mqtt_base>/raw` – Live-Rawframes, unretained (Default-Stream).
- `<mqtt_base>/mode` – **durable + retained** Betriebsarten-Latch aus bekannten stabilen `0x321 flags16`.
- `<mqtt_base>/mode/current` – **transient + unretained** letzter beobachteter `0x321`-Wert (Debug/Observability).
- `<mqtt_base>/snapshot` – retained Bootstrap (`line1`, `line2`, `mode_code`).
- `<mqtt_base>/state` – optionaler Legacy-Vollstate (`publish_state=0` per Default).

## Durable `mode` vs transient `mode/current`

- `mode` ist die langlebige Betriebsart (Start-/Reconnect-fähig via retained).
- `mode/current` zeigt nur den aktuell beobachteten `0x321`-Wert und ist bewusst nicht retained.
- Unbekannte/transiente Werte dürfen `mode` nicht überschreiben.

## Bootstrap-Semantik

`state.sh` hydriert den UI-Startzustand aus:
1. retained `<mqtt_base>/mode` (durable)
2. retained `<mqtt_base>/snapshot`
3. optional `<mqtt_base>/state` nur als Legacy-Fallback

`mode/current` ist **keine** Bootstrap-Quelle.

## Stream-API (`/cgi-bin/heizungpanel_stream`)

- `?mode=raw` (Default)
- `?mode=mode` oder `?mode=mode_durable`
- `?mode=mode_current`, `?mode=current`, `?mode=mode/current`
- `?mode=snapshot`
- `?mode=state` (legacy)

## Defaults

- `publish_raw=1`
- `publish_mode=1`
- `publish_snapshot=1`
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
