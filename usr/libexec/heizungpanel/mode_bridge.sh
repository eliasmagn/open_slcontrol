#!/bin/sh

MQTT_HOST="$1"
MQTT_PORT="$2"
TOPIC_RAW="$3"
TOPIC_MODE="$4"
TOPIC_MODE_CURRENT="$5"

[ -n "$MQTT_HOST" ] || MQTT_HOST="127.0.0.1"
[ -n "$MQTT_PORT" ] || MQTT_PORT="1883"
[ -n "$TOPIC_RAW" ] || TOPIC_RAW="heizungpanel/raw"
[ -n "$TOPIC_MODE" ] || TOPIC_MODE="heizungpanel/mode"
[ -n "$TOPIC_MODE_CURRENT" ] || TOPIC_MODE_CURRENT="${TOPIC_MODE}/current"
BUILD_TAG="commit:8b755f2"

logger -t heizungpanel "mode bridge start ($BUILD_TAG)"

while true; do
  mosquitto_sub -h "$MQTT_HOST" -p "$MQTT_PORT" -t "$TOPIC_RAW" 2>/dev/null \
    | awk '
function now_ms(    cmd, out) {
  cmd = "date +%s000"
  cmd | getline out
  close(cmd)
  return out + 0
}
function mode_name(flags) {
  if (flags == "7FFF") return "dauer"
  if (flags == "BFFF") return "uhr"
  if (flags == "DFFF") return "boiler"
  if (flags == "EFFF") return "uhr_boiler"
  if (flags == "F7FF") return "aussen_reg"
  if (flags == "FBFF") return "pruef"
  if (flags == "FDFF") return "hand"
  if (flags == "FFFF") return "running_poll"
  return "unknown"
}
function is_persistent_mode(flags) {
  return (flags == "7FFF" || flags == "BFFF" || flags == "DFFF" || flags == "EFFF" ||
          flags == "F7FF" || flags == "FBFF" || flags == "FDFF")
}
function emit_current(flags,    ts, name) {
  ts = now_ms()
  name = mode_name(flags)
  printf("current\t{\"schema_version\":1,\"ts_ms\":%d,\"flags16\":\"%s\",\"mode_name\":\"%s\"}\n", ts, flags, name)
  fflush()
}
function emit_mode(flags,    ts, name) {
  ts = now_ms()
  name = mode_name(flags)
  printf("mode\t{\"schema_version\":1,\"ts_ms\":%d,\"flags16\":\"%s\",\"mode_name\":\"%s\"}\n", ts, flags, name)
  fflush()
}
function parse_id_hex(line,    a) {
  if (match(line, /([0-9A-Fa-f]+)#([0-9A-Fa-f]+)/, a)) {
    id = toupper(a[1]); data = toupper(a[2]); return 1
  }
  return 0
}
function parse_len_bytes(line,    m, n, i, tok, want, count, out) {
  if (!match(line, /(^|[[:space:]])([0-9A-Fa-f]+)[[:space:]]+\[[[:space:]]*([0-9]+)[[:space:]]*\][[:space:]]+(.+)$/, m))
    return 0
  id = toupper(m[2]); want = m[3] + 0
  n = split(m[4], tok, /[[:space:]]+/)
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
{
  id = ""; data = ""
  if (!parse_id_hex($0) && !parse_len_bytes($0))
    next

  if (id != "321" || length(data) < 4)
    next

  flags = substr(data, 1, 4)
  if (flags == last_flags)
    next

  last_flags = flags
  emit_current(flags)

  if (is_persistent_mode(flags))
    emit_mode(flags)
}' | while IFS="$(printf '\t')" read -r kind payload; do
      [ -n "$payload" ] || continue
      if [ "$kind" = "mode" ]; then
        printf '%s\n' "$payload" | mosquitto_pub -h "$MQTT_HOST" -p "$MQTT_PORT" -t "$TOPIC_MODE" -r -l
      elif [ "$kind" = "current" ]; then
        printf '%s\n' "$payload" | mosquitto_pub -h "$MQTT_HOST" -p "$MQTT_PORT" -t "$TOPIC_MODE_CURRENT" -l
      fi
    done

  rc=$?
  logger -t heizungpanel "mode bridge exited (rc=$rc); retrying"
  sleep 1
done
