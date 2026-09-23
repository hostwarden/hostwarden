#!/bin/sh
# guard-taboos-test.sh — dev-only fixture matrix for
# guard-taboos.sh. Run manually before committing guard
# changes:  sh .claude/hooks/guard-taboos-test.sh
# Not invoked by Claude Code at runtime.

CLAUDE_DIR="$(cd "$(dirname "$0")/.." && pwd)"
# The skills live here. .claude/skills is a link to it, but
# the real path is the one thing every tool agrees on.
SKILLS_DIR="$CLAUDE_DIR/../.agents/skills"
PASS=0
FAIL=0

# The guard picks its scope from the checkout it sits in (the
# header of guard-taboos.sh), and this matrix runs in a development
# checkout or a worktree. So it judges copies: one in a tree that
# is an operations checkout by mode.sh's own test, for the full
# scope, and one in a plain directory, for the local one. A
# --verdict child inherits both through the environment.
if [ -z "${GUARD_OPS:-}" ]; then
  GUARD_TREES=$(mktemp -d)
  for t in ops dev; do
    mkdir -p "$GUARD_TREES/$t/.claude/hooks"
    cp "$CLAUDE_DIR/hooks/guard-taboos.sh" "$CLAUDE_DIR/hooks/mode.sh" \
      "$CLAUDE_DIR/hooks/json.sh" "$GUARD_TREES/$t/.claude/hooks/"
  done
  mkdir -p "$GUARD_TREES/ops/.git" "$GUARD_TREES/ops/memory"
  : > "$GUARD_TREES/ops/memory/.hostwarden-workspace"
  GUARD_OPS="$GUARD_TREES/ops/.claude/hooks/guard-taboos.sh"
  GUARD_DEV="$GUARD_TREES/dev/.claude/hooks/guard-taboos.sh"
  export GUARD_OPS GUARD_DEV
fi
HOOK=$GUARD_OPS

json_for() {
  # json_for <command> [tool] [mode] — a raw command string as
  # PreToolUse hook input for Bash, or for the tool named, in the
  # permission mode given, or none. The tool JSON takes the first
  # argument as the whole hook input already.
  if [ "${2:-}" = JSON ]; then
    printf '%s' "$1"
  elif command -v jq >/dev/null 2>&1; then
    printf '%s' "$1" | jq -cRs --arg t "${2:-Bash}" --arg m "${3:-}" \
      '{tool_name:$t,tool_input:{command:.}}
       + (if $m == "" then {} else {permission_mode:$m} end)'
  else
    printf '%s' "$1" | python3 -c 'import json,sys; \
d={"tool_name":sys.argv[1],"tool_input":{"command":sys.stdin.read()}}; \
d.update({"permission_mode":sys.argv[2]} if sys.argv[2] else {}); \
print(json.dumps(d))' "${2:-Bash}" "${3:-}"
  fi
}

# Whether a guard's output is a deny. verdict below and hook_case
# further down both judge by it.
denied() { case "$1" in *'"permissionDecision":"deny"'*) true ;; *) false ;; esac; }
# The guard's second tier: a prompt the user answers, for a guest
# stopped or deleted (guard-taboos.sh -> Guest stop and delete).
asked() { case "$1" in *'"permissionDecision":"ask"'*) true ;; *) false ;; esac; }

verdict() {
  # verdict <expect> <tool> <command> <hook> <input> [label] — one
  # fixture, one line of output, in the queue's own field order.
  # Runs no process but the guard itself: every fork and exec here
  # is paid once per fixture, and on a workstation with an EDR agent
  # each one is also inspected. HOSTWARDEN_GUARD_DISABLE is unset by
  # the caller, once.
  OUT=$(sh "$4" <<EOF
$5
EOF
)
  if denied "$OUT"; then GOT=deny
  elif asked "$OUT"; then GOT=ask
  else GOT=pass
  fi
  # A decision Claude Code cannot parse is no decision at all: a
  # reason with a backslash in it once broke the JSON unnoticed.
  # The drain validates every deny and every ask it gets back, all
  # in one jq run.
  case "$GOT:$1" in
  deny:deny|ask:ask) printf '%s:%s\n' "$GOT" "$OUT" ;;
  pass:pass) echo ok ;;
  *)
    case $2 in
    Bash) echo "FAIL [$1, got $GOT]$6: $3" ;;
    *) echo "FAIL [$1, got $GOT] $2$6: $3" ;;
    esac ;;
  esac
}

# Child of the parallel drain at the bottom, judging a batch of
# fixtures. Everything it needs is defined above; it must exit
# before the fixtures below, or each child would queue the whole
# matrix again.
# Each fixture is four arguments: expectation, tool, command, and
# the hook input the drain built from them (a dash without jq).
# An expectation with a dev- prefix is judged by the copy in the
# development tree (check_dev below).
if [ "$1" = "--verdict" ]; then
  shift
  unset HOSTWARDEN_GUARD_DISABLE
  while [ $# -ge 4 ]; do
    IN=$4
    [ "$IN" != - ] || IN=$(json_for "$3" "$2")
    case $1 in
    dev-*) verdict "${1#dev-}" "$2" "$3" "$GUARD_DEV" "$IN" \
      ' in development' ;;
    *) verdict "$1" "$2" "$3" "$HOOK" "$IN" ;;
    esac
    shift 4
  done
  # A batch cut short mid-fixture would misread every fixture after
  # the cut; it fails the run instead.
  [ $# -eq 0 ] || echo "FAIL: a batch ended mid-fixture ($# arguments left)"
  exit 0
fi

SELF="$CLAUDE_DIR/hooks/$(basename "$0")"
QUEUE=$(mktemp)
trap 'rm -rf "$QUEUE" "$QUEUE.in" "$GUARD_TREES"' EXIT INT TERM
NCHECKS=0
# One core is the floor, not the default: a machine that will not
# say how many it has still runs the matrix, just no faster. Off
# CI, half the cores is the ceiling: on a workstation, other
# sessions and endpoint protection inspecting every process need the
# rest.
JOBS=$(getconf _NPROCESSORS_ONLN 2>/dev/null || echo 1)
[ -n "${CI:-}" ] || JOBS=$((JOBS / 2))
[ "$JOBS" -ge 1 ] || JOBS=1

check() {
  # Queued, not run. Every fixture is an independent invocation of
  # the guard costing ~80 ms, and nothing in one depends on
  # another, so running them one after the other spent ~55 s to
  # learn what ~13 s answers. A check that slow is a check people
  # stop running before they commit.
  # check <expect> <command> [tool] — Bash unless a tool is named.
  printf '%s\0%s\0%s\0' "$1" "${3:-Bash}" "$2" >> "$QUEUE"
  NCHECKS=$((NCHECKS + 1))
}

check_mode() {
  # check_mode <expect> <permission mode> <command> -- a Bash call
  # in that mode. check alone sends no mode at all.
  check "$1" "$(json_for "$3" Bash "$2")" JSON
}

# --- must block ------------------------------------------------
check deny 'halt'
check deny 'poweroff'
check deny 'systemctl poweroff'
check deny 'init 0'
check deny 'shutdown now'
check deny 'shutdown -h now'
check deny 'ssh root@h "shutdown -h now"'
# -r beside a halt or power-off flag: the last action flag wins on
# systemd and sysvinit, so these halt or power off.
check deny 'shutdown -r -h now'
check deny 'shutdown -r -P now'
check deny 'shutdown -r -H now'
check deny 'shutdown -r -p now'
check deny 'shutdown -h -r now'
check deny 'shutdown -r --halt now'
check deny 'shutdown -r --poweroff now'
check deny 'shutdown -r --pow now'
check deny 'shutdown -r --p now'
check deny 'shutdown -r --hal now'
check deny "shutdown -r '-h' now"
check deny 'shutdown -r "--poweroff" now'
check deny 'shutdown -r \-P now'
check deny "shutdown -r -'H' now"
check deny "shutdown -r \$'-h' now"
check deny "shutdown -r \$'--poweroff' now"
check deny 'shutdown -r --h"a"lt now'
check deny 'shutdown -r -\
h now'
check deny 'shut\
down -h now'
check deny 'mkfs.ext4 \
/dev/sda1'
check deny "shut''down -r -h now"
check deny 'shut\down -r -h now'
check deny 'shut"d"own -h now'
check deny "mk''fs.ext4 /dev/sda1"
check deny "shut\$''down -r -h now"
check deny "shut\$'d'own -r -h now"
check deny 'shut$""down -r -h now'
check pass 'echo $HOME$PATH'
check deny 'ssh root@h "fd\isk /dev/sda"'
check pass "echo it's fine"
check pass 'git log --format="%h %s" -5'
check deny "shutdown -r --'p'oweroff now"
check deny 'ssh root@h "shutdown -r '\''-h'\'' now"'
check deny 'shutdown -r -kh now'
check deny 'shutdown -c -h now'
check deny 'ssh root@h "shutdown -r -h now"'
check deny 'ssh -o BatchMode=yes root@h '\''mkfs.ext4 /dev/sda3'\'''
check deny 'mkfs.ext4 /dev/sda1'
check deny 'newfs /dev/ada0p3'
check deny 'wipefs -a /dev/sdb'
check deny 'fdisk /dev/sda'
check deny 'sfdisk /dev/sda < layout.txt'
check deny 'sgdisk -n 2:0:0 /dev/sda'
check deny 'sgdisk --zap-all /dev/sda'
check deny 'parted /dev/sda mklabel gpt'
check deny 'parted /dev/sda rm 2'
check deny 'gpart destroy -F ada0'
check deny 'gpart add -t freebsd-zfs ada0'
check deny 'dd if=image.raw of=/dev/sda bs=4M'
check deny 'ssh h "dd if=img of=/dev/vtbd0"'
check deny 'rm /etc/ssh/ssh_host_ed25519_key'
check deny 'rm -f ~/.ssh/id_ed25519'
check deny 'shred -u /root/.ssh/authorized_keys'
check deny "sed -i 's/^/#/' /etc/ssh/sshd_config"
check deny 'ssh h "echo PermitRootLogin yes >> /etc/ssh/sshd_config"'
check deny 'tee /etc/ssh/sshd_config < new.conf'
check deny 'vi /etc/ssh/sshd_config'
check deny 'HOSTWARDEN_GUARD_DISABLE=1 mkfs.ext4 /dev/sda1'
check deny 'export HOSTWARDEN_GUARD_DISABLE=1; fdisk /dev/sda'

# --- exemption must belong to the taboo invocation (issue #4) ---
# A -l / -r / -c anywhere in the string used to disarm the rule,
# so an ordinary read-only probe in front of a write command
# waved the write command through.
check deny 'ssh -l root host "fdisk /dev/sda"'
check deny 'ssh -l root host "gdisk /dev/sda"'
check deny 'ssh -c aes256-gcm@openssh.com root@host "shutdown -h now"'
check deny 'ls -l /dev && fdisk /dev/sda'
check deny 'grep -r ERROR /var/log/syslog; shutdown -h now'
check deny 'fdisk /dev/sda && ls -l /tmp'
check deny 'cp -l a b; sfdisk --delete /dev/sda'
check deny 'ssh -o BatchMode=yes root@h "lsblk -l && fdisk /dev/sdb"'
check deny 'ssh -o BatchMode=yes root@h "ls -l /dev/disk/by-id; fdisk /dev/sdb"'
check deny 'ssh -o BatchMode=yes root@h "gdisk -l /dev/sda; gdisk /dev/sdb"'
check deny 'ssh -o BatchMode=yes root@h "sfdisk -l /dev/sda && sfdisk /dev/sdb < pt"'
# No quote or separator to split on: the exemption is only
# recognized when it FOLLOWS the taboo command in its segment.
check deny 'ssh -l root host fdisk /dev/sda'
check deny 'ssh -luser host fdisk /dev/sda'
check deny 'ssh -c aes256-gcm@openssh.com root@host shutdown -h now'
check deny 'sudo -l root fdisk /dev/sda'

# --- same taboo, tool the rules did not name (issue #5) --------
# The taboos are effects, not a list of binaries. Every command
# below reaches a forbidden effect through a tool the original
# rules never mentioned.
check deny 'cfdisk /dev/sda'
check deny 'gpt destroy /dev/da0'
check deny 'gpt create -f /dev/disk2'
check deny 'diskutil eraseDisk JHFS+ Foo disk2'
check deny 'diskutil partitionDisk disk2 GPT JHFS+ Foo 100%'
check deny 'diskutil apfs deleteContainer disk2'
check deny 'diskutil secureErase 0 disk2'
check deny 'diskutil zeroDisk disk2'
# parted and sgdisk take several actions per invocation, so a
# read-only flag can always ride along with a write one. Their
# write sets are closed and enumerated in full instead.
check deny 'parted /dev/sda toggle 1 boot'
check deny 'parted /dev/sda name 1 data'
check deny 'parted /dev/sda move 1 100 200'
check deny 'parted /dev/sda mkpartfs primary ext2 1 100'
check deny 'sgdisk -U R /dev/sda'
check deny 'sgdisk -e /dev/sda'
check deny 'sgdisk -s /dev/sda'
check deny 'sgdisk -G /dev/sda'
check deny 'sgdisk --replicate=/dev/sdb /dev/sda'
check deny 'sgdisk -b backup.gpt -Z /dev/sda'
check deny 'growpart /dev/sda 1'

# --- disk wiped without touching the partition table -----------
check deny 'blkdiscard /dev/sda'
check deny 'blkdiscard --secure /dev/nvme0n1'
check deny 'nvme format /dev/nvme0n1'
check deny 'nvme sanitize /dev/nvme0n1'
check deny 'nvme delete-ns /dev/nvme0'
check deny 'nvme write-zeroes /dev/nvme0n1'
check deny 'hdparm --security-erase p /dev/sda'
check deny 'hdparm --make-bad-sector 1024 /dev/sda'
check deny 'badblocks -w /dev/sda'
check deny 'badblocks -sw /dev/sdb'
check deny 'shred /dev/sda'
check deny 'mke2fs -t ext4 /dev/sda1'
check deny 'newfs_msdos /dev/da0s1'
check deny 'cat disk.img > /dev/sda'
check deny 'tee /dev/sda < disk.img'
check deny 'dd if=disk.img > /dev/nvme0n1'
check deny 'ssh root@h "xzcat img.xz > /dev/vda"'

# --- power off under another name ------------------------------
check deny 'telinit 0'
check deny 'echo o > /proc/sysrq-trigger'

# --- a guest stopped or deleted -------------------------------
# Asked where a prompt can reach a human; denied without a
# permission mode, which counts as no prompt, and in the modes that
# show none.
check deny 'pct stop 105'
check_mode ask default 'pct stop 105'
check deny 'pct shutdown 105'
check_mode ask default 'pct shutdown 105'
check deny 'ssh root@pve1 "pct stop 105"'
check_mode ask default 'ssh root@pve1 "pct stop 105"'
check deny 'incus stop web'
check_mode ask default 'incus stop web'
check deny 'incus --project prod stop web'
check_mode ask default 'incus --project prod stop web'
check deny 'incus stop --all'
check_mode ask default 'incus stop --all'
check deny 'incus -q stop web'
check_mode ask default 'incus -q stop web'
check deny 'incus --project=prod stop web'
check_mode ask default 'incus --project=prod stop web'
check deny 'lxc --force-local stop web'
check_mode ask default 'lxc --force-local stop web'
check deny 'qm stop 100'
check_mode ask default 'qm stop 100'
check deny 'qm shutdown 100 --timeout 60'
check_mode ask default 'qm shutdown 100 --timeout 60'
check deny 'pct destroy 105'
check_mode ask default 'pct destroy 105'
check deny 'qm destroy 100 --purge'
check_mode ask default 'qm destroy 100 --purge'
check deny 'incus delete --force web'
check_mode ask default 'incus delete --force web'
check deny 'incus --project prod delete web'
check_mode ask default 'incus --project prod delete web'
check deny 'lxc delete -f web'
check_mode ask default 'lxc delete -f web'
check deny 'virsh undefine web --remove-all-storage'
check_mode ask default 'virsh undefine web --remove-all-storage'
check deny 'virsh -c qemu:///system undefine web'
check_mode ask default 'virsh -c qemu:///system undefine web'
check deny 'lxc-destroy -n web'
check_mode ask default 'lxc-destroy -n web'
check deny 'ssh root@pve1 "qm stop 100 --skiplock"'
check_mode ask default 'ssh root@pve1 "qm stop 100 --skiplock"'
check deny 'virsh destroy web'
check_mode ask default 'virsh destroy web'
check deny 'virsh destroy web --graceful'
check_mode ask default 'virsh destroy web --graceful'
check deny 'virsh shutdown web'
check_mode ask default 'virsh shutdown web'
check deny 'virsh -c qemu:///system destroy web'
check_mode ask default 'virsh -c qemu:///system destroy web'
check deny 'virsh -c qemu:///system shutdown web'
check_mode ask default 'virsh -c qemu:///system shutdown web'
check deny 'virsh --connect qemu:///system destroy web'
check_mode ask default 'virsh --connect qemu:///system destroy web'
check deny 'lxc stop web --force'
check_mode ask default 'lxc stop web --force'
check deny 'lxc-stop -n web'
check_mode ask default 'lxc-stop -n web'
check deny 'lxc-stop -n web -k'
check_mode ask default 'lxc-stop -n web -k'
check deny 'xe vm-shutdown uuid=abc123'
check_mode ask default 'xe vm-shutdown uuid=abc123'
check deny 'xe vm-shutdown uuid=abc123 force=true'
check_mode ask default 'xe vm-shutdown uuid=abc123 force=true'
check deny 'xe vm-uninstall uuid=abc123 --force'
check_mode ask default 'xe vm-uninstall uuid=abc123 --force'
check deny 'xe vm-destroy uuid=abc123'
check_mode ask default 'xe vm-destroy uuid=abc123'
check deny 'xe -s pool1 -u root vm-shutdown uuid=abc123'
check_mode ask default 'xe -s pool1 -u root vm-shutdown uuid=abc123'
check deny 'ssh root@xen1 "xe vm-uninstall uuid=abc123"'
check_mode ask default 'ssh root@xen1 "xe vm-uninstall uuid=abc123"'
check_mode deny default 'xe vm-shutdown uuid=abc123; shutdown -h now'
check deny 'midclt call vm.stop 1'
check_mode ask default 'midclt call vm.stop 1'
# vm.poweroff spells the word the rule above denies in every
# mode. Stricter than the ask tier, and left that way.
check deny 'midclt call vm.poweroff 1'
check_mode deny default 'midclt call vm.poweroff 1'
check deny 'midclt call vm.delete 1'
check_mode ask default 'midclt call vm.delete 1'
check deny 'midclt call virt.instance.stop web'
check_mode ask default 'midclt call virt.instance.stop web'
check deny 'midclt call virt.instance.delete web'
check_mode ask default 'midclt call virt.instance.delete web'
check deny 'ssh root@nas1 "midclt call vm.delete 1"'
check_mode ask default 'ssh root@nas1 "midclt call vm.delete 1"'
check dev-deny 'midclt call vm.delete 1'
check deny 'pct stop 105 && pct destroy 105'
check_mode ask default 'pct stop 105 && pct destroy 105'
check dev-deny 'pct stop 105'
check dev-deny 'lxc-destroy -n web'
check dev-deny 'xe vm-destroy uuid=abc123'
check dev-deny 'xe -s pool1 vm-destroy uuid=abc123'
check dev-deny 'incus delete --force web'
check dev-deny 'virsh undefine web'
check dev-deny 'qm destroy 100'
check dev-deny 'ssh root@nas1.example.com "zpool destroy tank"'
check dev-deny 'ssh root@nas1.example.com "lvextend -L +1G vg0/root"'
# FreeBSD jails, by Bastille, iocage, jail(8) and the rc scripts
# that start them: the same ask, and the same deny without a
# human.
check deny 'bastille stop web'
check_mode ask default 'bastille stop web'
check deny 'bastille destroy web'
check_mode ask default 'bastille destroy web'
check deny 'bastille destroy -f web'
check_mode ask default 'bastille destroy -f web'
check deny 'iocage stop web'
check_mode ask default 'iocage stop web'
check deny 'iocage stop ALL'
check_mode ask default 'iocage stop ALL'
check deny 'iocage destroy -f web'
check_mode ask default 'iocage destroy -f web'
check deny 'jail -r web'
check_mode ask default 'jail -r web'
check deny 'jail -R web'
check_mode ask default 'jail -R web'
check deny 'jail -rc web'
check_mode ask default 'jail -rc web'
check deny 'jail -f /etc/jail.conf -r web'
check_mode ask default 'jail -f /etc/jail.conf -r web'
check deny '/usr/sbin/jail -r web'
check_mode ask default '/usr/sbin/jail -r web'
check deny 'service jail stop'
check_mode ask default 'service jail stop'
check deny 'service jail stop web'
check_mode ask default 'service jail stop web'
check deny 'service jail onestop web'
check_mode ask default 'service jail onestop web'
check deny 'service bastille stop'
check_mode ask default 'service bastille stop'
check deny 'service iocage stop'
check_mode ask default 'service iocage stop'
check deny '/etc/rc.d/jail stop web'
check_mode ask default '/etc/rc.d/jail stop web'
check deny 'ssh root@bsd1 "bastille stop web"'
check_mode ask default 'ssh root@bsd1 "bastille stop web"'
check deny 'ssh root@bsd1 "iocage destroy -f web"'
check_mode ask default 'ssh root@bsd1 "iocage destroy -f web"'
check dev-deny 'bastille stop web'
check dev-deny 'iocage destroy -f web'
check dev-deny 'jail -r web'
check dev-deny 'service jail stop web'
check_mode deny bypassPermissions 'bastille destroy web'
check_mode ask auto 'iocage stop web'
# A jail restarts through a stop, so it asks the same way.
check deny 'bastille restart web'
check_mode ask default 'bastille restart web'
check deny 'iocage restart web'
check_mode ask default 'iocage restart web'
check deny 'jail -rc web'
check_mode ask default 'jail -rc web'
check deny 'service jail restart'
check_mode ask default 'service jail restart'
check deny 'service jail restart web'
check_mode ask default 'service jail restart web'
check deny 'service jail onerestart web'
check_mode ask default 'service jail onerestart web'
check deny 'service jail forcerestart web'
check_mode ask default 'service jail forcerestart web'
check deny 'service bastille restart'
check_mode ask default 'service bastille restart'
check deny 'service iocage restart'
check_mode ask default 'service iocage restart'
check deny '/etc/rc.d/jail restart web'
check_mode ask default '/etc/rc.d/jail restart web'
check deny '/usr/local/etc/rc.d/bastille restart'
check_mode ask default '/usr/local/etc/rc.d/bastille restart'
check deny 'ssh root@bsd1 "service jail restart web"'
check_mode ask default 'ssh root@bsd1 "service jail restart web"'
check dev-deny 'bastille restart web'
check dev-deny 'service jail restart web'
check_mode deny bypassPermissions 'iocage restart web'
check_mode ask auto 'service jail onerestart web'
check pass 'bastille restart --help'
check pass 'service jail status web'
for m in acceptEdits plan auto; do
  check_mode ask "$m" 'pct stop 105'
done
for m in bypassPermissions dontAsk bogus; do
  check_mode deny "$m" 'pct stop 105'
done
# A host taboo in the same command still wins over the ask, and a
# guest's shutdown verb does not lend the host's its exemption.
check_mode deny default 'pct stop 105; mkfs.ext4 /dev/sda1'
check_mode deny default 'qm destroy 100 && reboot -f; halt'
check_mode deny default 'pct shutdown 105; shutdown -h now'
check_mode deny default 'ssh root@h "qm shutdown 100 && shutdown now"'
check_mode deny default 'pct exec 105 -- shutdown -h now'

# --- a guest that has never run ---------------------------------
# AGENTS.md -> Critical Safety Rules lets the first-boot
# configuration of a guest that never started set sshd's login
# options and keys. The guard cannot prove a root filesystem
# belongs to such a guest, so it asks for the two shapes a manager
# owns and denies everything else. hostwarden-new-guest writes
# these files; references/lxc.md and references/image-prep.md are
# where they come from.
FB_LXC=/var/lib/lxc/web4/rootfs/etc/ssh/sshd_config.d/10-hostwarden.conf
FB_IMG=/var/lib/libvirt/images/web1.qcow2
check deny "scp 10-hostwarden.conf root@h:$FB_LXC"
check_mode ask default "scp 10-hostwarden.conf root@h:$FB_LXC"
check_mode ask default "rsync a.conf root@h:/var/lib/machines/web4/etc/ssh/sshd_config.d/"
check_mode ask default "tee $FB_LXC"
check_mode ask default "sed -i s/x/y/ /var/lib/lxc/web4/rootfs/etc/ssh/sshd_config"
check_mode ask default "rm /var/lib/lxc/web4/rootfs/etc/ssh/ssh_host_ed25519_key"
check_mode ask default \
  "virt-customize -a $FB_IMG --copy-in 10-hostwarden.conf:/etc/ssh/sshd_config.d"
check_mode ask default \
  "guestfish --rw -a $FB_IMG -i write /etc/ssh/sshd_config.d/10-hostwarden.conf x"
# Where no prompt reaches a human, the answer is deny, as it is
# for stopping a guest.
for m in acceptEdits plan auto; do
  check_mode ask "$m" "scp 10-hostwarden.conf root@h:$FB_LXC"
done
for m in bypassPermissions dontAsk bogus; do
  check_mode deny "$m" "scp 10-hostwarden.conf root@h:$FB_LXC"
done
# The running system is never one of these, whatever it is called.
# /mnt is the live system as often as it is an image, one
# unqualified path beside a qualified one is still the host, and
# -d names a libvirt guest that may be running.
check_mode deny default "cp 10-hostwarden.conf /etc/ssh/sshd_config.d/10-hostwarden.conf"
check_mode deny default "cp 10-hostwarden.conf /mnt/etc/ssh/sshd_config.d/x.conf"
check_mode deny default "rm /etc/ssh/ssh_host_ed25519_key"
check_mode deny default \
  "scp a.conf root@h:$FB_LXC b.conf root@h:/etc/ssh/sshd_config.d/b.conf"
check_mode deny default \
  "virt-customize -d web1 --copy-in 10-hostwarden.conf:/etc/ssh/sshd_config.d"
# The image branch holds for one invocation alone: a second command
# or a redirect beside it spells the host's /etc/ssh the same way.
check_mode deny default \
  "guestmount -a $FB_IMG -i /mnt/x && cp a.conf /etc/ssh/sshd_config.d/b.conf"
check_mode deny default \
  "virt-customize -a $FB_IMG --copy-in x:/etc/ssh/sshd_config.d > /etc/ssh/sshd_config"
check_mode deny default \
  "virt-customize -a $FB_IMG --copy-in x:/etc/ssh/sshd_config.d; rm /etc/ssh/sshd_config"
# virt-edit and virt-copy-in write with no verb on the line.
check_mode ask default "virt-edit -a $FB_IMG /etc/ssh/sshd_config -e s/a/b/"
check_mode ask default "virt-copy-in -a $FB_IMG 10.conf /etc/ssh/sshd_config.d"
check_mode deny default "virt-edit -d web1 /etc/ssh/sshd_config -e s/a/b/"
# The local side of --copy-in and --upload is only read: the host's
# sshd_config copied into an image elsewhere is no write to sshd's
# config. The image side under /etc/ssh still asks, and a host write
# beside it is still denied.
check_mode pass default "virt-customize -a $FB_IMG --copy-in /etc/ssh/sshd_config:/tmp"
check_mode pass default \
  "virt-customize -a $FB_IMG --upload /etc/ssh/sshd_config:/root/sshd_config.host"
check_mode ask default \
  "virt-customize -a $FB_IMG --copy-in /etc/ssh/sshd_config.d/x.conf:/etc/ssh/sshd_config.d"
check_mode ask default \
  "virt-customize -a $FB_IMG --copy-in=10.conf:/etc/ssh/sshd_config.d"
check_mode ask default \
  "virt-customize -a $FB_IMG --copy-in /etc/ssh/sshd_config:/etc/ssh"
check_mode deny default \
  "virt-customize -a $FB_IMG --copy-in /etc/ssh/sshd_config:/tmp; cp a /etc/ssh/sshd_config"
# The ask is decided last: a taboo anywhere after a first-boot write
# in the same line is still that taboo's deny.
check_mode deny default \
  "scp a.conf root@h:$FB_LXC && cp k /root/.ssh/authorized_keys"
check_mode deny default "scp a.conf root@h:$FB_LXC; ansible-playbook site.yml"
check_mode deny default \
  "scp a.conf root@h:$FB_LXC; terraform apply -auto-approve"
check_mode deny default "scp a.conf root@h:$FB_LXC; tofu destroy"
check_mode deny default \
  "rm /var/lib/lxc/web4/rootfs/etc/ssh/ssh_host_ed25519_key; ansible-playbook site.yml"
# virt-sysprep deletes host keys by default without naming a path.
check_mode ask default "virt-sysprep -a $FB_IMG"
check_mode ask default "virt-sysprep -a $FB_IMG --operations machine-id"
check_mode deny bypassPermissions "virt-sysprep -a $FB_IMG"
check_mode deny default "virt-sysprep -d web1"
check_mode deny default "virt-sysprep -a $FB_IMG; ansible-playbook site.yml"
check_mode deny default "virt-sysprep -a $FB_IMG && cat /etc/hostname"
# A key further down a guest root than /etc/ssh is not covered.
check_mode deny default "rm /var/lib/lxc/web4/rootfs/root/.ssh/authorized_keys"
check_mode deny default "rm /var/lib/lxc/web4/rootfs/../../../../etc/ssh/ssh_host_ed25519_key"
# Reading stays reading, and the seed the guest actually reads is
# not sshd's config at all.
check pass "cat /var/lib/lxc/web4/rootfs/etc/ssh/sshd_config"
check pass "scp user-data root@h:/var/lib/lxc/web4/rootfs/var/lib/cloud/seed/nocloud-net/user-data"
check pass "virt-customize -a $FB_IMG --copy-in 90-hostwarden.cfg:/etc/cloud/cloud.cfg.d"
# One prompt names every reason the line holds, each once: a guest
# stopped beside a first-boot write, a key change beside an sshd
# write in the same guest, and a storage change beside a guest.
for pair in \
  "pct stop 105; scp a.conf root@h:$FB_LXC|stopping or deleting|for a guest that has not started" \
  "rm /var/lib/lxc/web4/rootfs/etc/ssh/ssh_host_ed25519_key; tee $FB_LXC|re-permissioning SSH keys|writing sshd's configuration" \
  "zpool replace tank sdb sdd; pct stop 105|this storage change|stopping or deleting"
do
  c=${pair%%|*} rest=${pair#*|}
  OUT=$(json_for "$c" Bash default \
    | env -u HOSTWARDEN_GUARD_DISABLE sh "$HOOK")
  for w in "${rest%%|*}" "${rest#*|}"; do
    case "$OUT" in
    *'"permissionDecision":"ask"'*"$w"*) PASS=$((PASS + 1)) ;;
    *) FAIL=$((FAIL + 1)); echo "FAIL: the combined ask lost: $w in $c" ;;
    esac
  done
done

# --- storage: repair and destroy denied, changes asked ----------
# rules/storage.md's three tiers. The repair-and-destroy tier is a
# taboo in every mode; the change tier is asked where a prompt can
# reach a human, like a guest stopped, and denied where none can;
# the read tier and every dry run pass.
check deny 'fsck /dev/sdb1'
check deny 'fsck -y /dev/sdb1'
check deny 'fsck.ext4 -p /dev/sdb1'
check deny 'e2fsck -fy /dev/sdb1'
check deny 'xfs_repair /dev/sdb1'
check deny 'xfs_repair -L /dev/sdb1'
check deny 'fsck_ffs -y /dev/ada0p2'
check deny 'dosfsck -a /dev/sdc1'
check_mode deny default 'ntfsfix /dev/sdb1'
check_mode deny default 'ntfsfix -d /dev/sdb1'
check deny 'ssh root@nas1.example.com "e2fsck -f -y /dev/md2"'
check deny 'fsck -N /dev/sdb1; fsck -y /dev/sdb1'
check deny 'btrfs check --repair /dev/sdb1'
check deny 'btrfs check --init-csum-tree /dev/sdb1'
check deny 'btrfs c --repair /dev/sdb1'
check deny 'btrfsck --repair /dev/sdb1'
check deny 'btrfs rescue zero-log /dev/sdb1'
check deny 'btrfs resc super-recover /dev/sdb1'
check deny 'btrfs -q rescue chunk-recover /dev/sdb1'
check deny 'debugfs -w /dev/sdb1'
check deny "debugfs -w -R 'rm /x' /dev/sdb1"
check deny 'mdadm --create /dev/md0 --level=1 --raid-devices=2 /dev/sdb1 /dev/sdc1'
check deny 'mdadm -Cv /dev/md0 -l1 -n2 /dev/sdb1 /dev/sdc1'
check deny 'mdadm --grow /dev/md0 --raid-devices=3'
check deny 'mdadm --zero-superblock /dev/sdb1'
check deny 'mdadm --assemble --force /dev/md0 /dev/sdb1 /dev/sdc1'
check deny 'mdadm --force --assemble /dev/md0'
check deny 'mdadm -A -f /dev/md0'
check deny 'mdadm -Af /dev/md0'
check deny 'mdadm --assemble /dev/md0 --update=resync'
check deny 'mdadm --action=repair /dev/md0'
check deny 'mdadm --action resync /dev/md0'
check deny 'echo repair > /sys/block/md0/md/sync_action'
check deny 'echo resync | tee /sys/block/md0/md/sync_action'
check deny 'ssh root@nas1.example.com "echo repair >/sys/block/md2/md/sync_action"'
check deny 'lvconvert --repair vg0/raid'
check deny 'lvconvert --repair vg0/thinpool'
check_mode deny default 'lvconvert --repair -y vg0/raid'
check deny 'pvcreate /dev/sdb'
check deny 'pvremove /dev/sdb'
check deny 'vgremove vg0'
check deny 'lvremove -y vg0/data'
check deny 'lvm lvremove vg0/data'
check deny 'lvreduce -L 10G vg0/data'
check deny 'lvresize -L -5G vg0/data'
check deny 'lvresize -L-5G vg0/data'
check deny 'lvresize --size -5G vg0/data'
check deny 'lvresize -y -L 10G vg0/data'
check deny 'lvresize -l 50%VG vg0/data'
check deny 'lvresize -L10G vg0/data'
check_mode deny default 'lvresize --size 10G vg0/data'
check_mode deny default 'lvresize -rL 10G vg0/data'
check_mode deny default 'lvresize -rl 50%VG vg0/data'
check_mode ask default 'lvresize -rL +10G vg0/data'
check_mode deny default 'midclt call pool.dataset.delete tank/x'
check_mode deny default "midclt call pool.export 1 '{\"destroy\": true}'"
check_mode deny default "midclt -U api-write call pool.export 1 '{\"cascade\": true, \"destroy\": true}'"
check_mode deny default 'ssh root@nas1.example.com midclt call pool.dataset.delete tank/x'
check deny 'vgcfgrestore vg0'
check deny 'zpool create tank mirror /dev/sdb /dev/sdc'
check deny 'zpool create -f tank /dev/sdb'
check deny 'zpool destroy tank'
check deny 'zpool labelclear -f /dev/sdb1'
check deny 'zpool import -F tank'
check deny 'zpool import -FX tank'
check deny 'zpool import -T 12345 tank'
check deny 'zpool import -f -F tank'
check deny 'zpool clear -F tank'
check deny 'zinject -d /dev/sdb -e io tank'
check deny 'zfs destroy tank/data'
check deny 'zfs destroy -r tank/data'
check deny 'zfs destroy "tank/data"'
check deny 'zfs destroy -R tank/data@snap'
check deny 'zfs destroy -rR tank/data@snap'
check deny 'zfs rollback -R tank/data@snap'
check_mode deny default 'zfs rollback -rR tank/data@snap'
check deny 'btrfs subvolume delete /mnt/data'
check deny 'btrfs sub del -c /mnt/data'
check deny 'btrfs -q subvolume delete /mnt/@home'
check_mode deny default 'btrfs su d /mnt/data'
check deny 'ssh root@nas1.example.com "zfs destroy -r tank/home"'
check deny 'midclt call disk.wipe sdb FULL'
check deny 'midclt call -job disk.wipe sdb QUICK'
check deny 'midclt call pool.create x'
check deny 'midclt -U api-write call disk.wipe sdb FULL'
check deny 'midclt -u ws://localhost/websocket call disk.wipe sdb FULL'
check deny "midclt call 'pool.create' x"
check deny 'zpool import --rewind-to-checkpoint tank'
check deny 'zpool import -m tank'
check deny 'pvck --repair -f meta.txt /dev/sdb'
check deny 'vgck --updatemetadata vg0'
check deny 'btrfs --format json check --repair /dev/sdb1'
check deny 'btrfs --log info rescue zero-log /dev/sdb1'
check deny 'diskutil repairVolume disk3s1'
check deny 'diskutil repairdisk disk3'
check deny 'ssh win1.example.com chkdsk D: /f /x'
check deny 'ssh win1.example.com "chkdsk C: /offlinescanandfix"'
check deny 'ssh win1.example.com Repair-Volume -DriveLetter D -OfflineScanAndFix'
check deny 'ssh win1.example.com "Get-Help Repair-Volume; Repair-Volume -DriveLetter D -SpotFix"'
check_mode deny default 'midclt call "disk.wipe" sdb FULL'
# The taboo tier denies in the modes that would otherwise ask.
check_mode deny default 'zpool destroy tank'
check_mode deny auto 'e2fsck -fy /dev/sdb1'
# Asked: routine changes on a healthy host.
for c in 'lvextend -r -L +10G vg0/root' 'lvcreate -L 10G -n data vg0' \
  'lvresize -L +5G vg0/data' 'lvresize --size=+5G vg0/data' \
  'lvresize -l +100%FREE vg0/data' 'vgextend vg0 /dev/sdc' \
  'vgcreate vg1 /dev/sdd' 'pvmove /dev/sdb' 'pvresize /dev/sda3' \
  'lvconvert --merge vg0/snap' 'vgreduce vg0 /dev/sdb' \
  'mdadm /dev/md0 --add /dev/sdc1' \
  'mdadm --manage /dev/md0 --fail /dev/sdb1' \
  'mdadm /dev/md0 -f /dev/sdb1' 'mdadm /dev/md0 -r /dev/sdb1' \
  'mdadm --stop /dev/md0' \
  'mdadm /dev/md0 --replace /dev/sdb1 --with /dev/sdc1' \
  'zpool replace tank /dev/sdb /dev/sdd' 'zpool attach tank sdb sdc' \
  'zpool detach tank sdc' 'zpool offline tank sdb' \
  'zpool online -e tank sdb' 'zpool add tank mirror sdd sde' \
  'zpool remove tank sdd' 'zpool split tank tank2' \
  'zpool upgrade tank' 'zpool upgrade -a' \
  'zpool import tank' 'zpool import -d /dev/disk/by-id tank' \
  'zpool import -a' 'zpool import -f -o altroot=/mnt tank' \
  'zpool export tank' \
  'zpool scrub tank' 'zpool scrub -e tank' \
  'btrfs scrub start /mnt' 'btrfs scrub resume /mnt' 'btrfs sc star /mnt' \
  'zfs destroy tank/data@2026-09-01' 'zfs destroy -r tank/data@auto' \
  'zfs destroy tank/data#bm' 'zfs rollback -r tank/data@snap' \
  'zfs receive -F tank/backup' 'zfs receive tank/backup' \
  'zfs send tank/data@s | zfs recv tank/copy' \
  'zfs send tank/data@s | ssh root@nas2.example.com zfs recv -F tank/data' \
  'btrfs device add /dev/sdc /mnt' 'btrfs device remove /dev/sdb /mnt' \
  'btrfs dev del /dev/sdb /mnt' \
  'btrfs replace start /dev/sdb /dev/sdc /mnt' \
  'btrfs balance start -dconvert=raid1 -mconvert=raid1 /mnt' \
  'midclt call pool.export 1' "midclt call pool.export 1 '{\"cascade\": true}'"
do
  check_mode ask default "$c"
done
# Without a permission mode no prompt can reach a human.
check deny 'lvextend -r -L +10G vg0/root'
check deny 'zfs destroy tank/data@2026-09-01'
check_mode ask auto 'zpool replace tank sdb sdd'
check_mode ask default 'zpool upgrade -V 5000 tank'
check_mode pass default 'lvextend -h'
check_mode ask default 'midclt call -job vm.stop 1'
check_mode ask default 'midclt -U api-write call vm.stop 1'
check_mode ask default "midclt call 'pool.export' 1"
check_mode deny bypassPermissions 'lvextend -L +1G vg0/root'
check_mode deny dontAsk 'mdadm /dev/md0 --add /dev/sdc1'
# A taboo in the same command still wins over the ask.
check_mode deny default 'zpool replace tank sdb sdd; zpool destroy tank'
check_mode deny default 'lvextend -L +1G vg0/x && mkfs.ext4 /dev/vg0/x'
check_mode deny default 'mdadm /dev/md0 --add /dev/sdc1; e2fsck -y /dev/md0'
# Read and dry runs pass. The default mode is the one that would
# show an ask, so it catches a read the change tier took in.
for c in 'fsck -N /dev/sdb1' 'e2fsck -n /dev/sdb1' 'e2fsck -fn /dev/sdb1' \
  'ntfsfix -n /dev/sdb1' 'ntfsfix --no-action /dev/sdb1' \
  'zfs receive -n tank/backup' \
  'xfs_repair -n /dev/sdb1' 'fsck_ffs -n /dev/ada0p2' \
  'btrfs check /dev/sdb1' 'btrfs check --readonly /dev/sdb1' \
  'btrfs device stats /mnt' 'btrfs filesystem show' \
  'btrfs balance status /mnt' 'btrfs rescue --help' \
  'debugfs -R stats /dev/sdb1' 'mdadm --detail /dev/md0' \
  'mdadm -D /dev/md0' 'mdadm --examine /dev/sdb1' \
  'mdadm --detail --scan' 'cat /proc/mdstat' 'pvs' 'vgs -o +vg_free' \
  'lvs -a' 'lvdisplay vg0/data' 'pvscan' 'lvremove --test vg0/data' \
  'lvextend -t -L +1G vg0/root' 'lvextend --help' 'zpool status -x' \
  'zpool status -g tank' 'zpool list -H -o name,health' 'zpool import' \
  'zpool import -Fn tank' 'zpool create -n tank /dev/sdb' \
  'zpool import -d /dev/disk/by-id' 'zpool import -D' \
  'ssh win1.example.com Get-Help Repair-Volume -Examples' \
  'ssh win1.example.com Get-Command Repair-Volume' \
  'zpool upgrade' 'zpool upgrade -v' 'zpool history tank' \
  'zpool scrub -s tank' 'zpool scrub -p tank' 'btrfs scrub status /mnt' \
  'btrfs scrub cancel /mnt' 'mdadm --action=check /dev/md0' \
  'btrfs subvolume list /mnt' 'btrfs subvolume show /mnt/data' \
  'btrfs subvolume snapshot -r /mnt/data /mnt/.snap/x' \
  'zfs destroy -n -R tank/data@snap' \
  'echo check > /sys/block/md0/md/sync_action' \
  'cat /sys/block/md0/md/sync_action' \
  'zpool add -n tank sdd' 'zfs list -t snapshot' \
  'zfs snapshot tank/data@before' 'zfs get compression tank' \
  'zfs destroy -n tank/data' 'zfs destroy -nv tank/data@snap' \
  'zdb -C tank' 'midclt call pool.query' 'midclt call disk.query' \
  'pvck /dev/sdb' 'vgck vg0' 'diskutil verifyVolume disk3s1' \
  'ssh win1.example.com chkdsk D:' \
  'ssh win1.example.com Repair-Volume -DriveLetter D -Scan' \
  'btrfs --format json filesystem show' \
  'journalctl -u systemd-fsck-root' \
  'systemctl status systemd-fsck-root.service'
do
  check_mode pass default "$c"
done

# --- SSH keys destroyed without rm/shred/unlink ----------------
check deny 'echo "" > /root/.ssh/authorized_keys'
check deny ': > /etc/ssh/ssh_host_ed25519_key'
check deny 'truncate -s 0 /root/.ssh/authorized_keys'
check deny 'mv /root/.ssh/authorized_keys /tmp/'
check deny 'chmod 000 /root/.ssh/authorized_keys'
check deny 'chown nobody /etc/ssh/ssh_host_rsa_key'
check deny 'ssh-keygen -q -N "" -f /etc/ssh/ssh_host_rsa_key'

# --- writes INTO a protected path (writes_to) ------------------
# A copy is judged by its destination: a key, ~/.ssh or a disk as
# the SOURCE is a read.
check deny 'echo x | tee /root/.ssh/authorized_keys'
check deny 'tee -a /home/alice/.ssh/authorized_keys < new.pub'
check deny 'cp /tmp/new /root/.ssh/authorized_keys'
check deny 'cp /tmp/new /root/.ssh/authorized_keys 2>/dev/null'
check deny 'cp /tmp/new /root/.ssh/authorized_keys 2>&1 | tee cp.log'
check deny 'cp -v /tmp/new "/root/.ssh/authorized_keys"'
check deny 'tee /tmp/copy /root/.ssh/authorized_keys < new.pub'
check deny 'rsync -e "ssh -i ~/.ssh/id_ed25519" keys h:/root/.ssh/authorized_keys'
check deny 'cp -f /tmp/id_ed25519 /root/.ssh/'
check deny 'cp -t /root/.ssh authorized_keys'
check deny 'rsync -a /backup/ssh/ /root/.ssh/'
check deny 'rsync --delete /tmp/empty/ /root/.ssh'
check deny 'scp keys root@h:/root/.ssh/authorized_keys'
check deny 'ssh root@h "cp /tmp/new /root/.ssh/authorized_keys && echo ok"'
check deny 'dd if=/dev/zero of=/etc/ssh/ssh_host_ed25519_key count=1'
check deny 'curl -fsS https://example.com/u.keys -o /root/.ssh/authorized_keys'
check deny 'wget -O ~/.ssh/authorized_keys https://example.com/u.keys'
check deny "sed -i '/old/d' /root/.ssh/authorized_keys"
check deny "sed -ni '1p' /root/.ssh/authorized_keys"
check deny 'vi /root/.ssh/authorized_keys'
check deny 'sort -u keys | sponge /root/.ssh/authorized_keys'
check deny 'setfacl -m u:bob:rw /root/.ssh/authorized_keys'
check deny 'find /home/alice/.ssh -name "id_*" -delete'
check deny '(cp /tmp/new /root/.ssh/authorized_keys)'
check deny 'echo $(cp /tmp/new /root/.ssh/authorized_keys)'
check deny 'cp /tmp/new /root/.ssh/authorized_keys # new key'
check deny 'cp -rt ~/.ssh keys'
check deny 'rsync --remove-source-files ~/.ssh/id_ed25519 /backup/'
check deny 'cp image.iso /dev/sdb'
check deny 'curl -fsS -o /dev/sdb https://example.com/img'
check deny 'tee /tmp/copy /dev/sdb < img'
check deny 'dd if=new.conf of=/etc/ssh/sshd_config'
check deny 'sort -u new.conf | sponge /etc/ssh/sshd_config'
check deny 'curl -o /etc/ssh/sshd_config.d/10-x.conf https://example.com/c'
check deny 'rsync new.conf h:/etc/ssh/sshd_config'
# Accepted false positive; see the list in the guard header.
check deny 'rsync -a site/ h:/var/www/ -e "ssh -i ~/.ssh/id_ed25519"'
check pass 'cp /root/.ssh/authorized_keys /root/backup/'
check pass 'cp /root/.ssh/id_ed25519 /root/.ssh/id_ed25519.bak'
check pass 'cp /tmp/new /tmp/x; cat /root/.ssh/authorized_keys'
check pass 'ssh -o BatchMode=yes root@h "cat /root/.ssh/authorized_keys"'
check pass 'cp /tmp/config /home/alice/.ssh/config'
check pass 'cp -a /root/.ssh /backup/root-ssh'
check pass 'scp -i ~/.ssh/id_ed25519 report.txt root@h:/tmp/'
check pass 'rsync -e "ssh -i ~/.ssh/id_ed25519" -a site/ h:/var/www/'
check pass 'ssh -o IdentityFile=~/.ssh/id_ed25519 root@h uptime'
check pass 'dd if=/root/.ssh/id_ed25519 of=/tmp/copy bs=1'
check pass 'ssh-keyscan h | tee -a ~/.ssh/known_hosts'
check pass 'curl -o /tmp/u.keys https://example.com/u.keys; wc -l /root/.ssh/authorized_keys'
check pass 'grep -i ed25519 /root/.ssh/authorized_keys | sed "s/ .*//"'
check pass 'ssh -i ~/.ssh/id_ed25519 root@h "sed -i s/a/b/ /etc/app.conf"'
check pass 'ssh -i ~/.ssh/id_ed25519 root@h "vim --version"'
check pass 'rsync -a --delete /root/.ssh/ /backup/root-ssh/'
check pass 'cp /dev/sda /root/disk.img'
check pass 'curl -o /tmp/sshd_config.new https://example.com/c'

# --- SSH keys reached through their directory (issue #7) -------
# The protected paths were key FILENAMES, so any operation on the
# enclosing .ssh directory reached every key in it without naming
# one. chmod 600 ~/.ssh/authorized_keys was denied while the
# recursive chown that does strictly more was not.
check deny 'chown -R alice:alice /home/alice/.ssh'
check deny 'chmod -R 700 /root/.ssh'
check deny 'chmod 000 /root/.ssh'
check deny 'rm -rf /home/alice/.ssh'
check deny 'mv /root/.ssh /root/.ssh.bak'
check deny 'install -d -m 700 -o alice -g alice /home/alice/.ssh'
check deny 'ssh -o BatchMode=yes root@h "chown -R alice:alice /home/alice/.ssh"'
# The exact shape that exposed this: the spelled-out chmod is
# denied, so the recursive form must not be the way around it.
check deny 'chown -R alice:alice /home/alice/.ssh && chmod 700 /home/alice/.ssh'
# Same reach through an interpreter, which names no key either.
check deny "python3 -c \"import shutil; shutil.rmtree('/root/.ssh')\""
check deny "node -e \"require('fs').chmodSync('/home/alice/.ssh', 0)\""

# --- same effect through an interpreter (issue #6) -------------
# The path rules recognized a write by the way it was spelled
# (redirect, tee, sed -i, an editor, rm/mv/chmod). An interpreter
# spells none of those and writes through plain file I/O.
check deny "python3 -c \"open('/etc/ssh/sshd_config','a').write('PermitRootLogin yes')\""
check deny "python3.11 -c \"open('/etc/ssh/sshd_config','w')\""
check deny "node -e \"require('fs').appendFileSync('/etc/ssh/sshd_config','X')\""
check deny "perl -e 'open(F,\">\",\"/etc/ssh/sshd_config\")'"
check deny "ruby -e \"File.write('/etc/ssh/sshd_config','')\""
check deny "awk 'BEGIN{printf \"\" > f}' f=/etc/ssh/sshd_config"
check deny "python3 -c \"import os; os.remove('/root/.ssh/authorized_keys')\""
check deny "node -e \"require('fs').unlinkSync('/root/.ssh/authorized_keys')\""
check deny "python3 -c \"open('/etc/ssh/ssh_host_ed25519_key','w').write('')\""
check deny "ruby -e \"File.unlink('/root/.ssh/id_ed25519')\""
check deny "ssh -o BatchMode=yes root@h \"python3 -c \\\"open('/etc/ssh/sshd_config','a')\\\"\""
# Raw devices are the same hole with worse consequences, and the
# original report did not cover them.
check deny "python3 -c \"open('/dev/sda','wb').write(b'0'*4096)\""
check deny "perl -e 'open(D,\">\",\"/dev/nvme0n1\"); print D chr(0)'"
check deny "node -e \"require('fs').writeFileSync('/dev/vda','')\""

# --- SSH connection sharing (rules/ssh-connections.md) ---------
# Hostwarden's control socket must not read as key material, or
# every remote rm/mv/chmod sent with the standard options is
# denied (see the accepted false positives in the guard).
check pass 'ssh -o ControlMaster=auto -o ControlPath=~/.cache/hostwarden/ssh-%C root@h "rm -f /var/tmp/old.log; chmod 644 /etc/motd"'

# --- Windows, as WSL reaches it --------------------------------
check deny 'shutdown.exe /s /t 0'
check deny 'shutdown.exe -s -t 0'
check deny 'Shutdown.exe /s /t 0'
check deny 'SHUTDOWN.EXE /p'
check deny 'shutdown -h now /r'
check deny 'shutdown -h now -a'
check deny 'MBR2GPT.EXE /convert'
check deny 'powershell.exe -Command Stop-Computer'
check deny 'pwsh.exe -c "stop-computer -Force"'
check deny 'wsl.exe --shutdown'
check deny 'wsl --terminate Ubuntu'
check deny 'WSL.EXE -t Ubuntu'
check deny 'wsl.exe --unregister Ubuntu'
check deny 'wslconfig.exe /t Ubuntu'
check deny 'wslconfig.exe /unregister Ubuntu'
check deny 'WslConfig /u Ubuntu'
check deny '"wsl.exe" --unregister Ubuntu'
check deny '"/mnt/c/Windows/System32/wsl.exe" --shutdown'
check deny 'cmd.exe /c format "D:" /q'
check deny 'rm -rf /mnt/c/ProgramData/ssh'
check deny 'chmod -R 000 /mnt/c/ProgramData/ssh/'
check deny 'echo x > /mnt/c/ProgramData/ssh/SSHD_CONFIG'
check deny ': > /mnt/c/ProgramData/ssh/SSH_HOST_ED25519_KEY'
check deny 'echo ssh-ed25519 AAAA >> /mnt/c/ProgramData/ssh/Administrators_Authorized_Keys'
check deny 'diskpart'
check deny 'diskpart.exe /s wipe.txt'
check deny 'powershell.exe -c "Clear-Disk -Number 1 -RemoveData"'
check deny 'powershell.exe -c "Get-Disk 1 | Initialize-Disk -PartitionStyle GPT"'
check deny 'pwsh.exe -c "Format-Volume -DriveLetter D"'
check deny 'powershell.exe -c "Remove-Partition -DiskNumber 1 -PartitionNumber 2"'
check deny 'powershell.exe -c "Resize-Partition -DriveLetter C -Size 100GB"'
check deny 'mbr2gpt.exe /convert /allowFullOS'
check deny 'cmd.exe /c format D: /q'
check deny 'powershell.exe -c "Set-Content \\.\PhysicalDrive1 -Value 0"'
check deny 'cp image.bin //./PhysicalDrive1'
check deny 'powershell.exe -c "Remove-Item C:\ProgramData\ssh\ssh_host_ed25519_key"'
check deny 'powershell.exe -c "Add-Content C:\ProgramData\ssh\sshd_config Port"'
check deny 'echo PasswordAuthentication no >> /mnt/c/ProgramData/ssh/sshd_config'
check deny 'rm /mnt/c/ProgramData/ssh/ssh_host_rsa_key'
check deny 'rm /mnt/c/programdata/ssh/ssh_host_rsa_key'
check deny 'pwsh.exe -c "Remove-Item $HOME\.ssh\id_ed25519"'
check deny 'powershell.exe -c "Set-Content C:\ProgramData\ssh\administrators_authorized_keys x"'
# Over SSH a Windows server runs cmd and PowerShell verbs without
# either being named.
check deny 'ssh host "del C:\ProgramData\ssh\sshd_config"'
check deny 'ssh host "ERASE C:\ProgramData\ssh\sshd_config"'
check deny 'ssh host "del /f /q C:\ProgramData\ssh\ssh_host_ed25519_key"'
check deny "ssh host 'del \"C:\\ProgramData\\ssh\\sshd_config\"'"
check deny 'ssh host "rd /s /q C:\ProgramData\ssh"'
check deny 'ssh host "move C:\ProgramData\ssh\sshd_config C:\tmp\x"'
check deny 'ssh host "ren C:\ProgramData\ssh\sshd_config old"'
check deny 'ssh host "copy /y C:\tmp\x C:\ProgramData\ssh\ssh_host_ed25519_key"'
check deny 'ssh host "xcopy C:\tmp\x C:\ProgramData\ssh\sshd_config"'
check deny 'ssh host "takeown /f C:\ProgramData\ssh\sshd_config"'
check deny 'ssh host "attrib +r C:\ProgramData\ssh\sshd_config"'
check deny 'ssh host "icacls C:\ProgramData\ssh\ssh_host_ed25519_key /grant Users:F"'
check deny 'ssh host "icacls C:\ProgramData\ssh\sshd_config /reset"'
check deny 'ssh host "Remove-Item -Recurse -Force C:\ProgramData\ssh"'
check deny 'ssh host "ri C:\ProgramData\ssh\sshd_config"'
check deny 'ssh host "Move-Item C:\ProgramData\ssh\sshd_config C:\tmp"'
check deny 'ssh host "Rename-Item C:\ProgramData\ssh\sshd_config old"'
check deny 'ssh host "Set-Content C:\ProgramData\ssh\sshd_config x"'
check deny 'ssh host "Clear-Content C:\ProgramData\ssh\sshd_config"'
check deny 'ssh host "Copy-Item C:\tmp\x C:\ProgramData\ssh\sshd_config"'
check deny 'ssh host "gci C:\ProgramData\ssh\ssh_host_* | ri"'
check deny 'ssh host "Get-ChildItem C:\ProgramData\ssh | Remove-Item -Force"'
check deny 'del /mnt/c/ProgramData/ssh/sshd_config'
check pass 'ssh host "type C:\ProgramData\ssh\sshd_config"'
check pass 'ssh host "Get-Content C:\ProgramData\ssh\sshd_config"'
check pass 'ssh host "dir C:\ProgramData\ssh"'
check pass 'ssh host "icacls C:\ProgramData\ssh\ssh_host_ed25519_key"'
check pass 'ssh host "findstr Port C:\ProgramData\ssh\sshd_config"'
check pass 'ssh host "Get-Acl C:\ProgramData\ssh\sshd_config | Format-List"'
check pass 'ssh host "Get-Service sshd; Get-Content C:\ProgramData\ssh\sshd_config"'
check pass 'ssh host "del C:\ProgramData\ssh-backups\old.txt"'
check pass 'ssh host "Set-Content C:\ProgramData\ssh_notes\report.txt x"'
check pass 'ssh host "del C:\ProgramData\ssh.old\report.txt"'
check pass 'ssh host "dir C:\ProgramData\ssh>NUL"'
# The directory followed by the shell's punctuation is still it.
check deny 'ssh host "rd /s /q C:\ProgramData\ssh>NUL"'
check deny 'ssh host "(Remove-Item -Recurse -Force C:\ProgramData\ssh)"'
check deny 'ssh host "gci C:\ProgramData\ssh| ri"'
check pass 'shutdown.exe /r /t 0'
check pass 'shutdown.exe /a'
check pass 'Shutdown.exe -r -t 0'
check pass 'MBR2GPT.EXE /Validate /AllowFullOS'
check pass 'powershell.exe -c Restart-Computer'
check pass 'wsl.exe --list --verbose'
check pass 'wslconfig.exe /l'
check pass 'wsl.exe -u root -e apt-get update'
check pass 'wsl.exe -d Ubuntu -- ls -t /var/log'
check pass 'powershell.exe -c "Get-Disk; Get-Partition; Get-Volume"'
check pass 'mbr2gpt.exe /validate /allowFullOS'
check pass 'cat /mnt/c/ProgramData/ssh/sshd_config'
check pass 'ls -l /mnt/c/ProgramData/ssh/'
check pass 'date +%Y-%m-%d --date=yesterday'
check pass 'git log --format="%h %s" -5'

# --- Windows Server, as SSH reaches it -------------------------
# The shape the Windows rules send: PowerShell in the body of a
# heredoc, which the guard scans because pwsh executes it.
PS_SSH='ssh -o BatchMode=yes -o ConnectTimeout=5 administrator@win1.example.com '\''pwsh -NoProfile -NonInteractive -Command -'\'' <<'\''EOS'\''
'
check deny 'shutdown /s /t 0'
check deny 'shutdown /p'
check deny 'shutdown /h'
check deny 'SHUTDOWN /P /F'
check deny 'shutdown /sg /t 0'
check deny 'shutdown.exe /h'
check deny 'shutdown /r /p'
check deny 'shutdown.exe /r /s'
check deny 'shutdown /r -h now'
check deny 'ssh administrator@win1.example.com shutdown /s /t 0'
check deny "${PS_SSH}shutdown /p
EOS"
check deny 'bcdedit /set {default} safeboot minimal'
check deny 'bcdedit /deletevalue {default} safeboot'
check deny 'bcdedit /v /set {default} testsigning on'
check deny 'bcdedit /enum; bcdedit /delete {ntldr}'
check deny 'BCDEdit.exe /default {current}'
check deny 'bcdedit /import C:\bcd.bak'
check deny 'C:\Windows\System32\bcdedit.exe /timeout 0'
check deny 'ssh administrator@win1.example.com "bcdedit /enum && bcdedit /bootsequence {fwbootmgr}"'
check deny "${PS_SSH}bcdedit /enum all
bcdedit /set {current} recoveryenabled No
EOS"
check deny 'cipher /w:C:\'
check deny 'cipher.exe /W:D:\data'
check deny 'cmd.exe /c "cipher /w:C:\temp"'
check deny "${PS_SSH}cipher /w:C:\\
EOS"
check deny 'powershell.exe -c "Remove-VirtualDisk Data01"'
check deny "${PS_SSH}Remove-VirtualDisk -FriendlyName Data01 -Confirm:\$false
EOS"
check deny "${PS_SSH}Get-StoragePool -FriendlyName Pool1 | Remove-StoragePool
EOS"
check deny "${PS_SSH}Get-Disk 1 | Clear-Disk -RemoveData
EOS"
check deny "${PS_SSH}Stop-Computer -Force
EOS"
check deny "${PS_SSH}Set-Content C:\\ProgramData\\ssh\\sshd_config 'Port 22'
EOS"
# A quote or backtick is dropped before the program sees its flag.
check deny 'bcdedit "/set" {default} safeboot minimal'
check deny 'bcdedit `/set {default} safeboot minimal'
check deny "bcdedit /enum '/delete' {ntldr}"
check deny 'cipher "/w:C:\"'
check deny "cipher.exe '/w' C:\\"
check deny 'shutdown /r "-h" now'
check deny 'shutdown /r "/p"'
check deny 'shutdown.exe /r "/s"'
check pass 'shutdown /r /t 0 /c "planned restart"'
check pass 'bcdedit /store "C:\Boot\BCD" /enum'
check pass 'shutdown /r /t 0'
check pass 'shutdown /g /t 0'
check pass 'shutdown /a'
check pass 'ssh administrator@win1.example.com shutdown /r /t 0'
check pass "${PS_SSH}shutdown /r /t 60 /d p:2:17
EOS"
check pass "${PS_SSH}Restart-Computer -Force
EOS"
check pass 'shutdown -r now'
check pass 'bcdedit'
check pass 'bcdedit /enum'
check pass 'bcdedit /enum all /v'
check pass 'bcdedit.exe /enum {current}'
check pass 'BCDEDIT /V'
check pass 'bcdedit /store C:\Boot\BCD /enum'
check pass 'ssh administrator@win1.example.com "bcdedit /enum active" 2>&1 | head -20'
check pass "${PS_SSH}bcdedit /enum firmware | Out-String
EOS"
check pass 'cipher'
check pass 'cipher /c secret.txt'
check pass 'cipher /u /n'
check pass "${PS_SSH}Get-Disk
Get-Partition
Get-Volume
Get-VirtualDisk
Get-StoragePool
EOS"
check pass 'ssh administrator@win1.example.com '\''cmd /c ver'\'''
# The OpenSSH DefaultShell value is Hostwarden's to set once the
# user approves; it is not a taboo.
check pass "${PS_SSH}Get-ItemProperty -Path HKLM:\\SOFTWARE\\OpenSSH -Name DefaultShell
EOS"
check pass "${PS_SSH}New-ItemProperty -Path HKLM:\\SOFTWARE\\OpenSSH -Name DefaultShell -Value 'C:\\Program Files\\PowerShell\\7\\pwsh.exe' -PropertyType String -Force
EOS"

# --- must pass -------------------------------------------------
check pass 'fdisk -l'
check pass 'sfdisk -l /dev/sda'
check pass 'sfdisk -d /dev/sda'
check pass 'gdisk -l /dev/sda'
check pass 'sgdisk -p /dev/sda'
check pass 'parted -l'
check pass 'gpart show ada0'
check pass 'gpart status'
check pass 'lsblk -f'
check pass 'diskutil list'
# Boot entries are outside the gate, and the hostwarden-os-install
# skill says so in plain words. Nothing here writes data, so every
# form stays allowed -- including the ones that change what boots.
check pass 'efibootmgr -v'
check pass 'efibootmgr -n 0003'
check pass 'efibootmgr -o 0003,0001,0000'
check pass 'efibootmgr -c -d /dev/sda -p 1 -L Debian -l /EFI/debian/shimx64.efi'
check pass 'efibootmgr -b 0003 -B'
check pass 'shutdown -r now'
check pass 'ssh root@h "shutdown -r now"'
check pass 'shutdown -c'
check pass 'shutdown -r -k now'
check pass 'shutdown -r --no-wall now'
check pass "shutdown -r '-k' now"
check pass '/sbin/shutdown -r -t 30 now'
check pass 'shutdown -r now; grep -h reboot /var/log/syslog'
check pass 'ssh -p 2222 root@h "shutdown -r now"'
check pass 'shutdown -c "maintenance is off"'
check pass 'shutdown -r now {a,b}'
# Brace expansion builds the flag: -{r,h} is -r -h.
check deny 'shutdown -r -{h,h} now'
check deny 'shutdown -r -{r,h} now'
check deny 'shutdown -r --{halt,x} now'
check deny 'shutdown -r {-h,-r} now'
check deny 'shutdown -r -{h..h} now'
check deny 'shutdown -r -{a..z} now'
check deny 'shutdown -r -{g..i..1} now'
check pass 'shutdown -r now; ls {1..3}'
# FreeBSD's -c takes a time and power cycles the machine.
check deny 'shutdown -c now'
check deny 'shutdown -c +5'
check deny '/sbin/shutdown -c 2359'
check deny 'shutdown -o -c now'
check deny 'shutdown -c "now"'
check deny 'ssh root@bsd "shutdown -c now"'
check pass 'mkswap /dev/sda2'
check pass 'rm /tmp/foo'
check pass 'systemctl restart nginx'
check pass 'pct list'
check pass 'pct status 105'
check pass 'pct reboot 105'
check pass 'incus restart web'
check pass 'incus exec web -- systemctl stop nginx'
check pass 'incus --project prod exec web -- systemctl stop nginx'
check pass 'pct exec 105 -- systemctl stop nginx'
check pass 'lxc-stop -n web -r'
check pass 'qm list'
check pass 'qm reboot 100'
check pass 'virsh list --all'
check pass 'virsh reboot web'
check pass 'virsh pool-destroy default'
check pass 'virsh net-destroy default'
check pass 'virsh dominfo web'
check pass 'incus snapshot delete web snap0'
check pass 'incus image delete abc123'
check pass 'pct delsnapshot 105 snap0'
check pass 'virsh vol-delete disk.qcow2 --pool default'
check pass 'pct exec 105 -- rm /tmp/old.log'
check pass 'incus exec web -- rm -rf /var/cache/apt/archives'
check pass 'docker stop web'
check pass 'xe vm-list is-control-domain=false'
check pass 'xe vm-disk-list vm=abc123'
check pass 'xe vm-reboot uuid=abc123'
check pass 'xe vm-param-list uuid=abc123'
check pass 'xe vdi-destroy uuid=abc123'
check pass 'xe sr-list'
check pass 'midclt call vm.query'
check pass 'midclt call vm.start 1'
check pass 'midclt call virt.instance.query'
check pass 'midclt call pool.dataset.query'
check pass 'midclt call vm.delete --help'
check pass 'incus delete --help'
check pass 'pct destroy --help'
check pass 'virsh shutdown --help'
check pass 'qm stop --help'
check pass 'xe vm-uninstall --help'
check pass 'lxc-stop -h'
check pass 'lxc-destroy --help'
check pass 'incus stop -h'
# Jail reads, starts and the help form pass.
check pass 'jls'
check pass 'jls -N'
check pass 'jls -n name path host.hostname'
check pass 'bastille list'
check pass 'bastille list all'
check pass 'iocage list'
check pass 'iocage list -l'
check pass 'iocage get -a web'
check pass 'iocage snaplist web'
check pass 'iocage snapshot -n snap0 web'
check pass 'bastille zfs web snapshot snap0'
check pass 'bastille start web'
check pass 'iocage start web'
check pass 'service jail start web'
check pass 'service jail status'
check pass 'jexec web service nginx stop'
check pass 'bastille cmd web service nginx stop'
check pass 'iocage exec web service nginx stop'
check pass 'jail -c web'
check pass 'sysrc jail_enable jail_list'
check pass 'bastille destroy --help'
check pass 'iocage stop -h'
check pass "jail -f /etc/jail.conf -e '|'"
check_mode pass default 'incus delete --help'
check_mode pass default 'pct destroy --help'
# The help form exempts its own invocation only.
check deny 'pct destroy --help; pct destroy 105'
check_mode ask default 'pct destroy --help && pct destroy 105'
check deny 'incus delete --help && incus delete web'
check_mode pass default 'pct list'
check_mode pass default 'incus exec web -- systemctl stop nginx'
check pass 'cat /etc/ssh/sshd_config'
check pass 'grep PermitRootLogin /etc/ssh/sshd_config'
check pass 'sshd -T'
check pass 'df -h'
check pass 'echo halting services'
check pass 'dd if=/dev/sda of=/root/disk-backup.img'
check pass 'uname -a'
check pass 'echo see HOSTWARDEN_GUARD_DISABLE in the docs'

# --- every code block the instruction layer ships passes -------
# The corpus is every place an instruction can carry a command, so
# a block stays covered when it moves between mechanisms. It is
# defined in corpus.sh, shared with instructions-test.sh, because
# two lists in one directory drift apart.
# A taboo word used as data in a documented probe is denied like
# the command itself and cancels the whole parallel batch. The
# security skill once skipped inert login shells by a regex of
# their names; the deny pins why that shape was retired. A block
# meant to be denied says so after the language on its fence:
# `operator` (the user runs it, Hostwarden never does) or `guard-off`
# (Hostwarden runs it only after the user relaunched with the
# override, so its file must say how). The file name in each
# block path keeps names unique when find starts awk twice.
check deny "awk -F: '(\$7 ~ /(nologin|false|sync|shutdown|halt)\$/)' /etc/passwd"

# shellcheck source=corpus.sh
. "$CLAUDE_DIR/hooks/corpus.sh"

BLOCKS=$(mktemp -d)
# CHANGELOG.md is scanned for identifiers but not for blocks: it
# records what a release changed, so a command it quotes is
# history, not something a session is told to run. Running it
# through the guard would fail CI for describing a past mistake
# accurately.
#
# Blocks are found by fenced() from corpus.sh, the parser the layout
# test uses: both fence characters, and a close only on a run at
# least as long as the opener. A prohibited command in a ~~~ block
# was once invisible to this matrix, which is the one place that
# cannot have a blind spot, and a ~~~~ block closed by nothing
# would sweep the next ordinary block into its exemption.
corpus_files | grep '\.md$' | grep -v '/CHANGELOG\.md$' \
  | tr '\n' '\0' | xargs -0 \
  awk -v dir="$BLOCKS" "$FENCE_AWK"'
  FNR == 1             { FM = ""; out = "" }
  { was = FM }
  !fenced($0)          { next }
  was == ""            { if (/[ \t](operator|guard-off)[ \t]*$/) next
                         f = FILENAME; gsub(/\//, "_", f); n++
                         # A long checkout path would pass the
                         # 255-byte limit on one file name.
                         if (length(f) > 150) f = substr(f, length(f) - 149)
                         out = dir "/" f "." n; next }
  FM == ""             { if (out) close(out); out = ""; next }
  out                  { print > out }
'
NBLOCKS=0
for blk in "$BLOCKS"/*; do
  [ -f "$blk" ] || continue
  NBLOCKS=$((NBLOCKS + 1))
  check pass "$(cat "$blk")"
done
rm -rf "$BLOCKS"
if [ "$NBLOCKS" -eq 0 ]; then
  FAIL=$((FAIL + 1))
  echo "FAIL: no code blocks found in the instruction corpus"
fi

# The OS-install references carry guard-off blocks by design, so
# finding none means the search broke, not that all is well.
NGUARDOFF=0
while read -r md; do
  [ -n "$md" ] || continue
  NGUARDOFF=$((NGUARDOFF + 1))
  if grep -q 'HOSTWARDEN_GUARD_DISABLE' "$md"; then
    PASS=$((PASS + 1))
  else
    FAIL=$((FAIL + 1))
    echo "FAIL: $md has guard-off blocks but never names" \
      "HOSTWARDEN_GUARD_DISABLE"
  fi
done <<EOF
$(corpus_files | grep '\.md$' | grep -v '/CHANGELOG\.md$' \
  | tr '\n' '\0' | xargs -0 grep -lE \
  '^[[:space:]]*(```|~~~).*[[:space:]]guard-off[[:space:]]*$')
EOF
if [ "$NGUARDOFF" -eq 0 ]; then
  FAIL=$((FAIL + 1))
  echo "FAIL: no guard-off blocks found in the instruction corpus"
fi

# --- the system-account probe fails closed ---------------------
# Printing only shells that end in sh passes the guard and misses
# every shell it does not know. The probe is read from the skill,
# and stripping its path makes awk read the fixture from stdin; a
# missing probe or one that stops ending in /etc/passwd fails.
PROBE=$(awk '/^## System Accounts with Login Shells/ { s = 1 }
  s && b && /^```$/ { exit }
  b { print }
  s && /^```bash$/ { b = 1 }' \
  "$SKILLS_DIR/hostwarden-security/references/user-accounts.md")
WANT="bash empty ksh postgres py root "
GOT=$(printf '%s\n' \
  'root:x:0:0:root:/root:/bin/bash' \
  'daemon:x:1:1:daemon:/usr/sbin:/usr/sbin/nologin' \
  'sync:x:4:65534:sync:/bin:/bin/sync' \
  'games:x:5:60:games:/usr/games:/bin/false' \
  'shutdown:x:6:0:shutdown:/sbin:/sbin/shutdown' \
  'halt:x:7:0:halt:/sbin:/sbin/halt' \
  'postgres:x:110:118::/var/lib/postgresql:/bin/bash' \
  'bash:x:990:990::/tmp:/bin/bash' \
  'ksh:x:991:991::/tmp:/bin/ksh93' \
  'py:x:992:992::/tmp:/usr/bin/python3' \
  'empty:x:993:993::/tmp:' \
  'alice:x:1000:1000::/home/alice:/usr/bin/zsh' \
  | sh -c "${PROBE%/etc/passwd}" | cut -d: -f1 | LC_ALL=C sort \
  | tr '\n' ' ')
if [ "$GOT" = "$WANT" ]; then
  PASS=$((PASS + 1))
else
  FAIL=$((FAIL + 1))
  echo "FAIL: system-account probe reported [$GOT], want [$WANT]"
fi

# --- read-only forms of the newly covered tools (issue #5) -----
check pass 'diskutil info disk0'
check pass 'diskutil apfs list'
check pass 'gpt show /dev/da0'
check pass 'parted /dev/sda print'
check pass 'parted /dev/sda unit MiB print'
check pass 'parted -m -l'
check pass 'sgdisk -p /dev/sda'
check pass 'sgdisk -i 1 /dev/sda'
check pass 'sgdisk -v /dev/sda'
check pass 'nvme list'
check pass 'nvme id-ctrl /dev/nvme0'
check pass 'nvme smart-log /dev/nvme0'
check pass 'badblocks -sv /dev/sda'
check pass 'hdparm -I /dev/sda'
check pass 'blockdev --getsize64 /dev/sda'
check pass 'shred -u /tmp/leftover.txt'
check pass 'wc -l /root/.ssh/authorized_keys'
check pass 'cp /etc/ssh/ssh_host_rsa_key.pub /tmp/'
check pass 'echo done > /dev/null'
check pass 'ssh-keygen -lf /etc/ssh/ssh_host_rsa_key.pub'
check pass 'growpart --dry-run /dev/sda 1'

# --- key probes deny each other when chained (rules/secrets.md) -
# Accepted false positive; see the list in the guard header.
check pass 'file /etc/ssh/ssh_host_ed25519_key'
check deny 'file /etc/ssh/ssh_host_ed25519_key; ssh-keygen -lf /etc/ssh/ssh_host_ed25519_key.pub'

# --- interpreters away from a protected target (issue #6) ------
# Only the combination is a taboo. An interpreter on its own,
# even writing files, is ordinary work and must stay usable.
check pass 'python3 --version'
check pass 'python3 -c "import json,sys; print(json.load(sys.stdin))"'
check pass "python3 -c \"open('/tmp/report.txt','w').write('x')\""
check pass 'node -e "console.log(process.version)"'
check pass 'python3 -m json.tool /etc/myapp/config.json'
check pass 'awk "/^worker_processes/ {print \$2}" /etc/nginx/nginx.conf'
check pass 'perl -pe "s/foo/bar/" /tmp/notes.txt'
check pass 'mix deps.get'
check pass 'ls -l /root/.ssh/'
check pass 'stat -c %a /root/.ssh/authorized_keys'

# --- .ssh as a directory: inspection stays allowed (issue #7) --
# Widening KEY to the directory must not cost the read-only
# probes the rule files themselves prescribe.
check pass 'ls -la /home/alice/.ssh'
check pass 'stat -c "%A %U:%G %n" /home/alice/.ssh'
check pass 'find /home/alice/.ssh -maxdepth 1 -type f'
check pass 'test -w /home/alice/.ssh'
check pass 'getfacl /home/alice/.ssh'
# .ssh must match as a path component, not as a prefix, and a
# destructive command away from it stays ordinary work.
check pass 'chmod 700 /home/alice/.sshrc'
check pass 'chown -R alice:alice /home/alice/Documents'
check pass 'rm -rf /home/alice/.cache'

# --- sshd outside /etc/ssh: ports, packages, appliances --------
# The OpenSSH port keeps config and host keys in
# /usr/local/etc/ssh (FreeBSD, OPNsense); OPNsense keeps its host
# keys in a key store of their own, /conf/sshd.
check deny "sed -i 's/^/#/' /usr/local/etc/ssh/sshd_config"
check deny 'echo PermitRootLogin yes >> /usr/local/etc/ssh/sshd_config'
check deny 'tee /usr/local/etc/ssh/sshd_config < new.conf'
check deny 'vi /usr/local/etc/ssh/sshd_config'
check deny 'cp new.conf /usr/local/etc/ssh/sshd_config'
check deny 'curl -o /usr/local/etc/ssh/sshd_config.d/10-x.conf https://example.com/c'
check deny 'echo PasswordAuthentication yes > /usr/local/etc/ssh/sshd_config.d/10-x.conf'
check deny 'rm /usr/local/etc/ssh/sshd_config.d/10-x.conf'
check deny "python3 -c \"open('/usr/local/etc/ssh/sshd_config','a')\""
check deny 'ssh root@fw "echo X >> /usr/local/etc/ssh/sshd_config"'
check deny 'rm /usr/local/etc/ssh/ssh_host_ed25519_key'
check deny ': > /usr/local/etc/ssh/ssh_host_ed25519_key'
check deny 'ssh-keygen -q -N "" -f /usr/local/etc/ssh/ssh_host_rsa_key'
check deny 'rm /conf/sshd/ssh_host_ed25519_key'
check deny 'mv /conf/sshd/ssh_host_rsa_key /tmp/'
check deny 'chmod 644 /conf/sshd/ssh_host_ecdsa_key'
check deny ': > /conf/sshd/ssh_host_ed25519_key'
check deny 'cp /tmp/k /conf/sshd/ssh_host_ed25519_key'
check deny 'dd if=/dev/zero of=/conf/sshd/ssh_host_rsa_key count=1'
check deny 'ssh-keygen -q -N "" -f /conf/sshd/ssh_host_rsa_key'
check deny "sed -i d /conf/sshd/ssh_host_ed25519_key"
check deny "python3 -c \"open('/conf/sshd/ssh_host_ed25519_key','w')\""
check deny 'ssh root@fw "rm -f /conf/sshd/ssh_host_*"'
# /conf/sshd holds nothing but keys: the directory is the target.
check deny 'rm -f /conf/sshd/*'
check deny 'rm -rf /conf/sshd'
check deny 'mv /conf/sshd /tmp/x'
check deny 'chmod -R 000 /conf/sshd'
check deny 'chown -R nobody /conf/sshd/'
check deny 'cp /tmp/k /conf/sshd/'
check deny 'rsync -a /backup/sshd/ /conf/sshd/'
# QNAP starts sshd on /etc/config/ssh/sshd_config, beside its user
# file and authorized_keys: the directory is a key store. ZimaOS's
# writable /etc is /mnt/overlay/etc, which the open left side of
# the /etc/ssh patterns already covers.
check deny "sed -i 's/^#Port/Port/' /etc/config/ssh/sshd_config"
check deny 'echo AllowUsers alice >> /etc/config/ssh/sshd_user_config'
check deny 'vi /etc/config/ssh/sshd_config'
check deny 'rm /etc/config/ssh/ssh_host_rsa_key'
check deny 'ssh-keygen -q -N "" -f /etc/config/ssh/ssh_host_ed25519_key'
check deny 'rm -rf /etc/config/ssh'
check deny 'chmod -R 777 /etc/config/ssh'
check deny 'ssh admin@nas1.example.com "rm /etc/config/ssh/authorized_keys"'
check deny "sed -i 's/^#Port/Port/' /mnt/overlay/etc/ssh/sshd_config"
check deny 'rm /mnt/overlay/etc/ssh/ssh_host_ed25519_key'
check pass 'ls -l /etc/config/ssh/'
check pass 'cat /etc/config/ssh/sshd_config'
# Prefixes are matched, not listed: Homebrew's etc/ssh too.
check deny 'echo X >> /opt/homebrew/etc/ssh/sshd_config'
check deny 'rm /opt/homebrew/etc/ssh/ssh_host_ed25519_key'
check deny 'echo X >> "/usr/local/etc/ssh/sshd_config"'
# pfSense keeps keys and config in /etc/ssh, but appends
# /etc/sshd_extra to the sshd_config it generates.
check deny 'echo PermitRootLogin yes >> /etc/sshd_extra'
check deny 'tee /etc/sshd_extra < extra.conf'
check deny "sed -i d /etc/sshd_extra"
check deny 'vi /etc/sshd_extra'
check deny 'rm /etc/sshd_extra'
check deny 'cp extra.conf /etc/sshd_extra'
check deny "python3 -c \"open('/etc/sshd_extra','a')\""
check pass 'cat /etc/sshd_extra'
check pass 'ls -l /etc/sshd_extra'
# OpenWrt runs dropbear: its config is the UCI file
# /etc/config/dropbear, changed through uci, and /etc/dropbear
# holds its host keys and root's authorized_keys, nothing else.
check deny "uci set dropbear.@dropbear[0].Port=2222"
check deny "uci set 'dropbear.@dropbear[0].PasswordAuth=on'"
check deny 'uci -q delete dropbear.@dropbear[0].Interface'
check deny 'uci add_list dropbear.@dropbear[0].keyfile=/tmp/k'
check deny 'uci add dropbear dropbear'
check deny 'uci commit dropbear'
check deny 'uci import dropbear < /tmp/dropbear.uci'
# Without a name, import commits every package its input declares.
check deny 'uci import < /tmp/backup.uci'
check deny 'uci import</tmp/backup.uci'
check deny 'uci -q import'
check deny 'cat /tmp/backup.uci | uci import'
check deny 'uci import # restore'
check deny "ssh root@router.example.com 'uci import < /tmp/backup.uci'"
check pass 'uci import firewall < /tmp/firewall.uci'
check pass 'uci -m import network < /tmp/network.uci'
# Configuration tools. A playbook's tasks are out of sight, so only
# the forms that run none pass; ad-hoc calls are judged by module.
check deny 'ansible-playbook -i inventory site.yml'
check deny 'ansible-playbook --check --diff -l web1.example.com site.yml'
check deny 'cd ~/ansible && ansible-playbook site.yml --limit web1.example.com'
check deny "ssh root@server1.example.com 'ansible-playbook -c local /etc/site.yml'"
check pass 'ansible-playbook --syntax-check site.yml'
check pass 'ansible-playbook -i inventory --list-tasks site.yml'
check pass 'ansible-playbook -i inventory site.yml --list-hosts'
check deny 'ansible-playbook --list-hosts site.yml; ansible-playbook site.yml'
check deny 'ansible-pull -U https://git.example.com/site.git'
check deny 'ansible-console web'
check pass 'ansible web1.example.com -m ping'
check pass 'ansible all -m setup -a filter=ansible_distribution*'
check pass 'ansible web1.example.com -a uptime'
check pass 'ansible web1.example.com -m command -a "cat /etc/ssh/sshd_config"'
check pass 'ansible web1.example.com -m stat -a path=/etc/ssh/sshd_config'
check pass 'ansible web1.example.com -b -m apt -a "name=nginx state=present"'
check pass 'ls -ld /etc/ansible/facts.d /root/.ansible 2>/dev/null || true'
check deny 'ansible web1.example.com -b -m parted -a "device=/dev/sdb number=1 state=present"'
check deny 'ansible web1.example.com -m community.general.parted -a "device=/dev/sdb"'
check deny "ansible web1.example.com -m 'community.general.filesystem' -a 'fstype=ext4 dev=/dev/sdb1'"
check deny 'ansible web1.example.com --module-name=community.general.shutdown'
check deny 'ansible win1.example.com -m community.windows.win_format -a drive_letter=D'
check deny 'ansible web1.example.com -m ansible.posix.authorized_key -a "user=root state=absent key=x"'
check deny 'ansible web1.example.com -m community.crypto.openssh_keypair -a path=/tmp/k'
check deny 'ansible web1.example.com -m script -a ./fix.sh'
check deny 'ansible web1.example.com -m "$MOD" -a "dest=/etc/ssh/sshd_config src=x"'
check pass 'ansible web1.example.com -m "$MOD" -a "name=nginx"'
# By path or in backticks, with the flags run together, and with an
# -m inside -a: every word that can name a module counts.
check deny '/usr/bin/ansible web1.example.com -m parted -a device=/dev/sdb'
check deny '/opt/homebrew/bin/ansible web1.example.com -m authorized_key -a user=root'
check deny 'echo `ansible web1.example.com -m parted -a device=/dev/sdb`'
check deny 'ansible web1.example.com -bm parted -a device=/dev/sdb'
check deny 'ansible web1.example.com --module-na parted -a device=/dev/sdb'
check deny 'ansible web1.example.com -m script -a "./setup.sh -m 700"'
check deny 'ansible web1.example.com -b -m parted -a "device=/dev/sdb" --ssh-extra-args "-m hmac-sha2-512"'
check deny 'ansible web1.example.com -m include_role -a name=disks'
check deny 'ansible web1.example.com -m ansible.builtin.include_tasks -a file=wipe.yml'
check deny 'ansible web1.example.com -b -m user -a "name=alice generate_ssh_key=yes force=yes"'
check deny 'ansible web1.example.com -m ansible.builtin.user -a "name=alice force=true generate_ssh_key=true"'
check deny 'ansible web1.example.com -b -m user -a "name=alice generate_ssh_key=yes force=TRUE"'
check deny "ansible web1.example.com -m user -a '{\"name\": \"alice\", \"generate_ssh_key\": true, \"force\": \"YES\"}'"
check deny 'ansible web1.example.com -m user -a "name=alice generate_ssh_key=1 force=y"'
check pass 'ansible web1.example.com -b -m user -a "name=alice generate_ssh_key=yes force=no"'
check pass 'terraform output apply'
check pass 'tofu -chdir=infra output destroy'
check pass 'terraform state show aws_instance.apply'
check pass 'ansible web1.example.com -b -m user -a "name=alice generate_ssh_key=yes"'
check pass 'ansible web1.example.com -b -m user -a "name=alice state=present force=yes"'
# Login options name a key without writing it, and the --*-args
# values go to ssh, never to a module.
check pass 'ansible web1.example.com -m apt -a "name=nginx" --ssh-common-args "-F ~/.ssh/config"'
check pass 'ansible web1.example.com --ssh-extra-args="-i ~/.ssh/jump" -m apt -a name=nginx'
check deny 'ansible web1.example.com --ssh-common-args "-F x" -m copy -a "src=k dest=/root/.ssh/authorized_keys"'
check pass 'ansible web1.example.com --private-key ~/.ssh/deploy -b -m apt -a "name=nginx state=present"'
check pass 'ansible web1.example.com -e ansible_ssh_private_key_file=~/.ssh/hw -m service -a "name=nginx state=reloaded"'
check pass 'ansible web1.example.com -m apt -a name=nginx; cat /etc/ssh/sshd_config'
check deny '/usr/local/bin/terraform apply'
check deny 'echo $(terraform apply -auto-approve)'
check deny '(tofu destroy)'
check deny 'terraform -chdir="my infra" apply'
check deny "ssh root@server1.example.com 'ansible localhost -c local -m parted -a device=/dev/sdb'"
check deny 'bash -c "ansible web1.example.com -m authorized_key -a user=root"'
check pass "ssh root@server1.example.com 'ansible localhost -c local -m ping'"
check deny 'ansible web1.example.com -b -m lineinfile -a "path=/etc/ssh/sshd_config line=PermitRootLogin\ no"'
check deny 'ansible web1.example.com -mcopy -a "src=k dest=/root/.ssh/authorized_keys"'
check deny 'ansible web1.example.com -m ansible.builtin.file -a "path=/root/.ssh mode=0777"'
check deny 'ansible web1.example.com -m shell -a "sed -i s/22/2222/ /etc/ssh/sshd_config"'
check deny 'ansible web1.example.com -m shell -a "mkfs.ext4 /dev/sdb1"'
check deny 'ansible web1.example.com -b -a "poweroff"'
check deny 'terraform apply'
check deny 'terraform -chdir=infra apply -auto-approve'
check deny 'tofu destroy -target=hcloud_server.web1'
check pass 'terraform plan'
check pass 'tofu state list'
check pass 'grep -rn "ansible[-]pull" /etc/cron.d/ 2>/dev/null || true'
check deny "ssh root@router.example.com 'uci set dropbear.@dropbear[0].RootLogin=1; uci commit dropbear'"
check deny "uci batch <<'EOF'
set dropbear.@dropbear[0].Port=2222
commit dropbear
EOF"
check deny 'echo "option Port 2222" >> /etc/config/dropbear'
check deny "sed -i 's/22/2222/' /etc/config/dropbear"
check deny 'vi /etc/config/dropbear'
check deny 'cp /tmp/dropbear /etc/config/dropbear'
check deny 'rm /etc/config/dropbear'
check deny "python3 -c \"open('/etc/config/dropbear','a')\""
check deny 'rm /etc/dropbear/dropbear_ed25519_host_key'
check deny ': > /etc/dropbear/dropbear_rsa_host_key'
check deny 'mv /etc/dropbear/dropbear_ecdsa_host_key /tmp/'
check deny 'rm -rf /etc/dropbear'
check deny 'chmod -R 644 /etc/dropbear'
check deny 'cp /tmp/k /etc/dropbear/'
# dropbear elsewhere: OpenRC's conf.d, Debian's defaults file.
check deny "sed -i 's/-w//' /etc/conf.d/dropbear"
check deny 'echo DROPBEAR_PORT=2222 >> /etc/default/dropbear'
check pass 'cat /etc/conf.d/dropbear /etc/default/dropbear'
# A bare commit writes every staged config, dropbear's included.
check deny 'uci commit'
check deny 'uci -q commit'
check deny 'uci changes; uci commit'
check deny 'uci commit >/dev/null'
check deny 'uci -q commit 2>/dev/null'
check deny 'uci commit 2>&1'
check deny 'uci commit # all of them'
check pass 'uci commit firewall >/dev/null'
check deny "ssh root@router.example.com 'uci set firewall.@defaults[0].syn_flood=1; uci commit'"
check deny "uci batch <<'EOF'
set firewall.@defaults[0].syn_flood=1
commit
EOF"
check pass 'uci set firewall.@defaults[0].syn_flood=1; uci commit firewall'
check pass 'git commit -m "docs: uci notes"'
check pass 'uci show dropbear'
check pass 'uci get dropbear.@dropbear[0].Port'
check pass 'uci changes dropbear'
check pass 'uci export dropbear'
check pass 'cat /etc/config/dropbear'
check pass 'ls -l /etc/dropbear'
check pass 'dropbearkey -y -f /etc/dropbear/dropbear_ed25519_host_key'
check pass 'uci set firewall.@defaults[0].syn_flood=1'
check pass 'uci commit firewall'
# OpenMediaVault renders sshd_config and rebuilds its
# authorized_keys directory from the ssh Salt state; deploying that
# state names neither path.
check deny 'omv-salt deploy run ssh'
check deny 'omv-salt deploy run nginx ssh samba'
check deny 'omv-salt deploy run -q ssh'
check deny "omv-salt deploy run 'ssh'"
check deny 'omv-salt deploy run ssh;true'
check deny 'ssh root@nas "omv-salt deploy run ssh"'
check deny 'omv-salt stage run deploy'
check deny 'omv-salt stage run --quiet deploy'
check pass 'omv-salt deploy run samba'
check pass 'omv-salt deploy run ssh-notes'
check pass 'omv-salt deploy list-dirty'
check pass 'omv-salt stage run prepare'
# segments() splits at quotes, so a quoted word must not hide it.
check deny '"/usr/sbin/omv-salt" deploy run ssh'
check deny "'omv-salt' stage run deploy"
check deny "omv-salt 'deploy' 'run' ssh"
check deny 'ssh root@nas "\"/usr/sbin/omv-salt\" deploy run ssh"'
check pass '"/usr/sbin/omv-salt" deploy run samba'
check pass "'omv-salt' stage run prepare"
check pass 'omv-salt deploy run samba; ssh root@nas uptime'
check pass 'cat /usr/local/etc/ssh/sshd_config'
check pass 'grep -r PermitRootLogin /usr/local/etc/ssh/sshd_config.d/'
check pass 'stat /usr/local/etc/ssh/sshd_config'
check pass 'ls -l /usr/local/etc/ssh/'
check pass 'ssh root@fw "sshd -T -f /usr/local/etc/ssh/sshd_config"'
check pass 'cat /usr/local/etc/ssh/ssh_host_ed25519_key.pub'
check pass 'ls -l /conf/sshd/'
check pass 'stat /conf/sshd/ssh_host_ed25519_key'
check pass 'cp /conf/sshd/ssh_host_ed25519_key.pub /tmp/'
check pass 'ssh-keygen -lf /conf/sshd/ssh_host_ed25519_key.pub'
# The rest of /conf is OPNsense's config store, not a key store.
check pass 'cp /conf/config.xml /root/config.xml.bak'
check pass 'rm /conf/backup/config-1700000000.xml'

# --- a redirect glued to the protected path --------------------
# END includes < and >: these replaced the file while the spaced
# forms were denied.
check deny 'tee /etc/ssh/sshd_config<<EOF'
check deny 'echo X | tee -a /etc/ssh/sshd_config>/dev/null'
check deny 'tee -a /etc/ssh/sshd_config</tmp/new'
check deny 'tee /etc/ssh/sshd_config.d/x.conf>/dev/null'
check deny 'ssh root@h "tee /etc/ssh/sshd_config.d/99.conf</tmp/x"'
check deny 'tee ~/.ssh/authorized_keys</tmp/k'
check deny 'echo k | tee -a ~/.ssh/authorized_keys>/dev/null'
check deny 'tee /etc/ssh/ssh_host_ed25519_key</tmp/k'
check pass 'tee /tmp/report.txt</tmp/in'

# --- CLOBBER: one list of destructive tools for keys and sshd --
check deny 'install -m 600 /tmp/new /etc/ssh/sshd_config'
check deny 'install -m 600 /tmp/new /usr/local/etc/ssh/sshd_config'
check deny 'ln -sf /tmp/x /etc/ssh/sshd_config'
check deny 'patch /etc/ssh/sshd_config < /tmp/d'
check deny 'shred -u /etc/ssh/sshd_config'
check deny 'patch ~/.ssh/authorized_keys < /tmp/d'
check pass 'ls -ln /etc/ssh/sshd_config'

# --- heredoc bodies: data vs code (issue #8) -------------------
# Prose legitimately contains taboo words. A heredoc body is only
# exempt when its CONSUMER cannot execute it. The deny cases below
# are the ones that make the exemption safe; if any of them ever
# flips to pass, the exemption has become a hole.
#
# The exact command that exposed this: Hostwarden's own changelog
# write, blocked over the word inside the prose.
check pass 'cat >> /Users/s/hostwarden/memory/servers/h/changelog.log <<EOF
  Verify: clean shutdown checkpoint + database ready.
EOF'
check pass 'cat >> notes.md <<EOF
We ran fdisk /dev/sda and then mkfs.ext4 /dev/sda1 on the new box.
EOF'
check pass 'tee /tmp/report.txt <<EOF
poweroff and halt are taboo; so is dd if=x of=/dev/sda.
EOF'
check pass 'tee -a /tmp/report.txt <<EOF
blkdiscard /dev/nvme0n1 must never run here.
EOF'
# A quoted delimiter and <<- (tab-stripping) are the same case.
check pass "cat > /tmp/doc.md <<'MARK'
shutdown -h now is what we must never do
MARK"
check pass 'cat > /tmp/doc.md <<-END
	shutdown -h now stays documented here
	END'
# Content AFTER the terminator is still command text and is
# still scanned — the exemption covers the body only.
check pass 'cat >> /tmp/doc.md <<EOF
a note about shutdown -h now
EOF
echo written; ls -l /tmp/doc.md'

# The body RUNS: every one of these must stay blocked.
check deny 'ssh root@h "bash -s" <<EOF
shutdown -h now
EOF'
check deny 'ssh -o BatchMode=yes root@h bash -s <<EOF
mkfs.ext4 /dev/sda1
EOF'
check deny 'bash <<EOF
fdisk /dev/sda
EOF'
check deny 'sh -s <<EOF
blkdiscard /dev/sda
EOF'
check deny 'python3 <<EOF
open("/etc/ssh/sshd_config","a").write("X")
EOF'
check deny 'sudo tee /tmp/x <<EOF
halt
EOF'
# A taboo appended AFTER the heredoc terminator is real code.
check deny 'cat >> /tmp/doc.md <<EOF
harmless prose
EOF
shutdown -h now'
check deny 'cat >> /tmp/doc.md <<EOF
harmless prose
EOF
fdisk /dev/sda'
# The sink itself must not be a device or a file that later runs.
check deny 'cat > /dev/sda <<EOF
anything
EOF'
check deny 'cat > /etc/cron.d/hostwarden-job <<EOF
0 3 * * * root shutdown -h now
EOF'
check deny 'cat > /etc/systemd/system/x.service <<EOF
ExecStart=/sbin/poweroff
EOF'
check deny 'cat > ~/.config/systemd/user/x.service <<EOF
ExecStart=/sbin/poweroff
EOF'
# "Later runs" is wider than cron and systemd: a script file, an
# executable directory, a shell start-up file and a launchd job
# all reach the effect on a delay, so their bodies stay scanned.
check deny 'cat > /usr/local/bin/maint.sh <<EOF
shutdown -h now
EOF'
check deny 'cat > ~/bin/wipe <<EOF
fdisk /dev/sda
EOF'
check deny 'tee /usr/local/sbin/nightly <<EOF
blkdiscard /dev/sdb
EOF'
check deny 'cat > /tmp/build.py <<EOF
os.system("shutdown -h now")
EOF'
check deny 'cat >> ~/.bashrc <<EOF
shutdown -h now
EOF'
check deny 'cat >> ~/.zprofile <<EOF
poweroff
EOF'
check deny 'cat >> ~/.profile <<EOF
halt
EOF'
check deny 'cat > ~/Library/LaunchAgents/x.plist <<EOF
<string>/sbin/shutdown -h now</string>
EOF'
# ...but the match is on the path, not on a substring of a word:
# a documentation file whose name merely contains "bin" or "sh"
# is still an ordinary file, and its prose is still exempt.
check pass 'cat >> /tmp/combine-notes.md <<EOF
The shutdown checkpoint ran before fdisk /dev/sda was needed.
EOF'
check pass 'cat >> /tmp/shipping.log <<EOF
poweroff was never issued on this host.
EOF'
# No terminator: the body cannot be delimited, so nothing is
# skipped and the taboo inside is scanned (fail closed).
check deny 'cat >> /tmp/doc.md <<EOF
shutdown -h now'
# Two heredocs on one line: the single-body assumption does not
# hold, so scan everything.
check deny 'cat <<EOF1 >/tmp/a; cat <<EOF2 >/tmp/b
shutdown -h now
EOF1
x
EOF2'
# A second command smuggled onto the sink line.
check deny 'cat >> /tmp/doc.md <<EOF; shutdown -h now
prose
EOF'
check deny 'cat >> /tmp/$(shutdown -h now) <<EOF
prose
EOF'
# Not a data sink at all, even though it looks close.
check deny 'cat >> /tmp/doc.md < <(shutdown -h now)'
# The interpreter rule still sees an interpreter + protected path
# when the heredoc is NOT the exempt shape.
check deny 'perl <<EOF
unlink("/root/.ssh/authorized_keys")
EOF'

# Stripping must fail CLOSED when awk cannot run at all: the body
# then stays in the scanned text, so a body that RUNS is caught
# and a documentation body is merely blocked as before.
SHIM2=$(mktemp -d)
printf '#!/bin/sh\nexit 2\n' > "$SHIM2/awk"
chmod +x "$SHIM2/awk"
OUT=$(json_for 'cat >> /tmp/doc.md <<EOF
shutdown -h now
EOF' | env -u HOSTWARDEN_GUARD_DISABLE PATH="$SHIM2:$PATH" sh "$HOOK")
if printf '%s' "$OUT" \
  | grep -q '"permissionDecision":"deny"'; then
  PASS=$((PASS + 1))
else
  FAIL=$((FAIL + 1))
  echo "FAIL: broken awk failed OPEN (heredoc body was skipped)"
fi
rm -rf "$SHIM2"

# --- fallback path: malformed (non-JSON) stdin -----------------
OUT=$(printf '%s' 'mkfs.ext4 /dev/sda1' \
  | env -u HOSTWARDEN_GUARD_DISABLE sh "$HOOK")
if printf '%s' "$OUT" \
  | grep -q '"permissionDecision":"deny"'; then
  PASS=$((PASS + 1))
else
  FAIL=$((FAIL + 1))
  echo "FAIL: raw-input fallback did not deny mkfs"
fi

expect() {
  # expect <label> <command...> — passes when the command succeeds.
  L=$1; shift
  if "$@"; then
    PASS=$((PASS + 1))
  else
    FAIL=$((FAIL + 1))
    echo "FAIL: $L"
  fi
}
V=HOSTWARDEN_GUARD_DISABLE

# --- operator override: set at launch, and recorded then ---------
# The variable switches the guard off only for a session whose start
# check-session.sh recorded; a value that arrives mid-session finds
# no record. HOME is a scratch directory, so the tester's own records
# never decide a fixture.
GHOME=$(mktemp -d)
mkdir -p "$GHOME/.cache/hostwarden"
: > "$GHOME/.cache/hostwarden/guard-off-s-recorded"
override_out() {
  printf '{"session_id":"%s","tool_name":"Bash","tool_input":{"command":"mkfs.ext4 /dev/sda1"}}' "$1" \
    | env HOME="$GHOME" "$V=1" sh "$HOOK"
}
expect "the override did not disable the guard for a recorded session" \
  [ -z "$(override_out s-recorded)" ]
expect "the override disabled the guard without a record (mid-session)" \
  denied "$(override_out s-unrecorded)"
rm -rf "$GHOME"

# --- settings files and records: guard-settings.sh ---------------
# The variable in a settings file would switch the guard off for the
# next session, and a forged record for this one; both are denied
# through every tool, whether or not the guard is already off.
SGUARD="$CLAUDE_DIR/hooks/guard-settings.sh"
hook_case() {
  # hook_case <hook> <name> <expect> <label> <json> [env assignment...]
  H=$1 N=$2 E=$3 L=$4 J=$5; shift 5
  OUT=$(printf '%s' "$J" | env -u "$V" "$@" sh "$H")
  if denied "$OUT"; then GOT=deny; else GOT=pass; fi
  expect "$N [$E, got $GOT]: $L" [ "$GOT" = "$E" ]
}
settings_case() { hook_case "$SGUARD" guard-settings "$@"; }
# A PATH without jq, for the fallbacks below: judged on the raw
# text, which may over-block, never under.
NOJQ=$(mktemp -d)
for t in sh cat grep printf sed tr head; do
  P=$(command -v "$t" 2>/dev/null) && ln -s "$P" "$NOJQ/$t"
done
settings_case deny 'Write settings.local.json' \
  '{"tool_name":"Write","tool_input":{"file_path":"/r/.claude/settings.local.json","content":"{\"env\":{\"'"$V"'\":\"1\"}}"}}'
settings_case deny 'Edit user settings.json' \
  '{"tool_name":"Edit","tool_input":{"file_path":"/h/.claude/settings.json","old_string":"{","new_string":"{\"env\":{\"'"$V"'\":\"1\"},"}}'
settings_case deny 'MultiEdit managed-settings.json' \
  '{"tool_name":"MultiEdit","tool_input":{"file_path":"/etc/claude-code/managed-settings.json","edits":[{"old_string":"a","new_string":"b"},{"old_string":"{","new_string":"{\"'"$V"'\":1,"}]}}'
settings_case deny 'Write while the guard is already off' \
  '{"tool_name":"Write","tool_input":{"file_path":"/r/.claude/settings.local.json","content":"'"$V"'"}}' \
  "$V=1"
settings_case deny 'Write to the settings file in upper case' \
  '{"tool_name":"Write","tool_input":{"file_path":"/r/.claude/SETTINGS.LOCAL.JSON","content":"'"$V"'"}}'
settings_case pass 'Edit that removes it again' \
  '{"tool_name":"Edit","tool_input":{"file_path":"/r/.claude/settings.local.json","old_string":"\"'"$V"'\": \"1\"","new_string":""}}'
settings_case pass 'README naming it' \
  '{"tool_name":"Edit","tool_input":{"file_path":"/r/README.md","old_string":"a","new_string":"'"$V"'"}}'
settings_case pass 'settings file without it' \
  '{"tool_name":"Write","tool_input":{"file_path":"/r/.claude/settings.local.json","content":"{\"env\":{\"HOSTWARDEN_NO_UPDATE\":\"1\"}}"}}'
settings_case deny 'Bash: jq into settings.local.json' \
  "$(json_for 'jq ".env.'"$V"' = \"1\"" .claude/settings.local.json')"
settings_case deny 'Bash: heredoc into settings.local.json' \
  "$(json_for 'cat > .claude/settings.local.json <<EOF
{"env": {"'"$V"'": "1"}}
EOF')"
settings_case deny 'Bash: append to user settings.json, guard off' \
  "$(json_for "printf x $V >> ~/.claude/settings.json")" "$V=1"
settings_case pass 'Bash: naming it in the docs' \
  "$(json_for "echo see $V in the docs")"
settings_case pass 'Bash: reading the settings file' \
  "$(json_for 'jq .env .claude/settings.local.json')"
settings_case deny 'Write a guard-off record' \
  '{"tool_name":"Write","tool_input":{"file_path":"/h/.cache/hostwarden/guard-off-abc","content":""}}'
settings_case deny 'Bash: touch a guard-off record' \
  "$(json_for 'cd ~/.cache/hostwarden && touch guard-off-abc')"
settings_case deny 'Write a Windows path to the settings file' \
  '{"tool_name":"Write","tool_input":{"file_path":"C:\\\\Users\\\\alice\\\\hw\\\\.claude\\\\settings.local.json","content":"'"$V"'"}}'
# While a settings file carries the variable, a change that never
# names it could flip its value: every Edit of it is denied, and so
# is a shell command naming a settings file. A Write without it, or
# the operator by hand, takes it out.
SET=$(mktemp -d)
mkdir -p "$SET/.claude"
printf '{"env": {"%s": "0"}}\n' "$V" > "$SET/.claude/settings.local.json"
settings_case deny 'Edit flipping the value of an existing key' \
  '{"tool_name":"Edit","tool_input":{"file_path":"'"$SET"'/.claude/settings.local.json","old_string":"\"0\"","new_string":"\"1\""}}'
settings_case pass 'Write taking the existing key out' \
  '{"tool_name":"Write","tool_input":{"file_path":"'"$SET"'/.claude/settings.local.json","content":"{}"}}'
settings_case deny 'Bash: sed on settings while the key exists' \
  "$(json_for "sed -i 's/0/1/' .claude/settings.local.json")" \
  "CLAUDE_PROJECT_DIR=$SET" "HOME=$SET/none"
settings_case pass 'Bash: sed on settings without the key' \
  "$(json_for "sed -i 's/0/1/' .claude/settings.local.json")" \
  "CLAUDE_PROJECT_DIR=$SET/none" "HOME=$SET/none"
# Without CLAUDE_PROJECT_DIR the hook finds the project from its own
# path, also when it runs by bare name from its directory.
mkdir -p "$SET/.claude/hooks"
cp "$SGUARD" "$CLAUDE_DIR/hooks/json.sh" "$SET/.claude/hooks/"
SED_JSON=$(json_for "sed -i 's/0/1/' .claude/settings.local.json")
for RUN in "sh $SET/.claude/hooks/guard-settings.sh" \
  "cd $SET/.claude/hooks && sh guard-settings.sh"; do
  OUT=$(printf '%s' "$SED_JSON" | env -u "$V" -u CLAUDE_PROJECT_DIR \
    HOME="$SET/none" sh -c "$RUN")
  expect "guard-settings found no project without CLAUDE_PROJECT_DIR: $RUN" \
    denied "$OUT"
done
rm -rf "$SET"
settings_case pass 'Edit a hook that mentions the records' \
  '{"tool_name":"Edit","tool_input":{"file_path":"/r/.claude/hooks/check-session.sh","old_string":"a","new_string":"guard-off-"}}'
settings_case deny 'no jq: Write settings.local.json' \
  '{"tool_name":"Write","tool_input":{"file_path":"/r/.claude/settings.local.json","content":"'"$V"'"}}' \
  "PATH=$NOJQ"

# --- the deny message: effect versus text ----------------------
# A deny forbids reaching the effect another way and names the
# route for a command that only carries the word as text. Without
# the second half an agent guesses, and learns to route around.
OUT=$(json_for 'mkfs.ext4 /dev/sda1' | env -u "$V" sh "$HOOK")
for w in 'never reach the same effect' 'git commit -F' \
  'gh --body-file' 'power[o]ff'; do
  case "$OUT" in
  *"$w"*) PASS=$((PASS + 1)) ;;
  *) FAIL=$((FAIL + 1)); echo "FAIL: the deny message lost: $w" ;;
  esac
done
expect "the deny message is not valid JSON" \
  sh -c 'printf "%s" "$1" | jq -e .hookSpecificOutput >/dev/null' _ "$OUT"

# --- Edit, Write, MultiEdit, NotebookEdit: the target path ------
# Judged by the file they write, in every mode: an SSH key,
# authorized_keys or sshd_config is denied, and their content is
# never scanned. The file-tool branch runs before the scope is read,
# so one case in the development tree stands for the mode.
file_case() { hook_case "$HOOK" "file tool" "$@"; }
fjson() {
  # fjson <tool> <path> [content] [cwd]
  jq -n --arg t "$1" --arg p "$2" --arg c "${3:-x}" --arg w "${4:-/r}" \
    'if $t == "NotebookEdit"
     then {cwd:$w,tool_name:$t,tool_input:{notebook_path:$p,new_source:$c}}
     else {cwd:$w,tool_name:$t,tool_input:{file_path:$p,content:$c}} end'
}
file_case deny 'Write authorized_keys' \
  "$(fjson Write /home/alice/.ssh/authorized_keys)"
hook_case "$GUARD_DEV" "file tool in development" deny 'Write authorized_keys' \
  "$(fjson Write /home/alice/.ssh/authorized_keys)"
file_case deny 'Write authorized_keys2' \
  "$(fjson Write /root/.ssh/authorized_keys2)"
file_case deny 'Edit a private key' \
  "$(fjson Edit /Users/alice/.ssh/id_ed25519)"
file_case deny 'Write a public key' \
  "$(fjson Write /home/alice/.ssh/id_ed25519.pub)"
file_case deny 'Edit sshd_config' "$(fjson Edit /etc/ssh/sshd_config)"
file_case deny 'MultiEdit a Homebrew sshd_config' \
  "$(fjson MultiEdit /opt/homebrew/etc/ssh/sshd_config)"
file_case deny 'Edit QNAP sshd_config' \
  "$(fjson Edit /etc/config/ssh/sshd_config)"
file_case deny 'Write QNAP sshd_user_config' \
  "$(fjson Write /etc/config/ssh/sshd_user_config)"
file_case deny 'Write an sshd drop-in' \
  "$(fjson Write /etc/ssh/sshd_config.d/50-local.conf)"
file_case deny 'Write a host key under /usr/local' \
  "$(fjson Write /usr/local/etc/ssh/ssh_host_ed25519_key)"
file_case deny 'Write into an appliance key store' \
  "$(fjson Write /conf/sshd/ssh_host_rsa_key)"
file_case deny 'Write the file pfSense merges into sshd_config' \
  "$(fjson Write /etc/sshd_extra)"
file_case deny 'Write sshd_config in an offline image' \
  "$(fjson Write /mnt/etc/ssh/sshd_config)"
file_case deny 'NotebookEdit onto authorized_keys' \
  "$(fjson NotebookEdit /home/alice/.ssh/authorized_keys)"
file_case deny 'relative path resolved against cwd' \
  "$(fjson Write .ssh/authorized_keys x /home/alice)"
file_case deny 'Write a dropbear host key' \
  "$(fjson Write /etc/dropbear/dropbear_ed25519_host_key)"
file_case deny "Write OpenWrt's dropbear config" \
  "$(fjson Write /etc/config/dropbear)"
file_case deny "Edit OpenRC's dropbear config" \
  "$(fjson Edit /etc/conf.d/dropbear)"
file_case deny "Write a key in OpenMediaVault's authorized_keys directory" \
  "$(fjson Write /var/lib/openmediavault/ssh/authorized_keys/alice)"
file_case deny "Write Windows' sshd_config through /mnt/c" \
  "$(fjson Write /mnt/c/ProgramData/ssh/sshd_config)"
file_case deny "Write administrators_authorized_keys with backslashes" \
  "$(fjson Write 'C:\ProgramData\ssh\administrators_authorized_keys')"
file_case deny 'a private key behind Windows separators' \
  "$(fjson Write 'C:\Users\alice\.ssh\id_ed25519')"
file_case pass 'a note about dropbear' \
  "$(fjson Write /r/docs/dropbear.md)"
# macOS file systems ignore case by default, so the match does too.
file_case deny 'authorized_keys in upper case' \
  "$(fjson Write /Users/alice/.SSH/AUTHORIZED_KEYS)"
file_case deny 'a private key in mixed case' \
  "$(fjson Write /Users/alice/.ssh/Id_Ed25519)"
file_case deny 'sshd_config under a mixed-case /etc/SSH' \
  "$(fjson Edit /etc/SSH/sshd_config)"
file_case pass 'a document named after the key file' \
  "$(fjson Edit /r/rules/authorized_keys.md)"
file_case pass 'an example sshd_config' \
  "$(fjson Edit /r/docs/sshd_config.example)"
file_case pass 'ssh client config' "$(fjson Write /home/alice/.ssh/config)"
file_case pass 'known_hosts' "$(fjson Write /home/alice/.ssh/known_hosts)"
file_case pass 'content that names taboos is text' \
  "$(fjson Edit /r/rules/os/debian.md 'mkfs.ext4 /dev/sda1; rm ~/.ssh/id_ed25519; shutdown -h now')"
file_case pass 'content with the off switch is text (guard-settings has settings)' \
  "$(fjson Write /r/docs/x.md 'HOSTWARDEN_GUARD_DISABLE=1')"
# Links: the file system decides, not the spelling.
FL=$(mktemp -d)
FL=$(cd "$FL" && pwd -P)
mkdir -p "$FL/.ssh"
: > "$FL/.ssh/authorized_keys"
ln -s .ssh/authorized_keys "$FL/notes.md"
ln -s .ssh "$FL/keys"
file_case deny 'a link that points at authorized_keys' \
  "$(fjson Write "$FL/notes.md")"
file_case deny 'a key reached through a linked directory' \
  "$(fjson Write "$FL/keys/id_ed25519")"
# A .. after a directory that does not exist yet: a tool that
# normalises the path by text lands on the key.
file_case deny 'a key behind a missing directory and ..' \
  "$(fjson Write "$FL/.ssh/nosuch/../id_ed25519")"
file_case deny 'a linked key directory behind a missing directory and ..' \
  "$(fjson Write "$FL/keys/nosuch/../id_ed25519")"
file_case pass 'a .. that leaves the key directory' \
  "$(fjson Write "$FL/.ssh/../notes.txt")"
ln -s loop-b "$FL/loop-a"
ln -s loop-a "$FL/loop-b"
file_case deny 'a chain of links that does not end' \
  "$(fjson Write "$FL/loop-a")"
rm -rf "$FL"
file_case deny 'no jq: Write authorized_keys' \
  "$(fjson Write /home/alice/.ssh/authorized_keys)" "PATH=$NOJQ"
file_case pass 'no jq: Write an ordinary file' \
  "$(fjson Write /r/docs/x.md 'hello')" "PATH=$NOJQ"
rm -rf "$NOJQ"

# --- Monitor runs a shell command too -----------------------------
# Its command arrives in tool_input.command like Bash's, and the
# matcher in settings.json hands it to both guards. A taboo sent
# through Monitor is a taboo; an ordinary watch passes.
check deny 'poweroff' Monitor
check deny 'sgdisk --zap-all /dev/sda' Monitor
check deny 'ssh root@h "shutdown -h now"' Monitor
check deny "printf 'PermitRootLogin no\\n' >> /etc/ssh/sshd_config" Monitor
check deny 'while true; do rm -f ~/.ssh/authorized_keys; sleep 60; done' Monitor
check pass 'tail -f /var/log/syslog | grep --line-buffered -E "error|fail"' Monitor
check pass 'until gh pr checks 12 | grep -qv pending; do sleep 30; done' Monitor
# A WebSocket watch has no command and starts no shell, so its
# description is not scanned as one.
check pass '{"tool_name":"Monitor","tool_input":{"ws":{"url":"wss://events.example.com/x"},"description":"watch shutdown events"}}' JSON
check pass '{"tool_name":"Monitor","tool_input":{"ws":{"url":"wss://events.example.com/x"},"description":"mkfs progress","timeout_ms":300000}}' JSON
# Its description does not rescue a command that is one.
check deny '{"tool_name":"Monitor","tool_input":{"command":"poweroff","description":"ws"}}' JSON
settings_case deny 'Monitor: write it into settings.local.json' \
  "$(json_for "printf x $V >> .claude/settings.local.json" Monitor)"
settings_case deny 'Monitor: touch a guard-off record' \
  "$(json_for 'touch ~/.cache/hostwarden/guard-off-abc' Monitor)"
settings_case pass 'Monitor: tail a log' \
  "$(json_for 'tail -f /var/log/syslog' Monitor)"

# --- check-session.sh: worktree and guard-off notices ----------
# The hook only reads .git files and the commondir they lead to, so
# hand-written ones cover every case: a checkout (a directory), a
# linked worktree with an absolute and with a relative gitdir, one
# whose common git directory is not called .git, and a submodule,
# which is not a worktree.
CSESSION="$CLAUDE_DIR/hooks/check-session.sh"
REPO=$(mktemp -d)
for d in main wt rel sep sub; do
  mkdir -p "$REPO/$d/.claude/hooks"
  cp "$CSESSION" "$CLAUDE_DIR/hooks/json.sh" "$REPO/$d/.claude/hooks/"
done
for w in wt rel; do
  mkdir -p "$REPO/main/.git/worktrees/$w"
  echo ../.. > "$REPO/main/.git/worktrees/$w/commondir"
done
mkdir -p "$REPO/meta/worktrees/sep" "$REPO/main/.git/modules/sub"
echo ../.. > "$REPO/meta/worktrees/sep/commondir"
printf 'gitdir: %s/main/.git/worktrees/wt\n' "$REPO" > "$REPO/wt/.git"
printf 'gitdir: ../main/.git/worktrees/rel\n' > "$REPO/rel/.git"
printf 'gitdir: %s/meta/worktrees/sep\n' "$REPO" > "$REPO/sep/.git"
printf 'gitdir: ../main/.git/modules/sub\n' > "$REPO/sub/.git"
session_out() {
  # session_out <dir> [env assignment] [session JSON]
  printf '%s' "${3:-{\}}" \
    | env -u "$V" HOME="$REPO/home" ${2:+"$2"} \
      sh "$REPO/$1/.claude/hooks/check-session.sh"
}
contains() { case "$1" in *"$2"*) true ;; *) false ;; esac; }
expect "check-session.sh spoke in an ordinary checkout" \
  [ -z "$(session_out main)" ]
# The worktree itself is mode.sh's to detect and session-mode.sh's
# to announce; check-session.sh stays out of it.
mode_of() {
  (. "$CLAUDE_DIR/hooks/mode.sh"; hostwarden_mode "$REPO/$1"
   echo "$HOSTWARDEN_MODE $HOSTWARDEN_MAIN")
}
expect "mode.sh missed a linked worktree or its checkout" \
  [ "$(mode_of wt)" = "worktree $REPO/main" ]
expect "mode.sh missed a worktree with a relative gitdir" \
  [ "$(mode_of rel)" = "worktree $REPO/main" ]
expect "mode.sh missed a worktree of a separate git dir" \
  contains "$(mode_of sep)" "worktree "
expect "mode.sh took a submodule for a worktree" \
  [ "$(mode_of sub)" = "development " ]
expect "check-session.sh announced a worktree session-mode.sh owns" \
  [ -z "$(session_out wt)" ]
# The record: made at startup with the variable set, never at a
# compaction, and taken away once the variable is gone.
REC="$REPO/home/.cache/hostwarden/guard-off-s1"
expect "check-session.sh did not report the guard as off" \
  contains "$(session_out main "$V=1" '{"session_id":"s1","source":"startup"}')" \
  "taboo guard is OFF"
expect "check-session.sh made no record at startup" [ -e "$REC" ]
rm -f "$REC"
expect "check-session.sh did not say a mid-session value stays inert" \
  contains "$(session_out main "$V=1" '{"session_id":"s1","source":"compact"}')" \
  "guard stays ON"
expect "check-session.sh made a record at a compaction" [ ! -e "$REC" ]
session_out main "$V=1" '{"session_id":"s1","source":"startup"}' >/dev/null
session_out main "" '{"session_id":"s1","source":"clear"}' >/dev/null
expect "check-session.sh kept a record once the variable was gone" \
  [ ! -e "$REC" ]
rm -rf "$REPO"

# --- degraded awk must fail CLOSED -----------------------------
# hit_without() decides the read-only exemptions via awk. If awk
# is missing or cannot evaluate POSIX classes, the exemption
# cannot be proven, and an unprovable exemption must block, not
# pass. Simulated with an awk shim that only fails.
SHIM=$(mktemp -d)
printf '#!/bin/sh\nexit 2\n' > "$SHIM/awk"
chmod +x "$SHIM/awk"
OUT=$(json_for 'fdisk -l /dev/sda' \
  | env -u HOSTWARDEN_GUARD_DISABLE PATH="$SHIM:$PATH" sh "$HOOK")
if printf '%s' "$OUT" \
  | grep -q '"permissionDecision":"deny"'; then
  PASS=$((PASS + 1))
else
  FAIL=$((FAIL + 1))
  echo "FAIL: broken awk failed OPEN (read-only fdisk was allowed)"
fi
rm -rf "$SHIM"

# --- no negated hit() may remain -------------------------------
# A rule of the form  hit X && ! hit Y  evaluates Y against the
# whole command string, so any unrelated flag disarms it (issue
# #4). Exemptions belong in hit_without(), which scopes them to
# the invocation. Without this check the shape creeps back in.
if grep -q '! *hit ' "$HOOK"; then
  FAIL=$((FAIL + 1))
  echo "FAIL: guard still uses a negated whole-string hit;" \
    "use hit_without() so the exemption stays scoped"
else
  PASS=$((PASS + 1))
fi

# --- development: the local scope ------------------------------
# The same guard in a development tree. Text that names a taboo
# is the work there and passes; anything that reaches a server,
# root or a container is judged in full, and what an ordinary
# user reaches stays guarded. The local scope depends on who runs
# the matrix: as root or in the disk group every fixture is full,
# and on a machine running systemd the power-off rules stay on, so
# the fixtures that assume otherwise are queued only where they
# hold.
check_dev() { check "dev-$1" "$2"; }
LOCAL_SCOPE=1
case "$(id 2>/dev/null)" in uid=0\(*|*\(disk\)*) LOCAL_SCOPE= ;; esac
if [ -n "$LOCAL_SCOPE" ]; then
  check_dev pass 'grep -rn fdisk rules/'
  check_dev pass 'rg -n mkfs AGENTS.md'
  check_dev pass 'git commit -m "docs: explain why mkfs is blocked"'
  check_dev pass 'git commit -m "fix: guard misses sfdisk --delete"'
  check_dev pass 'git log --oneline --grep=wipefs'
  check_dev pass 'git commit -m "feat(guard): refuse ansible-playbook and tofu apply"'
  check_dev pass 'grep -rn "ansible web1 -m parted" .claude/hooks/'
  check_dev pass 'gh pr create --title "guard: catch parted mklabel" --body x'
  check_dev pass 'grep -n "dd if=" rules/os/debian.md'
  check_dev pass 'mkfs.ext4 -F /tmp/disk.img'
  check_dev pass 'git commit -m "docs: cp image.raw /dev/sda"'
  check_dev pass 'rg "cp .* /dev/sda" .'
  check_dev pass 'grep -rn "zpool destroy" rules/'
  check_dev pass 'git commit -m "docs: why e2fsck -y is a taboo"'
  check_dev pass 'rg -n "lvremove|mdadm --create" .claude/hooks/'
  check_dev pass 'lvextend -L +1G vg0/root'
  if [ ! -d /run/systemd/system ]; then
    check_dev pass 'rg -n shutdown AGENTS.md'
    check_dev pass 'git commit -m "guard: FreeBSD shutdown -c now power cycles"'
    check_dev pass 'git log --oneline --grep=poweroff'
    check_dev pass 'gh pr create --title "guard: catch poweroff via systemctl" --body x'
  fi
fi
if [ -d /run/systemd/system ]; then
  check_dev deny 'systemctl poweroff'
  check_dev deny 'poweroff'
fi
# Reaching past this user's own files brings the full scope back.
check_dev deny 'ssh h "mkfs.ext4 /dev/sda1"'
check_dev deny 'sudo fdisk /dev/sda'
check_dev deny 'doas dd if=img of=/dev/sda'
check_dev deny 'docker exec lab fdisk /dev/sdb'
check_dev deny 'podman run --rm img wipefs -a /dev/sdb'
check_dev deny 'orb -m lab parted /dev/vdb mklabel gpt'
check_dev deny 'wsl.exe -u root mkfs.ext4 /dev/sdb'
check_dev deny 'powershell.exe -c "wsl -u root wipefs -a /dev/sdb"'
check_dev deny 'cmd.exe /c "wsl -u root fdisk /dev/sdb"'
# The Windows rules apply in every scope: a Windows user reaches
# them without admin.
check_dev deny 'wsl.exe --unregister Ubuntu'
check_dev deny 'Stop-Computer -Force'
check_dev deny "osascript -e 'do shell script \"newfs_apfs /dev/disk4\" with administrator privileges'"
check_dev deny 'git commit -m "ssh h mkfs.ext4 /dev/sda1"'
check_dev deny 'GIT_SSH_COMMAND=x git fetch; dd if=a of=/dev/sda'
check_dev deny 'rsync -a x h:/y; shutdown -h now'
check_dev deny 'ssh root@bsd "shutdown -c now"'
check_dev deny 'sudo cp image.raw /dev/sda'
# What an ordinary user reaches stays guarded in every scope.
check_dev deny 'rm -f ~/.ssh/id_ed25519'
check_dev deny 'chmod 000 ~/.ssh'
check_dev deny 'echo x > ~/.ssh/authorized_keys'
check_dev deny "sed -i '' 's/^#Port/Port/' /opt/homebrew/etc/ssh/sshd_config"
check_dev deny 'diskutil eraseDisk APFS X disk4'
check_dev deny 'python3 -c "import os; os.remove(\"/home/alice/.ssh/id_ed25519\")"'
check_dev deny 'HOSTWARDEN_GUARD_DISABLE=1 true'
# Without mode.sh beside it the guard cannot tell its mode, and a
# guard that cannot tell stays full.
NOMODE=$(mktemp -d)
cp "$GUARD_DEV" "$CLAUDE_DIR/hooks/json.sh" "$NOMODE/"
OUT=$(json_for 'mkfs.ext4 /dev/sda1' \
  | env -u HOSTWARDEN_GUARD_DISABLE sh "$NOMODE/guard-taboos.sh")
expect "the guard went local without mode.sh to tell its mode" \
  denied "$OUT"
# Without json.sh it can write no decision, and a hook that fails
# to start lets the call through; exit 2 blocks it instead, for
# guard-settings.sh too, once a call gets past its prefilter.
rm "$NOMODE/json.sh"
cp "$SGUARD" "$NOMODE/"
for g in guard-taboos.sh guard-settings.sh; do
  json_for 'cat notes/settings.json' | env -u HOSTWARDEN_GUARD_DISABLE \
    sh "$NOMODE/$g" >/dev/null 2>&1
  expect "$g without json.sh did not exit 2" [ $? -eq 2 ]
done
rm -rf "$NOMODE"

# --- drain the queued fixtures ---------------------------------
# Failures are sorted rather than printed as they land, so two
# runs of the same broken tree read the same.
if [ "$NCHECKS" -gt 0 ]; then
  # One jq run builds every fixture's hook input, so no child
  # starts one: four fields per fixture from here on.
  # Without jq the fourth is a dash and the child falls back to
  # json_for. Not an empty field: BSD xargs drops those. printf
  # repeats its format, so one takes a hundred fixtures.
  if command -v jq >/dev/null 2>&1; then
    jq -Rsj '([0] | implode) as $nul | split($nul)[:-1] | _nwise(3)
      | (.[0], .[1], .[2],
         if .[1] == "JSON" then .[2]
         else {tool_name: .[1], tool_input: {command: .[2]}} | tojson
         end) + $nul' < "$QUEUE" > "$QUEUE.in"
  else
    xargs -0 -n 300 printf '%s\0%s\0%s\0-\0' < "$QUEUE" > "$QUEUE.in"
  fi
  # Batches of 25, not one child per fixture: each child is a shell
  # that parses this file. 25 keeps a batch far below GNU xargs'
  # 128 KiB command buffer (under 30 KB today, the longest fenced
  # blocks included) and still gives every core several batches. A
  # batch that xargs cuts at that limit anyway fails in the child,
  # which counts what is left over. (BSD xargs -x would say so
  # itself, but with -0 it hands over one argument per call.)
  RESULT=$(xargs -0 -n 100 -P "$JOBS" sh "$SELF" --verdict \
    < "$QUEUE.in")
  XSTATUS=$?
  # Every deny that came back is valid JSON Claude Code reads as a
  # deny, or a failure: one jq run turns each deny: line into ok or
  # a FAIL line. Without jq the JSON cannot be checked.
  if command -v jq >/dev/null 2>&1; then
    RESULT=$(printf '%s\n' "$RESULT" | jq -Rr '
      if startswith("deny:") or startswith("ask:")
      then (index(":")) as $i | .[:$i] as $d | .[$i+1:] as $j
        | if ($j | try (fromjson
              | .hookSpecificOutput.permissionDecision == $d)
            catch false)
          then "ok"
          else "FAIL [\($d), got \($d) as invalid JSON]: \($j)" end
      else . end')
  else
    RESULT=$(printf '%s\n' "$RESULT" | sed -e 's/^deny:.*/ok/' \
      -e 's/^ask:.*/ok/')
  fi
  NGOT=$(printf '%s\n' "$RESULT" | grep -c . || true)
  NOK=$(printf '%s\n' "$RESULT" | grep -c '^ok$' || true)
  PASS=$((PASS + NOK))
  BADS=$(printf '%s\n' "$RESULT" | grep -v '^ok$' | grep . \
    | LC_ALL=C sort || true)
  if [ -n "$BADS" ]; then
    printf '%s\n' "$BADS"
    FAIL=$((FAIL + $(printf '%s\n' "$BADS" | wc -l)))
  fi
  # Every queued fixture has to come back with a line. A child
  # that dies before it prints one -- a failed spawn, an OOM kill
  # -- leaves a fixture unjudged, and a matrix that ran in part
  # is not a matrix that passed: that is how a taboo stops being
  # blocked without anything saying so.
  if [ "$XSTATUS" -ne 0 ] || [ "$NGOT" -ne "$NCHECKS" ]; then
    FAIL=$((FAIL + 1))
    echo "FAIL: the parallel drain returned $NGOT verdicts for" \
      "$NCHECKS fixtures (xargs exit $XSTATUS) -- the matrix did" \
      "not run in full, which is not the same as it passing"
  fi
fi

echo "guard-taboos tests: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
