# Konzept – open_slcontrol Slim Panel

## Zielbild

Aus der bisherigen, gewachsenen App wird ein **kleines, robustes Bedienpanel** mit minimaler Laufzeitkomplexität:

1. CAN-Rohdaten lesen
2. Rohdaten auf MQTT publizieren
3. Kleines Bootstrap-Artefakt lokal ablegen
4. Browser rendert Anzeige und Modus live aus Raw-Frames

## Architektur

- **Runtime:** `raw_bridge.sh` als einziger dauerhafter Bridge-Prozess
- **Bootstrap:** `/tmp/heizungpanel/bootstrap.json`
- **UI:** nur `Panel` + `Konfiguration`
- **Write-Gate:** Sendefunktionen nur bei `write_mode=1`

## Bewusste Nicht-Ziele

- Keine Engineering-Unterseiten
- Keine Mapping-/Sensor-Forschungsoberflächen
- Kein In-App-Git-Update
- Keine Legacy-Fullstate-Pipeline im Default-Scope

## Leitprinzipien

- **Slim first**: lieber entfernen als erweitern
- **Strong defaults**: read-only als Standard, write explizit aktivieren
- **Wartbar**: reduzierte Anzahl Dateien, Prozesse, UI-Flächen

## Betriebsmodus Deployment

- **Paket-Workflow bleibt Standard** für reproduzierbare Releases.
- **SSH-Deploy-Tool ist ergänzend** für schnelle Entwicklungszyklen auf Testgeräten (`tools/device_ssh_deploy.sh`).
- Das Deploy-Tool verteilt ausschließlich die Slim-Panel-Artefakte (Panel, Konfiguration, Raw-Bridge-Stack) und hält damit die Runtime weiterhin minimal.

