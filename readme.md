# open_slcontrol

OpenWrt/LuCI-App für Lindner & Sommerauer SL über CAN.

## Runtime-Modell (kanonisch, Stand 2026-04-10)

**Raw-first bleibt der Standardpfad.**

- Browser dekodiert Liveanzeige primär aus Raw-CAN (`0x320/0x321`) über SSE.
- Embedded hält nur leichte Retains für Bootstrap/Orientierung.
- Vollständiger Legacy-State ist optional und standardmäßig deaktiviert.

### MQTT-Topics (Primärpfad)

- `<mqtt_base>/raw`  
  Live-Rawframes (nicht retained), Primärquelle für die UI.
- `<mqtt_base>/mode`  
  **Durable, retained** Betriebsart-Latch aus bekannten stabilen `0x321 flags16`.
- `<mqtt_base>/mode/current`  
  **Transient, nicht retained**: letzter beobachteter `0x321`-Wert (Observability/Debug).
- `<mqtt_base>/snapshot`  
  Retained 2x20-Display-Bootstrap (`line1/line2/mode_code`).
- `<mqtt_base>/state`  
  Optional/legacy Vollstate (Debug/Fallback), standardmäßig aus.

## Durable `mode` vs transient `mode/current`

- `mode` = langlebiger Betriebszustand für LED-/Modus-Startzustand (retained).
- `mode/current` = flüchtiger Beobachtungskanal für laufende 0x321-Wechsel (nicht retained).
- Transiente/unbekannte 0x321-Werte überschreiben den durable Latch **nicht**.

## Bootstrap-Semantik (strict)

- `state.sh` baut Bootstrap aus retained `mode` + retained `snapshot`.
- `mode/current` wird **nicht** als Bootstrap-Quelle verwendet.
- Legacy `<mqtt_base>/state` wird nur bei fehlendem Bootstrap als Fallback abgefragt.
- Browser-Hydration bleibt Raw-first: Snapshot als Startbild, danach Live-Decode aus Raw.

## Standard-Runtime

In der Default-Konfiguration:

- `publish_raw=1`
- `publish_mode=1`
- `publish_snapshot=1`
- `publish_state=0`

`/etc/init.d/heizungpanel` startet damit typischerweise:

- `raw_bridge.sh`
- `mode_bridge.sh`
- `snapshot_bridge.sh`
- optional `state_bridge.sh` (nur bei `publish_state=1`)

## Streams

`/www/cgi-bin/heizungpanel_stream` unterstützt:

- `?mode=raw` (Default)
- `?mode=mode` (durable retained)
- `?mode=mode_current` oder `?mode=current` (transient)
- `?mode=snapshot`
- `?mode=state` (legacy)

## Architekturleitplanken

- Browser bleibt primärer Display-Decoder.
- Embedded bleibt leichtgewichtig.
- `state_bridge.sh` bleibt legacy/optional.
- CAN-Setup bleibt ausschließlich im Init-Skript.

## Betrieb (Kurz)

1. UCI prüfen (`/etc/config/heizungpanel`) – insbesondere `can_if`, `mqtt_*`, Publish-Flags, `write_mode`.
2. Dienst starten: `/etc/init.d/heizungpanel start`.
3. LuCI öffnen und prüfen, dass Raw-Stream aktiv ist.
4. Bei Bedarf Stream-Endpunkt direkt prüfen:  
   `/cgi-bin/heizungpanel_stream?mode=raw&token=<stream_token>`

## Relevante Projektdateien

- `concept.md` – Zielbild/Architektur.
- `checklist.md` – laufende Aufgaben und Status.
- `roadmap.md` – Milestones/Fortschritt.
- `readme.md` – aktueller Betriebs-/Deploy-Stand (kanonisch).
