#!/bin/sh
# session-mode.sh — SessionStart hook: announce the mode
# (mode.sh) that guard-mode.sh enforces, so the session starts
# in it instead of finding out from a denied call. In development
# it also puts the shim (shim.sh) in front of the tools that reach
# a server. In operations it also gives every later Bash call this
# session's own id, for presence.sh and bin/hostwarden-impact
# (rules/coordination.md → Presence map).

ROOT="$(cd "${0%/*}/../.." && pwd -P)"
# shellcheck source=mode.sh
. "$ROOT/.claude/hooks/mode.sh"
# shellcheck source=json.sh
. "$ROOT/.claude/hooks/json.sh"
cd "$ROOT" || exit 0

# shellcheck disable=SC2034 # read by hook_field in json.sh
INPUT=$(cat)
SID=$(hook_session_id)

CANON=hostwarden/hostwarden
# q <string> — single-quoted for the shell that sources the env file.
q() { printf "'%s'" "$(printf '%s' "$1" | sed "s/'/'\\\\''/g")"; }

hostwarden_mode "$ROOT"
case "$HOSTWARDEN_MODE" in
operations)
  echo "hostwarden: operations checkout — memory/ is the workspace."
  echo "  Server work as usual. Hostwarden's own files are read-only"
  echo "  here: a change to them goes to a development checkout and"
  echo "  a pull request."
  # Started from inside a development session, this one inherits
  # its shim and git-ssh.sh, which would refuse the server work
  # this checkout is for. Every Bash call drops them again.
  case ":$PATH:${GIT_SSH_COMMAND:-}" in
  */.claude/hooks/shim:* | *git-ssh.sh*)
    if [ -n "${CLAUDE_ENV_FILE:-}" ]; then
      {
        printf '%s\n' 'PATH=$(printf %s "$PATH" | tr : "\n" | grep -v "/\.claude/hooks/shim$" | paste -sd: -); export PATH'
        case "${GIT_SSH_COMMAND:-}" in
        *git-ssh.sh*)
          if [ -n "${HOSTWARDEN_GIT_SSH_COMMAND:-}" ]; then
            echo "export GIT_SSH_COMMAND=$(q "$HOSTWARDEN_GIT_SSH_COMMAND")"
          else
            echo "unset GIT_SSH_COMMAND"
          fi
          ;;
        esac
        echo "unset HOSTWARDEN_GIT_SSH_COMMAND"
      } >> "$CLAUDE_ENV_FILE"
    fi
    ;;
  esac
  # HOSTWARDEN_SESSION carries this session's id into every Bash
  # call, so `bin/hostwarden-impact announce`, `ack` and `done`
  # write it into the entries they make, the same id presence.sh
  # reads from each hook call. Written once: a second SessionStart
  # (resume, compaction) finds the line already there. A tool that
  # gives this hook no CLAUDE_ENV_FILE, or no session id, leaves
  # HOSTWARDEN_SESSION unset; those commands then fall back to a
  # session id of their own that correlates with nothing
  # (rules/coordination.md → Announce, wait, go).
  if [ -n "${CLAUDE_ENV_FILE:-}" ] && [ -n "$SID" ] \
     && ! grep -qF 'export HOSTWARDEN_SESSION=' "$CLAUDE_ENV_FILE" 2>/dev/null
  then
    echo "export HOSTWARDEN_SESSION=$(q "$SID")" >> "$CLAUDE_ENV_FILE"
  fi
  exit 0
  ;;
worktree)
  echo "hostwarden: linked worktree — development mode. This session"
  echo "  changes Hostwarden itself and reaches no server: a worktree"
  echo "  never carries memory/, so the access lists and the server"
  echo "  memory are not here."
  ;;
*)
  echo "hostwarden: development checkout — this session changes"
  echo "  Hostwarden itself and reaches no server, this machine"
  echo "  included. Changes go through a branch and a pull request."
  ;;
esac
hostwarden_next_step
echo "  A question only a live server answers: $HOSTWARDEN_NEXT_STEP."
# Operations never gets here: it has servers to try a command on.
echo "  To try a command instead of guessing its syntax:"
echo "  bin/hostwarden-lab exec <family> -- <command> runs it in a"
echo "  disposable container (debian, ubuntu, rhel, fedora, suse,"
echo "  alpine), neither a server nor local mode. A container cannot"
echo "  answer for systemd services, the firewall, kernel parameters,"
echo "  a reboot, the SSH pipeline, FreeBSD or macOS; for the Linux"
echo "  ones, bin/hostwarden-lab vm up gives a test clone a VM."

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
# the user set, kept in HOSTWARDEN_GIT_SSH_COMMAND. A GIT_SSH on
# its own, a program of the user's, stays theirs.
SHIM="$ROOT/.claude/hooks/shim"
if [ -z "${CLAUDE_ENV_FILE:-}" ]; then
  echo "  Claude Code gave this hook no CLAUDE_ENV_FILE, so the"
  echo "  shim that refuses ssh and sudo however they are started"
  echo "  is not in place; only the guard's reading of each"
  echo "  command stands in for it."
elif ! grep -qF "$SHIM" "$CLAUDE_ENV_FILE" 2>/dev/null; then
  {
    echo "case \":\$PATH:\" in *:$(q "$SHIM"):*) ;; *) export PATH=$(q "$SHIM"):\"\$PATH\" ;; esac"
    # What git would run: GIT_SSH_COMMAND outranks GIT_SSH. A
    # GIT_SSH named without a path goes through PATH and would find
    # the shim, so the wrapper carries it; one given by its path is
    # the user's own program and stays.
    U=${GIT_SSH_COMMAND:-${GIT_SSH:-}}
    case "${GIT_SSH_COMMAND:-}:$U" in
    :*/*) ;;
    *)
      # A session started from inside another inherits its
      # git-ssh.sh, which kept as the user's own would run itself.
      case "$U" in
      "" | *git-ssh.sh*) ;;
      *) echo "export HOSTWARDEN_GIT_SSH_COMMAND=$(q "$U")" ;;
      esac
      echo "export GIT_SSH_COMMAND=$(q "$(q "$ROOT/.claude/hooks/git-ssh.sh")")"
      ;;
    esac
  } >> "$CLAUDE_ENV_FILE"
fi

# Where a pull request goes. Compared by URL, never by remote
# name: in the maintainer's checkout `upstream` is Heinzel, in a
# contributor's fork it is this project.
# Credentials in the URL (a user and token before the host, or an
# access_token in the query) never reach the transcript: the user
# part, the query and the fragment go for every host.
ORIGIN=$(git remote get-url origin 2>/dev/null |
  sed -E 's#^([a-z+]+://)[^@/]*@#\1#; s|[?#].*$||
    s#^(https?://|ssh://)?([^@/]*@)?github\.com[:/]##; s#\.git$##')
if [ -n "$ORIGIN" ] && [ "$ORIGIN" != "$CANON" ]; then
  echo "  origin is $ORIGIN, not $CANON: pull requests go from"
  echo "  there to $CANON."
fi

exit 0
