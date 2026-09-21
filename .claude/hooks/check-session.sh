#!/bin/sh
# check-session.sh — SessionStart hook: say what makes this session
# unlike an ordinary one, before anything reaches a machine. Silent
# when neither applies.
#
# 1. A linked git worktree, which the desktop app can make the
#    default. rules/access-control.md → Linked Worktrees says why
#    hostwarden refuses to administer anything from one; this hook
#    only makes sure the agent knows it is in one.
# 2. The taboo guard switched off. The danger is the session after
#    the OS install that needed it, where nobody remembers — and in
#    the desktop app the setting lives in a file that outlasts the
#    session. Saying it at every start is also how the operator sees
#    that the setting took effect.

ROOT=$(cd "$(dirname "$0")/../.." && pwd)

# A linked worktree's .git is a file ("gitdir: <path>"), and the
# directory it names holds a `commondir` file pointing at the shared
# git directory. A submodule has a .git file too, but its git
# directory has no commondir. Neither the name of the common
# directory (a separate --git-dir need not be called .git) nor an
# absolute gitdir (worktree.useRelativePaths) is assumed. No git
# call needed.
GITDIR=""
[ -f "$ROOT/.git" ] && GITDIR=$(sed -n 's|^gitdir: ||p' "$ROOT/.git")
case "$GITDIR" in
  ""|/*) ;;
  *) GITDIR="$ROOT/$GITDIR" ;;
esac
if [ -n "$GITDIR" ] && [ -f "$GITDIR/commondir" ]; then
  COMMON=$(sed -n 1p "$GITDIR/commondir")
  case "$COMMON" in /*) ;; *) COMMON="$GITDIR/$COMMON" ;; esac
  COMMON=$(cd "$COMMON" 2>/dev/null && pwd)
  case "$COMMON" in
    */.git) MAIN="${COMMON%/.git}" ;;
    *) MAIN="the checkout that shares ${COMMON:-its git directory}" ;;
  esac
  echo "hostwarden: this session runs in a linked git worktree, not in"
  echo "  $MAIN. Do not reach any machine from it:"
  echo "  rules/access-control.md -> Linked Worktrees."
fi

if [ "${HOSTWARDEN_GUARD_DISABLE:-}" = "1" ]; then
  echo "hostwarden: the taboo guard is OFF for this session. Say so in"
  echo "  your first reply; unless this session is for the disk steps of"
  echo "  an OS install, ask the user to remove it and start a new one."
fi

exit 0
