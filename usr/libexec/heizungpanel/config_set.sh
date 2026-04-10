#!/bin/sh

KEY="$1"
VALUE="$2"

fail() {
  echo "$1" >&2
  exit "$2"
}

require_numeric() {
  case "$1" in
    ''|*[!0-9]*) return 1 ;;
    *) return 0 ;;
  esac
}

validate_host() {
  case "$1" in
    ''|*[!A-Za-z0-9._:-]*) return 1 ;;
    *) return 0 ;;
  esac
}

validate_base() {
  case "$1" in
    ''|*+*|*#*|/*|*/|*[!A-Za-z0-9._/-]*) return 1 ;;
    *) return 0 ;;
  esac
}

validate_hex_token() {
  case "$1" in
    '') return 0 ;;
    *[!0-9a-fA-F]*) return 1 ;;
  esac
  local len
  len="${#1}"
  [ "$len" -ge 16 ] && [ "$len" -le 128 ]
}

case "$KEY" in
  can_if)
    case "$VALUE" in
      ''|*[!A-Za-z0-9._-]*) fail "Invalid can_if" 2 ;;
    esac
    ;;
  can_bitrate)
    require_numeric "$VALUE" || fail "Invalid can_bitrate" 2
    [ "$VALUE" -ge 10000 ] && [ "$VALUE" -le 1000000 ] || fail "can_bitrate out of range" 2
    ;;
  mqtt_port)
    require_numeric "$VALUE" || fail "Invalid mqtt_port" 2
    [ "$VALUE" -ge 1 ] && [ "$VALUE" -le 65535 ] || fail "mqtt_port out of range" 2
    ;;
  state_mqtt_wait)
    require_numeric "$VALUE" || fail "Invalid state_mqtt_wait" 2
    [ "$VALUE" -ge 1 ] && [ "$VALUE" -le 10 ] || fail "state_mqtt_wait out of range" 2
    ;;
  poll_interval_ms)
    require_numeric "$VALUE" || fail "Invalid poll_interval_ms" 2
    [ "$VALUE" -ge 250 ] && [ "$VALUE" -le 10000 ] || fail "poll_interval_ms out of range" 2
    ;;
  write_mode)
    case "$VALUE" in 0|1) ;; *) fail "Invalid boolean for $KEY" 2 ;; esac
    ;;
  mqtt_host)
    validate_host "$VALUE" || fail "Invalid mqtt_host" 2
    ;;
  mqtt_base)
    validate_base "$VALUE" || fail "Invalid mqtt_base (no #,+ and no leading/trailing /)" 2
    ;;
  stream_token)
    validate_hex_token "$VALUE" || fail "Invalid stream_token (hex, 16..128 chars or empty)" 2
    ;;
  *)
    fail "Unsupported key: $KEY" 2
    ;;
esac

uci -q set "heizungpanel.main.$KEY=$VALUE" || fail "Failed to set $KEY" 1
uci -q commit heizungpanel || fail "Failed to commit UCI changes" 1

/etc/init.d/heizungpanel restart >/dev/null 2>&1 || fail "Saved config, but service restart failed" 1

echo "OK: $KEY=$VALUE"
