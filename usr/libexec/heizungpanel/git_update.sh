#!/bin/sh

set -eu

fail() {
  echo "$1" >&2
  exit "${2:-1}"
}

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || fail "Missing required command: $1" 3
}

json_escape() {
  printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g' -e ':a;N;$!ba;s/\n/\\n/g' -e 's/\r/\\r/g'
}

print_json_error() {
  local msg
  msg="$(json_escape "$1")"
  printf '{"ok":false,"error":"%s"}\n' "$msg"
}

cleanup() {
  [ -n "${TMPDIR_WORK:-}" ] && rm -rf "$TMPDIR_WORK"
}

trap cleanup EXIT INT TERM

REPO=""
REF=""
ARCHIVE_URL=""
OVERWRITE_CONFIG=0

while [ "$#" -gt 0 ]; do
  case "$1" in
    --repo)
      [ "$#" -ge 2 ] || fail "Missing value for --repo" 2
      REPO="$2"
      shift 2
      ;;
    --ref)
      [ "$#" -ge 2 ] || fail "Missing value for --ref" 2
      REF="$2"
      shift 2
      ;;
    --archive-url|--tar-url|--zip-url)
      [ "$#" -ge 2 ] || fail "Missing value for $1" 2
      ARCHIVE_URL="$2"
      shift 2
      ;;
    --overwrite-config)
      OVERWRITE_CONFIG=1
      shift
      ;;
    *)
      fail "Unknown argument: $1" 2
      ;;
  esac
done

if [ -z "$ARCHIVE_URL" ]; then
  [ -n "$REPO" ] || fail "Missing --repo (owner/name)" 2
  [ -n "$REF" ] || fail "Missing --ref (branch or commit)" 2

  case "$REPO" in
    *..*|*//*|/*|*/|*:*|*\ *|*[^A-Za-z0-9._/-]*) fail "Invalid --repo format" 2 ;;
  esac
  case "$REF" in
    ''|*..*|*/*|*\\*|*\ *|*[^A-Za-z0-9._-]*) fail "Invalid --ref format" 2 ;;
  esac

  ARCHIVE_URL="https://codeload.github.com/$REPO/tar.gz/$REF"
else
  case "$ARCHIVE_URL" in
    https://*) ;;
    *) fail "--archive-url/--tar-url/--zip-url must use https://" 2 ;;
  esac
fi

need_cmd tar
need_cmd cp
need_cmd chmod
need_cmd mkdir

FETCH_CMD=""
if command -v uclient-fetch >/dev/null 2>&1; then
  FETCH_CMD="uclient-fetch -q -O"
elif command -v wget >/dev/null 2>&1; then
  FETCH_CMD="wget -q -O"
elif command -v curl >/dev/null 2>&1; then
  FETCH_CMD="curl -fsSL -o"
else
  fail "No downloader found (uclient-fetch/wget/curl)" 3
fi

TMPDIR_WORK="$(mktemp -d /tmp/heizungpanel_git_update.XXXXXX)"
ARCHIVE_PATH="$TMPDIR_WORK/repo.tar.gz"
EXTRACT_DIR="$TMPDIR_WORK/extract"
mkdir -p "$EXTRACT_DIR"

sh -c "$FETCH_CMD \"$ARCHIVE_PATH\" \"$ARCHIVE_URL\"" || fail "Download failed from $ARCHIVE_URL" 4

tar -xzf "$ARCHIVE_PATH" -C "$EXTRACT_DIR" || fail "Unable to extract tar archive" 4

SRC_ROOT="$(find "$EXTRACT_DIR" -mindepth 1 -maxdepth 1 -type d | head -n 1)"
[ -n "$SRC_ROOT" ] || fail "Archive has no top-level directory" 4

FILES="
etc/init.d/heizungpanel
etc/config/heizungpanel
usr/libexec/heizungpanel/raw_bridge.sh
usr/libexec/heizungpanel/mode_bridge.sh
usr/libexec/heizungpanel/snapshot_bridge.sh
usr/libexec/heizungpanel/bootstrap_bridge.sh
usr/libexec/heizungpanel/state_bridge.sh
usr/libexec/heizungpanel/state.sh
usr/libexec/heizungpanel/parser.uc
usr/libexec/heizungpanel/press.sh
usr/libexec/heizungpanel/config.sh
usr/libexec/heizungpanel/config_get.sh
usr/libexec/heizungpanel/config_set.sh
usr/libexec/heizungpanel/set_mode.sh
usr/libexec/heizungpanel/m2_capture.sh
usr/libexec/heizungpanel/display_emulator.sh
usr/libexec/heizungpanel/mapping_validate.sh
usr/libexec/heizungpanel/isolate_321.sh
usr/libexec/heizungpanel/git_update.sh
usr/share/rpcd/acl.d/luci-app-heizungpanel.json
usr/share/luci/menu.d/luci-app-heizungpanel.json
www/luci-static/resources/view/heizungpanel/panel.js
www/luci-static/resources/view/heizungpanel/config.js
www/luci-static/resources/view/heizungpanel/sensors.js
www/luci-static/resources/view/heizungpanel/mapping.js
www/luci-static/resources/view/heizungpanel/git_update.js
www/cgi-bin/heizungpanel_stream
"

for rel in $FILES; do
  src="$SRC_ROOT/$rel"
  [ -f "$src" ] || fail "Missing required file in archive: $rel" 5
done

for rel in $FILES; do
  src="$SRC_ROOT/$rel"
  dst="/$rel"

  if [ "$rel" = "etc/config/heizungpanel" ] && [ "$OVERWRITE_CONFIG" -ne 1 ] && [ -f "$dst" ]; then
    continue
  fi

  mkdir -p "$(dirname "$dst")"
  cp "$src" "$dst"
done

cp "/usr/share/luci/menu.d/luci-app-heizungpanel.json" "/usr/share/luci-app-heizungpanel.json"

chmod 755 /etc/init.d/heizungpanel /www/cgi-bin/heizungpanel_stream
find /usr/libexec/heizungpanel -maxdepth 1 -type f -name '*.sh' -exec chmod 755 {} \;

/etc/init.d/rpcd reload >/dev/null 2>&1 || true
/etc/init.d/uhttpd reload >/dev/null 2>&1 || true
rm -rf /tmp/luci-indexcache /tmp/luci-modulecache >/dev/null 2>&1 || true
/etc/init.d/heizungpanel enable >/dev/null 2>&1 || true
/etc/init.d/heizungpanel stop >/dev/null 2>&1 || true
if /etc/init.d/heizungpanel start >/dev/null 2>&1; then
  printf '{"ok":true,"archive_url":"%s","message":"Update installed and service restarted"}\n' "$(json_escape "$ARCHIVE_URL")"
  exit 0
fi

print_json_error "Update installed, but service restart failed"
exit 6
