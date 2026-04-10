#!/bin/sh

CAN_IF="$1"
MQTT_HOST="$2"
MQTT_PORT="$3"
TOPIC_RAW="$4"

[ -n "$CAN_IF" ] || CAN_IF="can0"
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
