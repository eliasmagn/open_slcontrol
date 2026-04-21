# Checklist – Slim Panel Umbau

## Abgeschlossen

- [x] RPC-ACL für LuCI-Konfigseite korrigiert: `uci/get`/`uci/set` auf `heizungpanel` für `luci-app-heizungpanel` freigegeben (Fix für `RPC call to uci/get failed with ubus code 6: Permission denied`).
- [x] LuCI-Konfigseite: globalen Footer (**unten rechts Save / Save & Apply**) als einzigen Speichereinstieg verdrahtet; redundanten Formular-Button entfernt.
- [x] LED-/Modus-Mapping aus `0x320 83xx` in UCI konfigurierbar gemacht (`led_map_83`, `led_power_ein_when_bit7_clear`).
- [x] Button-/Mode-Sendemapping vollständig in UCI konfigurierbar gemacht (`mapping_*`) und in der LuCI-Konfigseite editierbar gemacht.
- [x] `0x320 83xx`-Decoder erweitert: Modus-Varianten `BF/3F`, `DF/5F`, `EF/6F`, `FB/7B` werden konsistent erkannt.
- [x] Ein/Aus-LEDs aus Bit-7-Ableitung des `83xx`-Statusbytes ergänzt.
- [x] Panel-Live-Update stabilisiert: CAN-IDs werden normalisiert (z. B. `0320` -> `320`), damit Display-Daten wieder kontinuierlich verarbeitet werden.
- [x] Panel-LEDs/Modus auf live `0x320 83xx`-Auswertung umgestellt (ohne persistentes Latch über den Frame-Rhythmus hinaus).
- [x] Bootstrap-/Snapshot-/Fallback-Logik vollständig entfernt; UI rendert nur noch aus Live-CAN-Raw-Frames.
- [x] SSH-Deploy-Tool für Slim-Artefakte wiederhergestellt (`tools/device_ssh_deploy.sh`).
- [x] LuCI-Menü auf **Panel + Konfiguration** reduziert.
- [x] Sensor-/Mapping-/Git-Update-Views entfernt.
- [x] ACL auf verbleibende benötigte Skripte reduziert.
- [x] Legacy-State-Bridge/Parser-Stack entfernt.
- [x] Konfig-API (`config_get.sh`, `config_set.sh`) auf Kernparameter reduziert.
- [x] Default-UCI-Konfig (`/etc/config/heizungpanel`) entschlackt.
- [x] Init-Service auf Raw-Bridge-Minimalbetrieb vereinfacht.
- [x] Dokumentation (`README.md`, `concept.md`, `roadmap.md`) auf Slim-Status aktualisiert.

- [x] Batch-Speicherpfad repariert: JSON-Import in `config_set.sh` tolerant für TAB- und Whitespace-getrennte Zeilen gemacht (fix für Fehler wie `Unsupported key: can_if can0`).
- [x] Konfigseite auf nativen LuCI-Flow umgestellt: kein eigener Save-Button mehr, stattdessen Standard **Save / Save & Apply** mit direktem UCI-Write.
- [x] Ein/Aus-Indikator korrigiert: Bit7-Logik für `0x320 83xx` liest jetzt explizit das erste `83xx`-Statusbyte (kein Fehlzugriff auf Folgebytes).

## Offene Aufgaben

- [ ] Optional: `panel.js` visuell weiter verschlanken (nur essentielle Statuszeilen).
- [ ] Optional: feste Command-Mappings dokumentieren (Operator-Quickref).
- [ ] Optional: kleiner Smoke-Test auf Zielgerät (LuCI klickbar + Raw-Stream vorhanden, inkl. kontinuierlicher Display-Aktualisierung).
