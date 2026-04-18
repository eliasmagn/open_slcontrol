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
LED_MAP_83="$(get_or_default led_map_83 'BF:7FFF,3F:7FFF,DF:BFFF,5F:BFFF,EF:DFFF,6F:DFFF,FB:EFFF,7B:EFFF,73:F7FF,7E:FDFF')"
LED_POWER_EIN_WHEN_BIT7_CLEAR="$(get_or_default led_power_ein_when_bit7_clear 1)"
MAP_Z="$(get_or_default mapping_z FF7F)"
MAP_MINUS="$(get_or_default mapping_minus '')"
MAP_QUIT="$(get_or_default mapping_quit FFBF)"
MAP_PLUS="$(get_or_default mapping_plus FFDF)"
MAP_V="$(get_or_default mapping_v FFFB)"
MAP_DAUER="$(get_or_default mapping_dauer 7FFF)"
MAP_UHR="$(get_or_default mapping_uhr BFFF)"
MAP_BOILER="$(get_or_default mapping_boiler DFFF)"
MAP_UHR_BOILER="$(get_or_default mapping_uhr_boiler EFFF)"
MAP_AUSSEN_REG="$(get_or_default mapping_aussen_reg F7FF)"
MAP_PRUEF="$(get_or_default mapping_pruef FBFF)"
MAP_HAND="$(get_or_default mapping_hand FDFF)"
MAP_EIN="$(get_or_default mapping_ein '')"
MAP_AUS="$(get_or_default mapping_aus '')"

printf '{"can_if":"%s","can_bitrate":"%s","mqtt_host":"%s","mqtt_port":"%s","mqtt_base":"%s","poll_interval_ms":"%s","write_mode":"%s","stream_token":"%s","led_map_83":"%s","led_power_ein_when_bit7_clear":"%s","mapping_z":"%s","mapping_minus":"%s","mapping_quit":"%s","mapping_plus":"%s","mapping_v":"%s","mapping_dauer":"%s","mapping_uhr":"%s","mapping_boiler":"%s","mapping_uhr_boiler":"%s","mapping_aussen_reg":"%s","mapping_pruef":"%s","mapping_hand":"%s","mapping_ein":"%s","mapping_aus":"%s"}\n' \
  "$(json_escape "$CAN_IF")" \
  "$(json_escape "$CAN_BITRATE")" \
  "$(json_escape "$MQTT_HOST")" \
  "$(json_escape "$MQTT_PORT")" \
  "$(json_escape "$MQTT_BASE")" \
  "$(json_escape "$POLL_MS")" \
  "$(json_escape "$WRITE_MODE")" \
  "$(json_escape "$STREAM_TOKEN")" \
  "$(json_escape "$LED_MAP_83")" \
  "$(json_escape "$LED_POWER_EIN_WHEN_BIT7_CLEAR")" \
  "$(json_escape "$MAP_Z")" \
  "$(json_escape "$MAP_MINUS")" \
  "$(json_escape "$MAP_QUIT")" \
  "$(json_escape "$MAP_PLUS")" \
  "$(json_escape "$MAP_V")" \
  "$(json_escape "$MAP_DAUER")" \
  "$(json_escape "$MAP_UHR")" \
  "$(json_escape "$MAP_BOILER")" \
  "$(json_escape "$MAP_UHR_BOILER")" \
  "$(json_escape "$MAP_AUSSEN_REG")" \
  "$(json_escape "$MAP_PRUEF")" \
  "$(json_escape "$MAP_HAND")" \
  "$(json_escape "$MAP_EIN")" \
  "$(json_escape "$MAP_AUS")"
