# shellcheck shell=sh
# Local agent selection. Never source user.md or evaluate its values.
# Callers set HW_AGENT_ROOT; --host selects the SSH configuration context.
# No host means the neutral hostwarden-agent.invalid, not a guessed server.
hw_agent_error() { echo "hostwarden: $*" >&2; return 1; }

hw_agent_saved() {
  HW_AGENT_SAVED=
  [ ! -L "$HW_AGENT_ROOT/memory/user.md" ] || {
    hw_agent_error 'memory/user.md is a link; agent selection refused'; return 1;
  }
  [ -f "$HW_AGENT_ROOT/memory/user.md" ] || return 0
  HW_AGENT_SAVED=$(awk '
    /^SSH agent socket:/ {
      n++; sub(/^SSH agent socket:[ \t]*/, ""); value=$0
    }
    END { if (n > 1 || (n == 1 && value == "")) exit 1; print value }
  ' "$HW_AGENT_ROOT/memory/user.md") || {
    hw_agent_error 'write one nonempty SSH agent socket: line in memory/user.md'
    return 1
  }
}

hw_agent_path() {
  # shellcheck disable=SC2088 # match a literal tilde; expand it explicitly
  case "$HW_AGENT_SOCKET" in
    none|'') HW_AGENT_SOCKET=; return 0 ;;
    SSH_AUTH_SOCK|'$SSH_AUTH_SOCK') HW_AGENT_SOCKET=${SSH_AUTH_SOCK:-} ;;
    '~/'*) HW_AGENT_SOCKET=$HOME/${HW_AGENT_SOCKET#\~/} ;;
  esac
  case "$HW_AGENT_SOCKET" in
    '') return 0 ;;
    *\"*|*\$*|*%*|*\\*|*'`'*|*'
'*|*"$(printf '\r')"*)
      hw_agent_error 'agent socket contains unsupported tokens or characters'
      return 1 ;;
    /*) ;;
    *) hw_agent_error 'agent socket must be absolute or start with ~/'; return 1 ;;
  esac
}

# shellcheck disable=SC2034 # query status is read by hostwarden-sync
hw_agent_resolve() {
  HW_AGENT_QUERY_FAILED=0
  hw_agent_saved || return 1
  HW_AGENT_SOCKET=$HW_AGENT_SAVED
  if [ -z "$HW_AGENT_SOCKET" ]; then
    case "${1:-hostwarden-agent.invalid}" in
      -*|'') hw_agent_error 'invalid agent configuration host'; return 1 ;;
    esac
    HW_AGENT_CONFIG=$(LC_ALL=C ssh -G "${1:-hostwarden-agent.invalid}") \
      || {
        HW_AGENT_QUERY_FAILED=1
        hw_agent_error 'cannot evaluate local SSH configuration'; return 1;
      }
    HW_AGENT_SOCKET=$(printf '%s\n' "$HW_AGENT_CONFIG" |
      sed -n 's/^identityagent //p')
    [ -n "$HW_AGENT_SOCKET" ] || HW_AGENT_SOCKET=${SSH_AUTH_SOCK:-}
  fi
  hw_agent_path
}

hw_agent_ready() {
  [ -n "$HW_AGENT_SOCKET" ] && [ -S "$HW_AGENT_SOCKET" ] || {
    hw_agent_error 'selected agent socket is missing or disabled; no fallback'
    return 1
  }
  # Suppress public keys and diagnostics; a locked or empty agent may return 1.
  if ! SSH_AUTH_SOCK=$HW_AGENT_SOCKET LC_ALL=C ssh-add -l >/dev/null 2>&1; then
    hw_agent_error 'selected agent unavailable, locked or has no identities; unlock it and retry'
    return 1
  fi
}
