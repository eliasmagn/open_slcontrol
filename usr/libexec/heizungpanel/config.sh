#!/bin/sh

POLL_MS="$(uci -q get heizungpanel.main.poll_interval_ms)"
WRITE_MODE="$(uci -q get heizungpanel.main.write_mode)"

case "$POLL_MS" in
  ''|*[!0-9]*) POLL_MS=1000 ;;
esac

if [ "$POLL_MS" -lt 250 ]; then
  POLL_MS=250
elif [ "$POLL_MS" -gt 10000 ]; then
  POLL_MS=10000
fi

[ "$WRITE_MODE" = "1" ] || WRITE_MODE=0

printf '{"poll_interval_ms":%s,"write_mode":%s}\n' "$POLL_MS" "$WRITE_MODE"
