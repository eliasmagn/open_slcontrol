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
BUILD_TAG="commit:8b755f2"

logger -t heizungpanel "raw bridge start ($BUILD_TAG)"

while true; do
  candump $CANDUMP_ARGS "$CAN_IF" 2>/dev/null | mosquitto_pub -h "$MQTT_HOST" -p "$MQTT_PORT" -t "$TOPIC_RAW" -l
  rc=$?
  logger -t heizungpanel "raw bridge exited (rc=$rc, if=$CAN_IF); retrying"
  sleep 1
done
