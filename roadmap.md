# Roadmap – open_slcontrol

## M1 – Betriebsstabilität (**abgeschlossen am 2026-04-09**)
**Ziel:** Solider 24/7-Read-only-Betrieb als Freigabe-Gate für Folgephasen.

### Erledigt
- LuCI-Panel-Emulation im UI klar als 2x16-LCD-Spiegel markiert (inkl. No-Data/Fehler-Leerzustand), damit die Ansicht als Gerätepanel-Emulation erkennbar ist.
- CAN-Start prüft Interface und loggt Fehler.
- State-Distribution über MQTT retained aktiv.
- LuCI-Stateabruf läuft MQTT-basiert (ohne Dateicache), um Stale-Reads zu vermeiden.
- UI-Status für `OK` / `keine Daten` / `Fehler` vorhanden.
- „Letzte Aktualisierung“ im UI sichtbar.
- ACL auf notwendige Skripte eingeschränkt.
- Reconnect bei CAN-Ausfall (Retry-Loops + CAN-Reinit in State- und Raw-Bridge).
- Restart-/Long-run-Stresstest durchgeführt und dokumentiert.

## M1.5 – Runtime-Knobs in Config/UI (**abgeschlossen am 2026-04-09**)
- Polling-Intervall in UCI modelliert (`poll_interval_ms`).
- LuCI übernimmt Polling-Wert aus UCI statt Hardcode.
- LuCI-Intervall-Validierung ist jetzt mit Backend-Clamp konsistent (`250..10000`).
- LuCI-Konfigurations-Switch für `write_mode` (Send mode) im Panel integriert; Persistenz via UCI + Service-Neustart.
- `listen_only` wird zur Laufzeit aus `write_mode` abgeleitet (kein redundanter separater Schalter mehr).

## Security Gate vor Write-Pfad (**abgeschlossen am 2026-04-09**)
- UCI-Write-Flag (`write_mode`, Default aus).
- Strikte Command-Allowlist in `press.sh`.
- UI bleibt default read-only, Write nur bei aktivem Flag.

## M2 – Datenqualität & Mapping (**in Arbeit, Stand v0.1 am 2026-04-09**)
### Erledigt in v0/v0.1
- Versionierte Mapping-Doku `docs/mapping_v0.md` erstellt.
- Parser umgestellt auf strukturierte LCD-Reassembly (`0x320`), Bitdekodierung (`0x321`) und `0x258/0x259` Pairing.
- Confidence-/Invariant-Metadaten im JSON-Output eingeführt.
- Session-Extrakt aus vorhandenem Dump als `docs/campaign_v0.md` dokumentiert.
- LCD-Zeichenrendering auf deutsches Panel-Mapping gesetzt: ASCII (`0x20..0x7E`) plus `0xDF -> °`, `0xE2 -> ß`, `0xF5 -> ü`, `0xE1 -> ä`, `0xEF -> ö`.
- Capture-Helper für Ein-Aktions-Sequenzen (`usr/libexec/heizungpanel/m2_capture.sh`) ergänzt.
- Mapping-Validierungs-Helper (`usr/libexec/heizungpanel/mapping_validate.sh`) ergänzt (0x321-Ratio + 0x258/0x259-Pairing aus Candump-Logs).
- 0x321-Isolations-Helper (`usr/libexec/heizungpanel/isolate_321.sh`) ergänzt (Unique-Flags + Kontextframes pro Wert), damit LED-/Modus-Hypothesen direkt aus Dumps gebildet werden können.
- Terminal-Display-Emulation erweitert (`usr/libexec/heizungpanel/display_emulator.sh`) für Live-MQTT und Offline-Candump/STDIN-Sicht auf rekonstruierte LCD-Daten (`0x320`) inkl. optionaler 0x321-Markertrace (`--show-flags`).

### Offen für M2-Abschluss
- Echte kontrollierte Ein-Aktions-Captures: Idle(60s), `+`, `-`, `Z`, `V`, Mode enter/exit.
- Pro Bit: Event-Puls vs Latch mit reproduzierbaren Zeitreihen final bestätigen.
- `likely`-Zuordnungen auf `confirmed` heben.

## M3 – Packaging/Distribution
- Feed/ImageBuilder-reife Paketstruktur (gestartet mit `package/luci-app-heizungpanel/Makefile`).
- Reproduzierbare Installation und definierter Upgradepfad (`docs/packaging_install.md`).
- SSH/SCP-Deploy-Helper vorhanden (`tools/device_ssh_deploy.sh`) für Push/Install sowie Remove/Uninstall auf laufenden Geräten.
- Stand 2026-04-09: Stage-Lifetime-Fix im Deploy-Helper umgesetzt (verhindert fehlende lokale Stage-Pfade während `scp`).
- Stand 2026-04-09: SCP-Protokollfix im Deploy-Helper umgesetzt (`scp -O`), damit Deploy auf OpenWrt/Dropbear ohne SFTP-Subsystem funktioniert.
- Stand 2026-04-09: SSH-Verbindungs-Multiplexing im Deploy-Helper aktiviert, damit Passwortabfragen pro Lauf auf eine Abfrage reduziert werden (abschaltbar via `--no-mux`).
- Stand 2026-04-09: Deploy liefert jetzt zusätzlich die LuCI-Menüdatei nach `/usr/share/luci/menu.d/luci-app-heizungpanel.json`, damit der Eintrag unter `Services` nach Reset/Neuinstallation sichtbar ist.
- Stand 2026-04-10: Deploy synchronisiert zusätzlich `/usr/share/luci-app-heizungpanel.json` (Install + Remove), damit aktuelle und ältere LuCI-Menüladepfade gleichermaßen abgedeckt sind.
- Stand 2026-04-10: Deploy spiegelt den Legacy-Menüpfad aus einer kanonischen `menu.d`-Quelle, um Redundanz/Drift zwischen zwei getrennten Menüdateien zu vermeiden.
- Stand 2026-04-09: Deploy löscht LuCI-Index-/Modulcache, damit Menüänderungen ohne manuellen Reboot übernommen werden.
- Stand 2026-04-09: Deploy startet den Dienst auf frischen Geräten robust mit `stop || true` + `start` (statt `restart`), damit nach Device-Reset kein zweiter Push nötig ist.
- Stand 2026-04-10: Deploy-CLI validiert fehlende Pflichtwerte robuster (`--port`, `--identity`, `--stage`) und bietet `--overwrite-config` für bewusstes Überschreiben von `/etc/config/heizungpanel`.

## M4 – Optionaler Write-Mode (nach Mapping/Validierung)
- Mappingbasierter Sendepfad auf Basis Allowlist.
- Optional: Audit-Logging für Write-Aktionen.

- Stand 2026-04-09: LuCI-Frontend-Syntax auf ES5-Kompatibilität korrigiert (`panel.js` ohne Template-Literal), wodurch der `compileClass`-Syntaxfehler beim Laden der Ansicht behoben ist.

- Stand 2026-04-09: lokaler Reconnect-/Stabilitäts-Harness (`tools/bridge_stability_harness.sh`) zeigt wiederholte Exit/Retry-Zyklen inkl. erneuter CAN-Initialisierung für beide Bridges.
- Stand 2026-04-09: LuCI-Statuslogik im Frontend gehärtet; bei leerem Payload trotz `status=ok` wird nun ein Warnstatus angezeigt ("verbunden, aber noch keine decodierbaren Paneldaten").
- Stand 2026-04-09: LuCI-Zeitstempel-Anzeige gehärtet; bei unplausibler Parser-`ts_ms`-Abweichung (>5 Minuten) zeigt das Panel Browserzeit (`Letzte Aktualisierung ... (Browserzeit)`), damit die UI-Zeit konsistent mit der LuCI-Systemansicht bleibt.
- Stand 2026-04-09: LuCI-Mode-LEDs und Modus-/Tastenhinweise werden jetzt live aus bekannten `0x321 flags16`-Werten gespeist (u.a. `7FFF/BFFF/DFFF/EFFF/F7FF/FBFF/FDFF`, Navigation `FFFB/FF7F`).
- Stand 2026-04-09: Parser akzeptiert jetzt zusätzlich timestampbasierte Candump-Zeilen mit `[len] bytes` (can-utils-abhängig), wodurch 0x320-LCD-Texte wieder im LuCI-Panel erscheinen.
- Stand 2026-04-10: Bridges wurden auf ein einheitliches Live-/Debug-Quellformat umgestellt (`candump -a -t a -x`, optional via `CANDUMP_ARGS`), damit Feld-Dumps 1:1 dem Laufzeitstrom entsprechen.
- Stand 2026-04-10: Parser schneidet bei `candump -x` die angehängte ASCII-Spalte (`'...'`) vor der Hex-Extraktion ab, um Fehlinterpretationen beim LCD-Reassembly zu verhindern.
- Stand 2026-04-10: LuCI-Statusabruf auf MQTT-Only umgestellt (`state.sh` ohne Dateicache, `state_bridge.sh` ohne `tee`-Statefile), um Anzeige-Latenz und Datei-Staleness zu reduzieren.
- Stand 2026-04-10: Runtime entschlackt (`init.d` ohne obsoletes `state_file`-Argument, `config.sh` nur mit benötigten Feldern), um Overhead und Komplexität zu senken.
- Stand 2026-04-10: Default-LuCI-Polling auf 500ms gesenkt (bei weiterem Clamp `250..10000`) für sichtbar niedrigere Interaktionslatenz.
- Stand 2026-04-10: LuCI nutzt primär Push-Updates via SSE (`/cgi-bin/heizungpanel_stream`) statt Intervall-Polling.
- Stand 2026-04-10: Parsing für die UI wurde in den Browser verlagert (`panel.js` dekodiert `0x320/0x321/0x1F5` aus Raw-Frames), um Router-CPU für die Paneldarstellung zu entlasten.
- Stand 2026-04-09: Deploy-Tool-Fileliste erweitert; `set_mode.sh` und `isolate_321.sh` werden bei Install/Push mit übertragen.
- Stand 2026-04-09: LuCI behandelt `press.sh`-Exitcode 4 jetzt als Hinweis „Mapping noch nicht hinterlegt“ statt als generischen Send-Fehler.
