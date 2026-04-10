#!/bin/sh

. /usr/share/libubox/jshn.sh

MQTT_WAIT="$(uci -q get heizungpanel.main.state_mqtt_wait)"
[ -n "$MQTT_WAIT" ] || MQTT_WAIT="1"

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

extract_json_field() {
  local raw="$1"
  local key="$2"
  json_cleanup
  json_load "$raw" 2>/dev/null || return 1
  json_get_var __val "$key"
  printf '%s' "$__val"
}

mqtt_get_retained() {
  local topic="$1"
  mosquitto_sub -h "$HOST" -p "$PORT" -t "$topic" -C 1 -W "$MQTT_WAIT" 2>/dev/null
}

MODE_JSON="$(mqtt_get_retained "$BASE/mode")"
SNAP_JSON="$(mqtt_get_retained "$BASE/snapshot")"

MODE_FLAGS="$(extract_json_field "$MODE_JSON" flags16 2>/dev/null || true)"
MODE_NAME="$(extract_json_field "$MODE_JSON" mode_name 2>/dev/null || true)"
MODE_TS="$(extract_json_field "$MODE_JSON" ts_ms 2>/dev/null || true)"

SNAP_LINE1="$(extract_json_field "$SNAP_JSON" line1 2>/dev/null || true)"
SNAP_LINE2="$(extract_json_field "$SNAP_JSON" line2 2>/dev/null || true)"
SNAP_MODE_CODE="$(extract_json_field "$SNAP_JSON" mode_code 2>/dev/null || true)"
SNAP_TS="$(extract_json_field "$SNAP_JSON" ts_ms 2>/dev/null || true)"

# compatibility/debug fallback: only query legacy full state when bootstrap data is missing
if [ -z "$SNAP_LINE1" ] || [ -z "$SNAP_LINE2" ] || [ -z "$MODE_FLAGS" ]; then
  STATE_JSON="$(mqtt_get_retained "$BASE/state")"
  ST_LINE1="$(extract_json_field "$STATE_JSON" line1 2>/dev/null || true)"
  ST_LINE2="$(extract_json_field "$STATE_JSON" line2 2>/dev/null || true)"
  ST_FLAGS="$(extract_json_field "$STATE_JSON" mode_flags16 2>/dev/null || true)"
  ST_CODE="$(extract_json_field "$STATE_JSON" mode_code 2>/dev/null || true)"

  [ -n "$SNAP_LINE1" ] || SNAP_LINE1="$ST_LINE1"
  [ -n "$SNAP_LINE2" ] || SNAP_LINE2="$ST_LINE2"
  [ -n "$MODE_FLAGS" ] || MODE_FLAGS="$ST_FLAGS"
  [ -n "$SNAP_MODE_CODE" ] || SNAP_MODE_CODE="$ST_CODE"
fi

[ -n "$MODE_FLAGS" ] || MODE_FLAGS="----"
[ -n "$MODE_NAME" ] || MODE_NAME="unknown"
[ -n "$SNAP_MODE_CODE" ] || SNAP_MODE_CODE="--"

if [ -n "$SNAP_LINE1" ] || [ -n "$SNAP_LINE2" ] || [ "$MODE_FLAGS" != "----" ]; then
  TS_NOW="$(now_ms)"
  AGE=-1
  if is_uint "$MODE_TS"; then
    AGE=$(( TS_NOW - MODE_TS ))
    [ "$AGE" -ge 0 ] || AGE=0
  elif is_uint "$SNAP_TS"; then
    AGE=$(( TS_NOW - SNAP_TS ))
    [ "$AGE" -ge 0 ] || AGE=0
  fi

  json_init
  json_add_string status "ok"
  json_add_int schema_version 2
  json_add_string source "bootstrap"
  json_add_int age_ms "$AGE"

  json_add_object mode
  json_add_string flags16 "$MODE_FLAGS"
  json_add_string mode_name "$MODE_NAME"
  json_add_string ts_ms "$MODE_TS"
  json_close_object

  json_add_object snapshot
  json_add_string line1 "$SNAP_LINE1"
  json_add_string line2 "$SNAP_LINE2"
  json_add_string mode_code "$SNAP_MODE_CODE"
  json_add_string ts_ms "$SNAP_TS"
  json_close_object

  # Flat compatibility fields for older frontend code paths.
  json_add_string mode_flags16 "$MODE_FLAGS"
  json_add_string line1 "$SNAP_LINE1"
  json_add_string line2 "$SNAP_LINE2"
  json_add_string mode_code "$SNAP_MODE_CODE"

  json_dump
  printf '\n'
  exit 0
fi

echo '{"status":"no_data","schema_version":2,"source":"none","age_ms":-1,"mode":{"flags16":"----","mode_name":"unknown","ts_ms":""},"snapshot":{"line1":"","line2":"","mode_code":"--","ts_ms":""},"mode_flags16":"----","line1":"","line2":"","mode_code":"--"}'
