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
#   operations   main checkout of a git clone, with a workspace.
#                Servers may be reached; hostwarden's own files
#                are read-only.
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
# file tests, with a process only inside a linked worktree — and
# it sets variables rather than printing, so the caller needs no
# subshell either.
#
# Expects nothing. Defines:
#   hostwarden_mode <root>  — sets HOSTWARDEN_MODE to one of the
#                             three answers, and HOSTWARDEN_MAIN to
#                             the main checkout of a worktree
#   hostwarden_refusal <tool>
#                           — sets HOSTWARDEN_REFUSAL to why <tool>
#                             is refused in development, so the
#                             guard and the shim say the same
#   hostwarden_git_batch    — sets up git to reach the workspace's
#                             remote without ever prompting

# shellcheck disable=SC2034 # read by whoever sources this file
hostwarden_mode() {
  HOSTWARDEN_MAIN=
  # A linked worktree's .git is a FILE ("gitdir: <path>"), and the
  # directory it names holds a `commondir` file pointing at the
  # shared git directory, whose parent is the main checkout. A
  # submodule has a .git file too, but no commondir: it is no
  # clone of its own, so it is development. Only this rare branch
  # starts a process (cd resolves relative and drive-letter paths).
  if [ -f "$1/.git" ]; then
    HOSTWARDEN_MODE=development
    read -r hm_git < "$1/.git"
    hm_git=$(cd "$1" && cd "${hm_git#gitdir: }" 2>/dev/null && pwd)
    if [ -n "$hm_git" ] && [ -f "$hm_git/commondir" ]; then
      read -r hm_common < "$hm_git/commondir"
      HOSTWARDEN_MAIN=$(cd "$hm_git" && cd "$hm_common/.." 2>/dev/null && pwd)
      HOSTWARDEN_MODE=worktree
    fi
  elif [ -d "$1/.git" ] && [ -f "$1/memory/.hostwarden-workspace" ]; then
    # A clone, not an archive copy: operations needs updates.
    HOSTWARDEN_MODE=operations
  else
    HOSTWARDEN_MODE=development
  fi
}

# Plain ASCII without quotes or backslashes: guard-mode.sh puts it
# into JSON as it is, so the one part it does not write itself,
# the main checkout's path, loses both. It names the next step,
# because a refusal that only stops leaves the developer to find
# the way to a live answer alone. Expects hostwarden_mode to have
# run.
# shellcheck disable=SC2034 # read by whoever sources this file
hostwarden_refusal() {
  if [ "$HOSTWARDEN_MODE" = worktree ]; then
    hr_main=$(printf '%s' "$HOSTWARDEN_MAIN" | tr -d '"\\')
    hr_why="this session runs in a linked git worktree. A worktree \
never carries memory/, so the access lists and the server memory are \
missing here. Next step: hand the check to an operations session in \
the main checkout, ${hr_main:-of this clone}, if that is an operations \
install"
  else
    hr_why="this checkout develops hostwarden (memory/ holds no \
workspace). Next step: hand the check to an operations session in a \
separate clone, set up once with bin/hostwarden-init"
  fi
  HOSTWARDEN_REFUSAL="hostwarden mode guard: $1 reaches a server, and \
$hr_why. How: rules/server-check-handoff.md (AGENTS.md - Development \
or Operations)."
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
  # Appended to a command the user set, not replaced by it: ssh
  # takes the first value it sees, so their own options still win,
  # and ours fill in what they left open.
  GIT_SSH_COMMAND="${GIT_SSH_COMMAND:-ssh} -o BatchMode=yes \
-o ConnectTimeout=5 -o ControlMaster=auto \
-o ControlPath=~/.cache/hostwarden/ssh-%C -o ControlPersist=10m \
-o ServerAliveInterval=15 -o ServerAliveCountMax=3"
  export GIT_TERMINAL_PROMPT GIT_SSH_COMMAND
}
