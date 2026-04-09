#!/bin/sh
set -eu

HOST="127.0.0.1"
PORT="1883"
TOPIC="heizungpanel/raw"
INPUT_MODE="mqtt"
INPUT_FILE=""
SHOW_FLAGS=0

usage() {
  cat <<USAGE
Usage:
  $0 [--host <host>] [--port <port>] [--topic <topic>] [--show-flags]
  $0 --file <candump.log> [--show-flags]
  $0 --stdin [--show-flags]

Modes:
  --file <path>   Read offline candump log file.
  --stdin         Read candump lines from STDIN.
  (default)       Subscribe to MQTT topic (heizungpanel/raw).

Notes:
  - Reconstructs a 2x16 LCD from 0x320 frames (offset-based merge).
  - With --show-flags, prints latest 0x321 flags and a short marker trace.
USAGE
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --host)
      [ "$#" -ge 2 ] || { echo "Missing value for --host" >&2; exit 2; }
      HOST="$2"; shift 2 ;;
    --port)
      [ "$#" -ge 2 ] || { echo "Missing value for --port" >&2; exit 2; }
      PORT="$2"; shift 2 ;;
    --topic)
      [ "$#" -ge 2 ] || { echo "Missing value for --topic" >&2; exit 2; }
      TOPIC="$2"; shift 2 ;;
    --file)
      [ "$#" -ge 2 ] || { echo "Missing value for --file" >&2; exit 2; }
      INPUT_MODE="file"; INPUT_FILE="$2"; shift 2 ;;
    --stdin)
      INPUT_MODE="stdin"; shift ;;
    --show-flags)
      SHOW_FLAGS=1; shift ;;
    -h|--help)
      usage; exit 0 ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 2 ;;
  esac
done

if [ "$INPUT_MODE" = "file" ] && [ ! -f "$INPUT_FILE" ]; then
  echo "Input file not found: $INPUT_FILE" >&2
  exit 2
fi

AWK_PROG='
function hex2dec(h, i, c, v, out) {
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
  if (h == "DF") return "°"
  if (h == "E2") return "ß"
  if (h == "F5") return "ü"
  if (h == "E1") return "ä"
  if (h == "EF") return "ö"
  v = hex2dec(h)
  if (v >= 32 && v <= 126)
    return sprintf("%c", v)

  return " "
}

function active_bits_from_flags(hex16, v, b, out) {
  v = hex2dec(hex16)
  out = ""
  for (b = 0; b < 16; b++) {
    if (int(v / (2 ^ b)) % 2 == 0) {
      if (length(out)) out = out ","
      out = out b
    }
  }
  return out
}

function push_trace(entry) {
  trace_count++
  trace[trace_count] = entry
  if (trace_count > 8) {
    for (i = 1; i < trace_count; i++) trace[i] = trace[i + 1]
    delete trace[trace_count]
    trace_count--
  }
}

function parse_frame(line,    a, n, id, data, i) {
  id = ""
  data = ""

  if (match(line, /([0-9A-Fa-f]+)#([0-9A-Fa-f]+)/, a)) {
    id = toupper(a[1])
    data = toupper(a[2])
    return id " " data
  }

  n = split(line, a, /[[:space:]]+/)
  if (n < 5) return ""

  id = toupper(a[2])
  if (a[3] !~ /^\[[0-9]+\]$/) return ""

  for (i = 4; i <= n; i++)
    if (a[i] ~ /^[0-9A-Fa-f]{2}$/)
      data = data toupper(a[i])

  if (!length(data)) return ""
  return id " " data
}

function render(    i, line1, line2) {
  line1 = ""
  line2 = ""

  for (i = 0; i < 16; i++) line1 = line1 lcd[i]
  for (i = 16; i < 32; i++) line2 = line2 lcd[i]

  printf("\033[H\033[J")
  print "Heizungpanel LCD Emulator"
  print "line1: [" line1 "]"
  print "line2: [" line2 "]"
  print "last_320: " last_320

  if (show_flags == 1) {
    print "flags16: " flags16 "  active_low_bits: [" active_bits "]"
    if (trace_count > 0) {
      print "flags321_trace (newest last):"
      for (i = 1; i <= trace_count; i++) print "  " trace[i]
    }
  }

  fflush()
}

BEGIN {
  for (i = 0; i < 32; i++) lcd[i] = " "
  frame_no = 0
  last_320 = "-"
  flags16 = "----"
  active_bits = ""
  trace_count = 0
}

{
  parsed = parse_frame($0)
  if (parsed == "") next

  split(parsed, parts, " ")
  id = parts[1]
  data = parts[2]
  frame_no++

  if (id == "321" && length(data) >= 4) {
    flags16 = substr(data, 1, 4)
    active_bits = active_bits_from_flags(flags16)
    if (show_flags == 1) {
      push_trace(sprintf("f=%d flags=%s bits=[%s]", frame_no, flags16, active_bits))
      render()
    }
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
  for (idx = 3; (idx + 1) <= length(data) && pos < 32; idx += 2) {
    b = substr(data, idx, 2)
    lcd[pos] = byte_to_char(b)
    pos++
  }

  last_320 = data
  render()
}
'

if [ "$INPUT_MODE" = "mqtt" ]; then
  exec mosquitto_sub -h "$HOST" -p "$PORT" -t "$TOPIC" 2>/dev/null | awk -v show_flags="$SHOW_FLAGS" "$AWK_PROG"
fi

if [ "$INPUT_MODE" = "file" ]; then
  exec awk -v show_flags="$SHOW_FLAGS" "$AWK_PROG" "$INPUT_FILE"
fi

exec awk -v show_flags="$SHOW_FLAGS" "$AWK_PROG"
