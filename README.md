# open_slcontrol

OpenWrt/LuCI-App für Lindner & Sommerauer SL über CAN.

Public entrypoint (kurz):
- **Raw-first Runtime**: Browser decodiert primär aus `<mqtt_base>/raw`.
- Embedded publiziert nur leichte Topics: durable retained `<mqtt_base>/mode`, transient unretained `<mqtt_base>/mode/current`, retained `<mqtt_base>/snapshot`.
- Legacy `<mqtt_base>/state` bleibt optional/debug.

👉 Kanonische Betriebs- und Deploy-Doku: [`readme.md`](./readme.md)
