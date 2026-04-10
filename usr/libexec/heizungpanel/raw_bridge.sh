#!/bin/sh

CAN_IF="$1"
CAN_BITRATE="$2"
CAN_SETUP="$3"
LISTEN_ONLY="$4"
MQTT_HOST="$5"
MQTT_PORT="$6"
TOPIC_RAW="$7"

[ -n "$CAN_IF" ] || CAN_IF="can0"
[ -n "$CAN_BITRATE" ] || CAN_BITRATE="69144"
[ -n "$CAN_SETUP" ] || CAN_SETUP="1"
[ -n "$LISTEN_ONLY" ] || LISTEN_ONLY="1"
[ -n "$MQTT_HOST" ] || MQTT_HOST="127.0.0.1"
[ -n "$MQTT_PORT" ] || MQTT_PORT="1883"
[ -n "$TOPIC_RAW" ] || TOPIC_RAW="heizungpanel/raw"
[ -n "$CANDUMP_ARGS" ] || CANDUMP_ARGS="-a -t a -x"

setup_can() {
  [ "$CAN_SETUP" = "1" ] || return 0

  if ! ip link show "$CAN_IF" >/dev/null 2>&1; then
    logger -t heizungpanel "CAN interface missing: $CAN_IF"
    return 1
  fi

  local lo_arg="listen-only off"
  [ "$LISTEN_ONLY" = "1" ] && lo_arg="listen-only on"

  ip link set "$CAN_IF" down >/dev/null 2>&1 || true
  if ! ip link set "$CAN_IF" type can bitrate "$CAN_BITRATE" $lo_arg >/dev/null 2>&1; then
    logger -t heizungpanel "CAN setup failed (raw bridge): if=$CAN_IF bitrate=$CAN_BITRATE"
    return 1
  fi

  if ! ip link set "$CAN_IF" up >/dev/null 2>&1; then
    logger -t heizungpanel "CAN bring-up failed (raw bridge): if=$CAN_IF"
    return 1
  fi

  return 0
}

while true; do
  if ! setup_can; then
    sleep 2
    continue
  fi

  candump $CANDUMP_ARGS "$CAN_IF" 2>/dev/null | mosquitto_pub -h "$MQTT_HOST" -p "$MQTT_PORT" -t "$TOPIC_RAW" -l
  rc=$?
  logger -t heizungpanel "raw bridge exited (rc=$rc, if=$CAN_IF); reinitializing CAN and retrying"
  sleep 1
done
