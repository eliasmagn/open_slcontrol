#!/bin/sh

CODE="$1"
WRITE_MODE="$(uci -q get heizungpanel.main.write_mode)"

case "$CODE" in
  z|minus|quit|plus|v|dauer|uhr|boiler|uhr_boiler|aussen_reg|pruef|hand|ein|aus)
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

# Safety gate passed (write_mode + strict allowlist), but frame mapping is still not configured.
echo "Write mode is enabled, but CAN send mapping is not configured for '$CODE'." >&2
exit 4
