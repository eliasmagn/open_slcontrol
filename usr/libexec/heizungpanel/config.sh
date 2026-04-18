#!/bin/sh

POLL_MS="$(uci -q get heizungpanel.main.poll_interval_ms)"
WRITE_MODE="$(uci -q get heizungpanel.main.write_mode)"
STREAM_TOKEN="$(uci -q get heizungpanel.main.stream_token)"
LED_MAP_83="$(uci -q get heizungpanel.main.led_map_83)"
LED_POWER_EIN_WHEN_BIT7_CLEAR="$(uci -q get heizungpanel.main.led_power_ein_when_bit7_clear)"
MAP_DAUER="$(uci -q get heizungpanel.main.mapping_dauer)"
MAP_UHR="$(uci -q get heizungpanel.main.mapping_uhr)"
MAP_BOILER="$(uci -q get heizungpanel.main.mapping_boiler)"
MAP_UHR_BOILER="$(uci -q get heizungpanel.main.mapping_uhr_boiler)"
MAP_AUSSEN_REG="$(uci -q get heizungpanel.main.mapping_aussen_reg)"
MAP_PRUEF="$(uci -q get heizungpanel.main.mapping_pruef)"
MAP_HAND="$(uci -q get heizungpanel.main.mapping_hand)"

case "$POLL_MS" in
  ''|*[!0-9]*) POLL_MS=500 ;;
esac

if [ "$POLL_MS" -lt 250 ]; then
  POLL_MS=250
elif [ "$POLL_MS" -gt 10000 ]; then
  POLL_MS=10000
fi

[ "$WRITE_MODE" = "1" ] || WRITE_MODE=0
[ "$LED_POWER_EIN_WHEN_BIT7_CLEAR" = "0" ] || LED_POWER_EIN_WHEN_BIT7_CLEAR=1

printf '{"poll_interval_ms":%s,"write_mode":%s,"stream_token":"%s","led_map_83":"%s","led_power_ein_when_bit7_clear":%s,"mapping_dauer":"%s","mapping_uhr":"%s","mapping_boiler":"%s","mapping_uhr_boiler":"%s","mapping_aussen_reg":"%s","mapping_pruef":"%s","mapping_hand":"%s"}\n' \
  "$POLL_MS" \
  "$WRITE_MODE" \
  "${STREAM_TOKEN:-}" \
  "${LED_MAP_83:-}" \
  "$LED_POWER_EIN_WHEN_BIT7_CLEAR" \
  "${MAP_DAUER:-}" \
  "${MAP_UHR:-}" \
  "${MAP_BOILER:-}" \
  "${MAP_UHR_BOILER:-}" \
  "${MAP_AUSSEN_REG:-}" \
  "${MAP_PRUEF:-}" \
  "${MAP_HAND:-}"
