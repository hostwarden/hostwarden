#!/bin/sh
# check-session.sh — SessionStart hook: say what makes this session
# unlike an ordinary one, before anything reaches a machine. Silent
# when neither applies.
#
# 1. A linked git worktree, which the desktop app can make the
#    default. rules/access-control.md → Linked Worktrees says why
#    hostwarden refuses to administer anything from one; this hook
#    only makes sure the agent knows it is in one.
# 2. The taboo guard switched off. Only a session that STARTS with
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

ROOT=$(cd "$(dirname "$0")/../.." && pwd)
INPUT=$(cat)

field() {
  printf '%s' "$INPUT" \
    | sed -n "s/.*\"$1\"[[:blank:]]*:[[:blank:]]*\"\([A-Za-z0-9_-]*\)\".*/\1/p" \
    | head -1
}

# A linked worktree's .git is a file ("gitdir: <path>"), and the
# directory it names holds a `commondir` file pointing at the shared
# git directory. A submodule has a .git file too, but its git
# directory has no commondir. `cd` resolves absolute, relative and
# drive-letter paths alike; no git call needed.
GITDIR=""
if [ -f "$ROOT/.git" ]; then
  G=$(sed -n 's|^gitdir: ||p' "$ROOT/.git")
  GITDIR=$(cd "$ROOT" && cd "$G" 2>/dev/null && pwd)
fi
if [ -n "$GITDIR" ] && [ -f "$GITDIR/commondir" ]; then
  COMMON=$(cd "$GITDIR" && cd "$(sed -n 1p commondir)" 2>/dev/null && pwd)
  case "$COMMON" in
    */.git) MAIN="${COMMON%/.git}" ;;
    *) MAIN="the checkout that shares ${COMMON:-its git directory}" ;;
  esac
  echo "hostwarden: this session runs in a linked git worktree, not in"
  echo "  $MAIN. Do not reach any machine from it:"
  echo "  rules/access-control.md -> Linked Worktrees."
fi

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
