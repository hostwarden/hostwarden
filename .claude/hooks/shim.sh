#!/bin/sh
# shim.sh — stands in for every tool that reaches a server, in a
# development session. .claude/hooks/shim/ holds one link to this
# file per tool — ssh, scp, sftp, mosh, sudo, sudoedit, doas,
# pkexec — and session-mode.sh puts that directory first on the
# PATH of every Bash call through $CLAUDE_ENV_FILE. Subagents
# inherit it.
#
# Why a shim and not only a parser: a tool is found through PATH
# wherever it is started from — bash -c, eval, xargs, find -exec,
# make, git -c core.sshCommand, a script, rsync's own ssh — and no
# reading of the command line covers all of those. What the shim
# cannot see, a path to the real binary or command -p, is left to
# guard-mode.sh.
#
# git push keeps working: GIT_SSH_COMMAND names the real binary,
# which session-mode.sh finds on PATH, skipping the shim.
#
# The refusal is the guard's (hostwarden_refusal in mode.sh), on
# stderr with exit status 1, because a shim cannot return a
# PreToolUse decision.
#
# Being blocked is EXPECTED behavior. Explain it to the user.
# Never call the real binary by its path or change PATH to evade
# the shim.

# $0 is the link in shim/, whose directory sits in .claude/hooks/.
ROOT=${0%/*}/../../..
# shellcheck source=mode.sh
. "$ROOT/.claude/hooks/mode.sh"
hostwarden_mode "$ROOT"
hostwarden_refusal "${0##*/}"
printf 'hostwarden mode guard: %s (AGENTS.md - Development or Operations). Explain this to the user; do not call the real binary by its path or change PATH to evade the guard.\n' \
  "$HOSTWARDEN_REFUSAL" >&2
exit 1
