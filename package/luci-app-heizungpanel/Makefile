include $(TOPDIR)/rules.mk

PKG_NAME:=luci-app-heizungpanel
PKG_VERSION:=0.2.0
PKG_RELEASE:=2

PKG_LICENSE:=MIT
PKG_MAINTAINER:=open_slcontrol <https://github.com/eliasmagn/open_slcontrol>

# Source trees live outside the recipe directory (canonical app layout),
# so hash them explicitly for rebuild triggering.
PKG_FILE_DEPENDS:=$(CURDIR)/../../etc $(CURDIR)/../../usr $(CURDIR)/../../www

include $(INCLUDE_DIR)/package.mk

define Package/luci-app-heizungpanel
  SECTION:=luci
  CATEGORY:=LuCI
  SUBMENU:=3. Applications
  TITLE:=Heizungpanel - CAN-bus heating control panel (Lindner & Sommerauer)
  DEPENDS:=+luci-base +rpcd +rpcd-mod-file +ucode +ucode-mod-fs +uclient-fetch +libustream-mbedtls +ca-bundle +mosquitto-client-nossl +kmod-can +kmod-can-raw +canutils-candump +canutils-cansend +uhttpd +uhttpd-mod-ubus +ip-full
  PKGARCH:=all
endef

define Package/luci-app-heizungpanel/description
 Live-only LuCI panel for a Lindner & Sommerauer heating unit on SocketCAN:
 CAN to MQTT bridge, SSE stream, mode/LED decoding from fresh CAN frames and
 write-guarded operator commands. No snapshots, no fallback UI state.
endef

define Package/luci-app-heizungpanel/conffiles
/etc/config/heizungpanel
endef

define Build/Configure
endef

define Build/Compile
endef

define Package/luci-app-heizungpanel/install
	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_BIN) $(CURDIR)/../../etc/init.d/heizungpanel $(1)/etc/init.d/
	$(INSTALL_DIR) $(1)/etc/config
	$(INSTALL_CONF) $(CURDIR)/../../etc/config/heizungpanel $(1)/etc/config/heizungpanel
	$(INSTALL_DIR) $(1)/usr/libexec/heizungpanel
	$(INSTALL_BIN) $(CURDIR)/../../usr/libexec/heizungpanel/alarm_watchdog.sh \
		$(CURDIR)/../../usr/libexec/heizungpanel/config.sh \
		$(CURDIR)/../../usr/libexec/heizungpanel/config_get.sh \
		$(CURDIR)/../../usr/libexec/heizungpanel/config_set.sh \
		$(CURDIR)/../../usr/libexec/heizungpanel/ha_bridge.sh \
		$(CURDIR)/../../usr/libexec/heizungpanel/press.sh \
		$(CURDIR)/../../usr/libexec/heizungpanel/raw_bridge.sh \
		$(CURDIR)/../../usr/libexec/heizungpanel/set_mode.sh \
		$(1)/usr/libexec/heizungpanel/
	$(INSTALL_DATA) $(CURDIR)/../../usr/libexec/heizungpanel/telegram_json.uc $(1)/usr/libexec/heizungpanel/
	$(INSTALL_DIR) $(1)/usr/share/rpcd/acl.d
	$(INSTALL_DATA) $(CURDIR)/../../usr/share/rpcd/acl.d/luci-app-heizungpanel.json $(1)/usr/share/rpcd/acl.d/
	$(INSTALL_DIR) $(1)/usr/share/luci/menu.d
	$(INSTALL_DATA) $(CURDIR)/../../usr/share/luci/menu.d/luci-app-heizungpanel.json $(1)/usr/share/luci/menu.d/
	$(INSTALL_DIR) $(1)/www/cgi-bin
	$(INSTALL_BIN) $(CURDIR)/../../www/cgi-bin/heizungpanel_stream $(1)/www/cgi-bin/
	$(INSTALL_DIR) $(1)/www/luci-static/resources/view/heizungpanel
	$(INSTALL_DATA) $(CURDIR)/../../www/luci-static/resources/view/heizungpanel/config.js \
		$(CURDIR)/../../www/luci-static/resources/view/heizungpanel/panel.js \
		$(1)/www/luci-static/resources/view/heizungpanel/
endef

define Package/luci-app-heizungpanel/postinst
#!/bin/sh
[ -n "$${IPKG_INSTROOT}" ] || {
	rm -f /tmp/luci-indexcache.*
	rm -rf /tmp/luci-modulecache/
	/etc/init.d/rpcd reload 2>/dev/null
	exit 0
}
endef

$(eval $(call BuildPackage,luci-app-heizungpanel))
