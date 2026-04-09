# Roadmap – open_slcontrol

## M1 – Betriebsstabilität (**abgeschlossen am 2026-04-09**)
**Ziel:** Solider 24/7-Read-only-Betrieb als Freigabe-Gate für Folgephasen.

### Erledigt
- CAN-Start prüft Interface und loggt Fehler.
- State-Cache via `/tmp/heizungpanel/state.json` aktiv.
- Frischeprüfung für Cache (`state_max_age`) aktiv.
- UI-Status für `OK` / `keine Daten` / `Fehler` vorhanden.
- „Letzte Aktualisierung“ im UI sichtbar.
- ACL auf notwendige Skripte eingeschränkt.
- Reconnect bei CAN-Ausfall (Retry-Loops + CAN-Reinit im State-Bridge-Prozess).
- Restart-/Long-run-Stresstest durchgeführt und dokumentiert.

## M1.5 – Runtime-Knobs in Config/UI (**abgeschlossen am 2026-04-09**)
- Polling-Intervall in UCI modelliert (`poll_interval_ms`).
- LuCI übernimmt Polling-Wert aus UCI statt Hardcode.
- LuCI-Intervall-Validierung ist jetzt mit Backend-Clamp konsistent (`250..10000`).

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
- Capture-Helper für Ein-Aktions-Sequenzen (`usr/libexec/heizungpanel/m2_capture.sh`) ergänzt.
- Terminal-Display-Emulation ergänzt (`usr/libexec/heizungpanel/display_emulator.sh`) für Live-Sicht auf gesendete LCD-Daten (`0x320`) ohne Originaldisplay.

### Offen für M2-Abschluss
- Echte kontrollierte Ein-Aktions-Captures: Idle(60s), `+`, `-`, `Z`, `V`, Mode enter/exit.
- Pro Bit: Event-Puls vs Latch mit reproduzierbaren Zeitreihen final bestätigen.
- `likely`-Zuordnungen auf `confirmed` heben.

## M3 – Packaging/Distribution
- Feed/ImageBuilder-reife Paketstruktur.
- Reproduzierbare Installation und definierter Upgradepfad.
- SSH/SCP-Deploy-Helper vorhanden (`tools/device_ssh_deploy.sh`) für Push/Install sowie Remove/Uninstall auf laufenden Geräten.
- Stand 2026-04-09: Stage-Lifetime-Fix im Deploy-Helper umgesetzt (verhindert fehlende lokale Stage-Pfade während `scp`).
- Stand 2026-04-09: SCP-Protokollfix im Deploy-Helper umgesetzt (`scp -O`), damit Deploy auf OpenWrt/Dropbear ohne SFTP-Subsystem funktioniert.
- Stand 2026-04-09: SSH-Verbindungs-Multiplexing im Deploy-Helper aktiviert, damit Passwortabfragen pro Lauf auf eine Abfrage reduziert werden (abschaltbar via `--no-mux`).
- Stand 2026-04-09: Deploy liefert jetzt zusätzlich die LuCI-Menüdatei nach `/usr/share/luci/menu.d/luci-app-heizungpanel.json`, damit der Eintrag unter `Services` nach Reset/Neuinstallation sichtbar ist.
- Stand 2026-04-09: Deploy löscht LuCI-Index-/Modulcache, damit Menüänderungen ohne manuellen Reboot übernommen werden.

## M4 – Optionaler Write-Mode (nach Mapping/Validierung)
- Mappingbasierter Sendepfad auf Basis Allowlist.
- Optional: Audit-Logging für Write-Aktionen.

- Stand 2026-04-09: LuCI-Frontend-Syntax auf ES5-Kompatibilität korrigiert (`panel.js` ohne Template-Literal), wodurch der `compileClass`-Syntaxfehler beim Laden der Ansicht behoben ist.
