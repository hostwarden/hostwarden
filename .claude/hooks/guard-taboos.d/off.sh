# guard-taboos.d/off.sh — the operator's off switch, scoped to the
# one host it names. Sourced by guard-taboos.sh, after reach.sh, in
# the order its GUARD_MODULES lists, into the one shell every module
# shares; never run on its own.
# shellcheck shell=sh disable=SC2034 # GUARD_OFF_NOTE is read by deny
#
# HOSTWARDEN_GUARD_DISABLE holds a hostname, or `localhost` for
# local mode (hostwarden_off_host, lib/mode.sh). It counts only
# where check-session.sh recorded that same host at SessionStart
# (~/.cache/hostwarden/guard-off-<id>): a value that arrives or
# changes mid-session finds no record of itself, and `1` or a list
# is never recorded.
#
# Where it counts, the command is cut down to what is not aimed at
# that host (hostwarden_coord_rest, lib/coord-rest.sh), and the
# modules after this one judge the rest as they judge any command:
#
#   - an ssh or sftp segment whose destination is the host, as
#     written or as hostwarden_coord_canon knows it, goes, and its
#     local redirections stay; one whose remote command reaches on
#     from the host — another ssh, an ssh:// URL, a host option
#     (-H, --host, -M, --machine), a UNC host, another Proxmox
#     node's /nodes/ path, or a command
#     OFF_REACH names: REMOTE (reach.sh), its guest managers and
#     the configuration-management tools — or whose redirection
#     target is quoted, stays whole;
#   - with `localhost`, a segment with no destination that
#     OFF_REACH does not match goes too, and so does an Edit, Write,
#     MultiEdit or
#     NotebookEdit call. No ssh segment goes, not even one to a
#     loopback address, which with a port is a guest's; and a
#     loopback destination never counts as a hostname's;
#   - everything else stays: another host's segment, an scp or
#     rsync, a destination the reader cannot see (a variable, a
#     script, a via-host guest), and, for a hostname, every local
#     command and every edit.
#
# Nothing left, the call passes. Without jq, or without the
# libraries, nothing is cut and the guard judges the whole command.
# The reader's limits are the accepted gap of
# docs/adr/20260924-guard-is-a-backstop-not-a-sandbox.md.

GUARD_OFF=""
if [ -n "${HOSTWARDEN_GUARD_DISABLE:-}" ] && [ -f "$LIBDIR/mode.sh" ]; then
  # shellcheck source=../../../lib/mode.sh
  . "$LIBDIR/mode.sh"
  GUARD_OFF=$(hostwarden_off_recorded "$(hook_session_id)" \
    "$HOSTWARDEN_GUARD_DISABLE") || GUARD_OFF=""
fi

if [ -n "$GUARD_OFF" ]; then
  GUARD_OFF_NOTE="The guard is off toward $GUARD_OFF only, and this \
part of the command is not aimed at it. "
  case "$INPUT" in
  *'"file_path"'*|*'"notebook_path"'*)
    [ "$GUARD_OFF" = localhost ] && exit 0 ;;
  *)
    if command -v jq >/dev/null 2>&1 &&
      [ -f "$LIBDIR/coord-tokenize.sh" ] &&
      [ -f "$LIBDIR/coord-lib.sh" ] &&
      [ -f "$LIBDIR/coord-rest.sh" ]; then
      # shellcheck source=../../../lib/coord-tokenize.sh
      . "$LIBDIR/coord-tokenize.sh"
      # shellcheck source=../../../lib/coord-lib.sh
      . "$LIBDIR/coord-lib.sh"
      # shellcheck source=../../../lib/coord-rest.sh
      . "$LIBDIR/coord-rest.sh"
      OFF_CMD=$(printf '%s' "$INPUT" |
        jq -r '.tool_input.command // empty' 2>/dev/null)
      OFF_LOOP='localhost 127.0.0.1 ::1'
      # What reaches past a host: REMOTE, the tools that push to
      # other machines, a host option, a UNC host, a Proxmox node
      # path, and any Windows program (WSL runs it on the Windows
      # host, never this machine).
      OFF_REACH="$REMOTE"'|(^|[^[:alnum:]_.-])(ansible[[:alnum:]-]*|terraform|tofu|salt[[:alnum:]-]*|pdsh|clush|pssh|parallel-ssh|dsh|parallel)([^[:alnum:]_.-]|$)|[[:space:]](-[[:alpha:]]*[HM]|--host|--machine)([[:space:]=]|$)|[[:space:]]\\\\[[:alnum:]]|pvesh[^;&|]*/nodes/|[[:alnum:]_-]\.exe([^[:alnum:]_.-]|$)'
      OFF_LOCAL=0
      if [ "$GUARD_OFF" = localhost ]; then
        OFF_LOCAL=1
        # No ssh call is this machine's: local mode runs none, and a
        # loopback address with a port is a guest's (AGENTS.md →
        # Local mode).
        OFF_NAMES=""
      else
        OFF_NAMES=$GUARD_OFF
        # Only an ssh or sftp segment is ever dropped as the host's,
        # so only a command naming one needs its aliases resolved.
        case "$OFF_CMD" in *ssh*|*sftp*)
          # cd && pwd, no -P: the string presence.sh hashes for the
          # cache directory that holds the radius index.
          OFF_ROOT=$(cd "$HOOKDIR/../.." 2>/dev/null && pwd)
          hostwarden_cache_dir "$OFF_ROOT"
          OFF_IDX=$HOSTWARDEN_CACHE/radius.idx
          OFF_WANT=$(hostwarden_coord_canon "$OFF_IDX" "$GUARD_OFF" "$OFF_ROOT")
          for OFF_D in $(hostwarden_coord_dest "$OFF_CMD" | cut -f1 | sort -u); do
            case " $OFF_LOOP " in *" $OFF_D "*) continue ;; esac
            [ "$(hostwarden_coord_canon "$OFF_IDX" "$OFF_D" "$OFF_ROOT")" = \
              "$OFF_WANT" ] && OFF_NAMES="$OFF_NAMES $OFF_D"
          done ;;
        esac
      fi
      if [ -n "$OFF_CMD" ]; then
        OFF_REST=$(hostwarden_coord_rest "$OFF_CMD" "$OFF_NAMES" \
          "$OFF_REACH" "$OFF_LOCAL") || OFF_REST=$OFF_CMD
        case "$OFF_REST" in *[![:space:]]*) ;; *) exit 0 ;; esac
        OFF_INPUT=$(printf '%s' "$INPUT" | jq -c --arg c "$OFF_REST" \
          '.tool_input.command = $c' 2>/dev/null) && INPUT=$OFF_INPUT
      fi
    fi ;;
  esac
fi
