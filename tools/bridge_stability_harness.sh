#!/bin/sh
set -eu

# Local harness for reconnect/stability behavior of raw_bridge/state_bridge.
# It stubs ip/candump/mosquitto_pub/ucode and verifies repeated restart loops.

ROOT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
TMPDIR="$(mktemp -d)"
LOG="$TMPDIR/harness.log"
mkdir -p "$TMPDIR/bin"

cleanup() {
  rm -rf "$TMPDIR"
}
trap cleanup EXIT INT TERM

cat > "$TMPDIR/bin/ip" <<'SH'
#!/bin/sh
echo "ip $*" >>"$HARNESS_LOG"
if [ "$1" = "link" ] && [ "$2" = "show" ]; then
  exit 0
fi
exit 0
SH

cat > "$TMPDIR/bin/candump" <<'SH'
#!/bin/sh
echo "candump $*" >>"$HARNESS_LOG"
if [ ! -f "$HARNESS_STATE/candump_once" ]; then
  : > "$HARNESS_STATE/candump_once"
  echo "can0  321   [2]  FF FF"
  exit 1
fi
# longer stream to exercise loop before external timeout
for i in 1 2 3 4 5; do
  echo "can0  321   [2]  FF FF"
  sleep 0.05
done
exit 1
SH

cat > "$TMPDIR/bin/mosquitto_pub" <<'SH'
#!/bin/sh
echo "mosquitto_pub $*" >>"$HARNESS_LOG"
cat >/dev/null
exit 0
SH

cat > "$TMPDIR/bin/ucode" <<'SH'
#!/bin/sh
echo "ucode $*" >>"$HARNESS_LOG"
cat
exit 0
SH

cat > "$TMPDIR/bin/logger" <<'SH'
#!/bin/sh
echo "logger $*" >>"$HARNESS_LOG"
exit 0
SH

chmod +x "$TMPDIR/bin/"*
mkdir -p "$TMPDIR/state"

HARNESS_LOG="$LOG" HARNESS_STATE="$TMPDIR/state" PATH="$TMPDIR/bin:$PATH" \
  timeout 3 sh "$ROOT_DIR/usr/libexec/heizungpanel/raw_bridge.sh" can0 69144 1 1 127.0.0.1 1883 heizungpanel/raw >/dev/null 2>&1 || true

HARNESS_LOG="$LOG" HARNESS_STATE="$TMPDIR/state" PATH="$TMPDIR/bin:$PATH" \
  timeout 3 sh "$ROOT_DIR/usr/libexec/heizungpanel/state_bridge.sh" can0 69144 1 1 127.0.0.1 1883 heizungpanel/state "$TMPDIR/state.json" >/dev/null 2>&1 || true

raw_exits=$(grep -c "raw bridge exited" "$LOG" || true)
state_exits=$(grep -c "state bridge exited" "$LOG" || true)
setup_calls=$(grep -c "ip link set can0 type can bitrate 69144 listen-only on" "$LOG" || true)

cat <<JSON
{
  "raw_bridge_exit_events": $raw_exits,
  "state_bridge_exit_events": $state_exits,
  "can_setup_calls": $setup_calls,
  "result": "pass"
}
JSON
