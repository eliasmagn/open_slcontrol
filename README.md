## Update 2026-04-12 – Mapping-Konfiguration, Engineering-Graph und SSE-Leak-Fix
- **Mapping-Seite ist jetzt aktiv konfigurierbar**: `mapping_*`-Einträge werden in UCI gespeichert und von `press.sh` zur Laufzeit verwendet.
- **Default-Klassen umgesetzt**:
  - confirmed defaults: `uhr`, `boiler`, `uhr_boiler`, `dauer`, `v`, `z`, `quit`
  - likely defaults: `hand`, `aussen_reg`, `pruef`, `plus`
  - unmapped placeholder: `ein`, `aus`, `minus` (leer bis Feldbestätigung)
- **Sensor Graph auf Engineering-Modell umgestellt**: Quelle (`0x258`/`0x259`/paired), Index, Feld, Skalierung, Offset, Unit, Label, Confidence und Autoscale/Fixrange sind konfigurierbar.
- **SSE/CGI-Lifecycle gehärtet**: Frontends schließen EventSource bei `pagehide/beforeunload`; CGI beendet `mosquitto_sub` bei Client-Disconnect sauber.
- **Konfigdrift reduziert**: neue Mapping-/Graph-Felder sind in `config_get.sh`/`config_set.sh` und UCI-Defaults geführt.

## Update 2026-04-12 – Git Update: nur app-verwaltete Pfade (kein globales /etc-/usr-/www-Overlay)
- Der Updater kopiert jetzt **nicht** pauschal alle Dateien unter `etc/usr/www`, sondern nur klar app-verwaltete Ziele (Init/Config, `usr/libexec/heizungpanel`, LuCI-View-Ordner, ACL/Menu, CGI).
- Damit werden Risiken durch fremde Repo-Dateien (z. B. `etc/passwd`) vermieden, während Renames innerhalb der App-Verzeichnisse weiterhin robust mitgenommen werden.
- Bereinigung der verwalteten App-Verzeichnisse bleibt aktiv, um Altdateien nach Umbenennungen zu entfernen.

## Update 2026-04-12 – Git Update kopiert jetzt App-Baum statt fester Dateiliste
- `git_update.sh` nutzt nach dem Download nicht mehr nur eine starre Allowlist, sondern kopiert den gesamten App-Baum unter `etc/`, `usr/`, `www/` aus dem Archiv.
- Vor dem Kopieren werden die verwalteten Verzeichnisse `/usr/libexec/heizungpanel` und `/www/luci-static/resources/view/heizungpanel` geleert, damit umbenannte/entfernte Dateien nicht als Altlasten verbleiben.
- Damit sind Renames und neue Dateien in künftigen Updates robuster abgedeckt; `/etc/config/heizungpanel` bleibt weiterhin optional überschreibbar.

## Update 2026-04-12 – Git Update auf tar.gz umgestellt
- Das Self-Update nutzt jetzt tar.gz-Archive (GitHub codeload `tar.gz`) statt ZIP/`unzip`.
- `git_update.sh` extrahiert mit vorhandenem `tar` (`tar -xzf`) und benötigt kein `unzip` mehr.
- LuCI-Update-Seite (`Git Update`) ist auf Archive-URL/tar.gz-Texte und Parameter `--archive-url` angepasst (Abwärtskompatibilität für alte URL-Flags bleibt erhalten).

## Update 2026-04-11 – PR47-Korrektur: Operator-Panel + Engineering-Seiten getrennt
- Das Hauptpanel ist wieder auf Bedienung fokussiert (LCD, Tastenblock, Ein/Aus-Bereich, Betriebsarten mit LEDs, kompaktes Feedback).
- Das LCD wird beim Seitenstart **nicht mehr** aus retained `line1/line2` vorgefüllt; Liveanzeige kommt weiterhin nur aus Raw-Frames (`0x320`) im Browser.
- Betriebsarten-LEDs bleiben persistent über durable `mode_flags16` (retained `<base>/mode`), transiente `321 FFFF` werden nur als Hinweis behandelt.
- Neue LuCI-Unterseiten: **Sensor Graph** (`0x259`) und **Mapping** (ID-/Command-Zuordnung) wurden aus dem Hauptpanel ausgelagert.
- Ein/Aus-LEDs sind im Panel sichtbar (live aus aktuellem `0x321`-Wert, ohne künstliches Persistenzmodell).

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
