#!/bin/sh
# session-mode.sh — SessionStart hook: announce the mode
# (mode.sh) that guard-mode.sh enforces, so the session starts
# in it instead of finding out from a denied call. In development
# it also puts the shim (shim.sh) in front of the tools that reach
# a server.

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

# The shim (shim.sh) goes first on the PATH of every later Bash
# call, subagents' included: Claude Code sources $CLAUDE_ENV_FILE
# before each one. The file survives resume and compaction, where
# this hook runs again, so what it writes is written once and
# would do nothing twice. It lives in the checkout because it is
# code: versioned and reviewed with the guard, never a stale copy
# in a cache that another checkout wrote.
#
# git push over SSH runs GIT_SSH_COMMAND, and a bare ssh there
# would find the shim: git-ssh.sh takes its place and runs what
# the user set, kept in HOSTWARDEN_GIT_SSH_COMMAND. GIT_SSH, a
# program of the user's own, stays theirs.
SHIM="$ROOT/.claude/hooks/shim"
# q <string> — single-quoted for the shell that sources the file.
q() { printf "'%s'" "$(printf '%s' "$1" | sed "s/'/'\\\\''/g")"; }
if [ -z "${CLAUDE_ENV_FILE:-}" ]; then
  echo "  Claude Code gave this hook no CLAUDE_ENV_FILE, so the"
  echo "  shim that refuses ssh and sudo however they are started"
  echo "  is not in place; only the guard's reading of each"
  echo "  command stands in for it."
elif ! grep -qF "$SHIM" "$CLAUDE_ENV_FILE" 2>/dev/null; then
  {
    echo "case \":\$PATH:\" in *:$(q "$SHIM"):*) ;; *) export PATH=$(q "$SHIM"):\"\$PATH\" ;; esac"
    if [ -z "${GIT_SSH:-}" ]; then
      [ -n "${GIT_SSH_COMMAND:-}" ] &&
        echo "export HOSTWARDEN_GIT_SSH_COMMAND=$(q "$GIT_SSH_COMMAND")"
      echo "export GIT_SSH_COMMAND=$(q "$(q "$ROOT/.claude/hooks/git-ssh.sh")")"
    fi
  } >> "$CLAUDE_ENV_FILE"
fi

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
