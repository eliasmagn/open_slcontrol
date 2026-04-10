# open_slcontrol

OpenWrt/LuCI-App für Lindner & Sommerauer SL über CAN.

Dieses Repository läuft im **raw-first** Modell:
- Browser ist der primäre Display-Decoder (Raw-SSE als Livepfad).
- Embedded veröffentlicht nur leichte Runtime-Topics (`raw`, durable `mode`, transient `mode/current`, `snapshot`).
- Legacy-Vollstate (`state`) bleibt optional/debug.

👉 **Kanonische Laufzeit-/Deploy-Dokumentation:** [`readme.md`](./readme.md)
