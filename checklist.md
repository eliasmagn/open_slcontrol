# Checklist – Slim Panel Umbau

## Abgeschlossen

- [x] Panel-Live-Update stabilisiert: CAN-IDs werden normalisiert (z. B. `0320` -> `320`), damit Display-Daten wieder kontinuierlich verarbeitet werden.
- [x] Panel-LEDs/Modus auf live `0x320 83xx`-Auswertung umgestellt (ohne persistentes Latch über den Frame-Rhythmus hinaus).
- [x] Bootstrap-Polling als passive Rückfallebene ergänzt, ohne aktive Live-Frames zu überschreiben.
- [x] SSH-Deploy-Tool für Slim-Artefakte wiederhergestellt (`tools/device_ssh_deploy.sh`).
- [x] LuCI-Menü auf **Panel + Konfiguration** reduziert.
- [x] Sensor-/Mapping-/Git-Update-Views entfernt.
- [x] ACL auf verbleibende benötigte Skripte reduziert.
- [x] Legacy-State-Bridge/Parser-Stack entfernt.
- [x] Konfig-API (`config_get.sh`, `config_set.sh`) auf Kernparameter reduziert.
- [x] Default-UCI-Konfig (`/etc/config/heizungpanel`) entschlackt.
- [x] Init-Service auf Raw-Bridge-Minimalbetrieb vereinfacht.
- [x] Dokumentation (`README.md`, `concept.md`, `roadmap.md`) auf Slim-Status aktualisiert.

## Offene Aufgaben

- [ ] Optional: `panel.js` visuell weiter verschlanken (nur essentielle Statuszeilen).
- [ ] Optional: feste Command-Mappings dokumentieren (Operator-Quickref).
- [ ] Optional: kleiner Smoke-Test auf Zielgerät (LuCI klickbar + Raw-Stream vorhanden, inkl. kontinuierlicher Display-Aktualisierung).
