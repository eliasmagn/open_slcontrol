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
OVERWRITE_CONFIG=0
USE_MUX=1
STAGE_LOCAL=""
MUX_DIR=""
MUX_ACTIVE=0
MUX_CONTROL_PATH=""

cleanup() {
  if [ "$MUX_ACTIVE" -eq 1 ] && [ -n "$REMOTE" ]; then
    set -- ssh -p "$SSH_PORT"
    if [ -n "$SSH_KEY" ]; then
      set -- "$@" -i "$SSH_KEY"
    fi
    if [ -n "$MUX_CONTROL_PATH" ]; then
      set -- "$@" -o "ControlPath=$MUX_CONTROL_PATH"
    fi
    "$@" -O exit "$REMOTE" >/dev/null 2>&1 || true
  fi
  [ -n "$STAGE_LOCAL" ] && rm -rf "$STAGE_LOCAL"
  [ -n "$MUX_DIR" ] && rm -rf "$MUX_DIR"
}

trap cleanup EXIT INT TERM

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
      --no-mux           Disable SSH connection multiplexing (prompts password each call)
      --no-restart       Do not restart/disable service after action
      --overwrite-config Always overwrite /etc/config/heizungpanel on install
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

run_ssh() {
  remote_cmd="$1"
  set -- ssh -p "$SSH_PORT"
  if [ -n "$SSH_KEY" ]; then
    set -- "$@" -i "$SSH_KEY"
  fi
  if [ "$USE_MUX" -eq 1 ] && [ -n "$MUX_CONTROL_PATH" ]; then
    set -- "$@" -o ControlMaster=auto -o ControlPersist=300 -o "ControlPath=$MUX_CONTROL_PATH"
  fi
  set -- "$@" "$REMOTE" "$remote_cmd"
  "$@"
}

run_scp() {
  # Force legacy SCP protocol (-O) to support OpenWrt/Dropbear targets
  # that do not provide an SFTP server binary/subsystem.
  if [ -n "$SSH_KEY" ] && [ "$USE_MUX" -eq 1 ] && [ -n "$MUX_CONTROL_PATH" ]; then
    scp -O -P "$SSH_PORT" -i "$SSH_KEY" \
      -o ControlMaster=auto -o ControlPersist=300 -o "ControlPath=$MUX_CONTROL_PATH" \
      "$@"
    return
  fi

  if [ -n "$SSH_KEY" ]; then
    scp -O -P "$SSH_PORT" -i "$SSH_KEY" "$@"
    return
  fi

  if [ "$USE_MUX" -eq 1 ] && [ -n "$MUX_CONTROL_PATH" ]; then
    scp -O -P "$SSH_PORT" \
      -o ControlMaster=auto -o ControlPersist=300 -o "ControlPath=$MUX_CONTROL_PATH" \
      "$@"
    return
  fi

  scp -O -P "$SSH_PORT" "$@"
}

require_opt_value() {
  opt="$1"
  if [ "$#" -lt 2 ] || [ -z "${2:-}" ]; then
    echo "Missing value for option: $opt" >&2
    usage
    exit 1
  fi
}

create_stage_tree() {
  STAGE_LOCAL="$(mktemp -d)"

  FILES="
etc/init.d/heizungpanel
etc/config/heizungpanel
usr/libexec/heizungpanel/raw_bridge.sh
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
usr/share/rpcd/acl.d/luci-app-heizungpanel.json
usr/share/luci/menu.d/luci-app-heizungpanel.json
www/luci-static/resources/view/heizungpanel/panel.js
www/luci-static/resources/view/heizungpanel/config.js
www/cgi-bin/heizungpanel_stream
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

  # Keep one canonical menu source in repo (menu.d) and mirror it to the
  # legacy path in staging for compatibility targets.
  mkdir -p "$STAGE_LOCAL/usr/share"
  cp "$STAGE_LOCAL/usr/share/luci/menu.d/luci-app-heizungpanel.json" \
    "$STAGE_LOCAL/usr/share/luci-app-heizungpanel.json"

}

setup_mux() {
  if [ "$USE_MUX" -eq 0 ]; then
    return 0
  fi

  require_cmd mktemp
  MUX_DIR="$(mktemp -d)"
  MUX_CONTROL_PATH="$MUX_DIR/ctl"

  echo "[0/4] Establish SSH master connection (single password prompt)"
  set -- ssh -fN -p "$SSH_PORT"
  if [ -n "$SSH_KEY" ]; then
    set -- "$@" -i "$SSH_KEY"
  fi
  "$@" -o ControlMaster=auto -o ControlPersist=300 -o "ControlPath=$MUX_CONTROL_PATH" "$REMOTE"
  MUX_ACTIVE=1
}

run_install() {
  require_cmd ssh
  require_cmd scp
  require_cmd mktemp

  setup_mux
  create_stage_tree
  if [ "$OVERWRITE_CONFIG" -eq 1 ]; then
    CONFIG_COPY_CMD="cp '$REMOTE_STAGE/etc/config/heizungpanel' /etc/config/heizungpanel"
  else
    CONFIG_COPY_CMD="[ -f /etc/config/heizungpanel ] || cp '$REMOTE_STAGE/etc/config/heizungpanel' /etc/config/heizungpanel"
  fi

  echo "[1/4] Prepare remote stage: $REMOTE_STAGE"
  run_ssh "rm -rf '$REMOTE_STAGE' && mkdir -p '$REMOTE_STAGE'"

  echo "[2/4] Upload files via scp"
  run_scp -r "$STAGE_LOCAL/etc" "$STAGE_LOCAL/usr" "$STAGE_LOCAL/www" "$REMOTE:$REMOTE_STAGE/"

  echo "[3/4] Install files on target"
  run_ssh "cp '$REMOTE_STAGE/etc/init.d/heizungpanel' /etc/init.d/heizungpanel && \
    $CONFIG_COPY_CMD && \
    mkdir -p /usr/libexec/heizungpanel /usr/share/rpcd/acl.d /usr/share/luci/menu.d /www/luci-static/resources/view/heizungpanel /www/cgi-bin && \
    cp '$REMOTE_STAGE'/usr/libexec/heizungpanel/* /usr/libexec/heizungpanel/ && \
    cp '$REMOTE_STAGE/usr/share/rpcd/acl.d/luci-app-heizungpanel.json' /usr/share/rpcd/acl.d/luci-app-heizungpanel.json && \
    cp '$REMOTE_STAGE/usr/share/luci-app-heizungpanel.json' /usr/share/luci-app-heizungpanel.json && \
    cp '$REMOTE_STAGE/usr/share/luci/menu.d/luci-app-heizungpanel.json' /usr/share/luci/menu.d/luci-app-heizungpanel.json && \
    cp '$REMOTE_STAGE/www/luci-static/resources/view/heizungpanel/panel.js' /www/luci-static/resources/view/heizungpanel/panel.js && \
    cp '$REMOTE_STAGE/www/luci-static/resources/view/heizungpanel/config.js' /www/luci-static/resources/view/heizungpanel/config.js && \
    cp '$REMOTE_STAGE/www/cgi-bin/heizungpanel_stream' /www/cgi-bin/heizungpanel_stream && \
    chmod 755 /etc/init.d/heizungpanel /usr/libexec/heizungpanel/*.sh /www/cgi-bin/heizungpanel_stream"

  if [ "$NO_RESTART" -eq 0 ]; then
    echo "[4/4] Reload services"
    run_ssh "/etc/init.d/rpcd reload >/dev/null 2>&1 || true; \
      /etc/init.d/uhttpd reload >/dev/null 2>&1 || true; \
      rm -rf /tmp/luci-indexcache /tmp/luci-modulecache >/dev/null 2>&1 || true; \
      /etc/init.d/heizungpanel enable >/dev/null 2>&1 || true; \
      CAN_SETUP=\$(uci -q get heizungpanel.main.can_setup || echo 1); \
      CAN_IF=\$(uci -q get heizungpanel.main.can_if || echo can0); \
      if [ \"\$CAN_SETUP\" = \"1\" ] && ! echo \"\$CAN_IF\" | grep -Eq '^(can|vcan|slcan)'; then \
        echo 'WARNING: Skip heizungpanel restart (unsafe can_if='\$CAN_IF')' >&2; \
      else \
        /etc/init.d/heizungpanel stop >/dev/null 2>&1 || true; \
        /etc/init.d/heizungpanel start; \
      fi"
  else
    echo "[4/4] Skipping restart (--no-restart set)"
  fi

  echo "Install completed on $REMOTE"
}

run_uninstall() {
  require_cmd ssh

  setup_mux
  echo "[1/2] Remove files from target"
  run_ssh "rm -f /etc/init.d/heizungpanel \
    /etc/config/heizungpanel \
    /usr/share/rpcd/acl.d/luci-app-heizungpanel.json \
    /usr/share/luci-app-heizungpanel.json \
    /usr/share/luci/menu.d/luci-app-heizungpanel.json \
    /www/luci-static/resources/view/heizungpanel/panel.js \
    /www/luci-static/resources/view/heizungpanel/config.js \
    /www/cgi-bin/heizungpanel_stream && \
    rm -rf /usr/libexec/heizungpanel"

  if [ "$NO_RESTART" -eq 0 ]; then
    echo "[2/2] Stop/reload services"
    run_ssh "/etc/init.d/heizungpanel stop >/dev/null 2>&1 || true; /etc/init.d/heizungpanel disable >/dev/null 2>&1 || true; /etc/init.d/rpcd reload >/dev/null 2>&1 || true; /etc/init.d/uhttpd reload >/dev/null 2>&1 || true"
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
      require_opt_value "$1" "${2:-}"
      SSH_PORT="$2"
      shift 2
      ;;
    -i|--identity)
      require_opt_value "$1" "${2:-}"
      SSH_KEY="$2"
      shift 2
      ;;
    -s|--stage)
      require_opt_value "$1" "${2:-}"
      REMOTE_STAGE="$2"
      shift 2
      ;;
    --no-restart)
      NO_RESTART=1
      shift
      ;;
    --overwrite-config)
      OVERWRITE_CONFIG=1
      shift
      ;;
    --no-mux)
      USE_MUX=0
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
