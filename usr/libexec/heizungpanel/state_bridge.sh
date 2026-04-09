#!/bin/sh

CAN_IF="$1"
CAN_BITRATE="$2"
CAN_SETUP="$3"
LISTEN_ONLY="$4"
MQTT_HOST="$5"
MQTT_PORT="$6"
TOPIC_STATE="$7"
STATE_FILE="$8"

[ -n "$CAN_IF" ] || CAN_IF="can0"
[ -n "$CAN_BITRATE" ] || CAN_BITRATE="69144"
[ -n "$CAN_SETUP" ] || CAN_SETUP="1"
[ -n "$LISTEN_ONLY" ] || LISTEN_ONLY="1"
[ -n "$MQTT_HOST" ] || MQTT_HOST="127.0.0.1"
[ -n "$MQTT_PORT" ] || MQTT_PORT="1883"
[ -n "$TOPIC_STATE" ] || TOPIC_STATE="heizungpanel/state"
[ -n "$STATE_FILE" ] || STATE_FILE="/tmp/heizungpanel/state.json"

setup_can() {
  [ "$CAN_SETUP" = "1" ] || return 0

  if ! ip link show "$CAN_IF" >/dev/null 2>&1; then
    logger -t heizungpanel "CAN interface missing: $CAN_IF"
    return 1
  fi

  local lo_arg=""
  [ "$LISTEN_ONLY" = "1" ] && lo_arg="listen-only on"

  ip link set "$CAN_IF" down >/dev/null 2>&1 || true
  if ! ip link set "$CAN_IF" type can bitrate "$CAN_BITRATE" $lo_arg >/dev/null 2>&1; then
    logger -t heizungpanel "CAN setup failed: if=$CAN_IF bitrate=$CAN_BITRATE"
    return 1
  fi

  if ! ip link set "$CAN_IF" up >/dev/null 2>&1; then
    logger -t heizungpanel "CAN bring-up failed: if=$CAN_IF"
    return 1
  fi

  return 0
}

while true; do
  if ! setup_can; then
    sleep 2
    continue
  fi

  CAN_IF="$CAN_IF" CAN_BITRATE="$CAN_BITRATE" candump -L "$CAN_IF" 2>/dev/null \
    | /usr/bin/ucode /usr/libexec/heizungpanel/parser.uc \
    | tee "$STATE_FILE" \
    | mosquitto_pub -h "$MQTT_HOST" -p "$MQTT_PORT" -t "$TOPIC_STATE" -r -l

  rc=$?
  logger -t heizungpanel "state bridge exited (rc=$rc, if=$CAN_IF); reinitializing CAN and retrying"
  sleep 1
done
