# guard-mode.d/development.sh — development: no server is reached.
# Sourced by guard-mode.sh, in the order its GUARD_MODULES lists,
# into the one shell every module shares; never run on its own.
# shellcheck shell=sh disable=SC2034 # read by the modules after it

# --- Development: no server is reached ------------------------
# A blocked tool named without a path is the shim's: it refuses
# wherever the tool is started from. This denies the ways past a
# PATH lookup:
#   - a Windows program from shim.sh as the first word of a
#     segment in any spelling but the shim's own (SSH.exe);
#   - a path to a blocked tool as the first word of a segment (split
#     on the shell's separators, past a negation, variable
#     assignments, redirections and launchers such as env,
#     timeout or setsid), or anywhere else when it names an executable
#     file: rsync -e /usr/bin/ssh, core.sshCommand=/usr/bin/ssh.
#     A path to a Windows program counts wherever it stands,
#     file or not, since Program Files splits it in two;
#   - $GIT_SSH_COMMAND at the start of a segment;
#   - command -p, which ignores PATH, anywhere in a command that
#     names a blocked tool, inside sh -c and eval strings too;
#   - a command that changes PATH (PATH=, zsh path=, unset PATH,
#     env -i or -, env -u PATH in its spellings) and names a
#     blocked tool anywhere;
#   - rsync with an rsync:// or host::module operand, which talks
#     to the daemon itself and never starts ssh;
#   - for Monitor, a blocked tool as the first word of a segment
#     even without a path, since the shim may not be on its PATH.
case "$TOOL" in
Bash|"") ;;
Monitor)
  # A WebSocket watch has no command and starts no shell. Without
  # jq CMD is never read, so that call is refused below instead.
  [ -z "$CMD" ] && [ -n "$JQ" ] && exit 0
  ;;
*) exit 0 ;;
esac
# Without jq the command is buried in JSON, and it names one of
# those forms (the prefilter in guard-mode.sh). Refuse rather than
# guess.
[ -n "$JQ" ] || deny "without jq this command cannot be read, and \
it may start a tool that reaches a server - install jq"
# jq could not parse the input: scan it raw, which can only
# over-block.
[ -n "$CMD" ] || CMD="$INPUT"

# One line: "deny <what>" for a verdict, "engine", "compose" or
# "vm <what>" for a container or lab VM, or "path <p>" for a path
# elsewhere in the command, which counts once it is a program.
#
# Containers and lab VMs: a container engine, orb, orbctl, limactl
# and lima count as the first word of a segment only, past the
# launchers cmdpos() reads, sh -c among them, so grep orb docs/ and a
# commit message about docker rm are not. An engine's options are
# read to the end of that segment, where the words after the image
# are the container's command and can only over-block.
FOUND=$(printf '%s' "$CMD" | awk -v tool="$TOOL" \
  -f "$GUARD_MODE_D/scan.awk")

BLOCKED=
case "$FOUND" in
"engine "*)
  deny "${FOUND#engine } reaches past the container into this \
machine. A development session runs containers without host \
access; scripts/lab.sh up <family> starts one that way" ;;
"remote "*)
  hostwarden_refusal "${FOUND#remote }, another container engine,"
  emit "$HOSTWARDEN_REFUSAL" ;;
"vmnew "*)
  deny "${FOUND#vmnew } creates a VM outside scripts/lab.sh vm up, \
which creates it without this machine's files mounted and records \
it, so vm down can delete it: scripts/lab.sh vm up <family> \
--ops <test clone>" ;;
"vmchange "*)
  deny "${FOUND#vmchange } starts, stops, deletes or changes a VM that \
may not be the lab's. scripts/lab.sh vm up starts the VMs this \
worktree creates, and vm down deletes only those" ;;
"change "*)
  deny "${FOUND#change } reaches or changes a container, image or \
volume the lab may not own. A development session reads, pulls, \
builds, runs and creates; scripts/lab.sh exec and down reach \
and remove only the lab's own containers" ;;
"compose "*)
  deny "${FOUND#compose } starts what a file says, which this guard \
cannot read; scripts/lab.sh up <family> starts a container \
without host access" ;;
"vm "*)
  deny "${FOUND#vm } - a lab VM is a test server of the operations \
clone it was created for, never used from a development session. \
Next step: hand the question to a session in that clone, which \
scripts/lab.sh list names; how: rules/server-check-handoff.md" ;;
"deny "*) BLOCKED=${FOUND#deny } ;;
*)
  # /etc/ssh is a directory, a path in a sentence names nothing,
  # and the shim only refuses.
  while IFS= read -r p; do
    p=${p#path }
    case "$p" in *.claude/hooks/shim/*) continue ;; esac
    if [ -f "$p" ] && [ -x "$p" ]; then
      BLOCKED="${p##*/} by its path"
      break
    fi
  done <<EOF
$FOUND
EOF
  ;;
esac
[ -n "$BLOCKED" ] || exit 0
hostwarden_refusal "$BLOCKED"
emit "$HOSTWARDEN_REFUSAL"
