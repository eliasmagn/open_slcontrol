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
- Reconnect bei CAN-Ausfall (Retry-Loops in den Bridges; CAN-Setup zentral im Init-Skript).
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
- Stand 2026-04-10: Deploy-Helper behebt einen Regressionsfehler im SCP-Aufruf; bei `install|push` werden Source/Target wieder korrekt übergeben (Fix für lokalen `scp usage`-Abbruch bei Schritt `[2/4]`).
- Stand 2026-04-10: Deploy-/Runtime-Härtung gegen Netzverlust: CAN-Setup akzeptiert nur noch `can*|vcan*|slcan*`; der Deploy-Helper überspringt den automatischen Dienstneustart bei unsicherem `can_if` und warnt stattdessen.

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


## M4.1 – Write-Pfad & sichere MQTT-Administration (**fortgeschritten am 2026-04-10**)
- `press.sh` sendet freigegebene Kommandos jetzt real auf `0x321` (`cansend <can_if> 321#...`) statt Stub-Antworten.
- Erfolgreiche TX-Kommandos werden in Syslog und optional auf MQTT (`<mqtt_base>/tx`) auditiert.
- Dedizierte LuCI-Konfig-Ansicht für App/MQTT/Safety ergänzt (`heizungpanel/config`).


## M4.2 – Konfigfluss vereinfacht (**abgeschlossen am 2026-04-10**)
- Zusätzliche MQTT-Schutz-/Unlock-Mechanik entfernt, da UCI-Standardmechanik als ausreichend bewertet wurde.
- Konfigoberfläche auf App + MQTT reduziert; keine separate Safety-Sektion mehr.

- Stand 2026-04-10: Send-Mode-Fix umgesetzt – CAN-Setup setzt `listen-only off` explizit bei `write_mode=1` (zentral im Init), damit TX zuverlässig funktioniert.
- Stand 2026-04-10: Feldabgleich umgesetzt – LCD-Geometrie von 2x16 auf 2x20 angepasst (Parser + LuCI-Renderer).
- Stand 2026-04-10: UI-Display simuliert jetzt Blanking bei Textwechsel (kurzer Full-Clear vor Neuzeichnung).
- Stand 2026-04-10: Betriebsarten-LEDs verwenden gelatchten Modus (`mode_flags16`) und bleiben dadurch persistent trotz transienter 0x321-Events.
- Stand 2026-04-10: Daemon hält den letzten Zustand wieder lokal in `/tmp/heizungpanel/state.json`; `state.sh` nutzt diesen Cache vor MQTT-Fallback für verlässlichen Initialzustand.
- Stand 2026-04-10 (Korrektur): künstliches Display-Blanking zurückgenommen; Push-Anzeige bleibt schnell, LED-Latching bleibt persistent.
- Stand 2026-04-10: 0x320-Frontend-Rendering auf vollständige Burst-Neuzeichnung umgestellt (gesamtes 2x20 wird neu geschrieben, keine Restzeichen aus Vorwerten).
- Stand 2026-04-10: UI-Feedback für Send-/Config-Aktionen von globalen LuCI-Alerts auf lokale Inline-Meldungen im Panel umgestellt (kurze Anzeigezeiten, kein Alert-Stacking, kein Layout-Sprung durch reservierten Meldungsbereich).
- Stand 2026-04-10: 0x320-Reassembly auf Marker-Protokoll umgestellt (`81` Start/Clear, adressierte Teilupdates, `83 <mode_byte>` Abschluss), um segmentweises Flackern/Abhacken im Uhrzeitbetrieb zu vermeiden.
- Stand 2026-04-10: Parser-JSON um `mode_code` erweitert; bekannte Abschlussbytes (`EF`/`FB`) stehen als zusätzliche Diagnose-/Hinweisquelle bereit.
- Stand 2026-04-10: State-Cache-Schreibpfad in `state_bridge.sh` auf Single-Line-Latest-State umgestellt (statt `tee`-Append), damit `/tmp/heizungpanel/state.json` nicht unendlich wächst und Systeme destabilisiert.
- Stand 2026-04-10: Parser-RegEx für Candump-Format-B auf ucode-kompatible Syntax ohne `(?:...)` korrigiert; damit endet der state-bridge Restart-Loop durch Laufzeit-Syntaxfehler.
- Stand 2026-04-10: `mode_code`-Deutung geschärft – `83 EF/83 FB` werden als Display-/Screenklasse geführt, nicht als Heizungs-Betriebsmodus.
- Stand 2026-04-10: LED-Priorität gehärtet – `0x321 mode_flags16` entscheidet primär; `0x320 mode_code` dient nur noch als Fallback bei fehlendem bekanntem Latch-Mode.
- Stand 2026-04-10: CAN-Quellenpriorität finalisiert – aktive Betriebsarten-LEDs werden ausschließlich aus `0x321` gesetzt; `0x320 mode_code` bleibt diagnostisch und setzt keinen Latch.
- Stand 2026-04-10: Moduswechsel-ACK im LuCI ergänzt – nach Sendekommando wird eine passende `0x321`-Bestätigung der Anlage aktiv überwacht (Erfolg/Timeout-Hinweis).
- Stand 2026-04-10: `0x320`-Abschlussbytes (`83 EF`/`83 FB`) in LuCI als Screenklasse gekennzeichnet („kein Anlagenmodus“), um Fehlinterpretation als Heizungsmodus zu vermeiden.
- Stand 2026-04-10: Build-Traceability ergänzt – Init + Bridges loggen nun ein `BUILD_TAG` (Commit-String) beim Start in Syslog.

- Stand 2026-04-10: Offene Konsolidierungspunkte geschlossen – Deploy-Dateisatz enthält die Konfig-Assets/Skripte, Konfig-Speichern läuft atomar (ein Commit/ein Restart), CAN-Setup hat genau einen Owner (Init), Parser-Env ist explizit exportiert und der Display-Emulator ist auf 2x20 synchronisiert.


## Stand 2026-04-10 – Konsolidierung Restpunkte (2. Runde)
- Bridge-Parameter bereinigt: keine toten CAN-Setup-Argumente mehr in `raw_bridge.sh`/`state_bridge.sh`.
- Parser-Env-Transfer explizit pro Aufruf: `CAN_IF`/`CAN_BITRATE` werden direkt am `ucode`-Prozess gesetzt.
- Doku-Quelle vereinheitlicht: `README.md` dient nur als Verweis auf `readme.md` (kanonisch).
- Kleine Code-Altlasten entfernt: `config.js` ohne ungenutztes `ui`-Require und ohne tote `inputRow()`-Funktion.

## Update 2026-04-10 – nächste PR-Serie (Architektur)
1. **PR 1 – Decoder-Single-Source-of-Truth**
   - Kanonischen Decoder im Backend fixieren.
   - LuCI-Raw-Decoder als Debugpfad markieren und schrittweise auf normalisierten State umstellen.
2. **PR 2 – Control-/Konfig-API-Konsolidierung**
   - Bestehende Konfigskripte hinter einer einheitlichen API zusammenführen.
3. **PR 3 – CAN-Ownership-Zentralisierung**
   - Eindeutige Ownership für CAN-Link-Lifecycle inkl. Recoveries.
4. **PR 4 – Packaging + Doku-Konsolidierung**
   - Install-Dateiliste als Single Source.
   - Einstiegsdoku auf eine kanonische Datei reduzieren.

### Bereits umgesetzt als Vorarbeit
- `state.sh` nutzt jetzt strukturelle JSON-Validierung und liefert versionierte State-Metafelder (`schema_version`, `source`, `age_ms`, `seq`).
- Stand 2026-04-10 (PR1 Teilschritt): SSE-Standardpfad liefert jetzt normalisierten State statt Raw-Frames; Browser-Raw-Decode ist damit nicht mehr Produktionspfad.
