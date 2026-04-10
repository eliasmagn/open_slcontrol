#!/bin/sh

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

validate_kv() {
  local key="$1"
  local value="$2"

  case "$key" in
    can_if)
      case "$value" in
        ''|*[!A-Za-z0-9._-]*) fail "Invalid can_if" 2 ;;
      esac
      ;;
    can_bitrate)
      require_numeric "$value" || fail "Invalid can_bitrate" 2
      [ "$value" -ge 10000 ] && [ "$value" -le 1000000 ] || fail "can_bitrate out of range" 2
      ;;
    mqtt_port)
      require_numeric "$value" || fail "Invalid mqtt_port" 2
      [ "$value" -ge 1 ] && [ "$value" -le 65535 ] || fail "mqtt_port out of range" 2
      ;;
    state_mqtt_wait)
      require_numeric "$value" || fail "Invalid state_mqtt_wait" 2
      [ "$value" -ge 1 ] && [ "$value" -le 10 ] || fail "state_mqtt_wait out of range" 2
      ;;
    poll_interval_ms)
      require_numeric "$value" || fail "Invalid poll_interval_ms" 2
      [ "$value" -ge 250 ] && [ "$value" -le 10000 ] || fail "poll_interval_ms out of range" 2
      ;;
    write_mode|publish_raw|publish_mode|publish_snapshot|publish_bootstrap|publish_state)
      case "$value" in 0|1) ;; *) fail "Invalid boolean for $key" 2 ;; esac
      ;;
    mqtt_host)
      validate_host "$value" || fail "Invalid mqtt_host" 2
      ;;
    mqtt_base)
      validate_base "$value" || fail "Invalid mqtt_base (no #,+ and no leading/trailing /)" 2
      ;;
    stream_token)
      validate_hex_token "$value" || fail "Invalid stream_token (hex, 16..128 chars or empty)" 2
      ;;
    *)
      fail "Unsupported key: $key" 2
      ;;
  esac
}

set_one() {
  local key="$1"
  local value="$2"

  validate_kv "$key" "$value"
  uci -q set "heizungpanel.main.$key=$value" || fail "Failed to set $key" 1
}

apply_and_restart_once() {
  uci -q commit heizungpanel || fail "Failed to commit UCI changes" 1
  /etc/init.d/heizungpanel restart >/dev/null 2>&1 || fail "Saved config, but service restart failed" 1
}

if [ "$1" = "--batch-json" ]; then
  JSON_PAYLOAD="$2"
  [ -n "$JSON_PAYLOAD" ] || fail "Missing JSON payload" 2

  # validate + set each field, commit once
  tmp_file="$(mktemp)" || fail "Failed to allocate temp file" 1
  trap 'rm -f "$tmp_file"' EXIT INT TERM

  CFG_JSON="$JSON_PAYLOAD" /usr/bin/ucode -e '
    "use strict";
    let raw = getenv("CFG_JSON") || "{}";
    let obj;
    try { obj = json(raw); } catch (e) { warn("Invalid JSON payload\n"); exit(2); }
    if (type(obj) != "object") { warn("Payload must be object\n"); exit(2); }
    for (let k in obj) {
      let v = obj[k];
      if (v == null)
        v = "";
      print(k + "\t" + sprintf("%s", v) + "\n");
    }
  ' > "$tmp_file" || fail "Invalid JSON payload" 2

  while IFS="\t" read -r key value; do
    set_one "$key" "$value"
  done < "$tmp_file"

  rm -f "$tmp_file"
  trap - EXIT INT TERM

  apply_and_restart_once
  echo "OK: batch"
  exit 0
fi

KEY="$1"
VALUE="$2"
set_one "$KEY" "$VALUE"
apply_and_restart_once

echo "OK: $KEY=$VALUE"
