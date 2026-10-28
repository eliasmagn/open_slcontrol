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

fail_read_only() {
  echo "$1" >&2
  if ! uci -q set 'heizungpanel.main.write_mode=0'; then
    logger -t heizungpanel "Failed to enforce read-only after write-mode error"
    echo "Read-only could not be enforced; check device configuration." >&2
    exit 1
  fi
  if ! uci -q commit heizungpanel; then
    logger -t heizungpanel "Read-only staged but commit failed"
    echo "Read-only staged, but persistence failed." >&2
  fi
  /etc/init.d/heizungpanel restart >/dev/null 2>&1 || echo "Read-only restart failed." >&2
  exit 1
}

if ! uci -q set "heizungpanel.main.$KEY=$VALUE"; then
  fail_read_only "Failed to set UCI value for $KEY"
fi

if ! uci -q commit heizungpanel; then
  fail_read_only "Failed to commit UCI changes"
fi

if ! /etc/init.d/heizungpanel restart >/dev/null 2>&1; then
  fail_read_only "Saved $KEY=$VALUE, but service restart failed"
fi

echo "OK: $KEY=$VALUE"
