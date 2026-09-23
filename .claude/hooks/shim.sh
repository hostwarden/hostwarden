# shellcheck shell=sh
# shim.sh — stands in for every tool that reaches a server, in a
# development session. .claude/hooks/shim/ holds one small script
# per tool, named after it, that sources this file, and
# session-mode.sh puts that directory first on the PATH of every
# Bash call through $CLAUDE_ENV_FILE. Subagents inherit it. Scripts
# rather than links, so a checkout without symbolic links gets a
# working shim too.
#
# Under WSL the Windows PATH is appended to the Linux one, so
# Windows programs are found by name as well; those that reach a
# server or administer the machine have a script in shim/ too. The
# drives under /mnt ignore case, so SSH.EXE finds the real binary;
# guard-mode.sh refuses every spelling but the one in shim/.
#
# Sourced, never executed, so it carries no shebang and tells
# ShellCheck its dialect with the directive above instead. $0 is
# the script in shim/.
#
# Why a shim and not only a parser: a tool is found through PATH
# wherever it is started from — bash -c, eval, xargs, find -exec,
# make, git -c core.sshCommand, a script, rsync's own ssh — and no
# reading of the command line covers all of those. What the shim
# cannot see, a path to the real binary or a changed PATH, is left
# to guard-mode.sh.
#
# git push keeps working: GIT_SSH_COMMAND is git-ssh.sh, which
# takes the shim off PATH before it starts the real command.
#
# The refusal is the guard's (hostwarden_refusal in mode.sh), on
# stderr with exit status 1, because a shim cannot return a
# PreToolUse decision.
#
# Being blocked is EXPECTED behavior. Explain it to the user.
# Never call the real binary by its path or change PATH to evade
# the shim.

ROOT=${0%/*}/../../..
# shellcheck source=mode.sh
. "$ROOT/.claude/hooks/mode.sh"
hostwarden_mode "$ROOT"
hostwarden_refusal "${0##*/}"
echo "$HOSTWARDEN_REFUSAL Explain this to the user; do not call the \
real binary by its path or change PATH to evade the guard." >&2
exit 1
