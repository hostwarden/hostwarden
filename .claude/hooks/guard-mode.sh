#!/bin/sh
# guard-mode.sh — PreToolUse hook (matcher: Bash|Monitor|Edit|
# Write|MultiEdit|NotebookEdit).
#
# Holds a session to the mode mode.sh determines:
#
#   development, worktree — the tools in shim/ are refused: remote
#     logins and copies, privilege tools, and the configuration
#     tools that reach servers or a cloud on their own. That list
#     is the one to extend; tests/hooks/guard-mode.sh holds the
#     prefilter below and T and W in guard-mode.d/scan.awk to it.
#     The shim does most of it
#     (shim.sh): session-mode.sh puts it first on PATH, so the
#     tools refuse wherever they are started from, rsync's own
#     ssh included. This hook denies the forms that go past a
#     PATH lookup: a path to the real binary (/usr/bin/ssh, also
#     as rsync -e or a core.sshCommand value), command -p, a
#     changed PATH, rsync to a daemon (rsync:// or host::module,
#     which never starts ssh), and $GIT_SSH_COMMAND, git's
#     route to the real ssh (git-ssh.sh), used as a command. Local
#     administration counts: Hostwarden's local mode is server
#     work too. Under WSL the same goes for the Windows programs
#     the shim covers (ssh.exe, wsl.exe, powershell.exe and the
#     rest, shim.sh), in any spelling of their name: the drives
#     under /mnt ignore case, and the shim does not. A Monitor
#     command is a shell command and is read exactly as a Bash
#     one, and more: Claude Code documents the env file that
#     carries the shim for Bash only, so for Monitor this hook
#     also denies a blocked tool named without a path, where the
#     shim would have stood.
#     Containers are allowed, as scripts/lab.sh starts them:
#     docker, podman and nerdctl may read, pull, build, run and
#     create on the local engine; --context, --host and their
#     variables (DOCKER_HOST, CONTAINER_HOST) reach another one,
#     a server, and are denied. A run or create is denied with an
#     option that reaches past the container into this machine —
#     --privileged, a host path as a volume or mount, a host
#     namespace, a device, an added capability, a lifted security
#     profile, a namespace of the host or of another container, a
#     published port, a host file or a host variable
#     read into it (--env-file, --label-file, -e NAME without a
#     value) — and so are a build that writes its result here
#     (--output, --iidfile, --metadata-file) or reads a secret,
#     the SSH agent or a host path (podman build -v) from here, a
#     compose file, a kube play and a volume over a host device,
#     which the guard cannot read.
#     Every other verb is denied: exec
#     reaches whatever container it names, a privileged one of
#     another project included, and rm, stop, prune and the rest
#     change containers the lab does not own. The lab's exec and
#     down run inside scripts/lab.sh, where only its own label
#     is used. On Linux the engine runs as root; on macOS a bind
#     mount reaches $HOME.
#     A lab VM is a test server of an operations clone, so orb,
#     orbctl, limactl and lima are denied where they run a command
#     in one or copy to or from it. Reading their state passes.
#     Creating one is denied: scripts/lab.sh vm up creates it
#     without this machine's files mounted, which orb and Lima do
#     by default, and records it for vm down. Starting, stopping,
#     deleting or changing a VM is denied, since it may not be the
#     lab's: vm up starts the VMs it creates, and vm down deletes
#     only those. A bare orb start starts OrbStack itself and passes.
#   operations — Edit and Write are denied on any path inside
#     the checkout that git does not ignore, so memory/ and the
#     user's own files (.claude/settings.local.json) stay
#     writable. A local commit on main would also stop the
#     auto-update, which only fast-forwards.
#
# Unlike guard-taboos.sh, HOSTWARDEN_GUARD_DISABLE does not
# touch this one. That variable exists for installing an
# operating system, which is operations work and never needs
# either of the rules here.
#
# What it deliberately does NOT do:
#   - Stop a shell write in operations (sed -i, a redirect). The
#     set of shell writers cannot be closed; Edit and Write are
#     how an agent changes a file, and the prose in AGENTS.md
#     covers the rest.
#   - Read quotes, wrappers or rsync operands over ssh. Every such case
#     reaches the tool through PATH, where the shim waits; a
#     parser for them never closes. The one exception is the
#     command word, which it follows past a fixed set of launchers
#     (env, timeout, setsid ...): the shim misses SSH.EXE, and
#     Monitor may have no shim at all. Nor does it look for a bare
#     tool name in a Bash command, so grep ssh and a commit
#     message about sudo pass. Quotes are not masked: a commit
#     message that names /usr/bin/ssh, or changes PATH and
#     mentions ssh at all, is denied; either is rare.
#   - Look inside a variable or a script file. A backstop against
#     the everyday mistake, not a sandbox: eval $GIT_SSH_COMMAND
#     or a script that resets PATH still reaches ssh, and only
#     the prose in AGENTS.md stands against it. So does a bare
#     tool inside eval or a script that Monitor runs, wherever
#     the shim is not on its PATH.
#
# It runs on every tool call, so it forks little. In development
# nothing at all unless the input could hold one of the forms
# above, then one jq for the whole input and one awk for the
# command. In operations a Bash or Monitor call ends before jq;
# an edit runs one jq, and git only for a path outside memory/.
#
# Being blocked is EXPECTED behavior. Explain it to the user.
# Never rephrase, re-quote, or otherwise obfuscate a command to
# evade this guard.

ROOT=${0%/*}/../..
# Without mode.sh or json.sh the guard can tell no mode and write no
# deny, and a hook that fails to start lets the call through (bash
# as sh leaves a failed . with status 1): exit 2 blocks it instead,
# as in guard-taboos.sh and guard-settings.sh.
for f in mode.sh json.sh; do
  if [ ! -f "$ROOT/lib/$f" ]; then
    echo "hostwarden mode guard: $f is missing from $ROOT/lib" >&2
    exit 2
  fi
done
# shellcheck source=../../lib/mode.sh
. "$ROOT/lib/mode.sh"
# shellcheck source=../../lib/json.sh
. "$ROOT/lib/json.sh"
hostwarden_mode "$ROOT"

INPUT=$(cat)

# emit <message> — the JSON decision on stdout; blocks in all
# permission modes. hook_deny (json.sh) escapes the message, so it
# may carry a path or a piece of the command as it is.
emit() {
  hook_deny "$1 Blocked in all permission modes. Explain this to the \
user; do not rephrase the command or pick another tool to evade the \
guard."
}
deny() {
  emit "hostwarden mode guard: $1 (AGENTS.md - Development or Operations)."
}

# Before anything is parsed: in development only a Bash or Monitor
# call is read, and only its command, which cwd and the transcript
# path are not part of. A Bash command without a path to a blocked
# tool, command -p, a change to PATH, GIT_SSH_COMMAND, a container
# engine or a VM manager holds none of the forms this hook denies.
# That is nearly every call, and it ends here without a single
# process. A Monitor call is rare and
# always goes on. The tool names below are shim/'s, as in T and W
# (guard-mode.d/scan.awk).
if [ "$HOSTWARDEN_MODE" != operations ]; then
  case "$INPUT" in
  *'"tool_name"'*'"Monitor"'*) ;;
  *'"tool_name"'*'"Bash"'*)
    case "${INPUT#*'"command"'}" in
    */ssh[!A-Za-z0-9_.-]*|*/scp[!A-Za-z0-9_.-]*|*/sftp[!A-Za-z0-9_.-]*) ;;
    */mosh[!A-Za-z0-9_.-]*|*/sudo[!A-Za-z0-9_.-]*|*/sudoedit[!A-Za-z0-9_.-]*) ;;
    */doas[!A-Za-z0-9_.-]*|*/pkexec[!A-Za-z0-9_.-]*|*command*-*p*) ;;
    */ansible[!A-Za-z0-9_.-]*|*/ansible-playbook[!A-Za-z0-9_.-]*) ;;
    */ansible-pull[!A-Za-z0-9_.-]*|*/ansible-console[!A-Za-z0-9_.-]*) ;;
    */terraform[!A-Za-z0-9_.-]*|*/tofu[!A-Za-z0-9_.-]*) ;;
    # A Windows program, by path or by a spelling the shim misses.
    *.[Ee][Xx][Ee][!A-Za-z0-9_]*) ;;
    # In JSON a newline or tab before it is \n or \t, a letter too.
    *[!A-Za-z0-9_]PATH=*|*[!A-Za-z0-9_]path=*|*'unset PATH'*) ;;
    *\\[nt]PATH=*|*\\[nt]path=*) ;;
    *'env -'*|*rsync*::*|*rsync*'rsync://'*) ;;
    *GIT_SSH_COMMAND*) ;;
    *docker*|*podman*|*nerdctl*|*orbctl*|*limactl*) ;;
    *[!A-Za-z0-9_.-]orb[!A-Za-z0-9_.-]*|*\\[nt]orb[!A-Za-z0-9_.-]*) ;;
    *[!A-Za-z0-9_.-]lima[!A-Za-z0-9_.-]*|*\\[nt]lima[!A-Za-z0-9_.-]*) ;;
    *) exit 0 ;;
    esac
    ;;
  *) exit 0 ;;
  esac
else
  # Operations restricts edits only, so a Bash or Monitor call ends
  # here. Inside the text of an edit every quote is escaped, so
  # these patterns can only match the tool name itself; anything
  # else goes on to jq.
  case "$INPUT" in
  *'"tool_name":"Bash"'*|*'"tool_name":"Monitor"'*) exit 0 ;;
  esac
fi

# The rest lives in guard-mode.d/, one file per stage, sourced in
# this order into this shell; development.sh runs scan.awk. A guard
# missing one would judge by less than it claims, and an awk without
# its program finds nothing and lets every command through: a missing
# file blocks the call with exit 2 instead, as a missing json.sh does.
GUARD_MODE_D=$ROOT/.claude/hooks/guard-mode.d
GUARD_MODULES='read operations development'
for f in read.sh operations.sh development.sh scan.awk; do
  if [ ! -f "$GUARD_MODE_D/$f" ]; then
    echo "hostwarden mode guard: guard-mode.d/$f is missing beside $0" >&2
    exit 2
  fi
done
for GUARD_MOD in $GUARD_MODULES; do
  # shellcheck source=/dev/null
  . "$GUARD_MODE_D/$GUARD_MOD.sh"
done
