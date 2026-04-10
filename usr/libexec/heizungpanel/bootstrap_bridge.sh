#!/bin/sh

. /usr/share/libubox/jshn.sh

MQTT_HOST="$1"
MQTT_PORT="$2"
TOPIC_MODE="$3"
TOPIC_SNAPSHOT="$4"
TOPIC_BOOTSTRAP="$5"

[ -n "$MQTT_HOST" ] || MQTT_HOST="127.0.0.1"
[ -n "$MQTT_PORT" ] || MQTT_PORT="1883"
[ -n "$TOPIC_MODE" ] || TOPIC_MODE="heizungpanel/mode"
[ -n "$TOPIC_SNAPSHOT" ] || TOPIC_SNAPSHOT="heizungpanel/snapshot"
[ -n "$TOPIC_BOOTSTRAP" ] || TOPIC_BOOTSTRAP="heizungpanel/bootstrap"
BUILD_TAG="commit:8b755f2"

logger -t heizungpanel "bootstrap bridge start ($BUILD_TAG)"

extract_json_field() {
  local raw="$1"
  local key="$2"
  json_cleanup
  json_load "$raw" 2>/dev/null || return 1
  json_get_var __val "$key"
  printf '%s' "$__val"
}

publish_bootstrap() {
  local mode_flags="$1"
  local mode_name="$2"
  local mode_ts="$3"
  local snap_line1="$4"
  local snap_line2="$5"
  local snap_mode_code="$6"
  local snap_ts="$7"

  [ -n "$mode_flags" ] || mode_flags="----"
  [ -n "$mode_name" ] || mode_name="unknown"
  [ -n "$snap_mode_code" ] || snap_mode_code="--"

  json_init
  json_add_int schema_version 1

  json_add_object mode
  json_add_string flags16 "$mode_flags"
  json_add_string mode_name "$mode_name"
  json_add_string ts_ms "$mode_ts"
  json_close_object

  json_add_object snapshot
  json_add_string line1 "$snap_line1"
  json_add_string line2 "$snap_line2"
  json_add_string mode_code "$snap_mode_code"
  json_add_string ts_ms "$snap_ts"
  json_close_object

  json_dump | mosquitto_pub -h "$MQTT_HOST" -p "$MQTT_PORT" -t "$TOPIC_BOOTSTRAP" -r -l
}

MODE_FLAGS=""
MODE_NAME=""
MODE_TS=""
SNAP_LINE1=""
SNAP_LINE2=""
SNAP_MODE_CODE=""
SNAP_TS=""

while true; do
  mosquitto_sub -h "$MQTT_HOST" -p "$MQTT_PORT" -v -t "$TOPIC_MODE" -t "$TOPIC_SNAPSHOT" 2>/dev/null \
    | while IFS= read -r line; do
        [ -n "$line" ] || continue
        topic="${line%% *}"
        payload="${line#* }"
        [ "$topic" = "$line" ] && continue

        if [ "$topic" = "$TOPIC_MODE" ]; then
          MODE_FLAGS="$(extract_json_field "$payload" flags16 2>/dev/null || true)"
          MODE_NAME="$(extract_json_field "$payload" mode_name 2>/dev/null || true)"
          MODE_TS="$(extract_json_field "$payload" ts_ms 2>/dev/null || true)"
        elif [ "$topic" = "$TOPIC_SNAPSHOT" ]; then
          SNAP_LINE1="$(extract_json_field "$payload" line1 2>/dev/null || true)"
          SNAP_LINE2="$(extract_json_field "$payload" line2 2>/dev/null || true)"
          SNAP_MODE_CODE="$(extract_json_field "$payload" mode_code 2>/dev/null || true)"
          SNAP_TS="$(extract_json_field "$payload" ts_ms 2>/dev/null || true)"
        else
          continue
        fi

        publish_bootstrap "$MODE_FLAGS" "$MODE_NAME" "$MODE_TS" "$SNAP_LINE1" "$SNAP_LINE2" "$SNAP_MODE_CODE" "$SNAP_TS"
      done

  rc=$?
  logger -t heizungpanel "bootstrap bridge exited (rc=$rc); retrying"
  sleep 1
done
