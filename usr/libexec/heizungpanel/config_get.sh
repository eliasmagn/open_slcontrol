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
STATE_WAIT="$(get_or_default state_mqtt_wait 1)"
POLL_MS="$(get_or_default poll_interval_ms 500)"
WRITE_MODE="$(get_or_default write_mode 0)"
STREAM_TOKEN="$(get_or_default stream_token '')"
PUBLISH_RAW="$(get_or_default publish_raw 1)"
PUBLISH_MODE="$(get_or_default publish_mode 1)"
PUBLISH_SNAPSHOT="$(get_or_default publish_snapshot 1)"
PUBLISH_BOOTSTRAP="$(get_or_default publish_bootstrap 0)"
PUBLISH_STATE="$(get_or_default publish_state 0)"

MAPPING_UHR="$(get_or_default mapping_uhr BFFF)"
MAPPING_BOILER="$(get_or_default mapping_boiler DFFF)"
MAPPING_UHR_BOILER="$(get_or_default mapping_uhr_boiler EFFF)"
MAPPING_DAUER="$(get_or_default mapping_dauer 7FFF)"
MAPPING_V="$(get_or_default mapping_v FFFB)"
MAPPING_Z="$(get_or_default mapping_z FF7F)"
MAPPING_QUIT="$(get_or_default mapping_quit FFBF)"
MAPPING_HAND="$(get_or_default mapping_hand FDFF)"
MAPPING_AUSSEN_REG="$(get_or_default mapping_aussen_reg F7FF)"
MAPPING_PRUEF="$(get_or_default mapping_pruef FBFF)"
MAPPING_PLUS="$(get_or_default mapping_plus FFDF)"
MAPPING_EIN="$(get_or_default mapping_ein '')"
MAPPING_AUS="$(get_or_default mapping_aus '')"
MAPPING_MINUS="$(get_or_default mapping_minus '')"

SENSOR_PROFILE="$(get_or_default sensor_profile engineering_generic)"
SENSOR_SOURCE="$(get_or_default sensor_source 259)"
SENSOR_INDEX="$(get_or_default sensor_index 00)"
SENSOR_FIELD="$(get_or_default sensor_field byte1)"
SENSOR_LABEL="$(get_or_default sensor_label 'Engineering channel')"
SENSOR_UNIT="$(get_or_default sensor_unit raw)"
SENSOR_SCALE="$(get_or_default sensor_scale 1)"
SENSOR_OFFSET="$(get_or_default sensor_offset 0)"
SENSOR_CONFIDENCE="$(get_or_default sensor_confidence unknown)"
SENSOR_AUTOSCALE="$(get_or_default sensor_autoscale 1)"
SENSOR_YMIN="$(get_or_default sensor_y_min 0)"
SENSOR_YMAX="$(get_or_default sensor_y_max 255)"
SENSOR_PROFILES_JSON="$(get_or_default sensor_profiles_json '{}')"

printf '{"can_if":"%s","can_bitrate":"%s","mqtt_host":"%s","mqtt_port":"%s","mqtt_base":"%s","state_mqtt_wait":"%s","poll_interval_ms":"%s","write_mode":"%s","stream_token":"%s","publish_raw":"%s","publish_mode":"%s","publish_snapshot":"%s","publish_bootstrap":"%s","publish_state":"%s","mapping_uhr":"%s","mapping_boiler":"%s","mapping_uhr_boiler":"%s","mapping_dauer":"%s","mapping_v":"%s","mapping_z":"%s","mapping_quit":"%s","mapping_hand":"%s","mapping_aussen_reg":"%s","mapping_pruef":"%s","mapping_plus":"%s","mapping_ein":"%s","mapping_aus":"%s","mapping_minus":"%s","sensor_profile":"%s","sensor_source":"%s","sensor_index":"%s","sensor_field":"%s","sensor_label":"%s","sensor_unit":"%s","sensor_scale":"%s","sensor_offset":"%s","sensor_confidence":"%s","sensor_autoscale":"%s","sensor_y_min":"%s","sensor_y_max":"%s","sensor_profiles_json":"%s"}\n' \
  "$(json_escape "$CAN_IF")" \
  "$(json_escape "$CAN_BITRATE")" \
  "$(json_escape "$MQTT_HOST")" \
  "$(json_escape "$MQTT_PORT")" \
  "$(json_escape "$MQTT_BASE")" \
  "$(json_escape "$STATE_WAIT")" \
  "$(json_escape "$POLL_MS")" \
  "$(json_escape "$WRITE_MODE")" \
  "$(json_escape "$STREAM_TOKEN")" \
  "$(json_escape "$PUBLISH_RAW")" \
  "$(json_escape "$PUBLISH_MODE")" \
  "$(json_escape "$PUBLISH_SNAPSHOT")" \
  "$(json_escape "$PUBLISH_BOOTSTRAP")" \
  "$(json_escape "$PUBLISH_STATE")" \
  "$(json_escape "$MAPPING_UHR")" \
  "$(json_escape "$MAPPING_BOILER")" \
  "$(json_escape "$MAPPING_UHR_BOILER")" \
  "$(json_escape "$MAPPING_DAUER")" \
  "$(json_escape "$MAPPING_V")" \
  "$(json_escape "$MAPPING_Z")" \
  "$(json_escape "$MAPPING_QUIT")" \
  "$(json_escape "$MAPPING_HAND")" \
  "$(json_escape "$MAPPING_AUSSEN_REG")" \
  "$(json_escape "$MAPPING_PRUEF")" \
  "$(json_escape "$MAPPING_PLUS")" \
  "$(json_escape "$MAPPING_EIN")" \
  "$(json_escape "$MAPPING_AUS")" \
  "$(json_escape "$MAPPING_MINUS")" \
  "$(json_escape "$SENSOR_PROFILE")" \
  "$(json_escape "$SENSOR_SOURCE")" \
  "$(json_escape "$SENSOR_INDEX")" \
  "$(json_escape "$SENSOR_FIELD")" \
  "$(json_escape "$SENSOR_LABEL")" \
  "$(json_escape "$SENSOR_UNIT")" \
  "$(json_escape "$SENSOR_SCALE")" \
  "$(json_escape "$SENSOR_OFFSET")" \
  "$(json_escape "$SENSOR_CONFIDENCE")" \
  "$(json_escape "$SENSOR_AUTOSCALE")" \
  "$(json_escape "$SENSOR_YMIN")" \
  "$(json_escape "$SENSOR_YMAX")" \
  "$(json_escape "$SENSOR_PROFILES_JSON")"
