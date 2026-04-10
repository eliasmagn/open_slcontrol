#!/bin/sh
MQTT_WAIT="$(uci -q get heizungpanel.main.state_mqtt_wait)"
[ -n "$MQTT_WAIT" ] || MQTT_WAIT="1"
STATE_CACHE="$(uci -q get heizungpanel.main.state_cache_file)"
[ -n "$STATE_CACHE" ] || STATE_CACHE="/tmp/heizungpanel/state.json"

is_valid_json_line() {
  case "$1" in
    *\{*\}*) return 0 ;;
    *) return 1 ;;
  esac
}

BASE="$(uci -q get heizungpanel.main.mqtt_base)"
HOST="$(uci -q get heizungpanel.main.mqtt_host)"
PORT="$(uci -q get heizungpanel.main.mqtt_port)"
[ -n "$BASE" ] || BASE="heizungpanel"
[ -n "$HOST" ] || HOST="127.0.0.1"
[ -n "$PORT" ] || PORT="1883"

if [ -s "$STATE_CACHE" ]; then
  CACHED="$(tail -n 1 "$STATE_CACHE" 2>/dev/null)"
  if is_valid_json_line "$CACHED"; then
    printf '%s\n' "$CACHED"
    exit 0
  fi
fi

LIVE="$(mosquitto_sub -h "$HOST" -p "$PORT" -t "$BASE/state" -C 1 -W "$MQTT_WAIT" 2>/dev/null)"
if is_valid_json_line "$LIVE"; then
  printf '%s\n' "$LIVE"
  exit 0
fi

echo '{"status":"no_data","line1":"","line2":"","flags16":"----","mode_flags16":"----","last_1f5":""}'
