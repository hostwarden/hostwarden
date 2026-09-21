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

# A linked worktree's .git is a file ("gitdir: <main>/.git/
# worktrees/<name>"), not a directory. No git call needed. A
# submodule has a .git file too, pointing into .git/modules/, so
# only a gitdir under .git/worktrees/ counts. The main checkout is
# named when git wrote an absolute path; a relative one
# (worktree.useRelativePaths) the rule derives itself.
MAIN=""
[ -f "$ROOT/.git" ] &&
  MAIN=$(sed -n 's|^gitdir: \(.*\)/\.git/worktrees/[^/]*$|\1|p' "$ROOT/.git")
if [ -n "$MAIN" ]; then
  case "$MAIN" in /*) ;; *) MAIN="the main checkout" ;; esac
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
