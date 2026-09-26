# guard-taboos.d/reach.sh — what takes a command past this user's
# own files, and the guest managers. Sourced by guard-taboos.sh,
# first in the order its GUARD_MODULES lists, into the one shell
# every module shares; never run on its own. off.sh reads REMOTE,
# scope.sh and the modules after it the rest.
# shellcheck shell=sh disable=SC2034 # read by the modules after it

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
# REMOTE is the part of it that reaches another machine or a guest,
# the privilege tools left out: what the off switch's localhost
# value never opens (off.sh).
REMOTE='(^|[^[:alnum:]_.-])(ssh|scp|sftp|mosh|rsync|docker|podman|nerdctl|lima|limactl|colima|orb|orbctl|multipass|vagrant|lxc-[[:alpha:]]+|midclt|machinectl|systemd-nspawn|jexec|jail'"$GMNAMES"'|kubectl|aws|gcloud|az|hcloud|doctl|wsl|wslconfig|powershell|pwsh)(\.exe)?([^[:alnum:]_.-]|$)|cmd\.exe|GIT_SSH_COMMAND'
REACH="$REMOTE"'|(^|[^[:alnum:]_.-])(sudo|sudoedit|doas|pkexec|run0|su|osascript|runas|gsudo)(\.exe)?([^[:alnum:]_.-]|$)'
