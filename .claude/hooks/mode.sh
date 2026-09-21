# shellcheck shell=sh
# mode.sh — which of two jobs this checkout is doing, defined once.
#
# Sourced, never executed, so it carries no shebang and tells
# ShellCheck its dialect with the directive above instead.
#
# A checkout of hostwarden either DEVELOPS hostwarden or OPERATES
# servers with it, never both. The two look identical from
# outside: same origin, same main, same files. What tells them
# apart is the workspace — memory/ as a git repository of its
# own, created by bin/hostwarden-init and marked with
# memory/.hostwarden-workspace. The remote URL decides nothing:
# a fork is a development checkout for the same reason the
# maintainer's is, because neither has a workspace.
#
# Three answers:
#
#   operations   main checkout with a workspace. Servers may be
#                reached; hostwarden's own files are read-only.
#   development  main checkout without a workspace. hostwarden's
#                files may change; no server is reached, not even
#                this machine.
#   worktree     a linked git worktree, whatever it holds.
#                Treated as development. memory/ is gitignored,
#                so a worktree never carries the access lists or
#                the server memory of the checkout it came from,
#                and anything written there is lost when the
#                worktree is removed.
#
# Cheap on purpose: the guard asks on every tool call, so this is
# two file tests, never a process — and it sets a variable rather
# than printing, so the caller needs no subshell either.
#
# Expects nothing. Defines:
#   hostwarden_mode <root>  — sets HOSTWARDEN_MODE to one of the
#                             three answers
#   hostwarden_git_batch    — sets up git to reach the workspace's
#                             remote without ever prompting

# shellcheck disable=SC2034 # read by whoever sources this file
hostwarden_mode() {
  # A linked worktree has a .git FILE pointing at the common
  # directory; the main checkout has a .git directory.
  if [ -f "$1/.git" ]; then
    HOSTWARDEN_MODE=worktree
  elif [ -f "$1/memory/.hostwarden-workspace" ]; then
    HOSTWARDEN_MODE=operations
  else
    HOSTWARDEN_MODE=development
  fi
}

# The workspace's remote is reached by init --clone and by sync,
# often from a session-start hook. Never wait for a prompt there:
# not for a credential, not for a host key. An SSH remote gets the
# options AGENTS.md → SSH Options sets for every connection,
# keepalives included, so a dead link cannot hold the session.
hostwarden_git_batch() {
  GIT_TERMINAL_PROMPT=0
  # Only the socket directory needs 0700; ~/.cache keeps the umask.
  # shellcheck disable=SC2174
  mkdir -p -m 700 "$HOME/.cache/hostwarden"
  GIT_SSH_COMMAND=${GIT_SSH_COMMAND:-ssh -o BatchMode=yes -o ConnectTimeout=5 \
-o ControlMaster=auto -o ControlPath=~/.cache/hostwarden/ssh-%C \
-o ControlPersist=10m -o ServerAliveInterval=15 -o ServerAliveCountMax=3}
  export GIT_TERMINAL_PROMPT GIT_SSH_COMMAND
}
