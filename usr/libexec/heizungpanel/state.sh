#!/bin/sh

. /usr/share/libubox/jshn.sh

MQTT_WAIT="$(uci -q get heizungpanel.main.state_mqtt_wait)"
[ -n "$MQTT_WAIT" ] || MQTT_WAIT="1"
STATE_CACHE="$(uci -q get heizungpanel.main.state_cache_file)"
[ -n "$STATE_CACHE" ] || STATE_CACHE="/tmp/heizungpanel/state.json"

BASE="$(uci -q get heizungpanel.main.mqtt_base)"
HOST="$(uci -q get heizungpanel.main.mqtt_host)"
PORT="$(uci -q get heizungpanel.main.mqtt_port)"
[ -n "$BASE" ] || BASE="heizungpanel"
[ -n "$HOST" ] || HOST="127.0.0.1"
[ -n "$PORT" ] || PORT="1883"

now_ms() {
  date +%s000
}

is_uint() {
  case "$1" in
    ''|*[!0-9]*) return 1 ;;
    *) return 0 ;;
  esac
}

normalize_state_json() {
  local raw="$1"
  local source_label="$2"
  local ts age frame

  json_cleanup
  json_load "$raw" 2>/dev/null || return 1

  json_get_type __root_type
  [ "$__root_type" = "object" ] || return 1

  json_get_var ts ts_ms
  json_get_var frame source_frame

  if is_uint "$ts"; then
    age=$(( $(now_ms) - ts ))
    [ "$age" -ge 0 ] || age=0
  else
    age=-1
  fi

  json_add_int schema_version 1
  json_add_string source "$source_label"
  json_add_int age_ms "$age"

  if is_uint "$frame"; then
    json_add_int seq "$frame"
  fi

  json_dump
}

emit_or_fail() {
  local raw="$1"
  local source_label="$2"
  local out

  out="$(normalize_state_json "$raw" "$source_label")" || return 1
  printf '%s\n' "$out"
}

if [ -s "$STATE_CACHE" ]; then
  CACHED="$(tail -n 1 "$STATE_CACHE" 2>/dev/null)"
  if emit_or_fail "$CACHED" "cache"; then
    exit 0
  fi
fi

LIVE="$(mosquitto_sub -h "$HOST" -p "$PORT" -t "$BASE/state" -C 1 -W "$MQTT_WAIT" 2>/dev/null)"
if emit_or_fail "$LIVE" "mqtt"; then
  exit 0
fi

echo '{"status":"no_data","schema_version":1,"source":"none","age_ms":-1,"seq":0,"line1":"","line2":"","flags16":"----","mode_flags16":"----","mode_code":"--","last_1f5":""}'
