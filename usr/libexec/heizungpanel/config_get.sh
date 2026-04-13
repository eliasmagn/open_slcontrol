#!/bin/sh

get_or_default() {
  local key="$1"
  local def="$2"
  local val
  val="$(uci -q get "heizungpanel.main.$key")"
  [ -n "$val" ] || val="$def"
  printf '%s' "$val"
}

json_escape() {
  printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'
}

CAN_IF="$(get_or_default can_if can0)"
CAN_BITRATE="$(get_or_default can_bitrate 69144)"
MQTT_HOST="$(get_or_default mqtt_host 127.0.0.1)"
MQTT_PORT="$(get_or_default mqtt_port 1883)"
MQTT_BASE="$(get_or_default mqtt_base heizungpanel)"
POLL_MS="$(get_or_default poll_interval_ms 500)"
WRITE_MODE="$(get_or_default write_mode 0)"
STREAM_TOKEN="$(get_or_default stream_token '')"

printf '{"can_if":"%s","can_bitrate":"%s","mqtt_host":"%s","mqtt_port":"%s","mqtt_base":"%s","poll_interval_ms":"%s","write_mode":"%s","stream_token":"%s"}\n' \
  "$(json_escape "$CAN_IF")" \
  "$(json_escape "$CAN_BITRATE")" \
  "$(json_escape "$MQTT_HOST")" \
  "$(json_escape "$MQTT_PORT")" \
  "$(json_escape "$MQTT_BASE")" \
  "$(json_escape "$POLL_MS")" \
  "$(json_escape "$WRITE_MODE")" \
  "$(json_escape "$STREAM_TOKEN")"
