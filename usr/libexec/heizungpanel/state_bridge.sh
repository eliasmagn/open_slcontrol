#!/bin/sh

CAN_IF="$1"
CAN_BITRATE="$2"
MQTT_HOST="$3"
MQTT_PORT="$4"
TOPIC_STATE="$5"

[ -n "$CAN_IF" ] || CAN_IF="can0"
[ -n "$CAN_BITRATE" ] || CAN_BITRATE="69144"
[ -n "$MQTT_HOST" ] || MQTT_HOST="127.0.0.1"
[ -n "$MQTT_PORT" ] || MQTT_PORT="1883"
[ -n "$TOPIC_STATE" ] || TOPIC_STATE="heizungpanel/state"
[ -n "$CANDUMP_ARGS" ] || CANDUMP_ARGS="-a -t a -x"
[ -n "$STATE_CACHE" ] || STATE_CACHE="/tmp/heizungpanel/state.json"
BUILD_TAG="commit:8b755f2"
STATE_CACHE_DIR="$(dirname "$STATE_CACHE")"

mkdir -p "$STATE_CACHE_DIR" >/dev/null 2>&1 || true
: > "$STATE_CACHE" 2>/dev/null || true
logger -t heizungpanel "state bridge start ($BUILD_TAG)"

cache_and_forward() {
  local line tmp
  tmp="${STATE_CACHE}.tmp"

  while IFS= read -r line; do
    # Keep cache bounded to exactly one JSON line to prevent /tmp growth.
    printf '%s\n' "$line" > "$tmp" 2>/dev/null || true
    mv "$tmp" "$STATE_CACHE" 2>/dev/null || true
    printf '%s\n' "$line"
  done
}

while true; do
  candump $CANDUMP_ARGS "$CAN_IF" 2>/dev/null \
    | CAN_IF="$CAN_IF" CAN_BITRATE="$CAN_BITRATE" /usr/bin/ucode /usr/libexec/heizungpanel/parser.uc \
    | cache_and_forward \
    | mosquitto_pub -h "$MQTT_HOST" -p "$MQTT_PORT" -t "$TOPIC_STATE" -r -l

  rc=$?
  logger -t heizungpanel "state bridge exited (rc=$rc, if=$CAN_IF); retrying"
  sleep 1
done
