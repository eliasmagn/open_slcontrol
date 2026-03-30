#!/bin/sh
BASE="$(uci -q get heizungpanel.main.mqtt_base)"
HOST="$(uci -q get heizungpanel.main.mqtt_host)"
PORT="$(uci -q get heizungpanel.main.mqtt_port)"
[ -n "$BASE" ] || BASE="heizungpanel"
[ -n "$HOST" ] || HOST="127.0.0.1"
[ -n "$PORT" ] || PORT="1883"
mosquitto_sub -h "$HOST" -p "$PORT" -t "$BASE/state" -C 1 -W 1 2>/dev/null || echo '{}'
