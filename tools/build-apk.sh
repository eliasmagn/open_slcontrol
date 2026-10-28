#!/bin/sh
set -eu
export LC_ALL=C
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
: "${OPENWRT_VERSION:?Set OPENWRT_VERSION}"
: "${SDK_URL:?Set SDK_URL}"
: "${SDK_SHA256:?Set SDK_SHA256}"
: "${OUTPUT_DIR:?Set OUTPUT_DIR}"
WORK=${APK_BUILD_WORK:-$ROOT/bin/apk-build}
mkdir -p "$WORK" "$OUTPUT_DIR"
WORK=$(CDPATH= cd -- "$WORK" && pwd)
OUTPUT_DIR=$(CDPATH= cd -- "$OUTPUT_DIR" && pwd)
export TMPDIR=$WORK/tmp
mkdir -p "$TMPDIR"
SOURCE=$(mktemp -d "$WORK/source.XXXXXX")
GIT_MASTER=1 git -C "$ROOT" archive -o "$WORK/source.tar" HEAD etc usr www package/luci-app-heizungpanel tools/device_ssh_deploy.sh LICENSE
tar -xf "$WORK/source.tar" -C "$SOURCE"
VERSION=$(sed -n 's/^PKG_VERSION:=//p' "$SOURCE/package/luci-app-heizungpanel/Makefile")
REVISION=$(sed -n 's/^PKG_RELEASE:=//p' "$SOURCE/package/luci-app-heizungpanel/Makefile")
awk '
  /^[[:space:]]*(#|$)/ { next }
  {
    line = $0; sub(/^[[:space:]]+/, "", line); sub(/[[:space:]]+$/, "", line)
    if (line ~ /^config[[:space:]]+heizungpanel[[:space:]]+/) {
      sub(/^config[[:space:]]+heizungpanel[[:space:]]+/, "", line)
      if (line == "\047main\047" || line == "\"main\"") sections++; else unsafe = 1
      next
    }
    if (sections != 1 || line !~ /^option[[:space:]]+/) { unsafe = 1; next }
    sub(/^option[[:space:]]+/, "", line)
    key = line; sub(/[[:space:]].*$/, "", key)
    value = line; sub(/^[^[:space:]]+[[:space:]]+/, "", value)
    if (key !~ /^[A-Za-z_][A-Za-z0-9_]*$/ || seen[key]++) { unsafe = 1; next }
    if (value ~ /^\047[^\047]*\047$/ || value ~ /^"[^"]*"$/) value = substr(value, 2, length(value) - 2)
    else if (value !~ /^[A-Za-z0-9_.:,\/-]+$/) { unsafe = 1; next }
    if (key == "write_mode") readonly = (value == "0")
    if ((key == "stream_token" || key ~ /^alarm_telegram_/ || key ~ /password|passwd|secret/ || key == "alarm_url") && value != "") unsafe = 1
  }
  END { exit (sections != 1 || !readonly || unsafe) }
' "$SOURCE/etc/config/heizungpanel" || { echo 'Public defaults must be read-only and credential-free' >&2; exit 2; }
for f in "$SOURCE/etc/init.d/heizungpanel" "$SOURCE"/usr/libexec/heizungpanel/*.sh "$SOURCE/www/cgi-bin/heizungpanel_stream" "$SOURCE/tools/device_ssh_deploy.sh"; do sh -n "$f"; done
for f in "$SOURCE"/www/luci-static/resources/view/heizungpanel/*.js; do node --check "$f"; done
jq -e . "$SOURCE/usr/share/rpcd/acl.d/luci-app-heizungpanel.json" "$SOURCE/usr/share/luci/menu.d/luci-app-heizungpanel.json" >/dev/null

if [ -z "${SDK_HOME:-}" ]; then
  archive=$WORK/sdk.tar.zst
  curl --fail --location --retry 2 --connect-timeout 20 "$SDK_URL" -o "$archive"
  printf '%s  %s\n' "$SDK_SHA256" "$archive" | sha256sum -c -
  mkdir -p "$WORK/sdk"
  tar --zstd -xf "$archive" -C "$WORK/sdk" --strip-components=1
  SDK_HOME=$WORK/sdk
fi
SDK_HOME=$(CDPATH= cd -- "$SDK_HOME" && pwd)
if [ "${1:-build}" = build ]; then
  printf 'src-link heizungpanel %s\n' "$SOURCE" > "$SDK_HOME/feeds.conf"
  cat "$SDK_HOME/feeds.conf.default" >> "$SDK_HOME/feeds.conf"
  (cd "$SDK_HOME" && ./scripts/feeds update -a && ./scripts/feeds install -p heizungpanel luci-app-heizungpanel)
  printf '\nCONFIG_PACKAGE_luci-app-heizungpanel=m\n' >> "$SDK_HOME/.config"
  make -C "$SDK_HOME" defconfig
  make -C "$SOURCE/package/luci-app-heizungpanel" TOPDIR="$SDK_HOME" compile V=s
  package=$(find "$SDK_HOME/bin/packages" -type f -name "luci-app-heizungpanel-$VERSION-r$REVISION.apk")
  [ -n "$package" ] && [ "$(printf '%s\n' "$package" | wc -l)" -eq 1 ] || { echo 'Expected exactly one APK' >&2; exit 3; }
  APK=$OUTPUT_DIR/luci-app-heizungpanel-$VERSION-r$REVISION-openwrt-$OPENWRT_VERSION.apk
  cp "$package" "$APK"
else
  : "${APK:?Set APK for verification}"
fi
EXTRACT=$(mktemp -d "$WORK/verify.XXXXXX")
trap 'rm -rf "$EXTRACT"' EXIT HUP INT TERM
"$SDK_HOME/staging_dir/host/bin/apk" extract --allow-untrusted --no-chown --destination "$EXTRACT" "$APK"
"$SDK_HOME/staging_dir/host/bin/apk" adbdump "$APK" > "$WORK/package-metadata.txt"
grep -Fx '  arch: noarch' "$WORK/package-metadata.txt" >/dev/null
grep -Fx "  version: $VERSION-r$REVISION" "$WORK/package-metadata.txt" >/dev/null
FILES=$(sed -n '/^etc\//,/^www\/cgi-bin/p' "$SOURCE/tools/device_ssh_deploy.sh")
for rel in $FILES; do
  cmp -s "$SOURCE/$rel" "$EXTRACT/$rel" || { echo "APK content mismatch: $rel" >&2; exit 4; }
  case "$rel" in
    etc/config/*) mode=600 ;;
    etc/init.d/*|usr/libexec/heizungpanel/*.sh|www/cgi-bin/*) mode=755 ;;
    *) mode=644 ;;
  esac
  [ "$(stat -c %a "$EXTRACT/$rel")" = "$mode" ] || { echo "APK mode mismatch: $rel" >&2; exit 4; }
done
[ "$(cat "$EXTRACT/lib/apk/packages/luci-app-heizungpanel.conffiles")" = /etc/config/heizungpanel ]
printf '%s\n' "$FILES" > "$WORK/expected-files"
printf '%s\n' lib/apk/packages/luci-app-heizungpanel.conffiles lib/apk/packages/luci-app-heizungpanel.conffiles_static lib/apk/packages/luci-app-heizungpanel.list >> "$WORK/expected-files"
sort "$WORK/expected-files" -o "$WORK/expected-files"
(cd "$EXTRACT" && find . -type f -o -type l | sed 's|^./||' | sort) > "$WORK/actual-files"
cmp -s "$WORK/expected-files" "$WORK/actual-files" || { echo 'Unexpected APK payload files' >&2; exit 4; }
if [ "${1:-build}" = build ]; then
  (cd "$OUTPUT_DIR" && sha256sum "$(basename "$APK")" > SHA256SUMS)
  commit=$(GIT_MASTER=1 git -C "$ROOT" rev-parse HEAD)
  jq -n --arg package_version "$VERSION-r$REVISION" --arg openwrt_version "$OPENWRT_VERSION" --arg source_commit "$commit" --arg sdk_sha256 "$SDK_SHA256" '{package_version:$package_version,openwrt_version:$openwrt_version,source_commit:$source_commit,sdk_sha256:$sdk_sha256}' > "$OUTPUT_DIR/BUILDINFO.json"
fi
echo 'APK metadata, all16 files, permissions, defaults and conffile verified'
