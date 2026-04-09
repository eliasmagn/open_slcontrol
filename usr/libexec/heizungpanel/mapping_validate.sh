#!/bin/sh
set -eu

if [ "$#" -lt 1 ]; then
  echo "Usage: $0 <candump.log> [pair_window_frames]" >&2
  exit 1
fi

INPUT="$1"
PAIR_WINDOW="${2:-80}"

if [ ! -f "$INPUT" ]; then
  echo "Input file not found: $INPUT" >&2
  exit 2
fi

awk -v pair_window="$PAIR_WINDOW" '
function to_int(h,    i,n,c,v) {
  h=toupper(h); n=0
  for (i=1; i<=length(h); i++) {
    c=substr(h,i,1)
    if (c>="0" && c<="9") v=c+0
    else v=index("ABCDEF", c)+9
    if (v<0) v=0
    n = n*16 + v
  }
  return n
}
function parse(line,    a,n,id,data,i,m,token) {
  id=""; data=""
  if (match(line, /([0-9A-Fa-f]+)#([0-9A-Fa-f]+)/, a)) {
    id=toupper(a[1]); data=toupper(a[2]); return id " " data
  }
  n=split(line, a, /[[:space:]]+/)
  if (n < 5) return ""
  id=toupper(a[2])
  if (a[3] ~ /^\[/) {
    for (i=4; i<=n; i++) if (a[i] ~ /^[0-9A-Fa-f]{2}$/) data=data toupper(a[i])
    if (length(data)) return id " " data
  }
  return ""
}
BEGIN {
  frame=0; flags_frames=0; single_active=0; multi_active=0
  unmatched_259=0; paired=0
}
{
  parsed=parse($0)
  if (parsed == "") next
  frame++

  split(parsed, p, " ")
  id=p[1]; data=p[2]

  if (id == "321" && length(data) >= 4) {
    flags=toupper(substr(data,1,4))
    v=to_int(flags)
    active=0
    for (b=0; b<16; b++) {
      mask = 2^b
      if (int(v / mask) % 2 == 0) active++
    }
    flags_frames++
    if (active == 1) single_active++
    else if (active > 1) multi_active++
    flag_hist[flags]++
  }

  if (id == "258" && length(data) >= 2) {
    idx=toupper(substr(data,1,2))
    pending[idx]=frame
    pending_data[idx]=data
    seen[idx]=1
  }

  if (id == "259" && length(data) >= 2) {
    idx=toupper(substr(data,1,2))
    seen[idx]=1
    if ((idx in pending) && ((frame - pending[idx]) <= pair_window)) {
      paired++
      delta=frame-pending[idx]
      pair_delta_sum += delta
      pair_data[idx]=pair_data[idx] sprintf("{\"delta\":%d,\"d258\":\"%s\",\"d259\":\"%s\"}", delta, pending_data[idx], data)
      delete pending[idx]
      delete pending_data[idx]
    } else {
      unmatched_259++
    }
  }
}
END {
  ratio = (flags_frames > 0) ? (single_active / flags_frames) : 0
  printf("{\n")
  printf("  \"frames_total\": %d,\n", frame)
  printf("  \"flags_321\": {\"frames\": %d, \"single_active_ratio\": %.6f, \"single_active_frames\": %d, \"multi_active_frames\": %d},\n", flags_frames, ratio, single_active, multi_active)
  printf("  \"pairing_258_259\": {\"pair_window_frames\": %d, \"paired\": %d, \"unmatched_259\": %d", pair_window, paired, unmatched_259)
  if (paired > 0) printf(", \"avg_delta_frames\": %.3f", pair_delta_sum/paired)
  printf("},\n")

  printf("  \"observed_indices\": [")
  c=0
  for (k in seen) { if (c++) printf(", "); printf("\"%s\"", k) }
  printf("]\n")
  printf("}\n")
}
' "$INPUT"
