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

# Minimal sanity checks: expected app entrypoints must exist.
[ -f "$SRC_ROOT/etc/init.d/heizungpanel" ] || fail "Archive missing etc/init.d/heizungpanel" 5
[ -f "$SRC_ROOT/usr/libexec/heizungpanel/git_update.sh" ] || fail "Archive missing usr/libexec/heizungpanel/git_update.sh" 5
[ -f "$SRC_ROOT/www/cgi-bin/heizungpanel_stream" ] || fail "Archive missing www/cgi-bin/heizungpanel_stream" 5

# Reset managed directories so removed/renamed files don't remain on target.
rm -rf /usr/libexec/heizungpanel /www/luci-static/resources/view/heizungpanel
mkdir -p /usr/libexec/heizungpanel /www/luci-static/resources/view/heizungpanel

# Copy app tree from extracted archive (future-proof for renamed/new files).
for top in etc usr www; do
  [ -d "$SRC_ROOT/$top" ] || continue
  find "$SRC_ROOT/$top" -type f | while IFS= read -r src; do
    rel="${src#$SRC_ROOT/}"
    dst="/$rel"

    if [ "$rel" = "etc/config/heizungpanel" ] && [ "$OVERWRITE_CONFIG" -ne 1 ] && [ -f "$dst" ]; then
      continue
    fi

    mkdir -p "$(dirname "$dst")"
    cp "$src" "$dst"
  done
done

# Mirror canonical menu file into the legacy location for compatibility targets.
if [ -f "/usr/share/luci/menu.d/luci-app-heizungpanel.json" ]; then
  cp "/usr/share/luci/menu.d/luci-app-heizungpanel.json" "/usr/share/luci-app-heizungpanel.json"
fi

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
