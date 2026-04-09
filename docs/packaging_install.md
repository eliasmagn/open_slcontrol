# Packaging & Install Path (Stand 2026-04-09)

## Ziel
Reproduzierbarer Install-/Upgradepfad für `luci-app-heizungpanel` über OpenWrt-Feed plus schneller SSH/SCP-Deploy für Entwicklung.

## Repository-Struktur
- Runtime/Init:
  - `etc/init.d/heizungpanel`
  - `etc/config/heizungpanel`
- Runtime-Skripte:
  - `usr/libexec/heizungpanel/*.sh`
  - `usr/libexec/heizungpanel/parser.uc`
- LuCI/RPCD:
  - `www/luci-static/resources/view/heizungpanel/panel.js`
  - `usr/share/luci/menu.d/luci-app-heizungpanel.json`
  - `usr/share/rpcd/acl.d/luci-app-heizungpanel.json`
- Feed-Stub:
  - `package/luci-app-heizungpanel/Makefile`
- Dev-Deploy:
  - `tools/device_ssh_deploy.sh`

## Entwicklungs-Deploy (ohne Buildroot)
1. `tools/device_ssh_deploy.sh install root@<router-ip>`
2. Script kopiert Dateien nach `/etc`, `/usr/libexec`, `/usr/share`, `/www`.
3. Danach Reload von `rpcd`/`uhttpd`, LuCI-Cache-Cleanup und Service-Restart.

## Upgrade-Pfad
- Gleiches Kommando wie Install (`install|push`), idempotent.
- Bei Anpassungen in UCI-Schema anschließend auf Zielgerät prüfen:
  - `uci show heizungpanel`
  - fehlende Defaults nachziehen und `uci commit heizungpanel`.

## Feed-Paket (Buildroot)
Die Datei `package/luci-app-heizungpanel/Makefile` ist als Einstieg vorhanden.
Für produktive Feed-Nutzung wird als nächster Schritt eine vollständige Paket-Installsektion ergänzt, die alle oben gelisteten Artefakte ins Rootfs installiert.

## Uninstall
- `tools/device_ssh_deploy.sh uninstall root@<router-ip>`
- entfernt init/config/libexec/LuCI/ACL-Dateien und stoppt/deaktiviert den Service.
