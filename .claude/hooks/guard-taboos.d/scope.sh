# guard-taboos.d/scope.sh — the scope and the ask tier.
# Sourced by guard-taboos.sh, in the order its GUARD_MODULES
# lists, into the one shell every module shares; never run
# on its own.
# shellcheck shell=sh disable=SC2034 # read by the modules after it

# --- Scope: full, or local to a development session -----------
# The header says what each scope covers. A hook copied without
# lib/mode.sh cannot tell its mode and stays full.
#
# REACH names what takes a command past this user's own files: a
# remote login or copy, a privilege tool (osascript elevates with
# "with administrator privileges"), a container, VM or
# cluster, a cloud CLI, Windows' shells and wsl, which the shim
# refuses under WSL too, and git's route to the real ssh. It is
# matched anywhere in the command, not only as a program: a
# commit message that names ssh and a taboo gets the full scope,
# which is rare, while a wrapper list for "program position"
# (nohup, timeout, xargs, find -exec ...) never closes. The
# Windows rules need no scope: WIN below gates them, and a
# Windows user reaches wsl --unregister or Stop-Computer without
# admin, so they apply in both.
#
# The global options a guest manager takes between its name and
# its verb: a flag with a value of its own (virsh -c URI, incus
# --project NAME, xe -s HOST -u USER), or any single dash word. The
# power-off rules and the guest rule below both need them.
GOPTS='([[:space:]]+(-c|--connect|--project|-s|--server|-u|--user|-p|--port|-pw|-pwf|--password)[[:space:]]+[^[:space:]]+|[[:space:]]+-[^[:space:]]+)*'
# The guest managers, written once: each as name:verbs, the verbs
# that stop or delete one of its guests as an ERE alternation. A
# jail's restart counts as its stop, which it begins with; pct and
# qm reboot are not on the list and stay the model's. REACH
# takes the names, the host shutdown rules the managers whose verb
# is a bare shutdown, and the guest rule at the end all of it. A
# manager whose stop has another shape is a form of its own there
# (GUESTFORMS).
GUESTMGRS='pct:stop|shutdown|destroy qm:stop|shutdown|destroy
virsh:destroy|shutdown|undefine incus:stop|delete lxc:stop|delete
xe:vm-shutdown|vm-destroy|vm-uninstall bastille:stop|restart|destroy
iocage:stop|restart|destroy'
GMNAMES='' GMWORDS='' GMSTOP='' GMSHUT='' GMSHUTWORDS=''
for gm in $GUESTMGRS; do
  GMNAMES="$GMNAMES|${gm%%:*}" GMWORDS="$GMWORDS ${gm%%:*}"
  GMSTOP="$GMSTOP|${gm%%:*}${GOPTS}[[:space:]]+(${gm#*:})"
  case "|${gm#*:}|" in
  *'|shutdown|'*)
    GMSHUT="$GMSHUT|${gm%%:*}" GMSHUTWORDS="$GMSHUTWORDS ${gm%%:*}" ;;
  esac
done
REACH='(^|[^[:alnum:]_.-])(ssh|scp|sftp|mosh|rsync|sudo|sudoedit|doas|pkexec|run0|su|osascript|runas|gsudo|docker|podman|nerdctl|lima|limactl|colima|orb|orbctl|multipass|vagrant|lxc-[[:alpha:]]+|midclt|machinectl|systemd-nspawn|jexec|jail'"$GMNAMES"'|kubectl|aws|gcloud|az|hcloud|doctl|wsl|wslconfig|powershell|pwsh)(\.exe)?([^[:alnum:]_.-]|$)|cmd\.exe|GIT_SSH_COMMAND'
SCOPE=full
if [ -f "$LIBDIR/mode.sh" ]; then
  # shellcheck source=../../../lib/mode.sh
  . "$LIBDIR/mode.sh"
  hostwarden_mode "$HOOKDIR/../.."
  case "$HOSTWARDEN_MODE" in
  development|worktree)
    SCOPE=local
    # Root, or the disk group (read-write on Linux block devices),
    # reaches what the local scope leaves out. One id answers both.
    if hit "$REACH"; then
      SCOPE=full
    else
      case "$(id 2>/dev/null)" in
      uid=0\(*|*\(disk\)*) SCOPE=full ;;
      esac
    fi
    # A development session judged in full says why in every deny.
    [ "$SCOPE" = full ] && GUARD_SCOPE_NOTE="This session develops \
Hostwarden; the full check applies because the command, or the user \
running it, can reach a server, root or a container. "
    ;;
  esac
fi
# full — the rules that need root, a server or a container apply.
full() { [ "$SCOPE" = full ]; }
# power — the power-off rules apply: in the full scope, and on any
# machine running systemd, whose logind lets the user at the seat
# power off without root.
power() { full || [ -d /run/systemd/system ]; }

# --- The ask tier ---------------------------------------------
# Some effects are legitimate work and still the user's call:
# stopping or deleting a guest, and a routine storage change. For
# those this is the hook's second tier: the user confirms the exact
# command in a prompt. Membership is narrow on purpose -- an effect
# earns ask instead of deny only when it is routine admin work AND
# no user-tunable policy already covers it (service restarts have
# memory/service-policy.md, so they stay with the model).
#
# A rule that finds such an effect calls ask_for and nothing is
# decided yet. The prompt names every effect found, each once, and
# the decision is taken at the very end of the file by ask_decide,
# the tier's one reading of the permission mode, so a taboo anywhere
# in the same command still denies.
#
# The prompt must reach a human. Claude Code documents ask as
# forcing one in auto mode; for bypassPermissions and dontAsk it
# documents nothing, so those deny, and so does a mode this hook
# cannot read. Measured upstream in Heinzel with Claude Code
# 2.1.267: in claude -p an ask is refused whatever the mode, so an
# unattended run stops rather than hanging, and a session started
# with --permission-mode auto reports default here. The operator
# override is HOSTWARDEN_GUARD_DISABLE, as for a taboo.
#
# ask_for <what> <effect, with its rule> <what to check>
ASKWHAT=''
ASKTEXT=''
ASKSEEN=''
ask_for() {
  case "|$ASKSEEN|" in *"|$1|"*) return 0 ;; esac
  ASKSEEN="$ASKSEEN|$1"
  ASKWHAT="${ASKWHAT:+$ASKWHAT, and }$1"
  ASKTEXT="${ASKTEXT:+$ASKTEXT }$1 $2. $3"
}
# ask_decide -- ask where a prompt reaches a human, deny where none
# does. MODE was read with the command; no jq means no mode, hence
# deny.
ask_decide() {
  case $MODE in
  default|acceptEdits|plan|auto)
    decide ask "$ASKTEXT"
    ;;
  *)
    decide deny "$ASKWHAT - this needs a confirmation prompt, and \
this session shows none, or a permission mode this hook does not \
know. Not a taboo: run it in a session that asks, or let the user \
run it. Do not rephrase the command."
    ;;
  esac
}
# A --help or -h after the verb prints the syntax and changes
# nothing, which AGENTS.md -> Verify Before Running asks for before
# a command is run, so both tiers exempt it, read from the verb on,
# per invocation as every read-only exemption here is.
HELP='^[^;&|]*[[:space:]](--help|-h)([[:space:]]|[;&|]|$)'
# TrueNAS' middleware client up to the method: options, some with a
# value of their own (-u URI, -U user), around call, and a quote
# before the method name.
MIDCLT='(^|[^[:alnum:]_.-])midclt([[:space:]]+-[^[:space:]]+([[:space:]]+[^-[:space:]][^[:space:]]*)?)*[[:space:]]+call([[:space:]]+-[^[:space:]]+)*[[:space:]]+["'"'"']?'
