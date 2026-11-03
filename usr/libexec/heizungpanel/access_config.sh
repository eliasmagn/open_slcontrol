#!/bin/sh

access_validate() {
    case "$1" in
        access_enabled) case "$2" in 0|1) return 0;; esac ;;
        access_window_seconds) awk -v v="$2" 'BEGIN {exit !(v ~ /^[0-9]+$/ && v >= 30 && v <= 3600)}' && return 0 ;;
        access_jitter_percent) awk -v v="$2" 'BEGIN {exit !(v ~ /^[0-9]+$/ && v >= 5 && v <= 40)}' && return 0 ;;
        access_jitter_ms) awk -v v="$2" 'BEGIN {exit !(v ~ /^[0-9]+$/ && v >= 20 && v <= 250)}' && return 0 ;;
        access_sequence)
            awk -v v="$2" 'BEGIN {n=split(v,a,","); if(n<3 || n>15) exit 1; for(i=1;i<=n;i++) if(a[i] !~ /^[0-9]+$/ || a[i]<120 || a[i]>10000) exit 1}' && return 0 ;;
        access_devices)
            awk -v v="$2" 'BEGIN {if(v=="") exit 0; if(v !~ /^[A-Za-z0-9_][A-Za-z0-9_.:-]*( [A-Za-z0-9_][A-Za-z0-9_.:-]*)*$/) exit 1; n=split(v,a," "); if(n>8) exit 1; for(i=1;i<=n;i++) if(length(a[i])>15 || seen[a[i]]++) exit 1}' && return 0 ;;
        access_led) case "$2" in *[!A-Za-z0-9_:.-]*|.*) ;; *) [ "${#2}" -le 64 ] && return 0;; esac ;;
    esac
    echo "Invalid access setting: $1" >&2
    return 2
}

access_load() {
    ACCESS_ENABLED=$(uci -q get heizungpanel.main.access_enabled || echo 0)
    ACCESS_DEVICES=$(uci -q get heizungpanel.main.access_devices || true)
    ACCESS_SEQUENCE=$(uci -q get heizungpanel.main.access_sequence || echo 2000,2000,300,300,300)
    ACCESS_WINDOW=$(uci -q get heizungpanel.main.access_window_seconds || echo 300)
    ACCESS_JITTER=$(uci -q get heizungpanel.main.access_jitter_percent || echo 25)
    ACCESS_MINIMUM=$(uci -q get heizungpanel.main.access_jitter_ms || echo 80)
    ACCESS_LED=$(uci -q get heizungpanel.main.access_led || true)
    access_validate access_enabled "$ACCESS_ENABLED" &&
    access_validate access_devices "$ACCESS_DEVICES" &&
    access_validate access_sequence "$ACCESS_SEQUENCE" &&
    access_validate access_window_seconds "$ACCESS_WINDOW" &&
    access_validate access_jitter_percent "$ACCESS_JITTER" &&
    access_validate access_jitter_ms "$ACCESS_MINIMUM" &&
    access_validate access_led "$ACCESS_LED" || return 2
    if [ "$ACCESS_ENABLED" = 1 ] && [ -z "$ACCESS_DEVICES" ]; then
        echo 'Select isolated Ethernet management devices before enabling access control' >&2
        return 2
    fi
}
