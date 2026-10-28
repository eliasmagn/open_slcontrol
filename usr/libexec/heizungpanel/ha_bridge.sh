#!/bin/sh

set -eu

PATH='/usr/sbin:/usr/bin:/sbin:/bin'
LC_ALL='C'
export PATH LC_ALL

CONFIG_GET='/usr/libexec/heizungpanel/config_get.sh'
CONFIG_SET='/usr/libexec/heizungpanel/config_set.sh'
PRESS='/usr/libexec/heizungpanel/press.sh'
SET_MODE='/usr/libexec/heizungpanel/set_mode.sh'

deny() {
  logger -t heizungpanel 'Denied HA bridge operation'
  echo 'Denied: unsupported or malformed HA bridge operation.' >&2
  exit 126
}

validate_config_json() {
  CFG_JSON="$1" /usr/bin/ucode -e '
    "use strict";
    let raw = getenv("CFG_JSON") || "";
    let obj;
    try { obj = json(raw); } catch (e) { exit(2); }
    if (type(obj) != "object") { exit(2); }

    let allowed = {
      "can_if": true,
      "can_bitrate": true,
      "mqtt_host": true,
      "mqtt_port": true,
      "mqtt_base": true,
      "poll_interval_ms": true,
      "publish_raw": true,
      "led_map_83": true,
      "led_power_ein_when_bit7_clear": true,
      "mapping_z": true,
      "mapping_minus": true,
      "mapping_quit": true,
      "mapping_plus": true,
      "mapping_v": true,
      "mapping_vz": true,
      "mapping_dauer": true,
      "mapping_uhr": true,
      "mapping_boiler": true,
      "mapping_uhr_boiler": true,
      "mapping_aussen_reg": true,
      "mapping_pruef": true,
      "mapping_hand": true,
      "mapping_ein": true,
      "mapping_aus": true
    };

    let count = 0;
    for (let key in obj) {
      if (!allowed[key] || type(obj[key]) != "string") { exit(2); }
      count++;
    }
    if (count == 0) { exit(2); }
  ' >/dev/null 2>&1
}

stream_raw() {
  command -v mosquitto_sub >/dev/null 2>&1 || {
    echo 'mosquitto_sub is unavailable.' >&2
    exit 127
  }

  mqtt_base="$(uci -q get heizungpanel.main.mqtt_base || true)"
  [ -n "$mqtt_base" ] || mqtt_base='heizungpanel'
  case "$mqtt_base" in
    *+*|*#*|/*|*/|*[!A-Za-z0-9._/-]*) deny ;;
  esac

  exec mosquitto_sub -h 127.0.0.1 -p 1883 -t "$mqtt_base/raw"
}

config_set_b64() {
  payload="$1"
  [ -n "$payload" ] || deny
  [ "${#payload}" -le 8192 ] || deny
  case "$payload" in
    *[!A-Za-z0-9_=-]*) deny ;;
  esac

  normalized="$(printf '%s' "$payload" | tr '_-' '/+')"
  decoded="$(printf '%s' "$normalized" | base64 -d 2>/dev/null)" || deny
  [ -n "$decoded" ] || deny
  validate_config_json "$decoded" || deny
  exec "$CONFIG_SET" --batch-json "$decoded"
}

original_command="${SSH_ORIGINAL_COMMAND:-}"
case "$original_command" in
  *"
"*|*"	"*) deny ;;
esac

case "$original_command" in
  stream)
    stream_raw
    ;;
  config-get)
    exec "$CONFIG_GET"
    ;;
  config-set-b64\ *)
    config_set_b64 "${original_command#config-set-b64 }"
    ;;
  write-mode\ 0)
    exec "$SET_MODE" write_mode 0
    ;;
  write-mode\ 1)
    exec "$SET_MODE" write_mode 1
    ;;
  press\ z|press\ minus|press\ quit|press\ plus|press\ v|press\ vz|press\ dauer|press\ uhr|press\ boiler|press\ uhr_boiler|press\ aussen_reg|press\ pruef|press\ hand|press\ ein|press\ aus)
    exec "$PRESS" "${original_command#press }"
    ;;
  *)
    deny
    ;;
esac
