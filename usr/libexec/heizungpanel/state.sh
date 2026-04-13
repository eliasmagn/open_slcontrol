#!/bin/sh

. /usr/share/libubox/jshn.sh

[ -n "$BOOTSTRAP_FILE" ] || BOOTSTRAP_FILE="/tmp/heizungpanel/bootstrap.json"

now_ms() {
  date +%s000
}

is_uint() {
  case "$1" in
    ''|*[!0-9]*) return 1 ;;
    *) return 0 ;;
  esac
}

extract_json_field() {
  local raw="$1"
  local key="$2"
  local first rest

  [ -n "$raw" ] || return 1

  if command -v jsonfilter >/dev/null 2>&1; then
    printf '%s' "$raw" | jsonfilter -q -e "@.${key}" 2>/dev/null
    return 0
  fi

  json_cleanup
  json_load "$raw" >/dev/null 2>&1 || return 1

  first="${key%%.*}"
  rest="${key#*.}"
  if [ "$first" != "$key" ]; then
    json_select "$first" >/dev/null 2>&1 || return 1
    json_get_var __val "$rest" >/dev/null 2>&1
    json_select .. >/dev/null 2>&1 || true
  else
    json_get_var __val "$key" >/dev/null 2>&1
  fi

  printf '%s' "$__val"
}

read_json_file() {
  local path="$1"
  [ -r "$path" ] || return 1
  sed -n '1p' "$path"
}

BOOTSTRAP_JSON="$(read_json_file "$BOOTSTRAP_FILE" 2>/dev/null || true)"

MODE_FLAGS="$(extract_json_field "$BOOTSTRAP_JSON" mode.flags16 2>/dev/null || true)"
[ -n "$MODE_FLAGS" ] || MODE_FLAGS="$(extract_json_field "$BOOTSTRAP_JSON" mode_flags16 2>/dev/null || true)"

MODE_NAME="$(extract_json_field "$BOOTSTRAP_JSON" mode.mode_name 2>/dev/null || true)"
MODE_TS="$(extract_json_field "$BOOTSTRAP_JSON" mode.ts_ms 2>/dev/null || true)"

SNAP_LINE1="$(extract_json_field "$BOOTSTRAP_JSON" snapshot.line1 2>/dev/null || true)"
[ -n "$SNAP_LINE1" ] || SNAP_LINE1="$(extract_json_field "$BOOTSTRAP_JSON" line1 2>/dev/null || true)"
SNAP_LINE2="$(extract_json_field "$BOOTSTRAP_JSON" snapshot.line2 2>/dev/null || true)"
[ -n "$SNAP_LINE2" ] || SNAP_LINE2="$(extract_json_field "$BOOTSTRAP_JSON" line2 2>/dev/null || true)"
SNAP_MODE_CODE="$(extract_json_field "$BOOTSTRAP_JSON" snapshot.mode_code 2>/dev/null || true)"
[ -n "$SNAP_MODE_CODE" ] || SNAP_MODE_CODE="$(extract_json_field "$BOOTSTRAP_JSON" mode_code 2>/dev/null || true)"
SNAP_TS="$(extract_json_field "$BOOTSTRAP_JSON" snapshot.ts_ms 2>/dev/null || true)"

[ -n "$MODE_FLAGS" ] || MODE_FLAGS="----"
[ -n "$MODE_NAME" ] || MODE_NAME="unknown"
[ -n "$SNAP_MODE_CODE" ] || SNAP_MODE_CODE="--"

if [ -n "$SNAP_LINE1" ] || [ -n "$SNAP_LINE2" ] || [ "$MODE_FLAGS" != "----" ]; then
  TS_NOW="$(now_ms)"
  AGE=-1

  if is_uint "$MODE_TS"; then
    AGE=$(( TS_NOW - MODE_TS ))
    [ "$AGE" -ge 0 ] || AGE=0
  elif is_uint "$SNAP_TS"; then
    AGE=$(( TS_NOW - SNAP_TS ))
    [ "$AGE" -ge 0 ] || AGE=0
  fi

  json_init
  json_add_string status "ok"
  json_add_int schema_version 2
  json_add_string source "bootstrap_file"
  json_add_int age_ms "$AGE"

  json_add_object mode
  json_add_string flags16 "$MODE_FLAGS"
  json_add_string mode_name "$MODE_NAME"
  json_add_string ts_ms "$MODE_TS"
  json_close_object

  json_add_object snapshot
  json_add_string line1 "$SNAP_LINE1"
  json_add_string line2 "$SNAP_LINE2"
  json_add_string mode_code "$SNAP_MODE_CODE"
  json_add_string ts_ms "$SNAP_TS"
  json_close_object

  json_add_string mode_flags16 "$MODE_FLAGS"
  json_add_string line1 "$SNAP_LINE1"
  json_add_string line2 "$SNAP_LINE2"
  json_add_string mode_code "$SNAP_MODE_CODE"

  json_dump
  printf '\n'
  exit 0
fi

echo '{"status":"no_data","schema_version":2,"source":"none","age_ms":-1,"mode":{"flags16":"----","mode_name":"unknown","ts_ms":""},"snapshot":{"line1":"","line2":"","mode_code":"--","ts_ms":""},"mode_flags16":"----","line1":"","line2":"","mode_code":"--"}'
