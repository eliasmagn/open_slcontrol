#!/bin/sh
STATE_FILE="/tmp/heizungpanel/state.json"
STATE_DIR="/tmp/heizungpanel"
STATE_TMP="${STATE_DIR}/state.json.tmp"

MAX_AGE="$(uci -q get heizungpanel.main.state_max_age)"
[ -n "$MAX_AGE" ] || MAX_AGE="15"

is_valid_json_line() {
  [ -n "$1" ] || return 1
  echo "$1" | grep -q '^[[:space:]]*{.*}[[:space:]]*$'
}

emit_cache_if_fresh() {
  [ -s "$STATE_FILE" ] || return 1

  local now mtime age cached
  now="$(date +%s)"
  mtime="$(stat -c %Y "$STATE_FILE" 2>/dev/null || echo 0)"
  age=$((now - mtime))

  [ "$age" -le "$MAX_AGE" ] || return 1

  cached="$(cat "$STATE_FILE" 2>/dev/null)"
  is_valid_json_line "$cached" || return 1
  printf '%s\n' "$cached"
  return 0
}

if emit_cache_if_fresh; then
  exit 0
fi

BASE="$(uci -q get heizungpanel.main.mqtt_base)"
HOST="$(uci -q get heizungpanel.main.mqtt_host)"
PORT="$(uci -q get heizungpanel.main.mqtt_port)"
[ -n "$BASE" ] || BASE="heizungpanel"
[ -n "$HOST" ] || HOST="127.0.0.1"
[ -n "$PORT" ] || PORT="1883"

LIVE="$(mosquitto_sub -h "$HOST" -p "$PORT" -t "$BASE/state" -C 1 -W 1 2>/dev/null)"
if is_valid_json_line "$LIVE"; then
  mkdir -p "$STATE_DIR"
  printf '%s\n' "$LIVE" >"$STATE_TMP" 2>/dev/null && mv "$STATE_TMP" "$STATE_FILE"
  printf '%s\n' "$LIVE"
  exit 0
fi

if [ -s "$STATE_FILE" ]; then
  CACHED="$(cat "$STATE_FILE" 2>/dev/null)"
  if is_valid_json_line "$CACHED"; then
    printf '%s\n' "$CACHED"
    exit 0
  fi
fi

echo '{"status":"no_data","line1":"","line2":"","flags16":"----","last_1f5":""}'
