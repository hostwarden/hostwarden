#!/bin/sh
# session-mode.sh — SessionStart hook: announce the mode
# (mode.sh) that guard-mode.sh enforces, so the session starts
# in it instead of finding out from a denied call.

ROOT="$(cd "${0%/*}/../.." && pwd -P)"
# shellcheck source=mode.sh
. "$ROOT/.claude/hooks/mode.sh"
cd "$ROOT" || exit 0

CANON=jpawlowski/hostwarden

hostwarden_mode "$ROOT"
case "$HOSTWARDEN_MODE" in
operations)
  echo "hostwarden: operations checkout — memory/ is the workspace."
  echo "  Server work as usual. hostwarden's own files are read-only"
  echo "  here: a change to them goes to a development checkout and"
  echo "  a pull request."
  exit 0
  ;;
worktree)
  echo "hostwarden: linked worktree — development mode. This session"
  echo "  changes hostwarden itself and reaches no server: a worktree"
  echo "  never carries memory/, so the access lists and the server"
  echo "  memory are not here. Server work runs only in the main"
  echo "  checkout${HOSTWARDEN_MAIN:+ ($HOSTWARDEN_MAIN)}, and only if that is an"
  echo "  operations install."
  ;;
*)
  echo "hostwarden: development checkout — this session changes"
  echo "  hostwarden itself and reaches no server, this machine"
  echo "  included. Changes go through a branch and a pull request."
  echo "  Server work needs an operations checkout: a separate clone,"
  echo "  set up once with bin/hostwarden-init."
  ;;
esac

# Where a pull request goes. Compared by URL, never by remote
# name: in the maintainer's checkout `upstream` is heinzel, in a
# contributor's fork it is this project.
# Credentials in the URL (a user and token before the host)
# never reach the transcript: the user part goes for every host.
ORIGIN=$(git remote get-url origin 2>/dev/null |
  sed -E 's#^([a-z+]+://)[^@/]*@#\1#
    s#^(https?://|ssh://)?([^@/]*@)?github\.com[:/]##; s#\.git$##')
if [ -n "$ORIGIN" ] && [ "$ORIGIN" != "$CANON" ]; then
  echo "  origin is $ORIGIN, not $CANON: pull requests go from"
  echo "  there to $CANON."
fi

exit 0
