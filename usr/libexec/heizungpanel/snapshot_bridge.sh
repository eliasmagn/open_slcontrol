#!/bin/sh

MQTT_HOST="$1"
MQTT_PORT="$2"
TOPIC_RAW="$3"
TOPIC_SNAPSHOT="$4"

[ -n "$MQTT_HOST" ] || MQTT_HOST="127.0.0.1"
[ -n "$MQTT_PORT" ] || MQTT_PORT="1883"
[ -n "$TOPIC_RAW" ] || TOPIC_RAW="heizungpanel/raw"
[ -n "$TOPIC_SNAPSHOT" ] || TOPIC_SNAPSHOT="heizungpanel/snapshot"
BUILD_TAG="commit:8b755f2"

logger -t heizungpanel "snapshot bridge start ($BUILD_TAG)"

while true; do
  mosquitto_sub -h "$MQTT_HOST" -p "$MQTT_PORT" -t "$TOPIC_RAW" 2>/dev/null \
    | awk '
function now_ms(    cmd, out) {
  cmd = "date +%s000"
  cmd | getline out
  close(cmd)
  return out + 0
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
function emit_snapshot(    i, l1, l2, ts) {
  l1 = ""; l2 = ""
  for (i = 0; i < 20; i++) l1 = l1 lcd[i]
  for (i = 20; i < 40; i++) l2 = l2 lcd[i]
  ts = now_ms()
  printf("{\"schema_version\":1,\"ts_ms\":%d,\"line1\":\"%s\",\"line2\":\"%s\",\"mode_code\":\"%s\"}\n", ts, l1, l2, mode_code)
  fflush()
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
BEGIN {
  for (i = 0; i < 40; i++) lcd[i] = " "
  mode_code = "--"
}
{
  id = ""; data = ""
  if (!parse_id_hex($0) && !parse_len_bytes($0))
    next

  if (id == "320" && length(data) >= 2) {
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
    next
  }
}
' \
    | mosquitto_pub -h "$MQTT_HOST" -p "$MQTT_PORT" -t "$TOPIC_SNAPSHOT" -r -l

  rc=$?
  logger -t heizungpanel "snapshot bridge exited (rc=$rc); retrying"
  sleep 1
done
