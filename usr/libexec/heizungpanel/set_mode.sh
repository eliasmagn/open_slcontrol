#!/bin/sh

KEY="$1"
VALUE="$2"

case "$KEY" in
  write_mode) ;;
  *)
    echo "Unsupported key: $KEY" >&2
    exit 2
    ;;
esac

case "$VALUE" in
  0|1) ;;
  *)
    echo "Invalid value for $KEY: $VALUE (expected 0 or 1)" >&2
    exit 2
    ;;
esac

if ! uci -q set "heizungpanel.main.$KEY=$VALUE"; then
  echo "Failed to set UCI value for $KEY" >&2
  exit 1
fi

if ! uci -q commit heizungpanel; then
  echo "Failed to commit UCI changes" >&2
  exit 1
fi

if ! /etc/init.d/heizungpanel restart >/dev/null 2>&1; then
  echo "Saved $KEY=$VALUE, but service restart failed" >&2
  exit 1
fi

echo "OK: $KEY=$VALUE"
