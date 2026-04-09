#!/bin/sh
set -eu

OUT_DIR="${1:-/tmp/heizungpanel/m2}"
CAN_IF="${2:-can0}"
DURATION="${3:-8}"
LABEL="${4:-capture}"

mkdir -p "$OUT_DIR"
TS="$(date +%Y%m%d_%H%M%S)"
RAW_FILE="$OUT_DIR/${TS}_${LABEL}.candump"
SUMMARY_FILE="$OUT_DIR/${TS}_${LABEL}.summary.json"

if ! command -v candump >/dev/null 2>&1; then
  echo "candump not found" >&2
  exit 10
fi

if ! ip link show "$CAN_IF" >/dev/null 2>&1; then
  echo "CAN interface not found: $CAN_IF" >&2
  exit 11
fi

logger -t heizungpanel "m2_capture start label=$LABEL if=$CAN_IF duration=${DURATION}s file=$RAW_FILE"
timeout "$DURATION" candump -L "$CAN_IF" >"$RAW_FILE"

if [ ! -s "$RAW_FILE" ]; then
  echo "No frames captured in ${DURATION}s" >&2
  exit 12
fi

awk '
function flush_bits() {
  if (curr_flags != "") {
    if (!(curr_flags in seen_bits)) {
      seen_bits[curr_flags] = 1;
      bit_order[++bit_n] = curr_flags;
    }
  }
}
{
  if (match($0, /321#([0-9A-Fa-f]{4})/, m)) {
    curr_flags = toupper(m[1]);
    flush_bits();
  }
  if (match($0, /258#([0-9A-Fa-f]{2})/, m2)) {
    idx=toupper(m2[1]);
    if (!(idx in seen_idx)) {
      seen_idx[idx]=1;
      idx_order[++idx_n]=idx;
    }
  }
  if (match($0, /259#([0-9A-Fa-f]{2})/, m3)) {
    idx=toupper(m3[1]);
    if (!(idx in seen_idx)) {
      seen_idx[idx]=1;
      idx_order[++idx_n]=idx;
    }
  }
}
END {
  printf("{\n  \"label\": \"%s\",\n  \"observed_flags16\": [", label);
  for (i=1; i<=bit_n; i++) {
    printf("\"%s\"", bit_order[i]);
    if (i < bit_n) printf(", ");
  }
  printf("],\n  \"observed_258_259_indices\": [");
  for (j=1; j<=idx_n; j++) {
    printf("\"%s\"", idx_order[j]);
    if (j < idx_n) printf(", ");
  }
  printf("]\n}\n");
}
' label="$LABEL" "$RAW_FILE" >"$SUMMARY_FILE"

logger -t heizungpanel "m2_capture done label=$LABEL raw=$RAW_FILE summary=$SUMMARY_FILE"
printf '%s\n' "$SUMMARY_FILE"
