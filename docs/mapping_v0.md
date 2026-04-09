# Mapping v0 (aus Dump vom 2026-04-09)

> Zweck: erster versionierter Stand für Protokoll-Engineering (read-only), inkl. Confidence-Modell.

## Confidence Labels
- `confirmed`: direkt und reproduzierbar im Dump sichtbar.
- `likely`: starkes Indiz, aber noch mit Einzelaktions-Captures zu validieren.
- `unknown`: beobachtet, aber Bedeutung unklar.

## 0x320 – Text-Reassembly-Regeln

| Feld | Regel | Confidence |
|---|---|---|
| Byte 0 | LCD-Offset/Adresse | confirmed |
| Offsets `0x00..0x0F` | Zeile 1, Spalte 0..15 | confirmed |
| Offsets `0x40..0x4F` | Zeile 2, Spalte 0..15 | confirmed |
| Offsets `0x10..0x1F`, `0x50..0x5F` | Zusätzliche Chunks (Boundary/weitergeschriebene Teilblöcke), tolerant behandeln | likely |
| Bytes 1..N | ASCII-Zeichenpayload | confirmed |
| `0xDF` im Payload | Grad-/Sonderzeichen (`°`) | likely |

Parser v0 reassembliert beide LCD-Zeilen über den Offset + Payload.

## 0x321 – Bit -> tentative meaning (active-low)

Active-low gelesen als 16-bit Word: Bit=0 => „aktiv“.

| flags16 | aktiviertes Bit (Mask) | Tentative Meaning | Event vs Latch (v0) | Confidence |
|---|---:|---|---|---|
| `FF7F` | `0x0080` | Taste `Z` (Marker `z`) | eher Event | likely |
| `FFFB` | `0x0004` | Taste `V` (Marker `v`) | eher Latch in Menülauf (lang aktiv) | likely |
| `FFDF` | `0x0020` | Taste `+` (Marker `+`) | eher Event | likely |
| `DFFF` | `0x2000` | Taste `-` / Boilerbetrieb-Kontext | gemischt | unknown |
| `FFBF` | `0x0040` | Quit/Zurück (Marker `q`, Putzprogramm-Kontext) | eher Event | likely |
| `BFFF` | `0x4000` | Mode-Bit (Betriebsartenwechsel) | eher Latch | likely |
| `EFFF` | `0x1000` | Mode-Bit (Uhr+Boiler-Kontext) | eher Latch | likely |
| `7FFF` | `0x8000` | Mode-Bit (Dauerbetrieb-Kontext) | eher Latch | likely |
| `FBFF` | `0x0400` | Mode-Bit (Prüf/Putz-ähnlicher Kontext) | eher Event | likely |
| `F7FF` | `0x0800` | Mode-Bit (Außentemp.-Menü/Regelung) | eher Latch | likely |
| `FDFF` | `0x0200` | Mode-Bit (Handbetrieb) | eher Latch | likely |

## 0x258 / 0x259 – Pairing-Regel

- Pair-Key: erstes Datenbyte = `index` (`00..0C` im Dump beobachtet).
- Pairing-Fenster: ein `0x258(index)` sollte zeitnah durch `0x259(index)` ergänzt werden.
- Parser v0 nutzt ein Frame-Fenster (`PAIR_WINDOW`, Default 80 Frames) und emittiert gepaarte Objekte.

### Beobachtete Indizes
`00, 01, 02, 03, 04, 05, 06, 07, 08, 09, 0A, 0B, 0C` (voller Block `00..0C`).

| Bereich | Beobachtung | Confidence |
|---|---|---|
| `00..03` | häufig 7-Byte `0x259`, wirkt wie Hauptwerte/Status | likely |
| `04..0A` | gemischt 5-/7-Byte `0x259`, wirkt wie Parameterblöcke | likely |
| `0B..0C` | konstante Zusatz-/Meta-Werte | likely |


## 0x258 / 0x259 – tentative index mapping (v0)

| Index | Vermutete Klasse | Confidence |
|---|---|---|
| `00` | Header/Hauptstatus | likely |
| `01` | Header/Hauptstatus | likely |
| `02` | Header/Hauptstatus | likely |
| `03` | Header/Hauptstatus | likely |
| `04` | Parameterblock | likely |
| `05` | Parameterblock | likely |
| `06` | Parameterblock | likely |
| `07` | Parameterblock | likely |
| `08` | Parameterblock | likely |
| `09` | Parameterblock | likely |
| `0A` | Parameterblock | likely |
| `0B` | Zusatz/Meta | likely |
| `0C` | Zusatz/Meta | likely |

## Invariants v0 (nur Warnung, kein Crash)
- `0x321`: „mostly one bit low“ (Single-active-low dominiert).
- `0x320`: Offsets primär in erwarteten Bereichen (`00..0F`, `40..4F`, plus tolerierte Chunks).
- `0x258/0x259`: jedes `0x258(index)` soll innerhalb des Fensters ein `0x259(index)` finden.

