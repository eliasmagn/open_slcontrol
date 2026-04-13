# Roadmap – open_slcontrol Slim Panel

## April 2026 – Slim-Reset (abgeschlossen)

- Produktfläche auf zwei Seiten reduziert: **Panel** und **Konfiguration**.
- Nicht-kritische Features und Dateien entfernt.
- Runtime auf minimalen Raw-first-Betrieb fokussiert.

## Nächster Meilenstein – Hardening

1. Device-Smoke-Test auf echter OpenWrt-Instanz
   - CAN up/down Verhalten prüfen
   - MQTT reconnect prüfen
   - UI-Bootstrap->Live Übergang prüfen
2. Betriebsdoku ergänzen
   - kurze Troubleshooting-Sektion
   - klare Upgrade-Hinweise für Slim-Variante

## Danach – Bedienqualität

1. Optionales UI-Polishing (Spacing, Lesbarkeit, mobile Breite)
2. Optionales kleines Health-Widget (Broker erreichbar / Raw aktiv)

## Grundsatz

Neue Features nur, wenn sie den Slim-Kern nicht aufblähen.

## April 2026 – Deploy-Fähigkeit (abgeschlossen)

- `tools/device_ssh_deploy.sh` für den Slim-Umfang wieder eingeführt.
- Install/Uninstall-Pfade auf aktuelle Dateiliste abgestimmt.
- Schnellere Testzyklen auf OpenWrt-Geräten ohne vollständigen Feed-Release ermöglicht.

