#!/bin/sh
# check-session.sh — SessionStart hook: say when the taboo guard is
# switched off for this session, before anything reaches a machine.
# Silent otherwise. (A linked worktree is announced by
# session-mode.sh, with the rest of the mode.)
#
# The taboo guard switched off. Only a session that STARTS with
#    HOSTWARDEN_GUARD_DISABLE=1 — from the shell, or a settings file
#    the operator edited before starting it — gets it: this hook
#    records that in ~/.cache/hostwarden/guard-off-<session_id>, and
#    guard-taboos.sh honours the variable only where the record
#    exists. A value that arrives mid-session, through a settings
#    file reloaded while it runs, finds no record and changes
#    nothing. Only `startup` and `resume` start a process with a
#    fresh environment; `clear` and `compact` run inside the old one
#    and may only take a record away. The notice at every start is
#    also how the operator sees that the setting took effect.

INPUT=$(cat)

field() {
  printf '%s' "$INPUT" \
    | sed -n "s/.*\"$1\"[[:blank:]]*:[[:blank:]]*\"\([A-Za-z0-9_-]*\)\".*/\1/p" \
    | head -1
}

CACHE="$HOME/.cache/hostwarden"
SID=$(field session_id)
REC="$CACHE/guard-off-$SID"
if [ "${HOSTWARDEN_GUARD_DISABLE:-}" = "1" ] && [ -n "$SID" ]; then
  case "$(field source)" in
    startup|resume|"")
      mkdir -p "$HOME/.cache" && { [ -d "$CACHE" ] || mkdir -m 700 "$CACHE"; } \
        && : > "$REC" ;;
  esac
fi
if [ -n "$SID" ] && [ -e "$REC" ]; then
  if [ "${HOSTWARDEN_GUARD_DISABLE:-}" = "1" ]; then
    echo "hostwarden: the taboo guard is OFF for this session. Say so in"
    echo "  your first reply; unless this session is for the disk steps of"
    echo "  an OS install, ask the user to remove it and start a new one."
  else
    rm -f "$REC"
  fi
elif [ "${HOSTWARDEN_GUARD_DISABLE:-}" = "1" ]; then
  echo "hostwarden: HOSTWARDEN_GUARD_DISABLE is set, but this session"
  echo "  did not start with it, so the taboo guard stays ON. Tell the"
  echo "  user: the operator sets it and then starts a new session."
fi

# Records of sessions long gone.
find "$CACHE" -name 'guard-off-*' -mtime +2 -exec rm -f {} + 2>/dev/null

exit 0
