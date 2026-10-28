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
  [ "$len" -ge 16 ] && [ "$len" -le 128 ] && [ $((len % 2)) -eq 0 ]
}

validate_hex4_or_empty() {
  case "$1" in
    '') return 0 ;;
    [0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f]) return 0 ;;
    *) return 1 ;;
  esac
}

validate_led_map_83() {
  local raw="$1"
  local oldifs="$IFS"
  local item trimmed

  [ -n "$raw" ] || return 1
  case "$raw" in
    *[!0-9A-Fa-f:,\ ]*) return 1 ;;
  esac

  IFS=','
  for item in $raw; do
    trimmed="$(printf '%s' "$item" | sed 's/^ *//; s/ *$//')"
    case "$trimmed" in
      [0-9A-Fa-f][0-9A-Fa-f]:[0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f]) ;;
      *) IFS="$oldifs"; return 1 ;;
    esac
  done
  IFS="$oldifs"
  return 0
}

validate_kv() {
  local key="$1"
  local value="$2"

  case "$key" in
    can_if)
      case "$value" in
        can*|vcan*|slcan*) ;;
        *) fail "Invalid can_if (expected can*, vcan*, or slcan*)" 2 ;;
      esac
      case "$value" in
        *[!A-Za-z0-9._-]*) fail "Invalid can_if" 2 ;;
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
    poll_interval_ms)
      require_numeric "$value" || fail "Invalid poll_interval_ms" 2
      [ "$value" -ge 250 ] && [ "$value" -le 10000 ] || fail "poll_interval_ms out of range" 2
      ;;
    write_mode|publish_raw)
      case "$value" in 0|1) ;; *) fail "Invalid boolean for $key" 2 ;; esac
      ;;
    led_power_ein_when_bit7_clear)
      case "$value" in 0|1) ;; *) fail "Invalid boolean for led_power_ein_when_bit7_clear" 2 ;; esac
      ;;
    mqtt_host)
      validate_host "$value" || fail "Invalid mqtt_host" 2
      ;;
    mqtt_base)
      validate_base "$value" || fail "Invalid mqtt_base (no #,+ and no leading/trailing /)" 2
      ;;
    stream_token)
      validate_hex_token "$value" || fail "Invalid stream_token (hex, 16..128 chars, even length, or empty)" 2
      ;;
    led_map_83)
      validate_led_map_83 "$value" || fail "Invalid led_map_83 (expected comma-separated HEX2:HEX4 pairs)" 2
      ;;
    mapping_z|mapping_minus|mapping_quit|mapping_plus|mapping_v|mapping_vz|mapping_dauer|mapping_uhr|mapping_boiler|mapping_uhr_boiler|mapping_aussen_reg|mapping_pruef|mapping_hand|mapping_ein|mapping_aus)
      validate_hex4_or_empty "$value" || fail "Invalid mapping payload (expected 4 hex chars or empty)" 2
      ;;
    *)
      fail "Unsupported key: $key" 2
      ;;
  esac
}

parse_batch_line() {
  local line="$1"

  case "$line" in
    *"	"*)
      BATCH_KEY="${line%%	*}"
      BATCH_VALUE="${line#*	}"
      ;;
    *)
      BATCH_KEY="${line%%[[:space:]]*}"
      BATCH_VALUE="${line#"$BATCH_KEY"}"
      BATCH_VALUE="${BATCH_VALUE#"${BATCH_VALUE%%[![:space:]]*}"}"
      ;;
  esac
  [ -n "$BATCH_KEY" ] || fail "Invalid batch entry (missing key)" 2
}

validate_batch_file() {
  local input="$1"
  local line
  local count=0

  while IFS= read -r line; do
    [ -n "$line" ] || continue
    parse_batch_line "$line"
    validate_kv "$BATCH_KEY" "$BATCH_VALUE"
    count=$((count + 1))
  done < "$input"
  [ "$count" -gt 0 ] || fail "Batch contains no configuration values" 2
}

stage_batch_file() {
  local input="$1"
  local savedir="$2"
  local line

  while IFS= read -r line; do
    [ -n "$line" ] || continue
    parse_batch_line "$line"
    uci -q -t "$savedir" set "heizungpanel.main.$BATCH_KEY=$BATCH_VALUE" || return 1
  done < "$input"
}

restore_read_only() {
  local reason="$1"
  local restore_file="$CONFIG_FILE.restore.$$"
  local restored=1

  if ! cp -p "$BACKUP_FILE" "$restore_file" || ! mv -f "$restore_file" "$CONFIG_FILE"; then
    restored=0
    rm -f "$restore_file"
  fi
  uci -q revert heizungpanel.main.write_mode >/dev/null 2>&1 || true
  rm -rf "$FAILSAFE_DIR"
  mkdir -p "$FAILSAFE_DIR" || restored=0
  if ! uci -q -t "$FAILSAFE_DIR" set 'heizungpanel.main.write_mode=0' || \
     ! uci -q -t "$FAILSAFE_DIR" commit heizungpanel; then
    restored=0
  fi
  if ! "$SERVICE_SCRIPT" restart >/dev/null 2>&1; then
    restored=0
  fi

  logger -t heizungpanel "$reason; forced read-only rollback result=$restored"
  echo "$reason" >&2
  if [ "$restored" -eq 1 ]; then
    echo "Previous config restored with write_mode=0; unrelated staged changes were preserved." >&2
  else
    echo "Read-only rollback could not be confirmed; inspect router configuration before writing." >&2
  fi
  exit 1
}

apply_transaction() {
  local input="$1"

  TRANSACTION_DIR="$(mktemp -d)" || fail "Failed to allocate transaction directory" 1
  STAGING_DIR="$TRANSACTION_DIR/staging"
  FAILSAFE_DIR="$TRANSACTION_DIR/failsafe"
  BACKUP_FILE="$TRANSACTION_DIR/heizungpanel.config"
  mkdir -p "$STAGING_DIR" || fail "Failed to initialize transaction" 1
  cp -p "$CONFIG_FILE" "$BACKUP_FILE" || fail "Failed to back up current UCI config" 1
  trap 'rm -f "$batch_file"; rm -rf "$TRANSACTION_DIR"' EXIT INT TERM

  stage_batch_file "$input" "$STAGING_DIR" || restore_read_only "Failed to stage isolated UCI changes"
  uci -q -t "$STAGING_DIR" commit heizungpanel || restore_read_only "Failed to commit isolated UCI changes"
  "$SERVICE_SCRIPT" restart >/dev/null 2>&1 || restore_read_only "Committed config, but service restart failed"
}

CONFIG_FILE='/etc/config/heizungpanel'
SERVICE_SCRIPT='/etc/init.d/heizungpanel'
TRANSACTION_DIR=''
STAGING_DIR=''
FAILSAFE_DIR=''
BACKUP_FILE=''
batch_file="$(mktemp)" || fail "Failed to allocate temp file" 1
trap 'rm -f "$batch_file"' EXIT INT TERM

if [ "$1" = "--batch-json" ]; then
  JSON_PAYLOAD="$2"
  [ -n "$JSON_PAYLOAD" ] || fail "Missing JSON payload" 2

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
  ' > "$batch_file" || fail "Invalid JSON payload" 2
  validate_batch_file "$batch_file"
  apply_transaction "$batch_file"
  echo "OK: batch"
  exit 0
fi

KEY="$1"
VALUE="$2"
validate_kv "$KEY" "$VALUE"
printf '%s\t%s\n' "$KEY" "$VALUE" > "$batch_file"
apply_transaction "$batch_file"

echo "OK: $KEY"
