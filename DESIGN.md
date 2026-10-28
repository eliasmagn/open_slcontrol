# DESIGN.md – heizungpanel LuCI-Oberfläche

Codifies the existing visual system of the slim live panel and configuration so
future changes stay consistent. This is documentation of what ships, not a
redesign. The panel is a single self-contained LuCI view: one `<style>` element
built by `el()`, no external CSS, no framework, no build step, ES5-style
JavaScript. The configuration view uses native LuCI CBI primitives and adds no
parallel color or spacing system.

## 1. Palette (tokens)

| Token | Wert | Verwendung |
|---|---|---|
| `panel-bg` | `#3b3b3b` | Haupt-Panel-Fläche |
| `display-bg` | `#0b0f16` | LCD-Anzeige-Fläche |
| `display-border` | `#cfcfcf` (2px) | LCD-Rahmen |
| `display-text` | `#74d3ff` | LCD-Zeichen (aktiv) |
| `display-text-dim` | `#2f4b5f` | LCD-Zeichen (Initial-/Cleared-Zustand) |
| `key-bg` / `key-text` / `key-border` | `#d9d9d9` / `#222` / `#bfbfbf` | Tasten (hell, kontrastreich) |
| `surface-tint` | `rgba(255,255,255,.04)` | linke/rechte Kacheln |
| `surface-tint-strong` | `rgba(255,255,255,.06)` | Modus-Zeilen |
| `led-off` / `led-border` | `#555` / `#999` | ausgeschaltete LED |
| `led-mode-on` | `#ffd54a` | aktive Modus-LED (gelb) |
| `led-power-on` | `#9fff82` | Ein-LED (grün) |
| `led-unknown` | `#6e7f91` | unbekannter Power-Zustand |
| `status-ok` | `#97e493` | ok-Status/Feedback |
| `status-warn` | `#ffd166` | Warnungs-Status/Feedback |
| `status-err` | `#ff8a80` | Fehler-Status/Feedback |
| `focus-ring` | `#74d3ff` (2px, offset 2px) | `:focus-visible` auf allen Bedienelementen |

Neue Farben werden zuerst hier als Token ergänzt, dann im `<style>`-Block
verwendet. Keine Ad-hoc-Hexwerte im Markup.

## 2. Typografie

- LCD: `monospace`, 18px, `white-space: pre`, fix auf 20 Zeichen pro Zeile
  (`pad20`), zwei Zeilen.
- Status-/Untertexte (`.hp-status`, `.hp-sub`, `.hp-inline-msg`): 12px,
  Panel-Vordergrundfarbe bzw. Status-Token.
- Keine weiteren Schriftgrößen. Keine Webfonts (Router-Laufzeitumgebung).

## 3. Layout, Spacing, Radii

- Außenwrap `max-width: 760px`; Panel-Padding 18px; Kachel-Padding 12px;
  Grid-Gap 14px; Zeilenabstände in Modusliste/Power 8–10px.
- Zweispaltiges Grid `1fr / 1.2fr` (links Tasten+Power+Send mode, rechts
  Modusliste). **Responsiv:** bei `max-width: 640px` kollabiert das Grid auf
  eine Spalte (`grid-template-columns: 1fr`, Wrap 100%) – Keypad (3×70px) und
  Modusliste passen dann ohne horizontalen Overflow in 375px.
- Radien: Panel/Display/Kacheln 8–10px, Tasten 6px – ein weiches
  Radius-System, keine Mischung mit Pill- oder Kanten-Formen.

## 4. Primitives (Komponenten-System)

| Primitive | Fabrik | Zustände |
|---|---|---|
| `el(tag, attrs, children)` | DOM-Baukasten für alles | – |
| `btn(txt, code)` | `.hp-key`-Taste | enabled / disabled (`!sendEnabled` oder Send in-flight) |
| `mkMode(label, code)` | Moduszeile: Label + LED + `Setzen`-Button (`aria-label: "<label> setzen"`) | LED off/on, Button enabled/disabled |
| Power-LEDs | `.hp-led.power` | on / off / unknown (unknown = Grauton) |
| Statuszeile | `.hp-status` | ok / warn / err |
| Inline-Feedback | `.hp-inline-msg` (aria-live polite) | ok / warn / err / leer; Nachrichten-Slot mit Generations-Schutz (alte Clear-Timer löschen nie neuere Meldungen) |
| LCD-Anzeige | `.l` Zeilen | aktiv / dim (Initial- und 0x320-81-Clear-Zustand) |
| Lernassistent | native `.cbi-section`, `.cbi-value`, `.cbi-button`, `.alert-message` | bereit / Ruhephase / Pressfenster 1 / Pressfenster 2 / Vorschlag / abgelehnt / übernommen |
| Beitrags-Export | beschriftete native Eingaben, Mapping-Checkboxen, `<pre>`-Vorschau | leer / Vorschau / lokaler Download; kein Upload-Zustand |

## 5. Bewegung / Motion

Keine Animationen, Transitionen oder Micro-Interactions – bewusst
(betriebliche Steuerfläche, reduced-motion damit trivially erfüllt). Zustände
wechseln sofort. Das ist der Vertrag; wer Motion ergänzt, braucht einen
fachlichen Grund und einen Token hier.

## 6. Zustands- und Wahrheitsregeln (Verhalten)

- Modus/LEDs entstehen ausschließlich aus frischen `0x320 83xx`-Frames
  (TTL adaptiv 750–3000ms); danach „unbekannt“ – kein Latch. LCD-Text stammt
  aus den adressierten Textframes; Schreibvorgänge überschreiten nie eine sichtbare Zeile.
- „Letzte Aktualisierung“ zeigt ausschließlich die Ankunftszeit des letzten
  **gültigen Panel-Frames** (`0x320 83xx/81/Textwrite`, `0x321`), nie einen
  Timer-Tick. Unerkennbare Zeilen aktualisieren weder Status noch Frische.
- Clear-Frame (`0x320 81`) rendert das Display sofort leer (dim).
- Mappings (`led_map_83`, `mapping_*`) sind UCI-Wahrheit; leer/fehlt =
  deaktiviert/unknown. Kein Fallback-Default im Code – Defaults leben nur in
  der ausgelieferten `/etc/config/heizungpanel`. Explizite `0`-Werte
  (`publish_raw`, `led_power_ein_when_bit7_clear`, `write_mode`) bleiben `0`.
- Senden: genau ein fs.exec gleichzeitig (Buttons während des Flugs
  gesperrt), Fehlertexte je press.sh-Exit-Code, nie Success bei Fehlschlag.
- Write-Mode-Toggle: Backend (`set_mode.sh`) ist Arbiter; Erfolg lädt neu.
  Bei Fehlschlag bleibt Senden gesperrt, Checkbox aus und deaktiviert, mit
  ausdrücklichem Hinweis auf unklaren Gerätezustand und notwendiges Neuladen.
  Write-Mode wird nie automatisch aktiviert.
- Konfigurations-Lernen beobachtet ausschließlich `0x321` mit exakt zwei
  Datenbytes. Ruhephase und beide Pressfenster sind versuchsgebunden; es gibt
  keinen persistenten Hintergrund-/Nicht-Tasten-Katalog. Nur zwei konsistente
  Fenster dürfen einen Vorschlag erzeugen. Kollisionen blockieren; Ersetzen und
  Formularübernahme verlangen getrennte ausdrückliche Aktionen. Kein CAN-Send.
- Die Übernahme setzt nur das native LuCI-Feld und dessen Dirty-State. Speichern
  bleibt ausschließlich Aufgabe des globalen Save / Save & Apply-Footers.
- Der Beitrags-Export liest nur ausdrücklich ausgewählte `mapping_*`-Werte und
  vier freiwillige Metadatenfelder. Er erzeugt Vorschau/Blob lokal, ohne Upload,
  Zugangsdaten, Netzwerkadressen, Serienkennungen oder Raw-Dumps.

## 7. Lifecycle

Genau eine EventSource und genau ein Watchdog-Interval pro Panel-Leben:
`visibilitychange hidden` / `pagehide` → teardown; `visible` /
`pageshow(persisted)` → resume. Kein `beforeunload` (blockiert BFCache).
Re-Render derselben View-Instanz gibt Ressourcen über `this._heizungDispose`
ab (Listener alter Durchgänge werden entfernt).

## 8. Barrierefreiheit

- Sichtbarer Tastatur-Fokus: `:focus-visible` mit `focus-ring`-Token auf
  Tasten, Modus-Buttons und Write-Mode-Switch.
- Modus-Buttons tragen eindeutige zugängliche Namen (`"<label> setzen"`).
- Feedback-Region ist `aria-live="polite"`.
- Lern- und Exportstatus sind `aria-live="polite"`; Select, Bestätigung,
  Metadaten und Exportauswahl haben explizite Labels. Alle Aktionen sind echte
  `<button type="button">`-Elemente und lösen keinen Formular-Submit aus.
- Tasten-Texte sind kurze Keypad-Literale (Z, -, Quit, +, V, Ein, Aus) –
  bewusst so, da Abbild der Gerätetasten.

## 9. Akzeptierte Einschränkungen (accepted debt)

- LCD-Zeilen sind für Screenreader nicht ausgezeichnet (paddierte
  Monospace-Leerzeichen); Statuszeilen tragen die Information.
- Echte BFCache-Wiederverwendung wird von Chromium bei offener EventSource
  zur Navigationszeit meist abgelehnt; der `pageshow(persisted)`-Handler ist
  implementiert und synthetisch verifiziert, praktisch läuft der Back-Fall
  über Full-Reload (funktioniert korrekt).
- `poll_interval_ms` steuert heute nichts im Panel (Watchdog fix 500ms,
  Staleness-Schwelle fix 5000ms); Backend-Kontrakt bleibt unangetastet.
- Keine Dunkel-/Hell-Modus-Schaltung: das Panel ist bewusst dunkel (Gerätesicht).
