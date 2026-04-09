include $(TOPDIR)/rules.mk

PKG_NAME:=luci-app-heizungpanel
PKG_VERSION:=0.1.0
PKG_RELEASE:=1

PKG_LICENSE:=MIT
PKG_MAINTAINER:=open_slcontrol

LUCI_TITLE:=Heizungpanel (open_slcontrol)
LUCI_DEPENDS:=+luci-base +rpcd +ucode +mosquitto-client +kmod-can +kmod-can-raw +can-utils
LUCI_PKGARCH:=all

include $(TOPDIR)/feeds/luci/luci.mk

# call BuildPackage - OpenWrt buildroot entrypoint
