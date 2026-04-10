# open_slcontrol

OpenWrt/LuCI-App für Lindner & Sommerauer SL über CAN.

## Runtime-Modell (kanonisch)

Das Projekt läuft **raw-first**:

- Browser ist der primäre Display-Decoder (Liveanzeige aus `0x320/0x321` Raw-Frames).
- Embedded hält nur leichte Runtime-Topics für Bootstrap und Observability.
- Vollstate bleibt optionaler Legacy-/Debugpfad.

## MQTT-Topic-Modell

- `<mqtt_base>/raw`  
  Live-Rawframes, nicht retained; primäre UI-Livequelle.
- `<mqtt_base>/mode`  
  **Durable + retained** Betriebsarten-Latch aus bekannten stabilen `0x321 flags16`.
- `<mqtt_base>/mode/current`  
  **Transient + unretained** letzter beobachteter `0x321`-Wert (Debug/Observability).
- `<mqtt_base>/snapshot`  
  Retained Bootstrap für 2x20-Display (`line1`, `line2`, `mode_code`).
- `<mqtt_base>/state`  
  Optionaler Legacy-Vollstate (`publish_state=0` per Default).

## Durable `mode` vs transient `mode/current`

- `mode` ist der langlebige Anlagenmodus-Latch und bleibt über Reconnect/Neustart als retained Startzustand erhalten.
- `mode/current` bildet nur den letzten laufenden `0x321`-Beobachtungswert ab und ist bewusst nicht retained.
- Unbekannte/transiente `0x321`-Werte dürfen `mode` nicht überschreiben.

## Bootstrap-Semantik

`state.sh` liefert Bootstrap aus:

1. retained `<mqtt_base>/mode` (durable)
2. retained `<mqtt_base>/snapshot`
3. optional `<mqtt_base>/state` nur als Legacy-Fallback bei fehlenden Daten

`mode/current` ist **keine** Bootstrap-Quelle.

## Stream-API (`/cgi-bin/heizungpanel_stream`)

- `?mode=raw` (Default)
- `?mode=mode` (durable retained)
- `?mode=mode_current`, `?mode=current`, `?mode=mode/current` (transient)
- `?mode=snapshot`
- `?mode=state` (legacy)

## Defaults

- `publish_raw=1`
- `publish_mode=1`
- `publish_snapshot=1`
- `publish_state=0`

Damit bleiben Browser-Decode + Raw-Livepfad der Standard.

## Projektdateien

- `concept.md` – Architekturkonzept
- `checklist.md` – Aufgaben-/Statusliste
- `roadmap.md` – Fortschritts-/Meilensteinplanung
- `README.md` – kurze öffentliche Einstiegsversion
