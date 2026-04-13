# Checklist – Slim Panel Umbau

## Abgeschlossen

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
- [ ] Optional: kleiner Smoke-Test auf Zielgerät (LuCI klickbar + Raw-Stream vorhanden).
