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
- [x] MQTT-Stream-CGI auf `${mqtt_base}/raw` als einziges Live-Topic reduziert.
- [x] `${mqtt_base}/state` aus funktionaler MQTT-Nutzung entfernt.
- [x] UI-Statusmeldungen auf Live-only angepasst (Hinweis bei fehlenden Raw-Daten bzw. `publish_raw=0`).
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

- [x] Konfig-Validierung korrigiert: LuCI-Validatoren geben bei gültigen Eingaben konsistent `true` zurück (Fix für fälschliches „invalid field“ auf der Konfigseite).
- [x] Konfig-Validierung gehärtet: Feldschema dokumentiert und Frontend-/Backend-Checks auf konsistente Regeln gebracht (inkl. strikter Hex-Prüfung und gerader `stream_token`-Länge).

- [x] Passiver geführter Lernmodus im Konfigurations-Tab **Lernen & Beitrag**: Ruhephase mit temporären Hintergrundkandidaten, zwei getrennte Pressfenster, konsistenten Loslass-/Begleitwert erlaubt aber nicht übernommen, Mehrdeutigkeits-, Fenster-Mismatch- und Kollisions-Ablehnung, Ersetzen nur nach gesonderter Bestätigung, Kombinationen nur real gedrückt. Übernahme nur ins native LuCI-Formular; Speichern ausschließlich über den normalen Footer Save / Save & Apply (verifiziert mit synthetischer LuCI-Harness in Chromium, 43 Checks).
- [x] Freiwilliger sanitisierter Modell-Konfigurationsbeitrag: JSON-Vorschau + lokaler Download, keine Netzwerkübertragung, keine Tokens/Adressen/Raw-Dumps, `existing_unverified` vs. sitzungsbestätigtes `contributor_confirmed`, `independently_confirmed` bleibt false.
- [x] `mapping_vz` in Default-UCI-Konfiguration aufgenommen (leer = deaktiviert).

- [x] App-Update auf dem Referenzrouter deployt und verifiziert: Service läuft, CAN-Setup ok, Raw-Bridge aktiv, SSE-Stream liefert Live-Daten, LuCI-Dateien erreichbar, `write_mode=1`/`mapping_vz=FF7B`/`mapping_ein=FF7B` blieben erhalten, Lern-Tab vor Ort vorhanden.
- [x] ImageBuilder-Workflow im Projektordner (`imagebuilder/`): `build_image.sh` (Overlay aus App-Baum + Guards gegen Zugangsdateien/Token/write_mode), `packages.conf` (LuCI-Basis, WireGuard, CAN gs_usb, MQTT, Wartung; `-ppp -ppp-mod-pppoe`), `populate_packages.sh` (generischer Offline-Bootstrap des netzwerklosen Host-apk), `files/` für sanitisierte Extras, README mit Flash-/Versions-Regeln.
- [x] Release-Hygiene: Default `stream_token` geleert, Altlasten `etc/passwd`, `etc/group` und falsch liegende Menü-Dublette entfernt (auch aus Deploy-Manifest und vom Router), Paketversion auf 0.2.0 erhöht.
- [x] Erkenntnis dokumentiert: 25.12.0-rc4-Images sind wegen nachträglich aktualisierter Upstream-Feeds (libubox-Versatz) nicht mehr kohärent baubar; Slim-Image bedeutet bewussten Versionswechsel (z. B. 25.12.4) beim manuellen Flashen.

- [x] Versionspolitik entschieden: Slim-Images folgen grundsätzlich der aktuellsten stabilen OpenWrt-Version; Validierungsbau erfolgreich auf **25.12.5** (Kernel 6.12.94): `openwrt-25.12.5-ath79-generic-dlink_dir-825-b1-squashfs-sysupgrade.bin` (7,27 MB, nicht geflasht; identischer Bau auch für 25.12.4 vorhanden). Manifest geprüft: ppp/pppoe entfernt, WireGuard + Tools + LuCI-Proto, CAN gs_usb + can-utils, MQTT (Broker+Client, mosquitto-User angelegt), LuCI-Basis, WLAN/USB aus Profil. App inkl. Lern-Tab gebakt; Default `write_mode=0`, `stream_token=''`; keine Netzwerk-/Geheimnisdateien im Overlay; root-shadow ohne Hash. `populate_packages.sh` lädt 172/172 APKs zuverlässig (Feed-Zuordnung aus packages.adb).

- [x] `build_image.sh --device-config root@<router>`: privates Recovery-Image mit Live-Konfig (Netzwerk/WLAN/Firewall+WireGuard/DHCP/System/Dropbear+uhttpd/heizungpanel inkl. Host- und Login-Keys) — SSH-Fetch zur Bauzeit direkt ins `/tmp`-Overlay, Repo bleibt geheimnisfrei, passwd/group/shadow bleiben verboten, Warnung vor Veröffentlichen. Verifiziert am 25.12.5-Bau: WG-Interface, 4 WLAN-Blocks, Firewall-Zonen/Rules, `authorized_keys` + beide Host-Keys, heizungpanel-Liveconfig (write_mode/mappings/Token) enthalten; keine Staging-Reste in `/tmp`.

- [x] Router-lokaler Heizungs-Alarm (unabhängig vom Home Assistant): `alarm_watchdog.sh` als zweite procd-Instanz — Fehlertext-/Eingefroren/Funkstille-Erkennung aus dem Raw-MQTT-Stream, Telegram + generische HTTPS-Alarm-URLs (CallMeBot/HA-Webhook/ntfy), Wiederholung bis Recovery, Zugangsdaten nur in UCI (LuCI-Tab „Alarm", validiert). Shell-Testsuite: 13/13 bestanden (Auslösung, Kodierung, Token-geheim, Repeat, Recovery, Normaltext, Eingefroren, Funkstille, Deaktiviert).

- [x] Router-Zeitzone auf Europe/Berlin umgestellt (`system.@system[0].zonename`, persistent via UCI; interne Uhr bleibt NTP-UTC, nur Anzeige lokal). Log-Grenze durch `LOG-ZEITZONE GEAENDERT`-Marker dokumentiert; alle älteren Log-Einträge waren UTC. Alarm-Watchdog meldet Zeitzone in Start-Log und Alarmtexten (`%Z`), Testsuite weiterhin 13/13. Wissen in AGENTS.md (Abschnitt Zeitzonen) gesichert.

- [x] Alarm-Tab in den bestehenden Tab-Balken integriert (vorher eigene Zweit-Sektion mit eigenem Mini-Tab — strukturelle LuCI-Schwäche, u. a. Verdacht hinter dem hängenden Save/Save&Apply). Optionen heißen jetzt `alarm_*` in `heizungpanel.main`; Watchdog/init.d/Defaults/Tests migriert (Suite 13/13), Router-UCI migriert (alte Sektion entfernt), Watchdog läuft, HA wird im UI nicht erwähnt.

## Offene Aufgaben (Release-Vorbereitung)

- [ ] Lizenzdatei ergänzen und Server-/Dokumentationsrechte an Handbuchtexten klären.
- [ ] Paketbau mit vollständigem OpenWrt-SDK/Buildroot validieren (Makefile ist nicht alleinstehend baubar).
- [ ] LuCI-Endabnahme auf echtem Testgerät inkl. Lernassistent gegen reale Tastendrücke und Save & Apply; Flashen des 25.12.4-Slim-Images bewusst entscheiden (Versionswechsel von rc4).
- [ ] Vor Veröffentlichung Git-Historie auf alte Token-/Gerätedaten prüfen (bereits committeter Stream-Token muss aus der Historie entfernt werden).
- [ ] Optional: `panel.js` visuell weiter verschlanken (nur essentielle Statuszeilen).
- [ ] Optional: feste Command-Mappings dokumentieren (Operator-Quickref).
