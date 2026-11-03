# Bestätigte Panel-Befehle und Zusatzseiten

## Herkunft der Belegung

Die Belegung wurde in der gemeinsamen Sitzung am 10./11. Oktober 2026
erarbeitet. Insbesondere Plus und V+Z wurden vom Nutzer durch eigene
Sendeversuche mit Rückmeldung am echten Panel bestätigt. Es handelt sich
nicht um aus dem Handbuch extrahierte oder rechnerisch kombinierte CAN-Codes.
Die vorhandenen alten Protokollnotizen geben teilweise einen früheren,
unvollständigen Wissensstand wieder.

| Funktion | CAN-ID | Payload | UCI-Option |
| --- | --- | --- | --- |
| Ein | `0x321` | `FFEF` | `mapping_ein` |
| Aus | `0x321` | `FFFE` | `mapping_aus` |
| Minus | `0x321` | `FFDF` | `mapping_minus` |
| Plus | `0x321` | `FFFD` | `mapping_plus` |
| V+Z: nächste Zusatzseite | `0x321` | `FF7B` | `mapping_vz` |

Direkte Rückmeldungen des Nutzers in der Sitzung (Europe/Berlin):

- 10.10., ca. 14:17: Minus bestätigt durch Absenken des Boiler-Start-Sollwerts.
- 10.10., 15:21: „es ist fffd, meine intuition war richtig“; anschließend
  ausdrücklich bestätigt, dass der Versuch bereits durchgeführt wurde.
- 11.10., 18:19: „ff7B ist korrekt ich habe es getestet.“
- 11.10., 18:23: „mit ff7b kann man durch alle zusatzparameter menues springen“.

`mapping_ein=FF7B` war damals ein bewusst verwendeter temporärer Testträger
für V+Z, keine neue Ein-Belegung. Der Kollisionsschutz in `press.sh` darf dafür
nicht entfernt werden. Bei anderen Regler-/Firmwarevarianten die Zuordnung
prüfen; leere Mappings deaktivieren den betreffenden Befehl weiterhin.

## Zusatzseiten laut Pelletheizungs-Handbuch

Der bestätigte Code `FF7B` ist eine einzelne kombinierte V+Z-Betätigung.
Er ist kein absoluter Seitenaufruf und keine Folge getrennter V- und Z-Frames.
Die Anzahl gilt laut Handbuch **ausgehend vom Hauptmenü**:

| Anzahl | Seitengruppe | PDF-Seite / gedruckte Seite |
| --- | --- | --- |
| 1 | Verbrennung | 23 / 21 |
| 2 | Service | 26 / 24 |
| 3 | Fühlerabgleich | 31 / 29 |
| 4 | Hausanlage | 34 / 32 |
| 5 | Fehlerspeicher | 36 / 34 |
| 6 | Prüfparameter | 38 / 36 |

Das Panel bietet bewusst **einen** Weiterblättern-Button und beschreibt die
sechs Gruppen. Es führt keine blinde Mehrfachfolge aus und nimmt keinen
aktuellen Menüindex an. Den erreichten Bildschirm aus frischen Displayframes
ablesen. Plus/Minus können in diesen Menüs unmittelbar Werte ändern.
Laut Handbuch verlassen Betriebsarttasten die Zusatzmenüs; dabei die gewünschte
Betriebsart beachten. Der Aufruf der Prüfparameter ist nicht die Aktivierung
der Rauchgasmessung. Deren Kombination sowie automatische Reinigungsfolgen
werden ohne eigenen belegten Sendecode nicht ergänzt.

Die einzige Quelle für den tatsächlich gesendeten Payload bleibt UCI.
Schreibmodus, Whitelist, Hex-Prüfung und Ein/Aus-Kollisionsschutz bleiben aktiv.
Die Projektergänzung wurde ohne Sendeversuche an der Anlage vorgenommen.
