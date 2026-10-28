#!/bin/sh

CODE="$1"
WRITE_MODE="$(uci -q get heizungpanel.main.write_mode)"
CAN_IF="$(uci -q get heizungpanel.main.can_if)"
MQTT_HOST="$(uci -q get heizungpanel.main.mqtt_host)"
MQTT_PORT="$(uci -q get heizungpanel.main.mqtt_port)"
MQTT_BASE="$(uci -q get heizungpanel.main.mqtt_base)"

[ -n "$CAN_IF" ] || CAN_IF="can0"
[ -n "$MQTT_HOST" ] || MQTT_HOST="127.0.0.1"
[ -n "$MQTT_PORT" ] || MQTT_PORT="1883"
[ -n "$MQTT_BASE" ] || MQTT_BASE="heizungpanel"

case "$CODE" in
  z|minus|quit|plus|v|vz|dauer|uhr|boiler|uhr_boiler|aussen_reg|pruef|hand|ein|aus)
    ;;
  *)
    echo "Denied: unsupported command '$CODE'." >&2
    exit 3
    ;;
esac

if [ "$WRITE_MODE" != "1" ]; then
  echo "Write mode disabled in UCI (heizungpanel.main.write_mode=0)." >&2
  exit 2
fi

PAYLOAD="$(uci -q get "heizungpanel.main.mapping_${CODE}")"
# Missing or empty mappings deliberately disable sending. Defaults live in UCI.
PAYLOAD="$(echo "$PAYLOAD" | tr '[:lower:]' '[:upper:]')"

case "$PAYLOAD" in
  '') ;;
  [0-9A-F][0-9A-F][0-9A-F][0-9A-F]) ;;
  *)
    echo "Invalid mapping payload configured for '$CODE': '$PAYLOAD' (expected 4 hex chars)." >&2
    exit 7
    ;;
esac

if [ -z "$PAYLOAD" ]; then
  echo "Write mode is enabled, but CAN send mapping is not configured for '$CODE'." >&2
  exit 4
fi

case "$CODE" in
  ein|aus)
    VZ_PAYLOAD="$(uci -q get heizungpanel.main.mapping_vz)"
    VZ_PAYLOAD="$(printf '%s' "$VZ_PAYLOAD" | tr '[:lower:]' '[:upper:]')"
    if [ -n "$VZ_PAYLOAD" ] && [ "$PAYLOAD" = "$VZ_PAYLOAD" ]; then
      echo "Denied: mapping for '$CODE' collides with configured 'vz' mapping." >&2
      exit 8
    fi
    ;;
esac

if ! command -v cansend >/dev/null 2>&1; then
  echo "cansend binary not found on system." >&2
  exit 6
fi

if ! cansend "$CAN_IF" "321#$PAYLOAD" >/dev/null 2>&1; then
  echo "CAN send failed ($CAN_IF 321#$PAYLOAD)." >&2
  exit 5
fi

logger -t heizungpanel "tx code=$CODE frame=321#$PAYLOAD"

if command -v mosquitto_pub >/dev/null 2>&1; then
  # Optionales Debug-/Sendetopic (nicht Teil des UI-Livepfads)
  TS="$(date +%s)"
  mosquitto_pub -h "$MQTT_HOST" -p "$MQTT_PORT" -t "$MQTT_BASE/tx" -m "{\"ts\":$TS,\"code\":\"$CODE\",\"frame\":\"321#$PAYLOAD\",\"can_if\":\"$CAN_IF\"}" >/dev/null 2>&1 || true
fi

echo "OK: $CODE -> 321#$PAYLOAD"
exit 0
