#!/bin/sh
set -eu
. /usr/libexec/heizungpanel/access_config.sh
access_load

case "${1:-}" in
    setup|check)
        [ "$ACCESS_ENABLED" = 1 ] || exit 0
        if [ "$(uci -q get firewall.@defaults[0].flow_offloading || true)" = 1 ] ||
           [ "$(uci -q get firewall.@defaults[0].flow_offloading_hw || true)" = 1 ]; then
            echo 'Disable firewall flow offloading before enabling maintenance isolation' >&2
            exit 2
        fi
        for dev in $ACCESS_DEVICES; do
            [ "$dev" != lo ] || exit 2
            if [ -f "/sys/class/net/$dev/type" ]; then
                [ "$(cat "/sys/class/net/$dev/type")" = 1 ] || { echo 'Management device must use Ethernet framing' >&2; exit 2; }
            fi
            found=0
            for iface in $(uci show network | sed -n 's/^network\.\([^.=]*\)=interface$/\1/p'); do
                target=$(uci -q get "network.$iface.device" || true)
                [ "$target" = "$dev" ] || continue
                found=1
                for wifi in $(uci -q show wireless | sed -n 's/^wireless\.\([^.=]*\)=wifi-iface$/\1/p'); do
                    for net in $(uci -q get "wireless.$wifi.network" || true); do
                        [ "$net" != "$iface" ] || {
                            echo 'Management network must not contain configured Wi-Fi' >&2
                            exit 2
                        }
                    done
                done
            done
            [ "$found" = 1 ] || { echo 'Device must be explicitly assigned to a network interface' >&2; exit 2; }
            [ ! -e "/sys/class/net/$dev/phy80211" ] && [ ! -e "/sys/class/net/$dev/master" ] || {
                echo 'Management device must be a dedicated wired L3 device, not a bridge member or Wi-Fi device' >&2
                exit 2
            }
            for member in "/sys/class/net/$dev/brif/"*; do
                [ ! -e "$member/phy80211" ] || {
                    echo 'Management bridge must not contain Wi-Fi' >&2
                    exit 2
                }
            done
        done
        [ "$1" != check ] || exit 0
        existing=0
        nft list table inet heizung_access >/dev/null 2>&1 && existing=1
        {
            [ "$existing" = 0 ] || echo 'delete table inet heizung_access'
            echo 'table inet heizung_access {'
            echo 'set permitted { type ifname; flags timeout; timeout 3s; gc-interval 1s; }'
            echo 'chain input { type filter hook input priority -10; policy accept;'
            echo 'iifname @permitted tcp dport { 22, 80, 443 } accept'
            echo 'iifname @permitted udp dport { 67, 547 } accept'
            echo 'iifname @permitted icmpv6 type { nd-router-solicit, nd-neighbor-solicit, nd-neighbor-advert } accept'
            for dev in $ACCESS_DEVICES; do printf 'iifname "%s" drop\n' "$dev"; done
            echo '}'
            echo 'chain forward { type filter hook forward priority -10; policy accept;'
            for dev in $ACCESS_DEVICES; do printf 'iifname "%s" drop\noifname "%s" drop\n' "$dev" "$dev"; done
            echo '}'
            echo '}'
        } | nft -f -
        ;;
    open)
        [ "$ACCESS_ENABLED" = 1 ] || exit 2
        {
            echo 'flush set inet heizung_access permitted'
            for dev in $ACCESS_DEVICES; do printf 'add element inet heizung_access permitted { "%s" timeout 3s }\n' "$dev"; done
        } | nft -f -
        ;;
    close) nft list table inet heizung_access >/dev/null 2>&1 && nft flush set inet heizung_access permitted ;;
    disable) nft list table inet heizung_access >/dev/null 2>&1 && nft delete table inet heizung_access ;;
    *) exit 2 ;;
esac
exit 0
