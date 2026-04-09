# Konzept – open_slcontrol

## Ziel
Eine robuste OpenWrt/LuCI-App für Lindner & Sommerauer SL über CAN, mit stabilem Read-only-Betrieb als Standard und optionalem, abgesichertem Write-Modus.

## Ausgangslage
Die App ist funktional im Read-only-Pfad:
- LuCI-WebGUI ist sichtbar und nutzbar.
- CAN-Interface + Bridges laufen mit Reconnect-Verhalten.
- `candump`-Frames werden geparst und als JSON-State verteilt.
- Der SSH/SCP-Deploy-Weg ist vorhanden; ein Stage-Lifetime-Bug im Deploy-Skript wurde am 2026-04-09 behoben, damit Uploads zuverlässig laufen.
- Der SSH/SCP-Deploy-Weg ist auf OpenWrt/Dropbear-Ziele ohne SFTP-Server angepasst (`scp -O`), damit Deployments nicht an `ash: /usr/libexec/sftp-server: not found` scheitern (2026-04-09).
- Der SSH/SCP-Deploy-Weg nutzt jetzt standardmäßig SSH-Multiplexing (`ControlMaster/ControlPersist`), damit ein Deploy-Lauf nur eine Passwortabfrage benötigt (2026-04-09).
- Der SSH/SCP-Deploy-Weg liefert die LuCI-Menüdatei (`/usr/share/luci/menu.d/luci-app-heizungpanel.json`) mit aus und leert LuCI-Caches, damit der Menüpunkt unter `Services` nach Neuinstallation sofort sichtbar ist (2026-04-09).

## Architektur (Soll)
1. Erfassung: `candump` auf `can_if`.
2. Parsing: `parser.uc` erzeugt JSON-State.
3. Verteilung: MQTT retain + lokaler Cache (`/tmp/heizungpanel/state.json`).
4. UI: LuCI liest `state.sh`, zeigt Status/Fallback sauber an.
5. Runtime-Konfig: LuCI liest `poll_interval_ms`/`write_mode` über `config.sh` aus UCI.
6. Security-Gate: `press.sh` erzwingt `write_mode` + strikte Command-Allowlist.
7. Display-Emulation: `display_emulator.sh` rendert die aus `0x320` rekonstruierten LCD-Zeilen live aus MQTT **oder offline aus einem `candump`-Logfile/STDIN** und korreliert Marker-Eingaben (auch fragmentiert, z. B. `a` … `r`) mit nachfolgenden `0x321`-Statuswechseln.
8. Anzeige-Fidelity: Parser/Emulator dekodieren neben ASCII auch beobachtete LCD-Sonderzeichen (`°`, `ß`, `ü`, `ä`, `ö`), damit die LuCI-Ansicht näher am realen Paneltext liegt.

## Leitlinien
- Bestehende Funktionalität erhalten.
- Safety-first (read-only default, minimale ACL, Write-Gate).
- Schrittweise Härtung vor Feature-Ausbau.

## Umsetzungsreihenfolge (aktuell)
1. **M1 Stabilität abgeschlossen:** CAN-Reconnect + dokumentierter Restart/Long-run-Stresstest als Gate erfüllt.
2. **M1.5 Runtime-Knobs abgeschlossen:** Polling-Intervall vollständig UCI-/UI-gesteuert.
3. **Security-Gate vor Write abgeschlossen:** UCI-Write-Mode (default off) + strikte Allowlist aktiv.
4. **M2 Protokoll-Engineering (nächster Schritt):** strukturierte Dumps, versioniertes Mapping, Hypothesenvalidierung.
5. **M3 Packaging/Distribution:** Feed-Struktur und reproduzierbarer Install-/Upgradepfad inkl. SSH/SCP-Deploy-Helper (`tools/device_ssh_deploy.sh`) für Install/Uninstall auf Zielgeräten.

- LuCI-Frontend wird bewusst ES5-kompatibel gehalten (insbesondere in View-Skripten), da der LuCI-Loader auf Zielsystemen sonst mit `compileClass`-Syntaxfehlern ausfallen kann.
