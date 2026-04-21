# Konzept – open_slcontrol Slim Panel

## Zielbild

Aus der bisherigen, gewachsenen App wird ein **kleines, robustes Bedienpanel** mit minimaler Laufzeitkomplexität:

1. CAN-Rohdaten lesen
2. Rohdaten auf MQTT publizieren
3. Browser rendert Anzeige und Modus live aus Raw-Frames

## Architektur

- **Runtime:** `raw_bridge.sh` als einziger dauerhafter Bridge-Prozess
- **UI:** nur `Panel` + `Konfiguration`
- **Konfig-UX:** nativer LuCI Save/Save & Apply-Flow (kein separater proprietärer Save-Button)
- **Single Save Entry:** Änderungen werden zentral über den globalen LuCI-Footer (unten rechts) gespeichert, damit Dirty-State und Apply-Verhalten konsistent bleiben
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
- **Live statt Latch**: UI-LEDs/Modus folgen frischen `0x320 83xx`-Frames und werden nicht künstlich dauerhaft gehalten
- **Konfigurierbar ohne Code-Änderung**: Mapping-Logik für Anzeige (LED/Modus) und Senden (Buttons/Mode) liegt in UCI.

## Betriebsmodus Deployment

- **Paket-Workflow bleibt Standard** für reproduzierbare Releases.
- **SSH-Deploy-Tool ist ergänzend** für schnelle Entwicklungszyklen auf Testgeräten (`tools/device_ssh_deploy.sh`).
- Das Deploy-Tool verteilt ausschließlich die Slim-Panel-Artefakte (Panel, Konfiguration, Raw-Bridge-Stack) und hält damit die Runtime weiterhin minimal.


## Betriebsrobustheit (ergänzt)

- Konfigurations-Commitpfad muss atomar und parser-robust sein (Batch-Update ohne Key/Value-Verschiebung; tolerant für TAB-/Whitespace-Trennungen).
- LuCI-/rpcd-ACL muss explizit UCI-Zugriff auf `heizungpanel` erlauben, damit `form.Map`-basierte Konfigseiten `uci/get` und `uci/set` ohne ubus-Fehler ausführen können.
- Parser muss CAN-IDs tolerant verarbeiten (auch mit führenden Nullen aus unterschiedlichen `candump`-Formaten).
- Kein Bootstrap-/Snapshot-Fallback: Anzeige startet leer und folgt ausschließlich Live-Frames.
- `0x320 83xx`-Statusdecoder muss protokollnahe Varianten je Betriebsart abdecken (z. B. `BF/3F`, `DF/5F`, `EF/6F`, `FB/7B`).
- Ein/Aus-Anzeige wird aus dem ersten Statusbyte von `0x320 83xx` (Bit 7) abgeleitet; `0x321` dient nur als Bedienereignis, nicht als LED-Quelle.
