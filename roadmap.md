# Roadmap – open_slcontrol Slim Panel

## April 2026 – Slim-Reset (abgeschlossen)

- Produktfläche auf zwei Seiten reduziert: **Panel** und **Konfiguration**.
- Nicht-kritische Features und Dateien entfernt.
- Runtime auf minimalen Raw-first-Betrieb fokussiert.

## April 2026 – RPC-ACL-Fix (abgeschlossen)

- ACL um UCI-Lese-/Schreibrechte für `heizungpanel` ergänzt.
- Behebt das LuCI-Fehlbild `RPC call to uci/get failed with ubus code 6: Permission denied` auf der Konfigseite.

## Nächster Meilenstein – Hardening

1. Device-Smoke-Test auf echter OpenWrt-Instanz
   - CAN up/down Verhalten prüfen
   - MQTT reconnect prüfen
   - UI-Start ohne Snapshot prüfen (leer bis erste Live-Frames eintreffen)
   - Verifizieren, dass die Ein/Aus-Ableitung aus Bit 7 von `0x320 83xx` bei allen Betriebsarten stabil bleibt
   - Verifizieren, dass LED-/Modusanzeige bei ausbleibenden `0x320 83xx` sauber auf „unbekannt“ zurückfällt (kein Über-Latch)
   - Verifizieren, dass geänderte UCI-Maps (`led_map_83`, `mapping_*`) nach Save/Restart korrekt im Panel und bei Sendebefehlen wirken
2. Betriebsdoku ergänzen
   - kurze Troubleshooting-Sektion
   - klare Upgrade-Hinweise für Slim-Variante

## Danach – Bedienqualität

1. Optionales UI-Polishing (Spacing, Lesbarkeit, mobile Breite)
2. Optionales kleines Health-Widget (Broker erreichbar / Raw aktiv)


## April 2026 – Live-Update-Fix (abgeschlossen)

- Parser im Panel für CAN-IDs robust gemacht (führende Nullen werden akzeptiert).
- Bootstrap-/Snapshot-Pfade vollständig entfernt; Anzeige rendert nur noch aus Live-Raw-Frames.
- Kleinere Rendering-Korrektur bei Power-LED-Update umgesetzt.

## April 2026 – Config-Validation-Fix (abgeschlossen)

- Validierungsrückgaben der LuCI-Konfigfelder vereinheitlicht (`true` bei gültig, Fehlermeldung bei ungültig).
- Fehlbild „invalid field“ bei offensichtlich gültigen Eingaben auf der Konfigseite beseitigt.

## Grundsatz

Neue Features nur, wenn sie den Slim-Kern nicht aufblähen.

## April 2026 – Deploy-Fähigkeit (abgeschlossen)

- `tools/device_ssh_deploy.sh` für den Slim-Umfang wieder eingeführt.
- Install/Uninstall-Pfade auf aktuelle Dateiliste abgestimmt.
- Schnellere Testzyklen auf OpenWrt-Geräten ohne vollständigen Feed-Release ermöglicht.

## April 2026 – Konfig-Save-Fix (abgeschlossen)

- JSON-Batch-Import in `config_set.sh` robust gegen fehlerhafte Feldtrennung gemacht (TAB + Whitespace-Fallback).
- LuCI-Konfigseite auf klaren **Save & Apply**-Wording angepasst.
- Fehlbild `Unsupported key: can_if can0` damit beseitigt.

## April 2026 – Bit7-Power-Fix (abgeschlossen)

- Ein/Aus-Auswertung im Panel auf `0x320 83xx` belassen (keine Ableitung aus `0x321`-Buttonframes).
- Bit7-Decoder so korrigiert, dass nur das erste `83xx`-Statusbyte ausgewertet wird.
- Effekt „Ein/Aus wirkt invertiert bzw. ändert sich nicht“ damit beseitigt.

## April 2026 – LuCI-Config-Flow (abgeschlossen)

- Konfigseite auf natives LuCI-Formular (`form.Map`) umgestellt.
- Eigener separater Save-Button entfernt; Standard **Save / Save & Apply** wird verwendet.
- UCI-Werte werden direkt über LuCI geschrieben statt über einen proprietären Frontend-Batch-Call.

## April 2026 – Footer-Save-Flow-Fix (abgeschlossen)

- Konfig-View auf explizite Delegation zu `form.Map`-Save/Apply/Reset umgestellt.
- Damit nutzt die Seite zuverlässig den globalen LuCI-Buttonblock unten rechts für Änderungs-Erkennung und Commit.
- Redundanter zweiter Speichern-Einstieg in der Formularfläche entfällt funktional.


## April 2026 – Konfig-Schema-Hardening (abgeschlossen)

- Erwartete Werte pro Konfigfeld als klares Schema dokumentiert.
- LuCI- und Backend-Validierung auf denselben Regelsatz ausgerichtet.
- Hex-Felder gegen Sonderzeichen und falsche Längen gehärtet; `stream_token` verlangt zusätzlich gerade Länge.
