# Konzept – open_slcontrol

## Ziel
Eine robuste OpenWrt/LuCI-App für Lindner & Sommerauer SL über CAN, mit stabilem Read-only-Betrieb als Standard und optionalem, abgesichertem Write-Modus.

## Ausgangslage
Die App ist funktional im Read-only-Pfad:
- LuCI-WebGUI ist sichtbar und nutzbar.
- CAN-Interface + Bridges laufen mit Reconnect-Verhalten inkl. CAN-Reinit in beiden Bridges.
- `candump`-Frames werden geparst und als JSON-State verteilt.
- Der SSH/SCP-Deploy-Weg ist vorhanden; ein Stage-Lifetime-Bug im Deploy-Skript wurde am 2026-04-09 behoben, damit Uploads zuverlässig laufen.
- Der SSH/SCP-Deploy-Weg ist auf OpenWrt/Dropbear-Ziele ohne SFTP-Server angepasst (`scp -O`), damit Deployments nicht an `ash: /usr/libexec/sftp-server: not found` scheitern (2026-04-09).
- Der SSH/SCP-Deploy-Weg nutzt jetzt standardmäßig SSH-Multiplexing (`ControlMaster/ControlPersist`), damit ein Deploy-Lauf nur eine Passwortabfrage benötigt (2026-04-09).
- Der SSH/SCP-Deploy-Weg liefert die LuCI-Menüdatei (`/usr/share/luci/menu.d/luci-app-heizungpanel.json`) mit aus und leert LuCI-Caches, damit der Menüpunkt unter `Services` nach Neuinstallation sofort sichtbar ist (2026-04-09).
- Der SSH/SCP-Deploy-Weg synchronisiert zusätzlich `/usr/share/luci-app-heizungpanel.json` bei Install/Uninstall, damit sowohl aktuelle als auch ältere LuCI-Menüladepfade unterstützt werden (2026-04-10).
- Der SSH/SCP-Deploy-Weg spiegelt den Legacy-Menüpfad aus einer kanonischen `menu.d`-Quelle, um redundante Pflege und Drift zwischen zwei Menüdateien zu vermeiden (2026-04-10).
- Der SSH/SCP-Deploy-Weg startet den Dienst nach frischer Erstinstallation robust per `stop || true` + `start` (statt `restart`), um den „zweiter Push nötig“-Effekt nach Device-Reset zu vermeiden (2026-04-09).
- Der SSH/SCP-Deploy-Weg validiert Pflichtargumente für Optionen robust und überschreibt `/etc/config/heizungpanel` standardmäßig nicht mehr ungefragt (optional via `--overwrite-config`) (2026-04-10).
- Der SSH/SCP-Deploy-Weg reicht beim Upload die Stage-Quellen wieder korrekt an `scp` durch; damit bricht `install|push` nach Schritt `[2/4] Upload files via scp` nicht mehr mit der reinen `scp`-Usage ab (2026-04-10).
- Der SSH/SCP-Deploy-Weg prüft vor dem automatischen Dienstneustart die CAN-Interface-Sicherheit und überspringt den Restart mit Warnung, wenn ein unsicheres `can_if` erkannt wird (2026-04-10).

## Architektur (Soll)
1. Erfassung: `candump` auf `can_if` (Raw/State jeweils mit CAN-Reinit bei Fehlern).
2. Parsing: `parser.uc` bleibt für den State-Topic-Pfad verfügbar, aber die LuCI-Visualisierung dekodiert eingehende Rohframes (`0x320/0x321/0x1F5`) direkt im Browser.
3. Verteilung: MQTT retain als Primärquelle; zusätzlich stellt ein CGI-SSE-Bridge (`/www/cgi-bin/heizungpanel_stream`) den Raw-Topic-Strom als `text/event-stream` bereit.
   Für den lokalen Fallback hält `state_bridge.sh` den State-Cache in `/tmp` bewusst als **Single-Line Latest-State** (kein Log-Append), um RAM-/tmp-Wachstum zu verhindern.
4. UI: LuCI nutzt primär EventSource-Push (SSE) statt festem Polling. Die LCD-Emulation rendert ASCII (`0x20..0x7E`) plus beobachtete deutsche Sonderzeichen (`0xDF -> °`, `0xE2 -> ß`, `0xF5 -> ü`, `0xE1 -> ä`, `0xEF -> ö`) clientseitig. Bei fehlendem EventSource-Support bleibt Polling-Fallback aktiv.
   Das 0x320-Display wird markerbasiert zusammengesetzt (`0x81` = Clear/Neubeginn, adressierte Teilupdates, `0x83 <mode_byte>` = Abschluss), um segmentweises „Abhacken“ zu vermeiden. Send-Kommandos ohne hinterlegtes CAN-Mapping werden als lokaler UI-Hinweis ausgewiesen.
5. Runtime-Konfig: LuCI liest `poll_interval_ms`/`write_mode` über `config.sh` aus UCI und bietet im Panel einen Konfigurations-Switch für den Send-Mode (`write_mode`). `listen_only` wird nur intern im Dienst aus `write_mode` abgeleitet (keine redundante Frontend-Konfiguration). Default-Polling ist auf 500 ms abgesenkt, um die UI-Latenz zu reduzieren.
6. Security-Gate: `press.sh` erzwingt `write_mode` + strikte Command-Allowlist und sendet bestätigte Mapping-Codes als `0x321`-Frames über `cansend`.
7. Display-Emulation: `display_emulator.sh` rendert die aus `0x320` rekonstruierten LCD-Zeilen live aus MQTT-Raw oder offline aus Candump/STDIN; fragmentierte Markerblöcke werden offset-basiert gemerged, optional mit 0x321-Markertrace (`--show-flags`).
8. Mapping-Validierung: `mapping_validate.sh` prüft 0x321-Flags und 0x258/0x259-Index-Paare aus Candump-Dateien für reproduzierbare M2-Befunde.
9. 0x321-Clusteranalyse: `isolate_321.sh` gruppiert Candump-Frames nach identischem `flags16` und zeigt Kontextframes, um LED-/Moduszuordnungen reproduzierbar abzuleiten.
10. Parser-Robustheit: `parser.uc` akzeptiert neben `ID#HEX` auch timestampbasierte Candump-Varianten mit `[len] bytes` (je nach can-utils-Version), damit 0x320-Text zuverlässig in UI/State ankommt.
11. Candump-Quellformat vereinheitlicht: Bridges nutzen standardmäßig `candump -a -t a -x`; `parser.uc` entfernt die angehängte ASCII-Spalte vor dem Byte-Parsing, um Fehlmatches aus `'...'`-Debugtext zu vermeiden.

## Leitlinien
- Bestehende Funktionalität erhalten.
- Safety-first (read-only default, minimale ACL, Write-Gate).
- Schrittweise Härtung vor Feature-Ausbau.

## Umsetzungsreihenfolge (aktuell)
1. **M1 Stabilität abgeschlossen:** CAN-Reconnect + dokumentierter Restart/Long-run-Stresstest als Gate erfüllt.
2. **M1.5 Runtime-Knobs abgeschlossen:** Polling-Intervall vollständig UCI-/UI-gesteuert.
3. **Security-Gate vor Write abgeschlossen:** UCI-Write-Mode (default off) + strikte Allowlist aktiv.
4. **M2 Protokoll-Engineering (nächster Schritt):** strukturierte Dumps, versioniertes Mapping, Hypothesenvalidierung.
5. **M3 Packaging/Distribution:** Feed-Struktur und reproduzierbarer Install-/Upgradepfad inkl. SSH/SCP-Deploy-Helper (`tools/device_ssh_deploy.sh`) für Install/Uninstall auf Zielgeräten; Feed-Stub vorhanden (`package/luci-app-heizungpanel/Makefile`), Installpfad dokumentiert (`docs/packaging_install.md`).

- LuCI-Frontend wird bewusst ES5-kompatibel gehalten (insbesondere in View-Skripten), da der LuCI-Loader auf Zielsystemen sonst mit `compileClass`-Syntaxfehlern ausfallen kann.
- UI-Statuslogik wurde gehärtet: Ein formales `status=ok` ohne decodierbare LCD-/Flag-Nutzdaten wird als Warnzustand dargestellt, um Scheinsicherheit im LuCI-Panel zu vermeiden (2026-04-09).

12. Dedizierte Konfiguration: eigene LuCI-Seite (`heizungpanel/config`) für App-/MQTT-/Safety-Einstellungen mit serverseitiger Validierung (`config_set.sh`) statt verteilter Einzel-Toggles.


15. Vereinfachter Konfigfluss: keine zusätzliche MQTT-Unlock-Policy mehr; die App verwendet den normalen UCI-Konfigurationspfad für `heizungpanel.main` ohne extra Schutzschicht.

16. CAN-Write-Betrieb: Bei aktivem Write-Mode wird beim (Re-)Setup des CAN-Interfaces `listen-only off` explizit gesetzt (Init + Bridge-Reinit), um latente Listen-only-Reste sicher zu überschreiben.
17. Interface-Safety: CAN-Setup ist strikt auf Interface-Präfixe `can*`, `vcan*`, `slcan*` begrenzt, damit Fehlkonfigurationen keine Netzwerk-Uplinks herunterfahren.
18. Feldabgleich 2026-04-10: LCD-Geometrie auf 2x20 erweitert (statt 2x16), inkl. HD44780-Offset-Fenster `0x00..0x13` und `0x40..0x53`.
19. UI-Verhalten: Bei erkannten Inhaltswechseln wird ein kurzes LCD-Blanking simuliert, um das reale Umschaltverhalten besser abzubilden.
20. Persistenter Modusstatus: Parser führt `mode_flags16` als gelatchten Betriebsartenstatus; LuCI-LEDs orientieren sich daran statt an kurzlebigen Event-Flags.
21. Daemon-seitige Zustandsvorhaltung: `state_bridge.sh` schreibt den letzten JSON-State nach `/tmp/heizungpanel/state.json`, sodass beim ersten Öffnen des Webinterface sofort ein bekannter Zustand vorliegt (auch wenn MQTT gerade keine frische Antwort liefert).
22. Korrektur 2026-04-10: Display bleibt im Push-Betrieb ohne künstliches Blanking; persistiert wird nur der Betriebsartenstatus der LEDs (Latch), nicht ein zusätzlicher Display-Flicker-Effekt.
23. Lesbarkeits-/Safety-Korrektur 2026-04-10: Im Frontend wird pro 0x320-Burst immer ein kompletter 2x20-Frame aus einem zuvor geleerten 40-Char-Buffer aufgebaut und dann als Ganzes gerendert (keine Restzeichen).
