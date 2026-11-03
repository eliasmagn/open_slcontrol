#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT INT TERM
ENGINE=$ROOT/usr/libexec/heizungpanel/access_sequence.awk
. "$ROOT/usr/libexec/heizungpanel/access_config.sh"
state=$TMP/state
: > "$state"

step() {
    awk -v cmd="$1" -v now="$2" -v sessions="${3:-0}" -v enabled="${enabled:-1}" \
        -v sequence=2000,2000,300,300,300 -v jitter=25 -v minimum=80 -v window=300 \
        -f "$ENGINE" "$state" > "$TMP/next"
    mv "$TMP/next" "$state"
}
expect() {
    actual=$(awk -v key="$1" '$1==key {print $2}' "$state")
    [ "$actual" = "$2" ] || { echo "FAIL: $1 expected $2, got $actual" >&2; exit 1; }
}
press_pattern() {
    for timestamp in 1000 3100 5050 5370 5650 5960; do step button "$timestamp"; done
}

step reset 0
press_pattern
expect mode open
step button 6000
expect mode open
step button 6200
expect mode closed
echo 'PASS: jitter accepted; bounce ignored; subsequent press closes'

step reset 1000000000
for timestamp in 1000001000 1000003100 1000005050 1000005370 1000005650 1000005960; do step button "$timestamp"; done
expect mode open
expect last 1000005960
echo 'PASS: millisecond resolution retained after long uptime'

step reset 0
enabled=0
press_pattern
expect mode closed
enabled=1
echo 'PASS: disabled feature never opens access'

step reset 0
for timestamp in 1000 2000 2300 2600 2900 3200; do step button "$timestamp"; done
expect mode closed
echo 'PASS: incorrect rhythm rejected'

step reset 0
press_pattern
step tick 400000 1
expect mode open
expect held 1
step tick 401000 0
expect deadline 701000
step tick 700999 0
expect mode open
step tick 701000 0
expect mode closed
echo 'PASS: valid session holds; full configured post-session timeout closes'

step reset 0
press_pattern
step tick 6000 1
step button 6300
expect mode closed
step tick 7000 1
expect mode closed
echo 'PASS: manual closure overrides session; session cannot reopen access'

step reset 0
press_pattern
step tick 305960 0
expect mode closed
echo 'PASS: unauthenticated window expires'

step learn-start 0
press_pattern
expect mode record
expect count 6
step learn-next 7000
expect mode confirm
for timestamp in 8000 10000 12000 12300 12600 12900; do step button "$timestamp"; done
step learn-finish 14000
expect mode ready
expect candidate 2050,1975,310,290,305
echo 'PASS: two physical-event samples produce an averaged candidate without opening'

step learn-start 20000
step button 21000
step learn-next 22000
expect error press_count
expect mode record
step tick 80001
expect mode closed
expect error learning_timeout
echo 'PASS: short enrollment rejected; enrollment timeout closes'

step learn-start 0
press_pattern
step learn-next 7000
for timestamp in 8000 8500 9000 9500 10000 10500; do step button "$timestamp"; done
step learn-finish 11000
expect error mismatch
expect candidate ''
echo 'PASS: inconsistent confirmation rejected'

for pair in 'access_enabled 2' 'access_sequence 100,200,300' 'access_sequence 200,300' \
    'access_devices eth0;reboot' 'access_devices lo/../etc' 'access_devices eth0\ eth0' \
    'access_led ../power' 'access_jitter_percent 41' 'access_window_seconds 0'; do
    key=${pair%% *}
    value=${pair#* }
    if access_validate "$key" "$value" 2>/dev/null; then
        echo "FAIL: accepted invalid setting $key" >&2
        exit 1
    fi
done
access_validate access_devices 'eth0.1 br-maint'
access_validate access_sequence '2000,2000,300,300,300'
access_validate access_led 'router:red:status'
echo 'PASS: configuration boundary rejects invalid values and accepts valid settings'

STATE=$TMP/led-state
mkdir -p "$STATE" "$TMP/leds/qa:red:status"
ACCESS_LED=qa:red:status
printf 'none [heartbeat] timer\n' > "$TMP/leds/$ACCESS_LED/trigger"
printf '0\n' > "$TMP/leds/$ACCESS_LED/brightness"
printf '1\n' > "$TMP/leds/$ACCESS_LED/max_brightness"
sed -n '/^led_restore()/,/^session_count()/p' "$ROOT/usr/libexec/heizungpanel/access.sh" |
    sed '$d' | sed "s|/sys/class/leds/|$TMP/leds/|g" > "$TMP/led-functions"
. "$TMP/led-functions"
clock_ms() { echo 1000; }
led_show open
[ "$(cat "$TMP/leds/$ACCESS_LED/brightness")" = 1 ]
[ "$(cat "$TMP/leds/$ACCESS_LED/trigger")" = none ]
led_show closed
[ "$(cat "$TMP/leds/$ACCESS_LED/brightness")" = 0 ]
[ "$(cat "$TMP/leds/$ACCESS_LED/trigger")" = heartbeat ]
printf 'none [heartbeat] timer\n' > "$TMP/leds/$ACCESS_LED/trigger"
led_show learning
[ "$(cat "$TMP/leds/$ACCESS_LED/brightness")" = 1 ]
clock_ms() { echo 2000; }
led_show learning
[ "$(cat "$TMP/leds/$ACCESS_LED/brightness")" = 0 ]
led_show closed
[ "$(cat "$TMP/leds/$ACCESS_LED/trigger")" = heartbeat ]
echo 'PASS: LED file-model shows open/blinking states and restores original trigger/brightness'
