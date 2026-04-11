## Update 2026-04-11 – Git-Update Unterseite (ZIP)
- Neue LuCI-Unterseite **Git Update** unter `Services -> Heizungpanel -> Git Update`.
- Die Seite kann jetzt einen **Branch oder Commit als ZIP** laden und die App direkt auf dem Router aktualisieren.
- Backend-Skript `git_update.sh` lädt per `uclient-fetch`/`wget`/`curl`, entpackt das Archiv, installiert alle relevanten Dateien und startet die Dienste neu.
- Optional kann `/etc/config/heizungpanel` beim Update bewusst mit überschrieben werden.

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
