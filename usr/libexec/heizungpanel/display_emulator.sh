#!/bin/sh

MODE="mqtt"
INPUT_FILE=""
SHOW_FLAGS=0

MQTT_HOST="127.0.0.1"
MQTT_PORT="1883"
TOPIC_RAW="heizungpanel/raw"

usage() {
  cat <<'EOF'
Usage:
  display_emulator.sh [mqtt_host] [mqtt_port] [topic]
  display_emulator.sh --file <candump.txt>
  display_emulator.sh --stdin
  display_emulator.sh [..source..] --show-flags

Notes:
  - Supports candump style with and without "#":
      can0  320   [8]  00 4B 65 73 ...
      (timestamp) can0 320#004B6573...
  - Optional leading action markers are supported:
      z  can0  320 ...
      v  can0  321 ...
  - Marker fragments split across multiple lines are merged (e.g. "a" ... "r" => "ar").
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    --file)
      MODE="file"
      INPUT_FILE="$2"
      shift 2
      ;;
    --stdin)
      MODE="stdin"
      shift
      ;;
    --show-flags)
      SHOW_FLAGS=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      if [ "$MODE" = "mqtt" ] && [ "$MQTT_HOST" = "127.0.0.1" ]; then
        MQTT_HOST="$1"
      elif [ "$MODE" = "mqtt" ] && [ "$MQTT_PORT" = "1883" ]; then
        MQTT_PORT="$1"
      elif [ "$MODE" = "mqtt" ] && [ "$TOPIC_RAW" = "heizungpanel/raw" ]; then
        TOPIC_RAW="$1"
      else
        echo "Unknown argument: $1" >&2
        usage >&2
        exit 2
      fi
      shift
      ;;
  esac
done

[ -n "$INPUT_FILE" ] || true
[ -r "$INPUT_FILE" ] || [ "$MODE" != "file" ] || { echo "Cannot read file: $INPUT_FILE" >&2; exit 2; }

if [ -t 1 ]; then
  CLEAR_MODE=1
else
  CLEAR_MODE=0
fi

run_emu() {
  awk -v clear_mode="$CLEAR_MODE" -v show_flags="$SHOW_FLAGS" '
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
  if (h == "E2")
    return "ß"
  if (h == "F5")
    return "ü"
  if (h == "E1")
    return "ä"
  if (h == "EF")
    return "ö"

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

  if (clear_mode == 1)
    printf("\033[H\033[J")
  print "Heizungpanel LCD Emulator (from MQTT raw 0x320)"
  print "source: " source_name
  print "line1: [" line1 "]"
  print "line2: [" line2 "]"
  print "last frame: " last_frame
  print "last marker: " last_marker
  print "frames lcd320: " lcd_frames "  flags321: " flags_frames
  fflush()
}

BEGIN {
  for (i = 0; i < 32; i++) lcd[i] = " "
  last_frame = "-"
  last_flags = "----"
  last_marker = "-"
  lcd_frames = 0
  flags_frames = 0
  source_name = ENVIRON["EMU_SOURCE"]
  frame_no = 0
  pending_marker = ""
  pending_marker_frame = 0
  pending_marker_last = 0
  marker_merge_window = 60
  marker_stale_window = 240
}

{
  marker = ""
  line = $0
  if (match(line, /^[[:space:]]*([A-Za-z+\-]{1,3})\s+can[0-9]+[[:space:]]+/, mm)) {
    marker = mm[1]
    sub(/^[[:space:]]*[A-Za-z+\-]{1,3}\s+/, "", line)
  }

  id = ""
  data = ""

  if (match(line, /([0-9A-Fa-f]+)#([0-9A-Fa-f]+)/, m) != 0) {
    id = toupper(m[1])
    data = toupper(m[2])
  } else if (match(line, /^[[:space:]]*(\([^)]+\)[[:space:]]*)?can[0-9]+[[:space:]]+([0-9A-Fa-f]+)[[:space:]]+\[[[:space:]]*[0-9]+[[:space:]]*\][[:space:]]+/, x) != 0) {
    id = toupper(x[2])
    rest = line
    sub(/^[[:space:]]*(\([^)]+\)[[:space:]]*)?can[0-9]+[[:space:]]+[0-9A-Fa-f]+[[:space:]]+\[[[:space:]]*[0-9]+[[:space:]]*\][[:space:]]+/, "", rest)
    n = split(rest, parts, /[[:space:]]+/)
    for (i = 1; i <= n; i++) {
      if (parts[i] ~ /^[0-9A-Fa-f][0-9A-Fa-f]$/)
        data = data toupper(parts[i])
    }
  } else {
    next
  }
  frame_no++

  if (marker != "") {
    marker = tolower(marker)
    if (pending_marker == "") {
      pending_marker = marker
      pending_marker_frame = frame_no
      pending_marker_last = frame_no
    } else if ((frame_no - pending_marker_last) <= marker_merge_window) {
      pending_marker = pending_marker marker
      pending_marker_last = frame_no
      if (length(pending_marker) > 8)
        pending_marker = substr(pending_marker, length(pending_marker) - 7)
    } else {
      pending_marker = marker
      pending_marker_frame = frame_no
      pending_marker_last = frame_no
    }
  } else if (pending_marker != "" && (frame_no - pending_marker_last) > marker_stale_window) {
    pending_marker = ""
  }

  if (id == "321") {
    if (length(data) >= 4) {
      flags = substr(data, 1, 4)
      flags_frames++
      if (flags != last_flags || pending_marker != "") {
        last_flags = flags
        if (pending_marker != "")
          last_marker = pending_marker
        else
          last_marker = "-"
        if (show_flags == 1)
          print "[flags321] marker=" last_marker " flags16=" flags " frame=" frame_no
        pending_marker = ""
      }
    }
    next
  }

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
  if (pending_marker != "")
    last_marker = pending_marker
  lcd_frames++
  render()
}
'
}

case "$MODE" in
  mqtt)
    EMU_SOURCE="mqtt:${MQTT_HOST}:${MQTT_PORT}/${TOPIC_RAW}"
    export EMU_SOURCE
    mosquitto_sub -h "$MQTT_HOST" -p "$MQTT_PORT" -t "$TOPIC_RAW" 2>/dev/null | run_emu
    ;;
  file)
    EMU_SOURCE="file:${INPUT_FILE}"
    export EMU_SOURCE
    cat "$INPUT_FILE" | run_emu
    ;;
  stdin)
    EMU_SOURCE="stdin"
    export EMU_SOURCE
    cat | run_emu
    ;;
esac
