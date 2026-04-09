#!/bin/sh

MQTT_HOST="$1"
MQTT_PORT="$2"
TOPIC_RAW="$3"

[ -n "$MQTT_HOST" ] || MQTT_HOST="127.0.0.1"
[ -n "$MQTT_PORT" ] || MQTT_PORT="1883"
[ -n "$TOPIC_RAW" ] || TOPIC_RAW="heizungpanel/raw"

exec mosquitto_sub -h "$MQTT_HOST" -p "$MQTT_PORT" -t "$TOPIC_RAW" 2>/dev/null | awk '
function hex2dec(h,  i, c, v, out) {
  h = toupper(h)
  out = 0
  for (i = 1; i <= length(h); i++) {
    c = substr(h, i, 1)
    v = index("0123456789ABCDEF", c) - 1
    if (v < 0)
      return -1
    out = (out * 16) + v
  }
  return out
}

function lcd_index(off) {
  if (off >= 0x00 && off <= 0x0F) return off
  if (off >= 0x40 && off <= 0x4F) return 16 + (off - 0x40)
  if (off >= 0x10 && off <= 0x1F) return off
  if (off >= 0x50 && off <= 0x5F) return 16 + (off - 0x50)
  return -1
}

function byte_to_char(h, v) {
  h = toupper(h)
  if (h == "DF")
    return "°"

  v = hex2dec(h)
  if (v >= 32 && v <= 126)
    return sprintf("%c", v)

  return " "
}

function render( i, line1, line2) {
  line1 = ""
  line2 = ""

  for (i = 0; i < 16; i++) line1 = line1 lcd[i]
  for (i = 16; i < 32; i++) line2 = line2 lcd[i]

  printf("\033[H\033[J")
  print "Heizungpanel LCD Emulator (from MQTT raw 0x320)"
  print "line1: [" line1 "]"
  print "line2: [" line2 "]"
  print "last frame: " last_frame
  fflush()
}

BEGIN {
  for (i = 0; i < 32; i++) lcd[i] = " "
  last_frame = "-"
}

{
  if (match($0, /([0-9A-Fa-f]+)#([0-9A-Fa-f]+)/, m) == 0)
    next

  id = toupper(m[1])
  data = toupper(m[2])
  if (id != "320" || length(data) < 4)
    next

  off_hex = substr(data, 1, 2)
  off = hex2dec(off_hex)
  if (off < 0)
    next

  base = lcd_index(off)
  if (base < 0)
    next

  pos = base
  for (p = 3; (p + 1) <= length(data) && pos < 32; p += 2) {
    b = substr(data, p, 2)
    lcd[pos] = byte_to_char(b)
    pos++
  }

  last_frame = data
  render()
}
'
