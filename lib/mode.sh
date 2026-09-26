# shellcheck shell=sh
# mode.sh — which of two jobs this checkout is doing, defined once.
#
# Sourced, never executed, so it carries no shebang and tells
# ShellCheck its dialect with the directive above instead.
#
# A checkout of Hostwarden either DEVELOPS Hostwarden or OPERATES
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
#                Servers may be reached; Hostwarden's own files
#                are read-only.
#   development  main checkout without a workspace. Hostwarden's
#                files may change; no server is reached, not even
#                this machine.
#   worktree     a linked git worktree, whatever it holds.
#                Treated as development. memory/ is gitignored,
#                so a worktree never carries the access lists or
#                the machine memory of the checkout it came from,
#                and anything written there is lost when the
#                worktree is removed.
#
# Cheap on purpose: the guard asks on every tool call, so this is
# file tests, with a process only for a linked worktree whose paths
# git did not write the usual way — and it sets variables rather
# than printing, so the caller needs no subshell either.
#
# Expects nothing. Defines:
#   hostwarden_mode <root>  — sets HOSTWARDEN_MODE to one of the
#                             three answers, and HOSTWARDEN_MAIN to
#                             the main checkout of a worktree
#   hostwarden_next_step    — sets HOSTWARDEN_NEXT_STEP to where
#                             server work goes from development, so
#                             the session start and every refusal
#                             name the same way
#   hostwarden_refusal <tool>
#                           — sets HOSTWARDEN_REFUSAL to why <tool>
#                             is refused in development, so the
#                             guard and the shim say the same
#   hostwarden_git_batch [<repo>]
#                           — sets up git to reach <repo>'s remote
#                             (none: a clone's) without ever prompting
#   hostwarden_path_without_shim
#                           — sets HOSTWARDEN_PATH to PATH without
#                             any Hostwarden shim directory (shim.sh)
#   hostwarden_cache_dir <root>
#                           — sets HOSTWARDEN_CHECKOUT_ID to <root>'s
#                             checksum and HOSTWARDEN_CACHE to its
#                             directory under ~/.cache/hostwarden
#   HOSTWARDEN_SSH_OPTIONS  — the connection options every SSH call
#                             carries, as Key=value words

# shellcheck disable=SC2034 # read by whoever sources this file
hostwarden_mode() {
  HOSTWARDEN_MAIN=
  # A linked worktree's .git is a FILE ("gitdir: <path>"), and the
  # directory it names holds a `commondir` file pointing at the
  # shared git directory, whose parent is the main checkout. A
  # submodule has a .git file too, but no commondir: it is no
  # clone of its own, so it is development. The usual pair, an
  # absolute gitdir and a commondir of ../.., resolves as text; only
  # anything else starts a process (cd resolves relative and
  # drive-letter paths).
  if [ -f "$1/.git" ]; then
    HOSTWARDEN_MODE=development
    read -r hm_git < "$1/.git"
    hm_git=${hm_git#gitdir: }
    case $hm_git in
    /*) ;;
    *) hm_git=$(cd "$1" && cd "$hm_git" 2>/dev/null && pwd) ;;
    esac
    if [ -n "$hm_git" ] && [ -f "$hm_git/commondir" ]; then
      read -r hm_common < "$hm_git/commondir"
      case $hm_common in
      ../..) HOSTWARDEN_MAIN=${hm_git%/*/*/*} ;;
      *) HOSTWARDEN_MAIN=$(cd "$hm_git" && cd "$hm_common/.." 2>/dev/null \
           && pwd) ;;
      esac
      HOSTWARDEN_MODE=worktree
    fi
  elif [ -d "$1/.git" ] && [ -f "$1/memory/.hostwarden-workspace" ]; then
    # A clone, not an archive copy: operations needs updates.
    HOSTWARDEN_MODE=operations
  else
    HOSTWARDEN_MODE=development
  fi
}

# A refusal that only stops leaves the developer to find the way
# to a live answer alone, so the session start and every refusal
# name the next step. Expects hostwarden_mode to have run.
# shellcheck disable=SC2034 # read by whoever sources this file
hostwarden_next_step() {
  if [ "$HOSTWARDEN_MODE" = worktree ]; then
    HOSTWARDEN_NEXT_STEP="hand the check to an operations session in \
the main checkout, $HOSTWARDEN_MAIN, if that is an operations install"
  else
    HOSTWARDEN_NEXT_STEP="hand the check to an operations session in \
a separate clone, set up once with bin/hostwarden-init"
  fi
  HOSTWARDEN_NEXT_STEP="$HOSTWARDEN_NEXT_STEP; how: \
rules/server-check-handoff.md"
}

# shellcheck disable=SC2034 # read by whoever sources this file
hostwarden_refusal() {
  if [ "$HOSTWARDEN_MODE" = worktree ]; then
    hr_why="this session runs in a linked git worktree. A worktree \
never carries memory/, so the access lists and the machine memory are \
missing here"
  else
    hr_why="this checkout develops Hostwarden (memory/ holds no \
workspace)"
  fi
  hostwarden_next_step
  HOSTWARDEN_REFUSAL="hostwarden mode guard: $1 reaches a server or \
administers this machine, and \
$hr_why. Next step: $HOSTWARDEN_NEXT_STEP (AGENTS.md - Development \
or Operations)."
}

# A checkout's own name on this machine, the checksum of its
# absolute path: memory/ssh_config names its SSH sockets with it,
# and what bin/hostwarden-impact keeps between runs lives in the
# directory it names, so two checkouts never read each other's.
# The directory is created by whoever writes to it, at 0700.
# shellcheck disable=SC2034 # read by whoever sources this file
hostwarden_cache_dir() {
  HOSTWARDEN_CHECKOUT_ID=$(printf %s "$1" | cksum | cut -d' ' -f1)
  HOSTWARDEN_CACHE=$HOME/.cache/hostwarden/ws-$HOSTWARDEN_CHECKOUT_ID
}

# hostwarden_off_host <value> — the one host the taboo guard's off
# switch names, lowercased and without a final dot, a loopback
# address as localhost, on stdout; exit
# 1 and nothing for a value that names none: empty, a bare number
# such as 1, a list, anything but a hostname, `localhost` or an
# address. check-session.sh records it, guard-taboos.d/off.sh
# compares against the record (hostwarden_off_recorded).
hostwarden_off_host() {
  hoh=$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')
  hoh=${hoh%.}
  case $hoh in 127.0.0.1 | ::1) hoh=localhost ;; esac
  case $hoh in '' | *[!a-z0-9.:_-]* | [.:_-]*) return 1 ;; esac
  case $hoh in *[!0-9]*) printf '%s\n' "$hoh" ;; *) return 1 ;; esac
}

# hostwarden_off_record <session> — the file where check-session.sh
# records the host a session started with.
hostwarden_off_record() {
  printf '%s\n' "$HOME/.cache/hostwarden/guard-off-$1"
}

# hostwarden_off_recorded <session> <value> — the host <value>
# names, where the session's record holds that same host; exit 1
# and nothing otherwise.
hostwarden_off_recorded() {
  [ -n "$1" ] || return 1
  hor=$(hostwarden_off_host "$2") || return 1
  [ "$hor" = "$(cat "$(hostwarden_off_record "$1")" 2>/dev/null)" ] ||
    return 1
  printf '%s\n' "$hor"
}

# Connection sharing and keepalives (rules/ssh-connections.md → Why
# these values), written once: bin/hostwarden-ssh-config turns them
# into memory/ssh_config, hostwarden_git_batch into -o options, and
# the doctor checks that ssh accepts them. No word holds a space.
# The generator puts the checkout's checksum into ControlPath; the
# workspace remote keeps this plain one, so its master, checked
# against the user's own known_hosts, is never shared with a
# managed host's.
# shellcheck disable=SC2034 # read by whoever sources this file
HOSTWARDEN_SSH_OPTIONS="BatchMode=yes ConnectTimeout=5 \
ControlMaster=auto ControlPath=~/.cache/hostwarden/ssh-%C \
ControlPersist=10m ServerAliveInterval=15 ServerAliveCountMax=3"

# The workspace's remote is reached by init --clone and by sync,
# often from a session-start hook. Never wait for a prompt there:
# not for a credential, not for a host key. An SSH remote gets the
# sharing and keepalives AGENTS.md → SSH Options sets for every
# connection, so a dead link cannot hold the session, but not its
# -F file: the remote is no managed host, and its key is checked
# against the user's own known_hosts (rules/host-keys.md).
hostwarden_git_batch() {
  GIT_TERMINAL_PROMPT=0
  # Only the socket directory needs 0700; ~/.cache keeps the umask.
  # shellcheck disable=SC2174
  mkdir -p -m 700 "$HOME/.cache/hostwarden"
  # Appended to a command the user set, not replaced by it: ssh
  # takes the first value it sees, so their own options still win,
  # and ours fill in what they left open. GIT_SSH_COMMAND outranks
  # core.sshCommand, so that, where set, is the command ours are
  # appended to — a mirror's deploy key, say. It is read from the
  # repository the caller contacts, never from another one: the
  # workspace in memory/ can use a key the checkout around it does
  # not. Without one, as before a clone, only the user's and the
  # system's setting count.
  # An unset key makes `git config` fail, which must not end a
  # caller running under `set -e`.
  if [ -z "${GIT_SSH_COMMAND:-}" ]; then
    if [ -n "${1:-}" ]; then
      GIT_SSH_COMMAND=$(git -C "$1" config core.sshCommand 2>/dev/null) \
        || GIT_SSH_COMMAND=
    else
      GIT_SSH_COMMAND=$(git config --global core.sshCommand 2>/dev/null \
        || git config --system core.sshCommand 2>/dev/null) \
        || GIT_SSH_COMMAND=
    fi
  fi
  export GIT_TERMINAL_PROMPT
  # A GIT_SSH program with nothing above it stays in charge: git runs
  # it as a bare path, and plink or a wrapper may take no ssh
  # options at all. An empty GIT_SSH_COMMAND would outrank it too.
  if [ -z "$GIT_SSH_COMMAND" ] && [ -n "${GIT_SSH:-}" ]; then
    unset GIT_SSH_COMMAND
    return 0
  fi
  GIT_SSH_COMMAND=${GIT_SSH_COMMAND:-ssh}
  for hw_o in $HOSTWARDEN_SSH_OPTIONS; do
    GIT_SSH_COMMAND="$GIT_SSH_COMMAND -o $hw_o"
  done
  export GIT_SSH_COMMAND
}

# Every Hostwarden shim goes, not only this checkout's: a session
# started from inside another one carries both on PATH. Parameter
# expansion only, so the doctor can use it before it knows which
# tools exist, and a caller's `set -f` and IFS stay as they were.
# shellcheck disable=SC2034 # read by whoever sources this file
hostwarden_path_without_shim() {
  HOSTWARDEN_PATH=
  hp_rest=$PATH:
  while [ -n "$hp_rest" ]; do
    hp_dir=${hp_rest%%:*}
    hp_rest=${hp_rest#*:}
    case $hp_dir in
    */.claude/hooks/shim) ;;
    *) HOSTWARDEN_PATH=$HOSTWARDEN_PATH${HOSTWARDEN_PATH:+:}$hp_dir ;;
    esac
  done
}
