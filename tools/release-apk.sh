#!/bin/sh
set -eu
export LC_ALL=C
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
: "${GH_REPO:?Set GH_REPO}"
: "${GH_TOKEN:?Use the GitHub Actions token}"
WORK=${RELEASE_WORK:-$ROOT/bin/release-work}
mkdir -p "$WORK"
WORK=$(CDPATH= cd -- "$WORK" && pwd)
export OUTPUT_DIR=$WORK/assets APK_BUILD_WORK=$WORK/build
mkdir -p "$OUTPUT_DIR"
publish=${APK_RELEASES_ENABLED:-}
if [ -z "$publish" ]; then
  publish=false
  if [ -f "$ROOT/.github/apk-publication-enabled" ]; then publish=$(cat "$ROOT/.github/apk-publication-enabled"); fi
fi
case "$publish" in true|false) ;; *) echo 'Invalid publication policy' >&2; exit 2 ;; esac
retry=${APK_RELEASE_RETRY:-false}
event=${APK_RELEASE_EVENT:-workflow_dispatch}
blocked() {
  echo "::warning::$1"
  [ "$event" = schedule ] && exit 0
  exit 2
}
VERSION=$(sed -n 's/^PKG_VERSION:=//p' "$ROOT/package/luci-app-heizungpanel/Makefile")
REVISION=$(sed -n 's/^PKG_RELEASE:=//p' "$ROOT/package/luci-app-heizungpanel/Makefile")
printf '%s\n' "$VERSION:$REVISION" | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+:[1-9][0-9]*$' || blocked 'Invalid package version'
curl --fail --location --retry 2 --connect-timeout 20 https://downloads.openwrt.org/.versions.json -o "$WORK/versions.json"
OPENWRT_VERSION=$(jq -er .stable_version "$WORK/versions.json")
printf '%s\n' "$OPENWRT_VERSION" | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+$' || blocked 'Stable OpenWrt version is not numeric'
export OPENWRT_VERSION
base=https://downloads.openwrt.org/releases/$OPENWRT_VERSION/targets/ath79/generic
curl --fail --location --retry 2 --connect-timeout 20 "$base/sha256sums" -o "$WORK/sdk-checksums"
sdk=$(awk '$2 ~ /^\*?openwrt-sdk-/ && $2 ~ /\.Linux-x86_64\.tar\.zst$/ { sub(/^\*/, "", $2); print $2 }' "$WORK/sdk-checksums")
[ -n "$sdk" ] && [ "$(printf '%s\n' "$sdk" | wc -l)" -eq 1 ] || blocked 'Expected one stable x86_64 SDK'
SDK_SHA256=$(awk -v n="$sdk" '{ sub(/^\*/, "", $2); if ($2 == n) print $1 }' "$WORK/sdk-checksums")
printf '%s\n' "$SDK_SHA256" | grep -Eq '^[0-9a-f]{64}$' || blocked 'Invalid official SDK checksum'
export SDK_SHA256 SDK_URL=$base/$sdk
commit=$(GIT_MASTER=1 git -C "$ROOT" rev-parse HEAD)
GIT_MASTER=1 git -C "$ROOT" ls-tree -r HEAD -- etc usr www package/luci-app-heizungpanel/Makefile > "$WORK/source-tree"
GIT_MASTER=1 git -C "$ROOT" ls-tree -r HEAD -- tools/build-apk.sh tools/release-apk.sh tools/device_ssh_deploy.sh .github/workflows/release-apk.yml > "$WORK/automation-tree"
source_hash=$(sha256sum "$WORK/source-tree" | cut -d ' ' -f 1)
automation_hash=$(sha256sum "$WORK/automation-tree" | cut -d ' ' -f 1)
attempt_hash=$(printf '%s\n' "$source_hash" "$automation_hash" "$OPENWRT_VERSION" "$sdk" "$SDK_SHA256" | sha256sum | cut -d ' ' -f 1)
tag=v$VERSION-r$REVISION-openwrt-$OPENWRT_VERSION
gh api --paginate --slurp "repos/$GH_REPO/releases?per_page=100" > "$WORK/releases.pages"
jq 'add' "$WORK/releases.pages" > "$WORK/releases.json"
jq '[.[] | select((.body // "") | contains("<!-- heizungpanel-release")) | . as $r | (.body | capture("(?s)<!-- heizungpanel-release\\n(?<metadata>.*?)\\n-->" ).metadata | fromjson) as $m | $m + {id:$r.id,draft:$r.draft,tag:$r.tag_name}]' "$WORK/releases.json" > "$WORK/records.json"
jq -e 'all(.[]; (.version | test("^[0-9]+\\.[0-9]+\\.[0-9]+$")) and (.revision | test("^[1-9][0-9]*$")) and (.source_hash | test("^[0-9a-f]{64}$")) and (.attempt_hash | test("^[0-9a-f]{64}$")) and (.source_commit | test("^[0-9a-f]{40}$")))' "$WORK/records.json" >/dev/null
policy=$(jq -r --arg v "$VERSION" --arg r "$REVISION" --arg h "$source_hash" 'any(.[]; .draft == false and .version == $v and .revision == $r and .source_hash != $h)' "$WORK/records.json")
if [ "$policy" = true ]; then
  blocked 'App source changed at an already published version: bump PKG_RELEASE'
fi
policy=$(jq -r --arg v "$VERSION" --arg r "$REVISION" '(($v | split(".") | map(tonumber)) + [($r | tonumber)]) as $current | any(.[]; .draft == false and (((.version | split(".") | map(tonumber)) + [(.revision | tonumber)]) > $current))' "$WORK/records.json")
if [ "$policy" = true ]; then
  blocked 'Package version regression rejected'
fi
jq --arg t "$tag" '.[] | select(.tag == $t)' "$WORK/records.json" > "$WORK/existing.json"
id=$(jq -r '.id // empty' "$WORK/existing.json")
if [ -z "$id" ]; then
  jq --arg v "$VERSION" --arg r "$REVISION" --arg o "$OPENWRT_VERSION" '.[] | select(.draft == false and .version == $v and .revision == $r and .openwrt == $o and (.tag | startswith("untagged-")))' "$WORK/records.json" > "$WORK/legacy-publication.json"
fi
policy=$(jq -r --arg t "$tag" 'any(.[]; .tag_name == $t)' "$WORK/releases.json")
if [ -z "$id" ] && [ "$policy" = true ]; then
  blocked 'Existing release has no recognized provenance; refusing to replace it'
fi
check_tag() {
  expected=$1
  gh api "repos/$GH_REPO/git/matching-refs/tags/$tag" > "$WORK/tag.refs"
  jq --arg t "refs/tags/$tag" '.[] | select(.ref == $t) | .object' "$WORK/tag.refs" > "$WORK/tag.json"
  if [ ! -s "$WORK/tag.json" ]; then
    if [ -n "${id:-}" ]; then
      gh api "repos/$GH_REPO/releases/$id" > "$WORK/draft-target.json"
      [ "$(jq -r .target_commitish "$WORK/draft-target.json")" = "$expected" ] || blocked 'Draft target differs from recorded source commit'
    fi
    return 0
  fi
  depth=0
  while [ "$(jq -r .type "$WORK/tag.json")" = tag ]; do
    depth=$((depth + 1))
    [ "$depth" -le 5 ] || blocked 'Annotated tag nesting rejected'
    sha=$(jq -r .sha "$WORK/tag.json")
    gh api "repos/$GH_REPO/git/tags/$sha" --jq .object > "$WORK/tag.next"
    mv "$WORK/tag.next" "$WORK/tag.json"
  done
  [ "$(jq -r .sha "$WORK/tag.json")" = "$expected" ] || blocked 'Existing tag targets another source commit; never move release tags'
}
if [ -z "$id" ] && [ -s "$WORK/legacy-publication.json" ]; then
  id=$(jq -r .id "$WORK/legacy-publication.json")
  old_tag=$(jq -r .tag "$WORK/legacy-publication.json")
  check_tag "$(jq -r .source_commit "$WORK/legacy-publication.json")"
  gh api --method PATCH "repos/$GH_REPO/releases/$id" -f tag_name="$tag" -f target_commitish="$(jq -r .source_commit "$WORK/legacy-publication.json")" >/dev/null
  echo 'Corrected an autogenerated publication tag without replacing assets or rebuilding'
  exit 0
fi
policy=$(jq -r --arg t "$tag" 'any(.[]; .tag_name == $t and .draft == false)' "$WORK/releases.json")
if [ "$policy" = true ]; then
  [ -n "$id" ] || blocked 'Existing published tag has no verified provenance'
  echo 'Matching published APK already exists; no SDK build needed'
  exit 0
fi
if [ -n "$id" ] && [ "$(jq -r .attempt_hash "$WORK/existing.json")" = "$attempt_hash" ]; then
  state=$(jq -r .state "$WORK/existing.json")
  if [ "$state" = ready ]; then
    if [ "$publish" != true ]; then echo 'Verified draft is ready; publishing disabled'; exit 0; fi
    gh release download "$tag" --repo "$GH_REPO" --dir "$OUTPUT_DIR" --clobber --pattern '*.apk' --pattern SHA256SUMS --pattern BUILDINFO.json
    (cd "$OUTPUT_DIR" && sha256sum -c SHA256SUMS)
    package=$(find "$OUTPUT_DIR" -maxdepth 1 -name '*.apk' -type f)
    [ -n "$package" ] && [ "$(printf '%s\n' "$package" | wc -l)" -eq 1 ] || blocked 'Expected one staged APK'
    [ "$(sha256sum "$package" | cut -d ' ' -f 1)" = "$(jq -r .apk_sha256 "$WORK/existing.json")" ] || blocked 'Staged APK differs from verified provenance'
    check_tag "$(jq -r .source_commit "$WORK/existing.json")"
    gh api --method PATCH "repos/$GH_REPO/releases/$id" -f tag_name="$tag" -f target_commitish="$(jq -r .source_commit "$WORK/existing.json")" -F draft=false -F prerelease=false -f make_latest=true >/dev/null
    echo "Published verified draft: https://github.com/$GH_REPO/releases/tag/$tag"
    exit 0
  fi
  if [ "$retry" != true ]; then echo 'Unchanged failed/interrupted attempt skipped; use manual retry after investigation'; exit 0; fi
fi
jq -n --arg version "$VERSION" --arg revision "$REVISION" --arg openwrt "$OPENWRT_VERSION" --arg source_hash "$source_hash" --arg attempt_hash "$attempt_hash" --arg source_commit "$commit" '{version:$version,revision:$revision,openwrt:$openwrt,source_hash:$source_hash,attempt_hash:$attempt_hash,source_commit:$source_commit,state:"attempting"}' > "$WORK/record.json"
check_tag "$commit"
body() {
  printf 'Verified noarch Heizungpanel APK for OpenWrt %s. Default configuration is read-only and contains no device credentials.\n\n<!-- heizungpanel-release\n' "$OPENWRT_VERSION"
  jq -c . "$WORK/record.json"
  printf '\n-->\n'
}
body > "$WORK/body.txt"
if [ -z "$id" ]; then
  gh api --method POST "repos/$GH_REPO/releases" -f tag_name="$tag" -f target_commitish="$commit" -f name="Heizungpanel $VERSION-r$REVISION / OpenWrt $OPENWRT_VERSION" -F draft=true -F prerelease=false -f body="$(cat "$WORK/body.txt")" > "$WORK/created.json"
  id=$(jq -er .id "$WORK/created.json")
else
  gh api --method PATCH "repos/$GH_REPO/releases/$id" -f tag_name="$tag" -f target_commitish="$commit" -f body="$(cat "$WORK/body.txt")" >/dev/null
fi
failed() {
  jq '.state = "failed"' "$WORK/record.json" > "$WORK/record.next" && mv "$WORK/record.next" "$WORK/record.json"
  body > "$WORK/body.txt"
  gh api --method PATCH "repos/$GH_REPO/releases/$id" -f tag_name="$tag" -f target_commitish="$commit" -f body="$(cat "$WORK/body.txt")" >/dev/null 2>&1 || true
}
trap 'failed' EXIT HUP INT TERM
"$ROOT/tools/build-apk.sh" build
jq '. + {source_hash:$source_hash,attempt_hash:$attempt_hash}' --arg source_hash "$source_hash" --arg attempt_hash "$attempt_hash" "$OUTPUT_DIR/BUILDINFO.json" > "$WORK/buildinfo.next"
mv "$WORK/buildinfo.next" "$OUTPUT_DIR/BUILDINFO.json"
gh release upload "$tag" "$OUTPUT_DIR"/*.apk "$OUTPUT_DIR/SHA256SUMS" "$OUTPUT_DIR/BUILDINFO.json" --repo "$GH_REPO" --clobber
package=$(find "$OUTPUT_DIR" -maxdepth 1 -name '*.apk' -type f)
apk_sha256=$(sha256sum "$package" | cut -d ' ' -f 1)
jq --arg apk_sha256 "$apk_sha256" '.state = "ready" | .apk_sha256 = $apk_sha256' "$WORK/record.json" > "$WORK/record.next" && mv "$WORK/record.next" "$WORK/record.json"
body > "$WORK/body.txt"
gh api --method PATCH "repos/$GH_REPO/releases/$id" -f tag_name="$tag" -f target_commitish="$commit" -f body="$(cat "$WORK/body.txt")" >/dev/null
trap - EXIT HUP INT TERM
if [ "$publish" = true ]; then
  check_tag "$commit"
  gh api --method PATCH "repos/$GH_REPO/releases/$id" -f tag_name="$tag" -f target_commitish="$commit" -F draft=false -F prerelease=false -f make_latest=true >/dev/null
  echo "Published: https://github.com/$GH_REPO/releases/tag/$tag"
else
  echo 'APK verified and staged in a draft release; enable APK_RELEASES_ENABLED to publish'
fi
