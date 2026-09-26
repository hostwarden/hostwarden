#!/bin/sh
# guard-taboos.sh — PreToolUse hook (matcher: Bash|Monitor|Edit|
# Write|MultiEdit|NotebookEdit).
# Monitor runs a shell command too, handed over in the same
# tool_input.command field, so both are read the same way here.
#
# Mechanically enforces Hostwarden's absolute taboos from
# AGENTS.md → Critical Safety Rules, below the model layer:
#
#   - halt / poweroff / shutdown without -r / init 0 /
#     telinit 0 / sysrq-trigger
#   - mkfs / mke2fs / newfs* / wipefs (write forms)
#   - partition-table writers (fdisk/cfdisk/sfdisk/gdisk/
#     sgdisk/parted/gpart/gpt/diskutil write forms)
#   - raw-device wipers that leave the partition table
#     alone (blkdiscard, nvme format/sanitize, hdparm
#     secure-erase, badblocks -w, shred, dd, a redirect,
#     tee, cp or a download onto a disk device)
#   - storage repair and destroy: the tier of rules/storage.md
#     that lists them (fsck without -n, a ZFS rewind, ...)
#   - destroying SSH keys (host keys, authorized_keys, id_*,
#     or the directory holding them: ~/.ssh, an appliance
#     key store such as /conf/sshd) by any means: rm/shred/
#     truncate/mv/chmod/chown/install/ln/setfacl/patch, find
#     -delete, a redirect, ssh-keygen -f, or a write into
#     one (tee, cp/rsync/scp, dd, sed -i, an editor, curl -o
#     and other output flags)
#   - writes to sshd_config(.d/) under any .../etc/ssh, or
#     to a file an appliance merges into it (/etc/sshd_extra),
#     and deploying OpenMediaVault's ssh Salt state, which
#     rewrites sshd_config and the keys without naming them
#   - any of the last three reached through a language
#     runtime (python/perl/ruby/node/awk ...), whose file
#     I/O looks nothing like a shell write
#   - deleting, moving or re-permissioning sshd's revocation
#     list (RevokedKeys) under any .../etc/ssh, directly or
#     through a language runtime: sshd then refuses every
#     public key login
#   - the same effects through a configuration tool: running a
#     playbook, ansible-pull or ansible-console at all; an ad-hoc
#     ansible call with a module that partitions, formats, powers
#     off, writes keys or runs a local script, or that writes to a
#     key or sshd_config; terraform or tofu apply and destroy
#   - the same effects on any Windows machine, reached over
#     SSH or through WSL: shutdown /s /p /h, Stop-Computer,
#     wsl --shutdown/--terminate (halt), wsl --unregister (the
#     distribution's whole disk), the same through wslconfig,
#     diskpart, mbr2gpt, format X:, cipher /w, bcdedit beyond
#     /enum and /v, the Storage cmdlets (Clear-Disk,
#     Format-Volume, Remove-VirtualDisk ...),
#     \\.\PhysicalDriveN, sshd_config and host keys under
#     ProgramData\ssh, and PowerShell or cmd.exe as a runtime
#   - an SSH key, a key store, sshd_config or dropbear's config
#     as the target of Edit, Write, MultiEdit or NotebookEdit,
#     which reach this machine's files without any shell
#
# ASKED, not denied -- the user confirms the exact command in a
# permission prompt (see "The ask tier" below the scope for the
# membership criterion and the modes that deny instead):
#
#   - stopping or deleting a system container, jail or VM (the
#     managers and their verbs in GUESTMGRS: pct/qm stop, shutdown
#     or destroy, incus/lxc stop or delete, virsh destroy,
#     shutdown or undefine, xe vm-shutdown, vm-destroy or
#     vm-uninstall, bastille/iocage stop, restart or destroy; and
#     lxc-stop, lxc-destroy, jail -r, service jail stop or restart
#     and its bastille and iocage twins, and TrueNAS' midclt call
#     vm.stop / vm.delete
#     and its virt.instance twins; that API's own poweroff method
#     spells the word the rule above denies in every mode, which
#     is stricter than this tier and stays that way)
#   - a routine storage change: the change tier of
#     rules/storage.md (lvextend, mdadm --add, zpool replace,
#     zfs destroy of a snapshot, ...)
#
# What it deliberately does NOT scan: the body of a heredoc that
# is written to an ordinary file by cat or tee (issue #8). That
# is documentation, not code. Every other heredoc — above all
# `ssh host bash -s <<EOF`, whose body runs remotely — is scanned
# in full.
#
# The taboos are EFFECTS, not a list of binaries. When a new
# tool reaches one of the effects above, it belongs in here,
# and the test matrix gets a line for it. Issue #5 came from
# the reverse: the rules named tools, so cfdisk, diskutil
# eraseDisk, gpt destroy, blkdiscard and a truncating
# redirect over authorized_keys all walked through. Issue #6
# was the same mistake one level in: the rules protecting a
# PATH named the ways a shell spells a write, so
# python3 -c "open('/etc/ssh/sshd_config','a').write(...)"
# was not a write to any of them. Issue #7 was the same
# mistake one level UP the path: the protected paths were key
# FILENAMES, so chown -R alice:alice /home/alice/.ssh
# re-permissioned every key in the directory without naming
# one, while the spelled-out chmod on authorized_keys was
# denied.
#
# The hook scans the ENTIRE command string, so taboos hidden
# inside wrappers like  ssh root@host "mkfs.ext4 /dev/sda1"
# are caught regardless of quoting. A PreToolUse deny blocks
# in every permission mode, including bypassPermissions.
#
# Rules that exempt a read-only form (fdisk -l, sfdisk -d,
# shutdown -r) evaluate that exemption per invocation, not
# against the whole string: it must sit in the same segment as
# the taboo command and follow it. This is stricter than a plain
# whole-string scan, so a taboo word inside quoted prose --
# documentation, commit messages, ticket notes -- is matched
# more often.
#
# Issue #8 narrowed the biggest source of that noise: a heredoc
# body written to a file by cat or tee is data, not code, and is
# no longer scanned. See the heredoc section below for the exact
# conditions and for why the consumer, never the body, decides.
# Writing Hostwarden's own changelog no longer trips the guard.
#
# Known, accepted false positives that REMAIN (the patterns are
# deliberately coarse — this guard protects production disks, not
# grep pipelines):
#   - A taboo word as a quoted ARGUMENT: `grep poweroff
#     /var/log/syslog`, `systemctl status shutdown.target`.
#     segments() splits on quotes so that ssh host "shutdown -h
#     now" is caught, and after that split an argument and an ssh
#     payload have the same shape. Separating them needs a
#     per-command list of which arguments are data, which is
#     open-ended and would reopen issue #4. Rephrase the probe
#     (`grep 'power[o]ff'`) instead.
#   - `cp /etc/ssh/sshd_config /tmp/` is blocked although it only
#     reads the file — copy out via `cat /etc/ssh/sshd_config >
#     /tmp/copy` instead.
#   - The sshd paths match as substrings, with no boundary on
#     either side: sshd_config.bak, /etc/sshd_extra.bak and a
#     copy staged under another root (mnt/etc/ssh/sshd_config)
#     count as the real file. The left side stays open on
#     purpose, so /usr/local/etc/ssh and an offline image are
#     covered (the hostwarden-os-install skill, cloud-image).
#     Keep backups outside the guarded path, e.g.
#     /root/backup/sshd_config.
#   - ssh-keygen with a private key path ANYWHERE in the command:
#     `file /etc/ssh/ssh_host_ed25519_key; ssh-keygen -lf
#     ...key.pub` is denied although each part passes alone.
#     Matching per invocation would miss K=<key>; ssh-keygen -f
#     $K, and what -l does next to ssh-keygen's write modes is
#     unverified, so there is no -l exemption either. Run the
#     fingerprint in a call of its own (rules/secrets.md).
#   - An ssh ControlPath under .ssh/ makes any rm, mv or chmod in
#     the same command look like a key operation. Hostwarden keeps
#     its sockets in ~/.cache/hostwarden for that reason
#     (rules/ssh-connections.md).
#   - rsync with -e "ssh -i ~/.ssh/id_..." AFTER its operands
#     reads as a copy onto that key, because writes_to takes the
#     last word as the destination. Put -e before the operands.
#
# Being blocked is EXPECTED behavior. Explain it to the user.
# Never rephrase, re-quote, or otherwise obfuscate a command to
# evade this guard, and never pick another tool to reach the same
# effect. A command that only carries a taboo word as TEXT -- a
# commit message, a PR body, a search pattern -- evades nothing
# when the text moves into a file that is passed instead (git
# commit -F, gh --body-file) or the pattern stops spelling the
# word. The deny message says so: an agent left to guess learns
# that routing around the guard is normal, and that habit is the
# danger on a production host. The same holds for an asked
# command: put it to the user as it stands, never in another
# spelling that skips the prompt.
#
# Two scopes, chosen by the mode mode.sh determines:
#
#   full   Every rule below. Operations, and any checkout whose
#          mode cannot be read.
#   local  A development checkout or a worktree, for a command
#          that names nothing reaching past this user's own files
#          (REACH below: ssh and its kin, sudo and its kin, a
#          container, VM or cloud tool), run by a user who is
#          neither root nor in the disk group. The rules that need
#          root -- power off, filesystems, partition tables, raw
#          devices -- have nothing to act on there: the shim
#          refuses sudo, and any route to a server, root or a
#          container brings the full scope back. What an ordinary
#          user reaches stays guarded: SSH keys, sshd_config (a
#          Homebrew one belongs to the user), diskutil, which
#          erases an external disk without root, the Windows rules
#          (wsl --unregister and Stop-Computer need no admin), and
#          on a machine running systemd every power-off rule,
#          because logind lets the user at the seat power off
#          without root.
#
# The local scope exists because this repository names taboos all
# day: its rules, tests, commit messages and PR titles are about
# them. A guard that fires on that text blocks the work without
# protecting anything, and teaches agents to route around it.
#
# Override for legitimate flows (the hostwarden-os-install skill
# runs mkfs/sgdisk by design): the OPERATOR sets
# HOSTWARDEN_GUARD_DISABLE=1 in the environment BEFORE launching
# the session. An inline assignment inside a proposed command
# does not count and is itself blocked, so the model cannot
# disarm the guard. Nor can a value that reaches the environment
# mid-session through a reloaded settings file: the variable counts
# only when check-session.sh recorded at SessionStart that this
# session started with it (~/.cache/hostwarden/guard-off-<id>).

# shellcheck disable=SC2034 # read by the modules and json.sh
INPUT=$(cat)

case $0 in */*) HOOKDIR=${0%/*} ;; *) HOOKDIR=. ;; esac
LIBDIR=$HOOKDIR/../../lib
# The rules live in guard-taboos.d/, one file per effect, sourced in
# this order into this shell: each reads what the ones before it
# set. Order is behaviour: the first deny wins, and a later rule
# reads HAS_KEY, SEGS or DISK as an earlier one left them. A new
# module is added to this list, and the fixture matrix gets its
# lines (tests/hooks/guard-taboos/).
GUARD_MODULES='edit command first-boot scope power disks storage ssh
config-mgmt interpreters guests'
# Without json.sh the guard could neither read the session nor say
# deny, and without one of its modules it would judge by fewer
# rules than it claims. A hook that fails to start lets the call
# through: exit 2 blocks it instead.
if [ ! -f "$LIBDIR/json.sh" ]; then
  echo "hostwarden guard: json.sh is missing from $LIBDIR" >&2
  exit 2
fi
for GUARD_MOD in $GUARD_MODULES; do
  if [ ! -f "$HOOKDIR/guard-taboos.d/$GUARD_MOD.sh" ]; then
    echo "hostwarden guard: guard-taboos.d/$GUARD_MOD.sh is missing" \
      "beside $0" >&2
    exit 2
  fi
done
# shellcheck source=../../lib/json.sh
. "$LIBDIR/json.sh"

# Operator-level override: inherited at launch, and recorded then.
if [ "${HOSTWARDEN_GUARD_DISABLE:-}" = "1" ]; then
  SID=$(hook_session_id)
  if [ -n "$SID" ] && [ -e "$HOME/.cache/hostwarden/guard-off-$SID" ]; then
    exit 0
  fi
fi

decide() {
  # decide <deny|ask> <reason> -- the JSON decision on stdout, then
  # done (json.sh).
  hook_decision "$1" "hostwarden guard: $2"
}

deny() {
  # A taboo: blocks in all permission modes.
  decide deny "$1 (AGENTS.md - Critical Safety Rules). \
${GUARD_SCOPE_NOTE:-}Blocked in all permission modes. Explain this to \
the user, and never reach the same effect another way - not by \
rephrasing, re-quoting or switching tools. A command that only \
carries the word as text and runs none of it is not evading anything \
when the text moves into a file that is passed instead (git commit \
-F, gh --body-file), or when a search pattern stops spelling the \
word (power[o]ff). ${GUARD_ROUTE:-Installing or replacing an OS is the \
one flow that legitimately needs these commands: read the \
hostwarden-os-install skill, which states what has to hold first.}"
}


# The rules, in order. A module that decides exits; one that finds
# an effect for the ask tier registers it with ask_for.
for GUARD_MOD in $GUARD_MODULES; do
  # shellcheck source=/dev/null
  . "$HOOKDIR/guard-taboos.d/$GUARD_MOD.sh"
done

# --- The ask tier: decided last --------------------------------
# Guests, storage changes and first-boot writes, whichever the line
# holds, in one prompt.
[ -n "$ASKWHAT" ] && ask_decide

# No taboo matched: no decision, normal permission flow applies.
exit 0
