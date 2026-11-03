#!/bin/sh
set -eu
BASE=/usr/libexec/heizungpanel
STATE=/tmp/heizungpanel-access
. "$BASE/access_config.sh"
access_load

secure_state() {
    [ ! -L "$STATE" ] || exit 2
    umask 077
    mkdir -p "$STATE"
    [ ! -L "$STATE" ] || exit 2
    set -- $(LC_ALL=C ls -ldn "$STATE")
    [ "$1" = drwx------ ] && [ "$3" = 0 ] || exit 2
}

clock_ms() { awk '{printf "%.0f\n", $1 * 1000}' /proc/uptime; }
field() { awk -v key="$1" '$1 == key {print $2}' "$STATE/state"; }
service_ready() {
    pid=$(cat "$STATE/ready" 2>/dev/null || true)
    case "$pid" in ''|*[!0-9]*) return 1;; esac
    kill -0 "$pid" 2>/dev/null
}

transition() (
    action=$1
    tries=0
    until mkdir "$STATE/lock" 2>/dev/null; do
        tries=$((tries + 1))
        [ "$tries" -lt 20 ] || return 1
        sleep 0.1
    done
    trap 'rmdir "$STATE/lock" 2>/dev/null || true' EXIT
    [ -f "$STATE/state" ] || : > "$STATE/state"
    if awk -v cmd="$action" -v now="$(clock_ms)" -v sessions="${SESSIONS:-0}" \
        -v enabled="$ACCESS_ENABLED" -v sequence="$ACCESS_SEQUENCE" \
        -v jitter="$ACCESS_JITTER" -v minimum="$ACCESS_MINIMUM" -v window="$ACCESS_WINDOW" \
        -f "$BASE/access_sequence.awk" "$STATE/state" > "$STATE/state.new"; then
        mv "$STATE/state.new" "$STATE/state"
        if [ "$ACCESS_ENABLED" = 1 ]; then
            if [ "$(field mode)" = open ]; then
                "$BASE/access_firewall.sh" open
            else
                "$BASE/access_firewall.sh" close
            fi
        fi
        rmdir "$STATE/lock"
        trap - EXIT
    else
        rmdir "$STATE/lock"
        trap - EXIT
        return 1
    fi
)

led_restore() {
    [ -f "$STATE/led" ] || return 0
    read -r led trigger brightness < "$STATE/led"
    access_validate access_led "$led" || return 1
    case "$trigger" in *[!A-Za-z0-9_-]*|'') return 1;; esac
    case "$brightness" in *[!0-9]*|'') return 1;; esac
    if [ -d "/sys/class/leds/$led" ]; then
        echo none > "/sys/class/leds/$led/trigger"
        echo "$brightness" > "/sys/class/leds/$led/brightness"
        echo "$trigger" > "/sys/class/leds/$led/trigger"
    fi
    rm -f "$STATE/led"
}

led_show() {
    display=$1
    if [ "$display" = closed ]; then led_restore; return; fi
    [ -n "$ACCESS_LED" ] && [ -d "/sys/class/leds/$ACCESS_LED" ] || return 0
    if [ ! -f "$STATE/led" ]; then
        trigger=$(sed -n 's/.*\[\([^]]*\)\].*/\1/p' "/sys/class/leds/$ACCESS_LED/trigger")
        brightness=$(cat "/sys/class/leds/$ACCESS_LED/brightness")
        printf '%s %s %s\n' "$ACCESS_LED" "$trigger" "$brightness" > "$STATE/led"
        echo none > "/sys/class/leds/$ACCESS_LED/trigger"
    fi
    brightness=$(cat "/sys/class/leds/$ACCESS_LED/max_brightness")
    if [ "$display" = learning ] && [ $(( $(clock_ms) / 1000 % 2 )) = 0 ]; then brightness=0; fi
    echo "$brightness" > "/sys/class/leds/$ACCESS_LED/brightness"
}

session_count() {
    ubus -S call session list '{}' | /usr/bin/ucode "$BASE/access_sessions.uc"
}

status() {
    [ -f "$STATE/state" ] || transition reset
    ready=false
    service_ready && ready=true
    awk -v ready="$ready" -v enabled="$ACCESS_ENABLED" '
        $1=="mode" {mode=$2} $1=="count" {count=$2} $1=="candidate" {candidate=$2}
        $1=="error" {error=$2} $1=="held" {held=$2} $1=="deadline" {deadline=$2}
        END {printf "{\"mode\":\"%s\",\"presses\":%d,\"sequence\":\"%s\",\"error\":\"%s\",\"session_hold\":%s,\"deadline_ms\":%.0f,\"service_ready\":%s,\"enabled\":%s,\"leds\":[", mode,count,candidate,error,held?"true":"false",deadline,ready,enabled==1?"true":"false"}
    ' "$STATE/state"
    separator=
    for path in /sys/class/leds/*; do
        [ -d "$path" ] || continue
        name=${path##*/}
        case "$name" in *[!A-Za-z0-9_:.-]*|.*) continue;; esac
        printf '%s"%s"' "$separator" "$name"
        separator=,
    done
    echo ']}'
}

secure_state
case "${1:-}" in
    daemon)
        rm -rf "$STATE/lock"
        led_restore
        transition reset
        if [ "$ACCESS_ENABLED" = 1 ]; then "$BASE/access_firewall.sh" setup; else "$BASE/access_firewall.sh" disable; fi
        echo "$$" > "$STATE/ready"
        trap '"$BASE/access_firewall.sh" close; led_restore; rm -f "$STATE/ready"' EXIT
        trap 'exit 0' INT TERM
        previous=closed
        while :; do
            mode=$(field mode)
            SESSIONS=0
            if [ "$mode" = open ]; then
                SESSIONS=$(session_count) || { transition close; continue; }
            fi
            if [ "$mode" != closed ]; then transition tick; fi
            mode=$(field mode)
            case "$mode" in
                open) led_show open ;;
                record|confirm|ready) led_show learning ;;
                *) led_show closed ;;
            esac
            if [ "$mode" != "$previous" ]; then
                case "$mode" in open|closed) logger -t heizungpanel "Ethernet maintenance access: $mode";; esac
                previous=$mode
            fi
            sleep 1
        done
        ;;
    button)
        service_ready || { "$BASE/access_firewall.sh" close; exit 1; }
        [ "${ACTION:-}" = released ] || exit 0
        case "${SEEN:-}" in ''|*[!0-9]*) exit 2;; esac
        if [ "$SEEN" -ge 2 ]; then transition reset; else transition button; fi
        ;;
    learn-start|learn-next|learn-finish|close)
        /etc/init.d/heizungpanel-access running || /etc/init.d/heizungpanel-access start
        tries=0
        until service_ready; do
            tries=$((tries + 1))
            [ "$tries" -lt 30 ] || { echo 'Access service did not become ready' >&2; exit 1; }
            sleep 0.1
        done
        if [ "$1" = learn-start ] && [ "$(field mode)" = open ]; then
            echo 'Learn before enabling the gate or through a separate trusted management connection while closed' >&2
            exit 2
        fi
        transition "$1"
        status
        ;;
    status) status ;;
    --help|-h) echo 'Usage: access.sh status|learn-start|learn-next|learn-finish|close'; exit 0 ;;
    *) echo 'Usage: access.sh status|learn-start|learn-next|learn-finish|close' >&2; exit 2 ;;
esac
