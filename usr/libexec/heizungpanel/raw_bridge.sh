#!/bin/sh

CAN_IF="$1"
MQTT_HOST="$2"
MQTT_PORT="$3"
TOPIC_RAW="$4"

[ -n "$CAN_IF" ] || CAN_IF="can0"
[ -n "$MQTT_HOST" ] || MQTT_HOST="127.0.0.1"
[ -n "$MQTT_PORT" ] || MQTT_PORT="1883"
[ -n "$TOPIC_RAW" ] || TOPIC_RAW="heizungpanel/raw"
[ -n "$CANDUMP_ARGS" ] || CANDUMP_ARGS="-a -t a -x"
[ -n "$BOOTSTRAP_FILE" ] || BOOTSTRAP_FILE="/tmp/heizungpanel/bootstrap.json"
BUILD_TAG="commit:8b755f2"

BOOTSTRAP_DIR="$(dirname "$BOOTSTRAP_FILE")"
mkdir -p "$BOOTSTRAP_DIR" >/dev/null 2>&1 || true

logger -t heizungpanel "raw bridge start ($BUILD_TAG)"

while true; do
  candump $CANDUMP_ARGS "$CAN_IF" 2>/dev/null \
    | awk -v bootstrap_file="$BOOTSTRAP_FILE" '
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
function write_bootstrap(    i, l1, l2, ts, mode_ts, snap_ts, mode_name_v, payload) {
  l1 = ""; l2 = ""
  for (i = 0; i < 20; i++) l1 = l1 lcd[i]
  for (i = 20; i < 40; i++) l2 = l2 lcd[i]

  ts = systime() * 1000
  mode_ts = (last_mode_ts > 0) ? last_mode_ts : ts
  snap_ts = (last_snapshot_ts > 0) ? last_snapshot_ts : ts
  mode_name_v = mode_name(mode_flags)

  payload = sprintf("{\"schema_version\":2,\"source\":\"raw_bridge\",\"ts_ms\":%d,\"mode\":{\"flags16\":\"%s\",\"mode_name\":\"%s\",\"ts_ms\":%d},\"snapshot\":{\"line1\":\"%s\",\"line2\":\"%s\",\"mode_code\":\"%s\",\"ts_ms\":%d},\"mode_flags16\":\"%s\",\"line1\":\"%s\",\"line2\":\"%s\",\"mode_code\":\"%s\"}", ts, json_escape(mode_flags), json_escape(mode_name_v), mode_ts, json_escape(l1), json_escape(l2), json_escape(mode_code), snap_ts, json_escape(mode_flags), json_escape(l1), json_escape(l2), json_escape(mode_code))

  print payload > bootstrap_file
  close(bootstrap_file)
}
BEGIN {
  for (i = 0; i < 40; i++) lcd[i] = " "
  mode_code = "--"
  mode_flags = "----"
  last_mode_ts = 0
  last_snapshot_ts = 0
}
{
  print $0
  fflush()

  id = ""; data = ""
  if (!parse_id_hex($0) && !parse_len_bytes($0))
    next

  mode_changed = 0
  snapshot_committed = 0

  if (id == "321" && length(data) >= 4) {
    flags = substr(data, 1, 4)
    if (mode_name(flags) != "unknown" && flags != mode_flags) {
      mode_flags = flags
      last_mode_ts = systime() * 1000
      mode_changed = 1
    }
    if (mode_changed)
      write_bootstrap()
    next
  }

  if (id != "320" || length(data) < 2)
    next

  lead = substr(data, 1, 2)
  if (lead == "81") {
    for (i = 0; i < 40; i++) lcd[i] = " "
  } else if (lead == "83") {
    if (length(data) >= 4)
      mode_code = substr(data, 3, 2)
    last_snapshot_ts = systime() * 1000
    snapshot_committed = 1
  } else if (length(data) >= 4) {
    off = hex2dec(lead)
    idx = lcd_index(off)
    if (idx >= 0) {
      pos = idx
      for (j = 3; (j + 1) <= length(data) && pos < 40; j += 2) {
        b = substr(data, j, 2)
        lcd[pos] = byte_to_char(b)
        pos++
      }
    }
  }

  if (snapshot_committed)
    write_bootstrap()
}
' | mosquitto_pub -h "$MQTT_HOST" -p "$MQTT_PORT" -t "$TOPIC_RAW" -l

  rc=$?
  logger -t heizungpanel "raw bridge exited (rc=$rc, if=$CAN_IF); retrying"
  sleep 1
done
