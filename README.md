# open_slcontrol

OpenWrt/LuCI-App für Lindner & Sommerauer SL über CAN.

## Runtime (Stand: 2026-04-12)

- **Raw-first bleibt das Produktmodell.**
- Embedded-Seite ist auf das Minimum reduziert:
  1. `candump` einmal lesen
  2. `<mqtt_base>/raw` einmal publizieren
  3. kleines lokales Bootstrap-Artefakt schreiben (`/tmp/heizungpanel/bootstrap.json`)
- Browser dekodiert Anzeige/Status weiterhin live aus Raw-Frames.
- Bootstrap-Datei wird nur bei sinnvollen Commit-Ereignissen geschrieben (Mode-Latch-Wechsel oder `0x320 83xx`), ohne per-Frame Shell-Spawn.
- Legacy-Vollstate bleibt optional (`publish_state=1`) und ist **nicht** Teil des Standardpfads.

## Was bewusst entfernt wurde

- `mode_bridge.sh`
- `snapshot_bridge.sh`
- `runtime_bridge.sh`
- always-on MQTT-Republish-Ketten für abgeleitete Topics

Damit sinken Prozesszahl, MQTT-Client-Fan-out und Shell-Pipeline-Komplexität deutlich.

## Bootstrap

- Das Panel lädt beim Start `?mode=bootstrap`.
- `state.sh` liefert die Bootstrap-Antwort primär aus `/tmp/heizungpanel/bootstrap.json`.
- Danach läuft die UI auf Live-Raw (`?mode=raw`).

## Stream-API

- `?mode=raw` (Default)
- `?mode=bootstrap`
- `?mode=state` (optionaler Legacy-Debugpfad)

## Doku

- [`dev_readme.md`](./dev_readme.md) – Betriebs-/Entwicklungsdetails
- [`concept.md`](./concept.md) – Architekturkonzept
- [`checklist.md`](./checklist.md) – Aufgabenstatus
- [`roadmap.md`](./roadmap.md) – Meilensteinfortschritt

## UI-UX Hinweis (Bootstrap -> Live)
- Wenn ein Bootstrap-Text vorhanden ist, bleibt er sichtbar, bis echte Live-Textsegmente aus `0x320` eintreffen.
- Frühe `0x320 81`/`0x320 83xx`-Frames löschen den Starttext nicht mehr vorzeitig.
- Das Operator-Panel bleibt bewusst ruhig formuliert; Engineering-Details bleiben auf den Engineering-Seiten.
