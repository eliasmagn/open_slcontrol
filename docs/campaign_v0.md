# Controlled one-action campaign (v0 aus vorhandenem Dump)

> Hinweis: Der vorliegende Dump enthält Marker (`z`, `v`, `+`, `-`, `q`, `b`, `u`, `d`, `a`, `p`, `h`) statt harter Wallclock-Timestamps. Diese Tabelle ist daher ein **v0-Extrakt** mit relativen Bereichen und dient als Vorlage für die nächste echte Ein-Aktions-Kampagne.

## Session-Log (v0)

| Session | Zeitbereich | Physische Aktion | 0x321 Transition(s) | 0x320 Textwechsel | 0x258/0x259 Indizes |
|---|---|---|---|---|---|
| Idle Baseline | Start bis erster Marker `z` | Keine Eingabe | überwiegend kein 0x321-Wechsel, `flags16` stabil | `Kesseltemp.   69°` stabil | wiederholt Block `00..0C` |
| Press `+` once | Marker `+` Block | `+` einmal drücken | `... -> FFDF` sichtbar | meist gleiche Kesseltemp-Seite, punktuelle Parameterupdates | u.a. `00,01,02,03` + Folgeblock `04..0C` |
| Press `-` once | Marker `-` Block | `-` einmal drücken | `... -> DFFF` im Anschluss sichtbar | Seiten bleiben nahe Kesseltemp/Status | Folgeblock `02..0C` beobachtet |
| Press `Z` once | Marker `z` Blöcke | `Z` Navigation | `... -> FF7F` wiederholt | Wechsel zwischen Menüs (`B.UWP Freigabe`, `Boiler Hysterese`, `Boiler Temp`, zurück) | wiederholte Blöcke `00..0C` |
| Press `V` once | Marker `v` Blöcke | `V` Navigation/Enter | `... -> FFFB` wiederholt | Einstieg in Menülisten (`B1/B2/B3/B4`, Boiler-Parameter etc.) | wiederholte Blöcke `00..0C` |
| Enter/Exit Mode menu | Marker `b/u/d/a/p/h/q` | Betriebsmode betreten/verlassen | `BFFF`, `7FFF`, `EFFF`, `F7FF`, `FBFF`, `FDFF`, `FFBF` kontextabhängig | Seiten wie `BOILERBETRIEB`, `UHRENBETRIEB`, `DAUERBETRIEB`, `AUßENTEMPERATUR`, `PUTZPROGRAMM`, `HANDBETRIEB` | durchgehend `00..0C` in Zyklen |

## Key discriminator (event vs latch)

- **Event/Button-Puls**: Bits mit Aktivphase über 1–2 relevante Frames (z. B. `FFDF`, `FFBF`) werden v0 als `event_button` klassifiziert.
- **Status/Latch**: Bits mit längerer Aktivphase über Menüzustände (z. B. `7FFF`, `EFFF`, `BFFF`, `F7FF`, `FDFF`) werden v0 als `status_latch` klassifiziert.
- Grenzfälle bleiben `unknown` bis zur echten Ein-Aktions-Aufnahme mit exakten Zeitstempeln.

## M2-v0.1 Durchführungsplan (strukturierte Einzelaktions-Captures)

### Sequenz (auf Zielgerät)
1. `mkdir -p /tmp/heizungpanel/m2`
2. Idle baseline: `usr/libexec/heizungpanel/m2_capture.sh /tmp/heizungpanel/m2 can0 8 idle`
3. Einzelaktionen (jeweils in separatem Lauf):
   - `... m2_capture.sh /tmp/heizungpanel/m2 can0 8 plus`
   - `... m2_capture.sh /tmp/heizungpanel/m2 can0 8 minus`
   - `... m2_capture.sh /tmp/heizungpanel/m2 can0 8 z`
   - `... m2_capture.sh /tmp/heizungpanel/m2 can0 8 v`
   - `... m2_capture.sh /tmp/heizungpanel/m2 can0 8 mode_enter`
   - `... m2_capture.sh /tmp/heizungpanel/m2 can0 8 mode_exit`
4. Pro Lauf die erzeugte `*.summary.json` sichern und gegen `docs/mapping_v0.md` vergleichen.

### Confidence-Promotion-Regel
- `unknown -> likely`: 1 sauberer Einzellauf mit plausibler Korrelation.
- `likely -> confirmed`: mindestens 3 reproduzierbare Einzelläufe ohne widersprüchliche Bit-/Indexsignatur.
- Bei Konflikt: Confidence wieder absenken und in `anomalies` dokumentieren.
