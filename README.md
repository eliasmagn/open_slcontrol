# open_slcontrol

OpenWrt/LuCI-App für Lindner & Sommerauer SL über CAN.

## Update 2026-04-10 – Fix für „WARNING: Variable 'MODE'...“ im Panel
- Ursache: Beim Bootstrap-Lesen konnten `jshn`-Warnungen bei fehlenden/nicht-objektförmigen JSON-Pfaden in stdout erscheinen und als Textartefakte im LCD-Panel landen.
- Fix: `state.sh` liest verschachtelte Felder bevorzugt via `jsonfilter` und unterdrückt im Fallback sämtliche `jshn`-Warn-Ausgaben.
- Ergebnis: Nach Panel-Reload bleibt die 2x20-Anzeige sauber; Modus-/LED-Status werden nicht mehr durch Warnstrings überlagert.

Public entrypoint (kurz):
- **Raw-first Runtime**: Browser decodiert primär aus `<mqtt_base>/raw`.
- Bootstrap ist kanonisch als retained `<mqtt_base>/bootstrap` verfügbar (kombiniert aus durable `mode` + `snapshot`).
- Ergänzend bleiben `<mqtt_base>/mode` (durable retained), `<mqtt_base>/mode/current` (transient), `<mqtt_base>/snapshot` (retained) und optional Legacy `<mqtt_base>/state`.

👉 Kanonische Betriebs- und Deploy-Doku: [`dev_readme.md`](./dev_readme.md)

## Update 2026-04-10 – Panel UI
- Moduszeilen im LuCI-Panel wurden visuell stabilisiert: LED und Aktionsbutton sind nun sauber ausgerichtet.
- Die fehlenden Tasten **Ein** und **Aus** wurden im linken Bedienblock ergänzt.
- Modusaktionen sind klarer beschriftet (`Setzen` statt Symbolbutton), damit die Bedienung am Touch/Browser eindeutiger ist.

## Update 2026-04-10 – Display-Bootstrap korrigiert
- Korrektur gemäß Feldanforderung: Das LCD-Display wird beim Seitenstart **nicht** mehr aus retained/persistenten Bootstrap-Daten vorbefüllt.
- Persistenz bleibt bewusst nur für den Betriebsartenstatus (LED-Latch über `mode_flags16`) aktiv.
- Das Display rendert ausschließlich aus Live-Rawframes (`0x320`), sobald diese eintreffen.

## Update 2026-04-11 – 0x321-Tracking präzisiert
- `mode_bridge.sh` klassifiziert jetzt `321 FFFF` explizit als transienten Lauf-/Poll-Status (`running_poll`) im `mode/current`-Stream.
- Retained Betriebsart (`<mqtt_base>/mode`) bleibt weiterhin strikt auf bekannte persistente Modi begrenzt, damit LED-Latches nicht von Pollframes überschrieben werden.
- Im LuCI-Panel bleiben LEDs auf dem zuletzt gelatchten Betriebsmodus; eingehende transiente `0x321`-Werte (z. B. `FFFF`) werden als Statushinweis angezeigt, während das LCD weiter ausschließlich aus Raw-Displayframes (`0x320`) aufgebaut wird.

## Update 2026-04-11 – Mapping + Sensor-Graph im Panel
- Unterhalb des virtuellen Panels gibt es jetzt einen neuen **Reverse-Engineering Mapping**-Bereich mit:
  - ID-Zuordnung (`0x1F5/0x258/0x259/0x320/0x321`),
  - Button-/Command-zu-CAN-Frame-Tabelle (inkl. `321#FFFF` als RX-Pollstatus),
  - auswählbarem Sensor-Graph auf Basis live eingehender `0x259`-Frames.
- Der Graph ist bewusst raw-nah: je `0x259`-Index werden Verlaufspunkte aus `data[4..5]` als Trend dargestellt, um Mapping-Hypothesen im Livebetrieb schnell visuell zu prüfen.
