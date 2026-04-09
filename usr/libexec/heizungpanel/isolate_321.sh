#!/bin/sh
set -eu

usage() {
  cat <<'USAGE'
Usage:
  isolate_321.sh <candump.log|-> [context_lines] [max_hits_per_flag]

Examples:
  isolate_321.sh /tmp/candump.log
  isolate_321.sh /tmp/candump.log 20 5
  cat /tmp/candump.log | isolate_321.sh - 12 3

Output:
  1) Summary of unique 0x321 values and counts.
  2) Context blocks per 0x321 value (nearby frames, grouped by same flags).
USAGE
}

[ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ] && { usage; exit 0; }

INPUT="${1:-}"
CTX="${2:-12}"
MAX_HITS="${3:-4}"

[ -n "$INPUT" ] || { usage >&2; exit 2; }

awk -v ctx="$CTX" -v max_hits="$MAX_HITS" '
function parse_frame(line,   m, id, data, n, a, i) {
  id = ""; data = "";

  if (match(line, /([0-9A-Fa-f]+)#([0-9A-Fa-f]+)/, m)) {
    id = toupper(m[1]);
    data = toupper(m[2]);
    return id "|" data;
  }

  n = split(line, a, /[[:space:]]+/);
  if (n < 4) return "";

  id = toupper(a[2]);
  for (i = 4; i <= n; i++)
    if (a[i] ~ /^[0-9A-Fa-f]{2}$/)
      data = data toupper(a[i]);

  if (id == "" || data == "") return "";
  return id "|" data;
}

function is_interesting(id) {
  return (id == "320" || id == "321" || id == "258" || id == "259" || id == "1F5");
}

BEGIN {
  total = 0;
}

{
  raw = $0;
  p = parse_frame(raw);
  if (p == "") next;

  split(p, x, "|");
  id = x[1];
  data = x[2];

  total++;
  line_raw[total] = raw;
  line_id[total] = id;
  line_data[total] = data;

  if (id == "321" && length(data) >= 4) {
    f = substr(data, 1, 4);
    flags_idx[++flags_events] = total;
    flags_val[flags_events] = f;
    flags_count[f]++;
    if (!(f in flags_seen)) {
      flags_seen[f] = 1;
      flags_order[++flags_unique] = f;
    }
  }
}

END {
  print "=== 0x321 summary ===";
  if (flags_unique == 0) {
    print "No 0x321 frames found.";
    exit 0;
  }

  for (i = 1; i <= flags_unique; i++) {
    f = flags_order[i];
    printf("flags16=%s count=%d\n", f, flags_count[f]);
  }

  print "";
  print "=== context by 0x321 value ===";

  for (u = 1; u <= flags_unique; u++) {
    target = flags_order[u];
    print "";
    printf("--- flags16=%s (showing up to %d hits, ±%d lines) ---\n", target, max_hits, ctx);

    shown = 0;
    for (e = 1; e <= flags_events; e++) {
      if (flags_val[e] != target) continue;
      shown++;
      if (shown > max_hits) break;

      center = flags_idx[e];
      start = center - ctx;
      stop = center + ctx;
      if (start < 1) start = 1;
      if (stop > total) stop = total;

      printf("hit #%d around parsed-line %d\n", shown, center);
      for (k = start; k <= stop; k++) {
        if (!is_interesting(line_id[k])) continue;
        marker = (k == center ? ">>" : "  ");
        printf("%s %s\n", marker, line_raw[k]);
      }
      print "";
    }
  }
}
' "$INPUT"
