#!/bin/sh

CAN_IF="$1"
MQTT_HOST="$2"
MQTT_PORT="$3"
TOPIC_RAW="$4"
TOPIC_MODE="$5"
TOPIC_MODE_CURRENT="$6"
TOPIC_SNAPSHOT="$7"
PUBLISH_RAW="$8"
PUBLISH_MODE="$9"
PUBLISH_SNAPSHOT="${10}"

[ -n "$CAN_IF" ] || CAN_IF="can0"
[ -n "$MQTT_HOST" ] || MQTT_HOST="127.0.0.1"
[ -n "$MQTT_PORT" ] || MQTT_PORT="1883"
[ -n "$TOPIC_RAW" ] || TOPIC_RAW="heizungpanel/raw"
[ -n "$TOPIC_MODE" ] || TOPIC_MODE="heizungpanel/mode"
[ -n "$TOPIC_MODE_CURRENT" ] || TOPIC_MODE_CURRENT="${TOPIC_MODE}/current"
[ -n "$TOPIC_SNAPSHOT" ] || TOPIC_SNAPSHOT="heizungpanel/snapshot"
[ -n "$PUBLISH_RAW" ] || PUBLISH_RAW="1"
[ -n "$PUBLISH_MODE" ] || PUBLISH_MODE="1"
[ -n "$PUBLISH_SNAPSHOT" ] || PUBLISH_SNAPSHOT="1"
[ -n "$CANDUMP_ARGS" ] || CANDUMP_ARGS="-a -t a -x"
BUILD_TAG="commit:8b755f2"

RAW_FIFO=""
MODE_FIFO=""
MODE_CUR_FIFO=""
SNAP_FIFO=""
RAW_PUB_PID=""
MODE_PUB_PID=""
MODE_CUR_PUB_PID=""
SNAP_PUB_PID=""

cleanup() {
  [ -n "$RAW_PUB_PID" ] && kill "$RAW_PUB_PID" >/dev/null 2>&1 || true
  [ -n "$MODE_PUB_PID" ] && kill "$MODE_PUB_PID" >/dev/null 2>&1 || true
  [ -n "$MODE_CUR_PUB_PID" ] && kill "$MODE_CUR_PUB_PID" >/dev/null 2>&1 || true
  [ -n "$SNAP_PUB_PID" ] && kill "$SNAP_PUB_PID" >/dev/null 2>&1 || true

  [ -n "$RAW_FIFO" ] && rm -f "$RAW_FIFO" >/dev/null 2>&1 || true
  [ -n "$MODE_FIFO" ] && rm -f "$MODE_FIFO" >/dev/null 2>&1 || true
  [ -n "$MODE_CUR_FIFO" ] && rm -f "$MODE_CUR_FIFO" >/dev/null 2>&1 || true
  [ -n "$SNAP_FIFO" ] && rm -f "$SNAP_FIFO" >/dev/null 2>&1 || true
}

trap cleanup EXIT INT TERM HUP PIPE

start_pub() {
  local fifo="$1"
  local topic="$2"
  local retained="$3"

  if [ "$retained" = "1" ]; then
    mosquitto_pub -h "$MQTT_HOST" -p "$MQTT_PORT" -t "$topic" -r -l < "$fifo" &
  else
    mosquitto_pub -h "$MQTT_HOST" -p "$MQTT_PORT" -t "$topic" -l < "$fifo" &
  fi
  printf '%s' "$!"
}

setup_publishers() {
  if [ "$PUBLISH_RAW" = "1" ]; then
    RAW_FIFO="/tmp/heizungpanel_runtime.raw.$$.$RANDOM.fifo"
    mkfifo "$RAW_FIFO" || return 1
    RAW_PUB_PID="$(start_pub "$RAW_FIFO" "$TOPIC_RAW" 0)"
  fi

  if [ "$PUBLISH_MODE" = "1" ]; then
    MODE_FIFO="/tmp/heizungpanel_runtime.mode.$$.$RANDOM.fifo"
    MODE_CUR_FIFO="/tmp/heizungpanel_runtime.modecur.$$.$RANDOM.fifo"
    mkfifo "$MODE_FIFO" || return 1
    mkfifo "$MODE_CUR_FIFO" || return 1
    MODE_PUB_PID="$(start_pub "$MODE_FIFO" "$TOPIC_MODE" 1)"
    MODE_CUR_PUB_PID="$(start_pub "$MODE_CUR_FIFO" "$TOPIC_MODE_CURRENT" 0)"
  fi

  if [ "$PUBLISH_SNAPSHOT" = "1" ]; then
    SNAP_FIFO="/tmp/heizungpanel_runtime.snapshot.$$.$RANDOM.fifo"
    mkfifo "$SNAP_FIFO" || return 1
    SNAP_PUB_PID="$(start_pub "$SNAP_FIFO" "$TOPIC_SNAPSHOT" 1)"
  fi

  return 0
}

forward_frames() {
  awk '
function mode_name(flags) {
  if (flags == "7FFF") return "dauer"
  if (flags == "BFFF") return "uhr"
  if (flags == "DFFF") return "boiler"
  if (flags == "EFFF") return "uhr_boiler"
  if (flags == "F7FF") return "aussen_reg"
  if (flags == "FBFF") return "pruef"
  if (flags == "FDFF") return "hand"
  return "unknown"
}
function hex2dec(h,    i, c, v, out) {
  h = toupper(h)
  out = 0
  for (i = 1; i <= length(h); i++) {
    c = substr(h, i, 1)
    v = index("0123456789ABCDEF", c) - 1
    if (v < 0) return -1
    out = (out * 16) + v
  }
  return out
}
function byte_to_char(h, v) {
  h = toupper(h)
  if (h == "DF") return "°"
  if (h == "E2") return "ß"
  if (h == "F5") return "ü"
  if (h == "E1") return "ä"
  if (h == "EF") return "ö"
  v = hex2dec(h)
  if (v >= 32 && v <= 126) return sprintf("%c", v)
  return " "
}
function lcd_index(off) {
  if (off >= 0x00 && off <= 0x13) return off
  if (off >= 0x40 && off <= 0x53) return 20 + (off - 0x40)
  if (off >= 0x14 && off <= 0x1F) return off
  if (off >= 0x54 && off <= 0x5F) return 20 + (off - 0x54)
  return -1
}
function json_escape(s,    i, c, out) {
  out = ""
  for (i = 1; i <= length(s); i++) {
    c = substr(s, i, 1)
    if (c == "\\") out = out "\\\\"
    else if (c == "\"") out = out "\\\""
    else if (c == "\b") out = out "\\b"
    else if (c == "\f") out = out "\\f"
    else if (c == "\n") out = out "\\n"
    else if (c == "\r") out = out "\\r"
    else if (c == "\t") out = out "\\t"
    else out = out c
  }
  return out
}
function parse_id_hex(line,    a) {
  if (match(line, /([0-9A-Fa-f]+)#([0-9A-Fa-f]+)/, a)) {
    id = toupper(a[1]); data = toupper(a[2]); return 1
  }
  return 0
}
function parse_len_bytes(line,    m, n, i, tok, want, count, out, tail, q) {
  if (!match(line, /(^|[[:space:]])([0-9A-Fa-f]+)[[:space:]]+\[[[:space:]]*([0-9]+)[[:space:]]*\][[:space:]]+(.+)$/, m))
    return 0
  id = toupper(m[2]); want = m[3] + 0; tail = m[4]
  q = index(tail, sprintf("%c", 39))
  if (q > 0) tail = substr(tail, 1, q - 1)
  n = split(tail, tok, /[[:space:]]+/)
  out = ""; count = 0
  for (i = 1; i <= n; i++) {
    if (tok[i] ~ /^[0-9A-Fa-f]{2}$/) {
      out = out toupper(tok[i])
      count++
      if (want > 0 && count >= want)
        break
    }
  }
  if (out == "") return 0
  data = out
  return 1
}
function emit_mode(flags, name, ts) {
  printf("M\t{\"schema_version\":1,\"ts_ms\":%d,\"flags16\":\"%s\",\"mode_name\":\"%s\"}\n", ts, flags, name)
}
function emit_mode_current(flags, name, ts) {
  printf("C\t{\"schema_version\":1,\"ts_ms\":%d,\"flags16\":\"%s\",\"mode_name\":\"%s\"}\n", ts, flags, name)
}
function emit_snapshot(    i, l1, l2, ts) {
  l1 = ""; l2 = ""
  for (i = 0; i < 20; i++) l1 = l1 lcd[i]
  for (i = 20; i < 40; i++) l2 = l2 lcd[i]
  ts = systime() * 1000
  printf("S\t{\"schema_version\":1,\"ts_ms\":%d,\"line1\":\"%s\",\"line2\":\"%s\",\"mode_code\":\"%s\"}\n", ts, json_escape(l1), json_escape(l2), json_escape(mode_code))
}
BEGIN {
  for (i = 0; i < 40; i++) lcd[i] = " "
  mode_code = "--"
}
{
  print "R\t" $0

  id = ""; data = ""
  if (!parse_id_hex($0) && !parse_len_bytes($0))
    next

  if (id == "321" && length(data) >= 4) {
    flags = substr(data, 1, 4)
    if (flags != last_mode_flags) {
      ts = systime() * 1000
      name = mode_name(flags)
      emit_mode_current(flags, name, ts)
      if (name != "unknown")
        emit_mode(flags, name, ts)
      last_mode_flags = flags
    }
    next
  }

  if (id != "320" || length(data) < 2)
    next

  lead = substr(data, 1, 2)
  if (lead == "81") {
    for (i = 0; i < 40; i++) lcd[i] = " "
    next
  }

  if (lead == "83") {
    if (length(data) >= 4)
      mode_code = substr(data, 3, 2)
    emit_snapshot()
    next
  }

  if (length(data) < 4)
    next

  off = hex2dec(lead)
  idx = lcd_index(off)
  if (idx < 0)
    next

  pos = idx
  for (j = 3; (j + 1) <= length(data) && pos < 40; j += 2) {
    b = substr(data, j, 2)
    lcd[pos] = byte_to_char(b)
    pos++
  }
}
' | while IFS="$(printf '\t')" read -r kind payload; do
    case "$kind" in
      R)
        [ "$PUBLISH_RAW" = "1" ] && printf '%s\n' "$payload" > "$RAW_FIFO" || true
        ;;
      M)
        [ "$PUBLISH_MODE" = "1" ] && printf '%s\n' "$payload" > "$MODE_FIFO" || true
        ;;
      C)
        [ "$PUBLISH_MODE" = "1" ] && printf '%s\n' "$payload" > "$MODE_CUR_FIFO" || true
        ;;
      S)
        [ "$PUBLISH_SNAPSHOT" = "1" ] && printf '%s\n' "$payload" > "$SNAP_FIFO" || true
        ;;
    esac
  done
}

logger -t heizungpanel "runtime bridge start ($BUILD_TAG)"

while true; do
  cleanup
  setup_publishers || {
    logger -t heizungpanel "runtime bridge publisher setup failed; retrying"
    sleep 1
    continue
  }

  candump $CANDUMP_ARGS "$CAN_IF" 2>/dev/null | forward_frames

  rc=$?
  logger -t heizungpanel "runtime bridge exited (rc=$rc, if=$CAN_IF); retrying"
  sleep 1
done
