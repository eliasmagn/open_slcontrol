#!/bin/sh
set -eu

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
REPO_ROOT="$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)"

REMOTE=""
SSH_PORT="22"
SSH_KEY=""
REMOTE_STAGE_PREFIX="/tmp/open_slcontrol_deploy"
REMOTE_STAGE=""
REMOTE_STAGE_ACTIVE=0
ACTION=""
NO_RESTART=0
OVERWRITE_CONFIG=0
PURGE_CONFIG=0
USE_MUX=1
STAGE_LOCAL=""
MUX_DIR=""
MUX_ACTIVE=0
MUX_CONTROL_PATH=""

cleanup_remote_stage() {
  if [ "$REMOTE_STAGE_ACTIVE" -eq 0 ]; then
    return 0
  fi

  if run_ssh "rm -rf '$REMOTE_STAGE'"; then
    REMOTE_STAGE_ACTIVE=0
    return 0
  fi
  return 1
}

cleanup() {
  cleanup_status="$1"
  trap - EXIT HUP INT TERM
  set +e
  cleanup_remote_stage
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
  exit "$cleanup_status"
}

trap 'cleanup $?' EXIT
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM

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
  -s, --stage <path>     Safe /tmp staging prefix (default: /tmp/open_slcontrol_deploy)
      --no-mux           Disable SSH connection multiplexing (prompts password each call)
      --no-restart       Do not restart the service after install
      --overwrite-config Always overwrite /etc/config/heizungpanel on install
      --purge-config     Remove /etc/config/heizungpanel on uninstall
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

argument_error() {
  echo "$1" >&2
  usage >&2
  exit 1
}

validate_remote() {
  case "$REMOTE" in
    ""|-*|*@*@*|*[!A-Za-z0-9_.@-]*)
      argument_error "Invalid SSH destination: $REMOTE"
      ;;
  esac

  case "$REMOTE" in
    *@*)
      validation_user=${REMOTE%%@*}
      validation_host=${REMOTE#*@}
      [ -n "$validation_user" ] || argument_error "Invalid SSH destination: $REMOTE"
      ;;
    *)
      validation_host=$REMOTE
      ;;
  esac

  case "$validation_host" in
    ""|[-.]*|*[-.]|*[!A-Za-z0-9.-]*)
      argument_error "Invalid SSH destination: $REMOTE"
      ;;
  esac
}

validate_port() {
  case "$SSH_PORT" in
    ""|*[!0-9]*)
      argument_error "Invalid SSH port: $SSH_PORT"
      ;;
  esac
  if [ "${#SSH_PORT}" -gt 5 ] || [ "$SSH_PORT" -lt 1 ] || [ "$SSH_PORT" -gt 65535 ]; then
    argument_error "Invalid SSH port: $SSH_PORT"
  fi
}

validate_stage_prefix() {
  case "$REMOTE_STAGE_PREFIX" in
    /tmp/*)
      validation_stage_name=${REMOTE_STAGE_PREFIX#/tmp/}
      ;;
    *)
      argument_error "Invalid remote stage prefix: $REMOTE_STAGE_PREFIX"
      ;;
  esac

  case "$validation_stage_name" in
    ""|[!A-Za-z0-9]*|*[!A-Za-z0-9._-]*)
      argument_error "Invalid remote stage prefix: $REMOTE_STAGE_PREFIX"
      ;;
  esac
}

validate_arguments() {
  case "$ACTION" in
    install|push|uninstall|remove) ;;
    *) argument_error "Unknown action: $ACTION" ;;
  esac

  validate_remote
  validate_port
  validate_stage_prefix

  case "$ACTION" in
    uninstall|remove)
      if [ "$NO_RESTART" -eq 1 ]; then
        argument_error "--no-restart is not compatible with uninstall"
      fi
      ;;
    install|push)
      if [ "$PURGE_CONFIG" -eq 1 ]; then
        argument_error "--purge-config is only valid with uninstall"
      fi
      ;;
  esac
}

validate_remote_stage() {
  case "$1" in
    "$REMOTE_STAGE_PREFIX".[A-Za-z0-9][A-Za-z0-9][A-Za-z0-9][A-Za-z0-9][A-Za-z0-9][A-Za-z0-9])
      return 0
      ;;
    *)
      echo "Unsafe remote stage returned by mktemp: $1" >&2
      return 1
      ;;
  esac
}

installed_files() {
  cat <<'EOF'
etc/init.d/heizungpanel
etc/config/heizungpanel
usr/libexec/heizungpanel/raw_bridge.sh
usr/libexec/heizungpanel/alarm_watchdog.sh
usr/libexec/heizungpanel/telegram_json.uc
usr/libexec/heizungpanel/press.sh
usr/libexec/heizungpanel/config.sh
usr/libexec/heizungpanel/config_get.sh
usr/libexec/heizungpanel/config_set.sh
usr/libexec/heizungpanel/set_mode.sh
usr/libexec/heizungpanel/ha_bridge.sh
usr/share/rpcd/acl.d/luci-app-heizungpanel.json
usr/share/luci/menu.d/luci-app-heizungpanel.json
www/luci-static/resources/view/heizungpanel/panel.js
www/luci-static/resources/view/heizungpanel/config.js
www/cgi-bin/heizungpanel_stream
EOF
}

create_stage_tree() {
  STAGE_LOCAL="$(mktemp -d)"
  FILES="$(installed_files)"

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

  create_stage_tree
  setup_mux

  echo "[1/4] Create remote stage from prefix: $REMOTE_STAGE_PREFIX"
  REMOTE_STAGE="$(run_ssh "mktemp -d '${REMOTE_STAGE_PREFIX}.XXXXXX'")"
  validate_remote_stage "$REMOTE_STAGE"
  REMOTE_STAGE_ACTIVE=1

  if [ "$OVERWRITE_CONFIG" -eq 1 ]; then
    CONFIG_COPY_CMD="cp '$REMOTE_STAGE/etc/config/heizungpanel' /etc/config/heizungpanel"
  else
    CONFIG_COPY_CMD="{ [ -f /etc/config/heizungpanel ] || cp '$REMOTE_STAGE/etc/config/heizungpanel' /etc/config/heizungpanel; }"
  fi

  echo "[2/4] Upload files via scp"
  run_scp -r "$STAGE_LOCAL/etc" "$STAGE_LOCAL/usr" "$STAGE_LOCAL/www" "$REMOTE:$REMOTE_STAGE/"

  echo "[3/4] Install files on target"
  INSTALL_CMD="command -v cmp >/dev/null && $CONFIG_COPY_CMD && chmod 600 /etc/config/heizungpanel && "
  for rel in $FILES; do
    [ "$rel" = "etc/config/heizungpanel" ] && continue
    case "$rel" in
      etc/init.d/*|usr/libexec/heizungpanel/*.sh|www/cgi-bin/*) mode=755 ;;
      *) mode=644 ;;
    esac
    INSTALL_CMD="${INSTALL_CMD}mkdir -p '/$(dirname "$rel")' && cp '$REMOTE_STAGE/$rel' '/$rel' && chmod $mode '/$rel' && cmp -s '$REMOTE_STAGE/$rel' '/$rel' && "
  done
  run_ssh "${INSTALL_CMD}:"
  cleanup_remote_stage

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
  echo "[1/3] Stop and disable service"
  run_ssh "if [ -x /etc/init.d/heizungpanel ]; then \
      /etc/init.d/heizungpanel stop && \
      /etc/init.d/heizungpanel disable; \
    fi"

  echo "[2/3] Remove files from target"
  REMOVE_CMD=""
  for rel in $(installed_files); do
    if [ "$rel" = "etc/config/heizungpanel" ] && [ "$PURGE_CONFIG" -eq 0 ]; then
      continue
    fi
    REMOVE_CMD="${REMOVE_CMD}rm -f '/$rel' && "
  done
  run_ssh "${REMOVE_CMD}{ rmdir /usr/libexec/heizungpanel 2>/dev/null || true; }"

  echo "[3/3] Reload services"
  run_ssh "/etc/init.d/rpcd reload >/dev/null 2>&1 || true; /etc/init.d/uhttpd reload >/dev/null 2>&1 || true"

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
      REMOTE_STAGE_PREFIX="$2"
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
    --purge-config)
      PURGE_CONFIG=1
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

validate_arguments

case "$ACTION" in
  install|push)
    run_install
    ;;
  uninstall|remove)
    run_uninstall
    ;;
esac
