#!/bin/sh
set -eu

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
REPO_ROOT="$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)"

REMOTE=""
SSH_PORT="22"
SSH_KEY=""
REMOTE_STAGE="/tmp/open_slcontrol_deploy"
ACTION=""
NO_RESTART=0

usage() {
  cat <<USAGE
Usage:
  $(basename "$0") <install|push|uninstall|remove> <user@host> [options]

Actions:
  install, push          Copy project files via scp and install on target.
  uninstall, remove      Remove installed project files from target.

Options:
  -p, --port <port>      SSH port (default: 22)
  -i, --identity <file>  SSH private key
  -s, --stage <path>     Remote staging directory (default: /tmp/open_slcontrol_deploy)
      --no-restart       Do not restart/disable service after action
  -h, --help             Show this help

Examples:
  $(basename "$0") install root@192.168.1.10
  $(basename "$0") push root@openwrt.local -i ~/.ssh/id_ed25519
  $(basename "$0") uninstall root@192.168.1.10 -p 2222
USAGE
}

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1" >&2
    exit 1
  fi
}

build_ssh_cmd() {
  set -- ssh -p "$SSH_PORT"
  if [ -n "$SSH_KEY" ]; then
    set -- "$@" -i "$SSH_KEY"
  fi
  set -- "$@" "$REMOTE"
  printf '%s\n' "$*"
}

build_scp_cmd() {
  set -- scp -P "$SSH_PORT"
  if [ -n "$SSH_KEY" ]; then
    set -- "$@" -i "$SSH_KEY"
  fi
  printf '%s\n' "$*"
}

create_stage_tree() {
  STAGE_LOCAL="$(mktemp -d)"
  trap 'rm -rf "$STAGE_LOCAL"' EXIT INT TERM

  FILES="
etc/init.d/heizungpanel
etc/config/heizungpanel
usr/libexec/heizungpanel/raw_bridge.sh
usr/libexec/heizungpanel/state_bridge.sh
usr/libexec/heizungpanel/state.sh
usr/libexec/heizungpanel/parser.uc
usr/libexec/heizungpanel/press.sh
usr/libexec/heizungpanel/config.sh
usr/libexec/heizungpanel/m2_capture.sh
usr/share/rpcd/acl.d/luci-app-heizungpanel.json
www/luci-static/resources/view/heizungpanel/panel.js
"

  for rel in $FILES; do
    src="$REPO_ROOT/$rel"
    dst="$STAGE_LOCAL/$rel"
    if [ ! -f "$src" ]; then
      echo "Missing source file: $src" >&2
      exit 2
    fi
    mkdir -p "$(dirname "$dst")"
    cp "$src" "$dst"
  done

  printf '%s\n' "$STAGE_LOCAL"
}

run_install() {
  require_cmd ssh
  require_cmd scp
  require_cmd mktemp

  STAGE_LOCAL="$(create_stage_tree)"
  SSH_CMD="$(build_ssh_cmd)"
  SCP_CMD="$(build_scp_cmd)"

  echo "[1/4] Prepare remote stage: $REMOTE_STAGE"
  # shellcheck disable=SC2086
  $SSH_CMD "rm -rf '$REMOTE_STAGE' && mkdir -p '$REMOTE_STAGE'"

  echo "[2/4] Upload files via scp"
  # shellcheck disable=SC2086
  $SCP_CMD -r "$STAGE_LOCAL/etc" "$STAGE_LOCAL/usr" "$STAGE_LOCAL/www" "$REMOTE:$REMOTE_STAGE/"

  echo "[3/4] Install files on target"
  # shellcheck disable=SC2086
  $SSH_CMD "cp '$REMOTE_STAGE/etc/init.d/heizungpanel' /etc/init.d/heizungpanel && \
    cp '$REMOTE_STAGE/etc/config/heizungpanel' /etc/config/heizungpanel && \
    mkdir -p /usr/libexec/heizungpanel /usr/share/rpcd/acl.d /www/luci-static/resources/view/heizungpanel && \
    cp '$REMOTE_STAGE'/usr/libexec/heizungpanel/* /usr/libexec/heizungpanel/ && \
    cp '$REMOTE_STAGE/usr/share/rpcd/acl.d/luci-app-heizungpanel.json' /usr/share/rpcd/acl.d/luci-app-heizungpanel.json && \
    cp '$REMOTE_STAGE/www/luci-static/resources/view/heizungpanel/panel.js' /www/luci-static/resources/view/heizungpanel/panel.js && \
    chmod 755 /etc/init.d/heizungpanel /usr/libexec/heizungpanel/*.sh"

  if [ "$NO_RESTART" -eq 0 ]; then
    echo "[4/4] Reload services"
    # shellcheck disable=SC2086
    $SSH_CMD "/etc/init.d/rpcd reload >/dev/null 2>&1 || true; /etc/init.d/uhttpd reload >/dev/null 2>&1 || true; /etc/init.d/heizungpanel enable >/dev/null 2>&1 || true; /etc/init.d/heizungpanel restart"
  else
    echo "[4/4] Skipping restart (--no-restart set)"
  fi

  echo "Install completed on $REMOTE"
}

run_uninstall() {
  require_cmd ssh

  SSH_CMD="$(build_ssh_cmd)"
  echo "[1/2] Remove files from target"
  # shellcheck disable=SC2086
  $SSH_CMD "rm -f /etc/init.d/heizungpanel \
    /etc/config/heizungpanel \
    /usr/share/rpcd/acl.d/luci-app-heizungpanel.json \
    /www/luci-static/resources/view/heizungpanel/panel.js && \
    rm -rf /usr/libexec/heizungpanel"

  if [ "$NO_RESTART" -eq 0 ]; then
    echo "[2/2] Stop/reload services"
    # shellcheck disable=SC2086
    $SSH_CMD "/etc/init.d/heizungpanel stop >/dev/null 2>&1 || true; /etc/init.d/heizungpanel disable >/dev/null 2>&1 || true; /etc/init.d/rpcd reload >/dev/null 2>&1 || true; /etc/init.d/uhttpd reload >/dev/null 2>&1 || true"
  else
    echo "[2/2] Skipping service actions (--no-restart set)"
  fi

  echo "Uninstall completed on $REMOTE"
}

if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
  usage
  exit 0
fi

if [ "$#" -lt 2 ]; then
  usage
  exit 1
fi

ACTION="$1"
REMOTE="$2"
shift 2

while [ "$#" -gt 0 ]; do
  case "$1" in
    -p|--port)
      SSH_PORT="$2"
      shift 2
      ;;
    -i|--identity)
      SSH_KEY="$2"
      shift 2
      ;;
    -s|--stage)
      REMOTE_STAGE="$2"
      shift 2
      ;;
    --no-restart)
      NO_RESTART=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage
      exit 1
      ;;
  esac
done

case "$ACTION" in
  install|push)
    run_install
    ;;
  uninstall|remove)
    run_uninstall
    ;;
  *)
    echo "Unknown action: $ACTION" >&2
    usage
    exit 1
    ;;
esac
