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

INPUT=$(cat)

case $0 in */*) HOOKDIR=${0%/*} ;; *) HOOKDIR=. ;; esac
# Without json.sh the guard could neither read the session nor say
# deny, and a hook that fails to start lets the call through: exit
# 2 blocks it instead.
if [ ! -f "$HOOKDIR/json.sh" ]; then
  echo "hostwarden guard: json.sh is missing beside $0" >&2
  exit 2
fi
# shellcheck source=json.sh
. "$HOOKDIR/json.sh"

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

# --- Edit, Write, MultiEdit, NotebookEdit: the target path ------
# These tools write one file, named in file_path (notebook_path),
# and a Bash call never carries that key: inside a JSON string the
# quotes around a key-like word are escaped, so a bare
# "file_path" is a key. Such a call is judged by its target alone,
# in every mode and scope, and never reaches the command scan
# below: its content is text that nothing runs.
#
# The targets are the key files and sshd's config the Bash rules
# protect, matched exactly on the right, so a document about them
# (a note named authorized_keys.md, sshd_config.example) stays
# editable:
# authorized_keys and OpenMediaVault's directory of that name, a
# private or public key under .ssh, a host key, an appliance key
# store (/conf/sshd, /etc/dropbear, /etc/config/ssh), Windows'
# ProgramData\ssh,
# sshd_config and its drop-ins, a file an appliance merges into
# it, and dropbear's config. ~/.ssh/config and known_hosts are not
# keys and stay open. The left side stays open as in the Bash
# rules, so /opt/homebrew/etc/ssh, an offline image and
# /mnt/c/ProgramData count.
#
# The path is judged as given and as the file system resolves it:
# the directory physically, and a link as the last component
# followed, so a link elsewhere that points at a key is the key.
# A . or .. segment is also removed by text first, and that form is
# resolved the same way: a directory that does not exist yet cannot
# be resolved, and a tool that normalises the path by text writes
# ~/.ssh/nosuch/../id_ed25519 to ~/.ssh/id_ed25519. The match
# ignores case: macOS file systems do by default, so ~/.SSH/
# AUTHORIZED_KEYS opens authorized_keys, and pwd -P keeps the case
# it was given.
# KEYSTORE: the appliances' key stores, whole directories of keys
# and sshd's config; KEYDIR below says whose they are.
KEYSTORE='conf/sshd|etc/config/ssh|etc/dropbear'
FILEKEY='((^|[/\\])authorized_keys2?|/authorized_keys/[^/]+|(^|[/\\])\.ssh[/\\]+id_[^/\\]+|/etc/ssh/ssh_host_[^/]+|/('"$KEYSTORE"')/[^/]+|/etc/ssh/sshd_config(\.d/[^/]+)?|/etc/sshd_extra|/etc/(config|conf\.d|default)/dropbear|programdata[/\\]+ssh[/\\]+[^/\\]+)$'
KEYMSG="writing an SSH key, authorized_keys or the SSH server's \
config is never allowed"
case "$INPUT" in
*'"file_path"'*|*'"notebook_path"'*)
  FP="" FWD=""
  if command -v jq >/dev/null 2>&1; then
    eval "$(printf '%s' "$INPUT" | jq -r '@sh "FP=\(.tool_input.file_path
      // .tool_input.notebook_path // "") FWD=\(.cwd // "")"' 2>/dev/null)"
  fi
  if [ -z "$FP" ]; then
    # Without jq, or a path jq could not read: the raw input
    # decides, which can only over-block.
    printf '%s' "$INPUT" | tr '"' '\n' | grep -Eiq "$FILEKEY" \
      && deny "$KEYMSG, and without jq the target of this edit cannot \
be told apart from its content - install jq"
    exit 0
  fi
  case "$FP" in /*) ;; *) FP="$FWD/$FP" ;; esac
  # resolve <path> — appends the path as the file system resolves it
  # to FALL, one per line.
  resolve() {
    R=$1 n=0
    while [ $n -lt 10 ]; do
      FD=${R%/*}
      [ -d "${FD:-/}" ] && R="$(cd "${FD:-/}" && pwd -P)/${R##*/}"
      [ -L "$R" ] || break
      L=$(readlink "$R")
      case "$L" in /*) R=$L ;; *) R="${R%/*}/$L" ;; esac
      n=$((n + 1))
    done
    # Still a link after ten steps: a loop, or a chain long enough
    # to hide where it ends. Neither can be shown to miss a key.
    [ -L "$R" ] && deny "$KEYMSG, and this edit goes through a chain \
of links that does not end, so its target cannot be shown to be \
something else"
    FALL="$FALL$R
"
  }
  FALL="$FP
"
  resolve "$FP"
  case "/$FP/" in
  */./*|*/../*)
    FNORM=$(printf '%s\n' "$FP" | awk -F/ '{
      n = 0
      for (i = 2; i <= NF; i++) {
        if ($i == "" || $i == ".") continue
        if ($i == "..") { if (n) n--; continue }
        s[++n] = $i
      }
      o = ""
      for (i = 1; i <= n; i++) o = o "/" s[i]
      print (o == "" ? "/" : o)
    }')
    FALL="$FALL$FNORM
"
    resolve "$FNORM"
    ;;
  esac
  if printf '%s' "$FALL" | grep -Eiq "$FILEKEY"; then
    deny "$KEYMSG, through an edit as much as through a shell - read \
it with cat, grep or sshd -T, and leave a change to it to the user"
  fi
  exit 0
  ;;
esac

# Extract the command string, Bash's or Monitor's. Without jq (or
# on malformed input) fall back to scanning the raw stdin text —
# that can only over-block, never under-block. A Monitor call
# without a command is a WebSocket watch, which starts no shell:
# jq marks it w and it passes, where its description would
# otherwise be scanned as a command. Without jq it cannot be told
# from a Monitor call jq failed on, so it is scanned raw.
# The permission mode, which only the guest rule at the end reads,
# comes from the same jq call, as shell assignments @sh has quoted.
# -s parses the whole input before printing anything, so input jq
# cannot read sets neither and is scanned raw.
CMD="" MODE=""
if command -v jq >/dev/null 2>&1; then
  eval "$(printf '%s' "$INPUT" | jq -rs '@sh "CMD=\(map(
      if .tool_name == "Monitor" and (.tool_input.command // "") == ""
      then "w" else "c" + (.tool_input.command // "") end) | join("\n"))
    MODE=\(map(.permission_mode // empty | tostring) | join("\n"))"' \
    2>/dev/null)"
  [ "$CMD" = w ] && exit 0
  CMD=${CMD#c}
fi
[ -n "$CMD" ] || CMD="$INPUT"

# --- Heredoc bodies that are DATA, not code -------------------
# Documentation is the one thing that legitimately contains taboo
# words: a changelog entry describing a shutdown checkpoint, a
# rule file about fdisk, a commit message. Scanned as a command
# string, that prose is indistinguishable from an invocation, and
# the guard blocked Hostwarden's own changelog write over the word
# "shutdown" inside a heredoc.
#
# A heredoc body is only safe to skip when the command consuming
# it CANNOT execute it. That is decided by the consumer, never by
# the body, because these two look almost identical:
#
#   cat >> notes.md <<EOF          <- the body is text
#   ssh host bash -s <<EOF         <- the body RUNS, remotely
#
# So the body is dropped only when the first line is one lone
# pure data sink -- cat or tee writing to an ordinary file -- and
# every other condition fails CLOSED back to scanning everything:
# more than one heredoc, an unrecognized consumer, a missing
# terminator, a /dev/ target, or any awk failure. Whatever sits
# OUTSIDE the body (the first line itself, and everything after
# the terminator) is always still scanned, so
#   cat >> f <<EOF ... EOF; shutdown -h now
# is caught on the trailing command exactly as before.
#
# Deliberate boundary: a data sink whose target is itself
# executed later is excluded from the exemption, because writing
# a taboo INTO such a file reaches the effect on a delay. That
# set is named by EFFECT -- "something runs this file later" --
# and enumerated as scheduler and init locations, anything under
# /etc, launchd, the executable directories, script files by
# extension, and the shell start-up files. Over-matching there
# costs nothing: it only means the body is scanned as ordinary
# command text, which is what every non-exempt command gets.
# The wider boundary stays the documented one -- this hook is a
# backstop against the everyday mistake, not a sandbox. A body
# built at runtime, or fetched, defeats any string matcher.
#
# Writes AT a protected path need no rule here: the sink line
# itself is never dropped, so cat >> ~/.ssh/authorized_keys is
# still judged by the normal SSH-key rules below.
#
# NOT fixed by this, on purpose: a taboo word quoted as an
# ARGUMENT, e.g. grep shutdown /var/log/syslog. segments() splits
# on quotes so that ssh host "shutdown -h now" is caught, and
# after that split the grep argument and the ssh payload are the
# same shape. Telling them apart needs a per-command list of
# which arguments are data, which is open-ended and would reopen
# issue #4. Rephrase the probe (grep 'shut[d]own') instead.
#
# Only commands that carry a << at all can have a heredoc, and
# the awk below can do nothing but reprint the rest. The guard
# runs on every Bash call, so that fork is worth skipping.
case "$CMD" in
*'<<'*)
CMD_NOHEREDOC=$(printf '%s\n' "$CMD" | awk '
  BEGIN { q = sprintf("%c", 39) }
  NR == 1 {
    first = $0
    # A raw device target is never an ordinary file.
    if (first ~ /\/dev\//) { bad = 1; exit }
    # Targets that something later EXECUTES are not inert either.
    # Schedulers, init and unit locations, anything under /etc:
    if (first ~ /cron|systemd|init\.d|rc\.d|profile\.d|\/etc\//) {
      bad = 1; exit
    }
    # launchd jobs (macOS):
    if (first ~ /launchd|LaunchAgents|LaunchDaemons|\.plist/) {
      bad = 1; exit
    }
    # the executable directories -- /bin /sbin /usr/bin ~/bin ...:
    if (first ~ /\/s?bin\//) { bad = 1; exit }
    # a script file by extension:
    if (first ~ /\.(sh|bash|zsh|ksh|command|py|pl|rb)([ \t<]|$)/) {
      bad = 1; exit
    }
    # a shell start-up file, sourced on the next login:
    if (first ~ /\.(bashrc|bash_profile|bash_login|zshrc|zshenv|zprofile|zlogin|kshrc|cshrc|profile|login)([ \t<]|$)/) {
      bad = 1; exit
    }
    # Exactly one heredoc, so there is exactly one body to find.
    tmp = first; cnt = 0
    while (match(tmp, /<</)) { cnt++; tmp = substr(tmp, RSTART + 2) }
    if (cnt != 1) { bad = 1; exit }
    # The whole first line must be the data sink and nothing else:
    # no ; & | backtick $( ) that could smuggle a second command.
    # The target may arrive either way round -- cat writes through
    # a redirect (cat > f), tee takes it as a plain argument
    # (tee f) -- so both separators are allowed. The path token
    # itself still excludes every character that could start
    # another command, and < > stay out of it so the heredoc
    # operator can never be swallowed as a filename.
    p = "[\"" q "]?[^ \t;|&`$()<>\"" q "]+[\"" q "]?"
    shape = "^[ \t]*(cat|tee)([ \t]+-a)?(([ \t]*>>?[ \t]*|[ \t]+)" p ")?[ \t]*<<-?[ \t]*[\"" q "]?[A-Za-z_][A-Za-z0-9_]*[\"" q "]?[ \t]*$"
    if (first !~ shape) { bad = 1; exit }
    d = first
    sub(/^.*<<-?[ \t]*/, "", d)
    gsub(/["]/, "", d); gsub(q, "", d); sub(/[ \t]*$/, "", d)
    if (d !~ /^[A-Za-z_][A-Za-z0-9_]*$/) { bad = 1; exit }
    delim = d
    print first
    next
  }
  # Drop the body. Ending it on a whitespace-stripped match too is
  # deliberate: erring early only scans MORE text, never less.
  !ended {
    t = $0; sub(/^[ \t]+/, "", t)
    if ($0 == delim || t == delim) ended = 1
    next
  }
  { print }
  END { if (bad || !ended) exit 1 }
' 2>/dev/null)
GUARD_STRIP_STATUS=$?
# Only a clean parse of a recognized data sink may shrink the
# scanned text. Anything else keeps the full command string.
if [ "$GUARD_STRIP_STATUS" -eq 0 ] && [ -n "$CMD_NOHEREDOC" ]; then
  CMD="$CMD_NOHEREDOC"
fi
  ;;
esac

# The command string, plus one line per invocation it contains.
# Separators are ; & | quotes and newlines. Quotes count on
# purpose: to the shell, ssh -l root host "fdisk /dev/sda" is
# ONE invocation, but it carries a second command inside, and
# only splitting there puts fdisk in a segment that no longer
# holds ssh's -l. The FULL string stays in the list, so this can
# only ever block more, never less.
#
# CMD is final by now, so the split is computed once. The rules
# below ask dozens of questions of it, and re-forking tr for each
# of them costs more than the whole rest of the hook.
#
# The shell drops a backslash-newline before it reads a word, so
# shutdown -r -\<newline>h runs shutdown -r -h. A command that
# holds one is scanned a second time with those lines joined,
# added beside the original rather than instead of it.
CMDJ=
case "$CMD" in
*'\
'*)
  CMDJ=$(printf '%s\n' "$CMD" \
    | sed -e ':a' -e '/\\$/{' -e 'N' -e 's/\\\n//' -e 'ba' -e '}')
  ;;
esac
# The same goes for quotes and backslashes inside a word:
# shut''down, shut$'d'own and mk\fs run shutdown and mkfs. A
# command with one between two word characters is scanned once
# more with every quote, backslash and quoting $ removed, again
# beside the original. A name built from escapes ($'\x64') or
# variables is out of reach: this is a backstop, not a shell.
CMDQ=
case "$CMD$CMDJ" in
*[[:alnum:]_][\"\'\\\`\$][[:alnum:]_\"\'\\\`\$]*)
  CMDQ=$(printf '%s\n' "${CMDJ:-$CMD}" \
    | sed -e 's/\$["'\'']//g' -e 's/["'\''`\\]//g')
  ;;
esac
SEGS=$(printf '%s\n' "$CMD"
       printf '%s' "$CMD" | tr ';&|"'"'"'\n' '\n'
       for more in "$CMDJ" "$CMDQ"; do
         [ -n "$more" ] || continue
         printf '\n%s\n' "$more"
         printf '%s' "$more" | tr ';&|"'"'"'\n' '\n'
       done)

segments() {
  printf '%s\n' "$SEGS"
}

# The three texts once more, one per line, for a builtin case. Each
# segment is a piece of one of them, so a word without a newline is
# in some segment exactly when it is in TEXT: a case on it answers
# hit on a plain word without a process, and keeps the greps of a
# rule off every command that lacks the word the rule needs.
TEXT="$CMD
$CMDJ
$CMDQ"

hit() {
  segments | grep -Eq "$1"
}

# Case-insensitive variant. diskutil accepts its verbs in any
# case, so eraseDisk and erasedisk are the same command.
hit_i() {
  segments | grep -Eiq "$1"
}

# A raw disk device, as opposed to /dev/null, /dev/stderr,
# /dev/shm or /dev/disk/by-id (all of which are ordinary and
# must stay usable).
DEV='(/dev/(sd|vd|xvd|hd|nvme|mmcblk|nbd|loop|da|ada|nda|r?disk[0-9])|[Pp][Hh][Yy][Ss][Ii][Cc][Aa][Ll][Dd][Rr][Ii][Vv][Ee][0-9])'

# Any SSH key file, OR the directory that holds them. The
# directory belongs in here because re-permissioning or removing
# it reaches every key through the parent without ever naming a
# key: chown -R alice:alice /home/alice/.ssh hands the whole set
# to another owner, chmod 000 /root/.ssh hides it from sshd, and
# rm -rf ~/.ssh deletes it. The old pattern listed key FILENAMES
# only, so all three walked through while the spelled-out
# chmod 600 ~/.ssh/authorized_keys was denied. Same mistake as
# issues #5 and #6, one level up the path: the rule named the
# spelling of the target instead of the effect on it.
#
# Boundary, deliberately left open: a command that destroys an
# enclosing directory without naming .ssh at all (rm -rf /home/
# alice, a whole-filesystem operation) reaches the same effect
# and is NOT caught here. Closing it would mean treating every
# home directory as a key store. This is a backstop against the
# everyday mistake, not a sandbox.
#
# KEYPRIV additionally excludes a trailing .pub, so reading or
# copying a public key stays allowed while the private half does
# not. It stays filename-only on purpose: it guards a truncating
# redirect and ssh-keygen -f, neither of which is meaningful
# against a directory. KEYFILE is the same set without the
# trailing boundary, for writes_to below.
#
# Host keys and sshd_config do not always live in /etc/ssh:
# the OpenSSH port or package puts them in /usr/local/etc/ssh
# (FreeBSD; on OPNsense only sshd_config, see KEYDIR) or
# /opt/homebrew/etc/ssh. No pattern here
# is anchored on the left, so /etc/ssh matches every such prefix,
# and the rules must keep it that way instead of listing
# prefixes.
#
# KEYDIR adds the key stores of appliances (KEYSTORE, defined
# with FILEKEY above) to .ssh: OPNsense's
# /conf/sshd, and OpenWrt's /etc/dropbear, which holds dropbear's
# host keys and root's authorized_keys and nothing else. The rest
# of /conf is config and stays ordinary work. QNAP's
# /etc/config/ssh holds the live sshd_config (its init script
# starts sshd -f on it), sshd_user_config and authorized_keys
# (rules/appliance/qnap.md), so it counts as a store too.
# /etc/ssh itself is NOT a key store: it also holds ssh_config
# and moduli, so rm -rf /etc/ssh or chmod -R on it is left open,
# on the same terms as the home directory above.
#
# Windows' OpenSSH keeps both in C:\ProgramData\ssh, reached from
# WSL as /mnt/c/ProgramData/ssh. NTFS ignores case, and a Windows
# path may use backslashes, hence WINSSH.
# Every name below it is matched in any case too, and the
# directory itself counts as a key store: it holds the host keys
# and administrators_authorized_keys.
WINSSHDIR='[Pp][Rr][Oo][Gg][Rr][Aa][Mm][Dd][Aa][Tt][Aa][/\\]+[Ss][Ss][Hh]'
WINSSH="${WINSSHDIR}[/\\\\]+"
HOSTKEY="((/etc/ssh|/($KEYSTORE))/ssh_host_|/etc/dropbear/dropbear_|${WINSSH}[Ss][Ss][Hh]_[Hh][Oo][Ss][Tt]_)"
KEYDIR="(\\.ssh|/($KEYSTORE)|$WINSSHDIR)"
KEY="($HOSTKEY|authorized_keys|$KEYDIR"'(/|[^[:alnum:]_.-]|$))'
KEYFILE="($HOSTKEY"'[[:alnum:]_-]*[Kk][Ee][Yy]|\.ssh[/\\]+id_[[:alnum:]_-]+|authorized_keys|'"$WINSSH"'[[:alnum:]_]*[Aa][Uu][Tt][Hh][Oo][Rr][Ii][Zz][Ee][Dd]_[Kk][Ee][Yy][Ss])'
KEYPRIV="$KEYFILE"'([^.[:alnum:]]|$)'

# sshd's config: sshd_config, its drop-in directory, a file an
# appliance merges into it when it regenerates the config
# (pfSense appends /etc/sshd_extra), QNAP's own copy and its
# user file under /etc/config/ssh, dropbear's config where
# a system runs dropbear instead: OpenWrt's UCI file
# /etc/config/dropbear, /etc/conf.d/dropbear under OpenRC,
# /etc/default/dropbear on Debian, and Windows' sshd_config
# under ProgramData\ssh. The .d suffix is optional, so a plain
# hit on SSHD also finds the bare file. Then the editors that
# rewrite a file in place.
SSHD="(/etc/(ssh/sshd_config(\\.d(/[[:alnum:]_.-]*)?)?|config/ssh/sshd_(user_)?config|sshd_extra|(config|conf\\.d|default)/dropbear)|${WINSSH}[Ss][Ss][Hh][Dd]_[Cc][Oo][Nn][Ff][Ii][Gg])"
EDITOR='(vi|vim|nvim|nano|emacs|ed)'

# --- a guest that has never run --------------------------------
# AGENTS.md -> Critical Safety Rules lets the first-boot
# configuration of a guest that has never started set sshd's login
# options and keys, whatever form that configuration takes, and
# hostwarden-new-guest writes it. Nothing here can prove that a
# root filesystem or an image belongs to such a guest, so the two
# shapes a manager owns are put to the user with the path in front
# of them, and everything else stays denied.
#
#   - the root filesystem of a container under its manager's own
#     directory: /var/lib/lxc/<name>/rootfs, /var/lib/machines/
#     <name>, an Incus or LXD container in its storage pool. A
#     path under one of those is not the running system's /etc.
#     The root must sit right in front of the guarded path, so
#     rootfs/../../etc/ssh is the host's and stays denied. For
#     keys that means host keys at rootfs/etc/ssh; a user's
#     authorized_keys further down stays denied.
#   - a disk image a libguestfs tool opened with -a or --add, as
#     the only command on the line. libguestfs refuses a disk
#     another process has open, so that is a file rather than a
#     server. A -d or --domain names a libvirt guest that may be
#     running and does not count, and neither does a line with a
#     second command or a redirect beside the tool: those spell
#     the host's /etc/ssh exactly as the image's is spelled.
#
# /mnt and /media are deliberately absent: a bind mount of the
# live system is spelled exactly the same way, and what the guard
# cannot tell apart it must not decide.
#
# Asking, not allowing, for the same reason the guest rules ask:
# the everyday mistake here is a path that looks like a guest and
# is the host. Where no prompt can reach a human the answer is
# deny, and the user runs it themselves.
#
# The ask is registered where it is found and decided at the end of
# this file, never on the spot: decide exits, and every rule after
# the sshd and key rules has to see the rest of the line first. A
# first-boot write followed by any taboo is that taboo's deny.
GUESTROOT='(/var/lib/lxc/[^/[:space:]]+/rootfs|/var/lib/machines/[^/[:space:]]+|/var/lib/(incus|lxd)/storage-pools/[^/[:space:]]+/containers/[^/[:space:]]+/rootfs)'
IMAGETOOL='(virt-customize|virt-copy-in|virt-edit|virt-sysprep|guestfish|guestmount)'

FB_NL='
'

first_boot_only() {
  # first_boot_only <path pattern> -- true when the command works
  # on an image through libguestfs, or when EVERY occurrence of
  # that pattern sits under a guest root. One unqualified /etc/ssh
  # beside a qualified one is enough to fail: a command that
  # touches both is a command that touches the host.
  if hit "(^|[^[:alnum:]_.-])$IMAGETOOL([^[:alnum:]_.-]|\$)"; then
    # One invocation and nothing beside it. A second command or a
    # redirect names paths the image tool never sees, spelled the
    # same as the ones it does.
    case $CMD in
    *';'* | *'&'* | *'|'* | *'>'* | *'`'* | *'$('*) return 1 ;;
    esac
    case $CMD in
    *"$FB_NL"*) return 1 ;;
    esac
    # A domain may be running, whatever else the line carries.
    hit '(^|[[:space:]])(-d|--domain)([[:space:]]|=)' && return 1
    # Every invocation must name an image with -a, scoped to the
    # invocation rather than to the whole string.
    hit_without "(^|[^[:alnum:]_.-])$IMAGETOOL([^[:alnum:]_.-]|\$)" \
      '(^|[[:space:]])(-a|--add)([[:space:]]|=)' || return 0
  fi
  FB_ALL=$(segments | grep -oE "$1" | grep -c .)
  FB_UNDER=$(segments | grep -oE "$GUESTROOT$1" | grep -c .)
  [ "$FB_ALL" -gt 0 ] && [ "$FB_ALL" -eq "$FB_UNDER" ]
}

image_write_targets() {
  # image_write_targets -- the command line with the local side of
  # virt-customize's --copy-in and --upload (LOCAL:REMOTE) dropped.
  # That side is only read, so copying the host's own sshd_config
  # into an image as a reference is a read of it; what is left names
  # the paths the image is written at (image_sshd_dir below counts a
  # REMOTE that is sshd's directory). A LOCAL that itself holds a
  # colon is left in place and still counts, which errs on asking.
  printf '%s' "$CMD" \
    | sed -E "s/(--(copy-in|upload)([[:space:]]+|=)[\"']?)[^:[:space:]\"']+:/\\1:/g"
}

image_sshd_dir() {
  # image_sshd_dir -- true when a --copy-in or --upload REMOTE is
  # sshd's directory or inside it, or dropbear's key store, whatever
  # the local file is called: --copy-in takes a directory, and the
  # file lands in it under its own name. The directories dropbear's
  # config file lives in (/etc/config, /etc/conf.d, /etc/default)
  # count only when the line names dropbear, since everything else
  # goes there too.
  IWT=$(image_write_targets)
  printf '%s' "$IWT" \
    | grep -Eq ":/etc/(ssh|dropbear)([/[:space:]\"']|\$)" && return 0
  printf '%s' "$IWT" \
    | grep -Eq ":/etc/(config|conf\\.d|default)([/[:space:]\"']|\$)" \
    && printf '%s' "$CMD" | grep -q dropbear
}

first_boot_ask() {
  # first_boot_ask <what> -- the ask tier (ask_for below) for a
  # write that only a guest's first boot may make.
  ask_for "$1" "for a guest that has not started yet. Only the \
first-boot configuration of a guest that never ran may set sshd's \
login options and keys (AGENTS.md - Critical Safety Rules)" "Check \
that the path is the guest's and not this host's before approving."
}

# A general-purpose language runtime. See the interpreter section
# at the bottom for why this list, and not a list of the ways
# those runtimes spell a write.
INTERP='(^|[^[:alnum:]_.-])(python[0-9.]*|perl|ruby|node|nodejs|deno|bun|php[0-9.]*|lua[0-9.]*|tclsh|osascript|Rscript|julia|elixir|escript|erl|[gmn]?awk)([^[:alnum:]_.-]|$)'
# Windows' shells are runtimes too: Set-Content and Remove-Item
# spell a write no rule below knows. Matched without regard to
# case, as Windows finds them; cmd only as cmd.exe, since a bare
# cmd is a common word.
WININTERP='(^|[^[:alnum:]_.-])((powershell|pwsh)(\.exe)?|cmd\.exe)([^[:alnum:]_.-]|$)'
# wsl.exe and its older twin wslconfig.exe, as a command word.
# A quote may close right after it: "wsl.exe" --shutdown.
WSL='(^|[^[:alnum:]_.-])wsl(config)?(\.exe)?["'"'"']?[[:space:]]'

# The Windows rules below can only match a command that names
# wsl, a .exe, PowerShell, or one of the words they look for.
# A Windows server reached over SSH may see none of the first
# three: it runs a bare shutdown /s as shutdown.exe.
# Checking that once, without a process, keeps their greps off
# every other call; the guard runs on each one. A Windows rule
# whose word is missing here never runs, so a new rule adds its
# word. Linux uses shutdown and ciphers too, so those two count
# only in the form Windows gives them: a slash after shutdown,
# a /w or -w after cipher.
WIN=
case "$CMD" in
*[Ww][Ss][Ll]*|*.[Ee][Xx][Ee]*|*[Pp][Ww][Ss][Hh]*) WIN=1 ;;
*[Pp][Oo][Ww][Ee][Rr][Ss][Hh][Ee][Ll][Ll]*|*[Dd][Ii][Ss][Kk]*) WIN=1 ;;
*-[Cc][Oo][Mm][Pp][Uu][Tt][Ee][Rr]*|*-[Pp][Aa][Rr][Tt]*) WIN=1 ;;
*-[Vv][Oo][Ll][Uu][Mm][Ee]*|*[Mm][Bb][Rr]2*) WIN=1 ;;
*[Ff][Oo][Rr][Mm][Aa][Tt]*|*-[Ss][Tt][Oo][Rr][Aa][Gg][Ee]*) WIN=1 ;;
*[Ss][Hh][Uu][Tt][Dd][Oo][Ww][Nn]*/*|*[Bb][Cc][Dd][Ee][Dd]*) WIN=1 ;;
*[Cc][Hh][Kk][Dd][Ss][Kk]*) WIN=1 ;;
*[Cc][Ii][Pp][Hh][Ee][Rr]*[/-][Ww]*) WIN=1 ;;
esac

# True when command $1 occurs somewhere WITHOUT its read-only
# exemption $2 applying to that occurrence. Two conditions make
# an exemption count: it must sit in the same segment as the
# command, and it must FOLLOW it. Otherwise a flag belonging to
# a wrapper disarms the taboo, which is what issue #4 reported:
# ssh -l root host "fdisk /dev/sda" and lsblk -l && fdisk /dev/sdb
# were both waved through because a bare -l existed anywhere.
# A third argument i matches without regard to case, as Windows
# reads its commands; both patterns are then written in lowercase.
# awk -v reads backslash escapes, so a new pattern spells a literal
# dot [.] rather than \. .
#
# An exemption anchored with ^ lists what every argument may be
# rather than naming one read-only flag. It sees the line from
# the character before the command on, hence ^[^[:alnum:]]?, and
# the whole unsplit command is one of the lines, hence its end at
# the next ; & or |.
hit_without() {
  segments | grep -Eq${3:-} "$1" || return 1
  # The command IS present. From here on the only question is
  # whether the exemption belongs to it, so every failure path
  # below must deny. If this awk cannot evaluate POSIX classes,
  # we cannot prove the exemption applies: block.
  printf 'x' | awk '{ exit(($0 ~ /[[:alnum:]]/) ? 0 : 1) }' \
    2>/dev/null || return 0
  segments | awk -v cmd="$1" -v exempt="$2" -v fold="${3:-}" '
    {
      line = fold ? tolower($0) : $0
      while (match(line, cmd)) {
        if (RLENGTH <= 0) break
        if (substr(line, RSTART) !~ exempt) { bare = 1; exit }
        line = substr(line, RSTART + RLENGTH)
      }
    }
    END { exit(bare ? 0 : 1) }' 2>/dev/null
  GUARD_AWK_STATUS=$?
  # Only a clean "every occurrence is exempt" (exit 1) allows.
  # Any other status is an awk failure, and that must not pass.
  [ "$GUARD_AWK_STATUS" -eq 1 ] && return 1
  return 0
}

# The model must not disarm the guard from inside a command.
# Matches the assignment form only — merely mentioning the
# variable name (docs, grep) is fine. Note: heredocs flow
# through the command string too, so writing the literal
# assignment into a file or commit message also triggers
# this; phrase such text without the equals sign.
case "$TEXT" in
*HOSTWARDEN_GUARD_DISABLE=*)
  deny "inline HOSTWARDEN_GUARD_DISABLE assignment is not \
allowed - the operator must export it before launching the \
session" ;;
esac

# --- Scope: full, or local to a development session -----------
# The header says what each scope covers. A hook copied without
# mode.sh beside it cannot tell its mode and stays full.
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
if [ -f "$HOOKDIR/mode.sh" ]; then
  # shellcheck source=mode.sh
  . "$HOOKDIR/mode.sh"
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

# --- Power off ------------------------------------------------
# Each rule greps only a command that holds its word (TEXT above).
case "$TEXT" in
*halt*|*poweroff*)
  if power && hit '(^|[^[:alnum:]_-])(halt|poweroff)([^[:alnum:]_-]|$)'; then
    deny "halt/poweroff never runs without explicit user request"
  fi ;;
esac
case "$TEXT" in
*init*)
  if power && hit '(^|[^[:alnum:]_.-])(tel)?init[[:space:]]+0([^0-9]|$)'; then
    deny "init 0 powers off the server"
  fi ;;
esac
# echo o > /proc/sysrq-trigger cuts the power instantly, and b
# resets without syncing. Nothing reads this file, so any
# mention of it is a write.
case "$TEXT" in
*sysrq-trigger*)
  power && deny "sysrq-trigger powers off or resets the server \
without shutting anything down cleanly" ;;
esac
# Both Linux rules need the word itself, so a command without it
# skips their greps, as the Windows rules do with WIN below.
case "$TEXT" in
*shutdown*)
  # Some guest managers take shutdown as a verb for one guest
  # (GMSHUT), which the guest rule at the end asks about. The host
  # rules here judge the segments with that verb renamed, and the
  # full set is restored after them. xe's vm-shutdown needs no
  # renaming: none of these rules reads a shutdown after a dash.
  SEGS_ALL=$SEGS
  for gm in $GMSHUTWORDS; do
    case $SEGS in
    *"$gm"*)
      SEGS=$(printf '%s\n' "$SEGS" | sed -E \
        "s/((^|[^[:alnum:]_.-])(${GMSHUT#|})${GOPTS}[[:space:]]+)shutdown/\1guest-off/g")
      break ;;
    esac
  done
  # Windows' shutdown is judged below, so the Linux rule exempts
  # it rather than lending it its -r: shutdown.exe, or shutdown
  # whose every flag takes Windows' slash, as a Windows server
  # reached over SSH runs it. One dash flag keeps it Linux's,
  # quoted or escaped too: the shell and PowerShell drop " ' and `
  # before the program sees its flag.
  if power && hit_without '(^|[^[:alnum:]_-])shutdown([^[:alnum:]_-]|$)' \
    '(^|[[:space:]])-(r|c)([[:space:]]|$)|^[^[:alnum:]]?shutdown[.]exe|^[^[:alnum:]]?shutdown[[:space:]]+/[^[:space:];&|]*([[:space:]]+["'\''`]*[^[:space:];&|"'\''`-][^[:space:];&|]*)*[[:space:]]*([;&|]|$)'
  then
    deny "shutdown without -r powers off the server (reboots \
use shutdown -r; -c cancels)"
  fi
  # systemd and sysvinit let the last action flag win, so
  # shutdown -r -h now powers off; FreeBSD and macOS refuse the
  # pair. Order does not matter here: a flag that halts one
  # implementation is not waved through because another reboots.
  # Only a dash flag counts, so Windows' slash form is left to the
  # rules below. The shell drops quotes, backslashes and the $ of
  # $'...' before the program sees '-h', $'--poweroff', \-P or
  # --h"a"lt, so any of them may sit anywhere in the flag. Brace
  # expansion builds a flag too: -{r,h} is -r -h, so { } and ,
  # count among them. A sequence, -{h..h} or -{a..z}, can name any
  # letter in its range, so a dash before one counts on its own.
  if power && hit '(^|[^[:alnum:]_-])shutdown[[:space:]]([^;&|]*[[:space:]])?["'\''`\\${},]*(-["'\''`\\${},[:alnum:]]*\{[[:alnum:]]\.\.[[:alnum:]][^[:space:];&|]*|-["'\''`\\${},[:alnum:]]*[hHPp]["'\''`\\${},[:alnum:]]*|-["'\''`\\${},]*-["'\''`\\${},]*(h["'\''`\\${},]*a|p)["'\''`\\${},[:alpha:]]*)(["'\''`\\${},[:space:]]|$)'
  then
    deny "shutdown with -h, -H, -P, -p, --halt or --poweroff \
halts or powers off the server even beside -r"
  fi
  # -c cancels on Linux and takes no time. FreeBSD's shutdown needs
  # a time, and there -c turns the power off and on again through
  # the BMC (shutdown(8)). So -c with a time is FreeBSD's power
  # cycle.
  if power && hit '(^|[^[:alnum:]_-])shutdown[[:space:]]([^;&|]*[[:space:]])?-[[:alpha:]]*c[[:alpha:]]*[[:space:]]([^;&|]*[[:space:]])?["'\'']?(now|\+[0-9]+|[0-9]+(:[0-9]+)?)["'\'']?([[:space:]]|$)'
  then
    deny "shutdown -c with a time power cycles a FreeBSD server \
(on Linux, shutdown -c alone cancels)"
  fi
  SEGS=$SEGS_ALL
  ;;
esac
# Windows reads shutdown in any case and takes its flags with / or
# -, the dash only where shutdown.exe cannot be Linux's. /s and
# /sg shut down, /p powers off at once and /h hibernates, even
# beside a /r. Otherwise /r and /g restart and /a aborts. Both
# rules must match every form the Linux rule hands over, and the
# gate for WIN must let it through: widen all four together.
WINSHUT='(^|[^[:alnum:]_-])shutdown(\.exe[[:space:]]+([^;&|]*[[:space:]])?["'\''`]*[/-]|[[:space:]]+/([^;&|]*[[:space:]]["'\''`]*/)?)'
if [ -n "$WIN" ] \
  && hit_i "${WINSHUT}(s|sg|p|h)([[:space:]\"'\`]|\$)"; then
  deny "shutdown /s, /p and /h power off or hibernate the machine"
fi
if [ -n "$WIN" ] \
  && hit_without '(^|[^[:alnum:]_-])shutdown(\.exe([^[:alnum:]_.-]|$)|[[:space:]]+/)' \
  '(^|[[:space:]])[/-][rga]([[:space:]]|$)' i; then
  deny "shutdown.exe without /r, /g or /a powers off the machine"
fi
# Windows, as WSL reaches it. Stop-Computer is PowerShell's
# power-off. wsl --shutdown stops the virtual machine that every
# distribution runs in, and --terminate (-t, and wslconfig's /t)
# one distribution: either is a halt for whatever runs inside.
# -t counts only right after wsl, where it cannot belong to the
# command wsl runs.
if [ -n "$WIN" ] \
  && hit_i '(^|[^[:alnum:]_-])stop-computer([^[:alnum:]_-]|$)'; then
  deny "Stop-Computer powers off the machine"
fi
if [ -n "$WIN" ] \
  && hit_i "${WSL}([^;&|]*[[:space:]])?(--(shutdown|terminate)([[:space:]=]|\$)|/(t|terminate)([[:space:]]|\$))|${WSL}+-t([[:space:]]|\$)"
then
  deny "wsl --shutdown and --terminate stop WSL distributions, \
which is a power-off for everything running in them"
fi

# True when the command writes INTO a path matching $1 (a regex
# without a trailing boundary) through a tool that names its
# target: tee or sponge, dd of=, an output flag (curl -o, wget -O,
# sort -o, openssl -out), or the destination of cp, rsync or scp.
# The same shapes reach a disk device, sshd_config and a key.
#
# A copy is judged by its DESTINATION, the last operand of its
# invocation, because the common legitimate forms name the
# protected path as the source: scp -i ~/.ssh/id_ed25519, a backup
# of authorized_keys, cp /dev/sda disk.img. Trailing options,
# redirects, a closing parenthesis or backtick and a comment are
# skipped while looking for that operand; cp -t names it up front.
# An = right before an output path is excluded on purpose:
# ssh -o IdentityFile=~/.ssh/id_ed25519 only reads the key.
#
# The set of writers cannot be closed (an archive unpacked into
# place, a git checkout, any tool with an output flag of its own),
# so this stays a backstop, not a sandbox.
#
# END includes < and >: a redirect glued to the path
# (tee /etc/ssh/sshd_config<<EOF) still ends it.
END="([\"'[:space:];|&)\`<>]|\$)"
ENDARG="[\"']?([[:space:]]+(-[^[:space:]]*|[0-9]*[<>]+&?([[:space:]]*[^[:space:]]+)?))*[[:space:])\`]*(#.*)?\$"
writes_to() {
  hit "(^|[^[:alnum:]_.-])(tee|sponge)[[:space:]]([^;|&<>]*[[:space:]])?[^[:space:];|&]*$1$END" \
    || hit "(^|[[:space:]])of=[^[:space:]]*$1$END" \
    || hit "(^|[[:space:]])(-[oO]|-out|--output(-document)?)([[:space:]]+|=)?[^[:space:]=]*$1$END" \
    || hit "(^|[^[:alnum:]_.-])(cp|rsync|scp)[[:space:]]([^;&|]*[[:space:]])?[^[:space:]]*$1$ENDARG" \
    || hit "(^|[^[:alnum:]_.-])cp[[:space:]]([^;&|]*[[:space:]])?(-[[:alpha:]]*t[[:space:]]*|--target-directory[=[:space:]])[^[:space:]]*$1$END"
}

# --- Disks: one precheck --------------------------------------
# Every disk rule from here to shred, and the write onto a device
# after the storage rules, needs a word of its own in the command,
# so one case finds out whether any can match, and the twenty-odd
# greps below run only then. A new disk rule adds its word here; the
# storage rules between the two parts keep prechecks of their own. The words are case-sensitive as the rules read them,
# diskutil and PhysicalDrive in any case; dd, shred and a write onto
# a device need a device path. The Windows rules in between keep
# their own precheck, WIN, which opens this one too.
DISK=$WIN
case "$TEXT" in
*mkfs*|*mke2fs*|*mkntfs*|*mkdosfs*|*mkexfatfs*|*mkudffs*) DISK=1 ;;
*newfs*|*wipefs*|*fdisk*|*gdisk*|*parted*|*growpart*) DISK=1 ;;
*gpt*|*gpart*|*[Dd][Ii][Ss][Kk][Uu][Tt][Ii][Ll]*) DISK=1 ;;
*blkdiscard*|*nvme*|*hdparm*|*badblocks*) DISK=1 ;;
*/dev/*|*[Pp][Hh][Yy][Ss][Ii][Cc][Aa][Ll][Dd][Rr][Ii][Vv][Ee]*) DISK=1 ;;
esac
if [ -n "$DISK" ]; then
# --- Filesystem creation --------------------------------------
if full && hit '(^|[^[:alnum:]_.-])mkfs(\.[[:alnum:]]+)?([^[:alnum:]_.-]|$)'
then
  deny "mkfs destroys the filesystem on its target"
fi
# newfs_msdos and friends: the suffix must be part of the match,
# otherwise the trailing word boundary rejects the underscore.
if full && hit '(^|[^[:alnum:]_.-])newfs([._][[:alnum:]]+)*([^[:alnum:]_.-]|$)'
then
  deny "newfs destroys the filesystem on its target"
fi
if full && hit '(^|[^[:alnum:]_.-])(mke2fs|mkntfs|mkdosfs|mkexfatfs|mkudffs|mkfs2?)([^[:alnum:]_.-]|$)'
then
  deny "this filesystem creator destroys the data on its target"
fi
if full && hit '(^|[^[:alnum:]_.-])wipefs([^[:alnum:]_.-]|$)' \
  && hit '(^|[[:space:]])(-a|--all|-o|--offset)'; then
  deny "wipefs in write mode erases filesystem signatures"
fi

# --- Partition table writers ----------------------------------
# Read-only inspection stays allowed: fdisk -l, sfdisk -l/-d,
# gdisk -l, sgdisk -p, parted -l/print, gpart show/status/list,
# lsblk, diskutil list.
if full && hit_without '(^|[^[:alnum:]_.-])fdisk([^[:alnum:]_.-]|$)' \
  '(^|[[:space:]])-l'; then
  deny "fdisk without -l opens the partition table for writing"
fi
# cfdisk has no read-only mode at all: it is the curses editor.
if full && hit '(^|[^[:alnum:]_.-])cfdisk([^[:alnum:]_.-]|$)'; then
  deny "cfdisk is an interactive partition editor with no \
read-only mode"
fi
if full && hit_without '(^|[^[:alnum:]_.-])sfdisk([^[:alnum:]_.-]|$)' \
  '(^|[[:space:]])(-l|--list|-d|--dump|-V|--verify)'; then
  deny "sfdisk in write mode modifies the partition table"
fi
if full && hit_without '(^|[^[:alnum:]_.-])c?gdisk([^[:alnum:]_.-]|$)' \
  '(^|[[:space:]])-l'; then
  deny "gdisk without -l opens the partition table for writing"
fi
# sgdisk and parted both take SEVERAL actions per invocation, so
# "allow when a read-only flag is present" cannot work: the read
# flag rides along with the write one (sgdisk -b backup.gpt -Z
# /dev/sda). Their write sets are closed and documented, so they
# are enumerated in full instead. Short flags below are the
# complete write set from sgdisk(8); the read-only ones (a D E f
# F i L O p P V v) are absent on purpose, and so is -b, which
# writes a backup FILE and not the disk.
if full && hit '(^|[^[:alnum:]_.-])sgdisk([^[:alnum:]_.-]|$)' \
  && hit '(^|[[:space:]])(-[BcCdegGhIjklmnNorRstTuUzZ]|--(byte-swap-name|change-name|recompute-chs|delete|move-second-header|mbrtogpt|randomize-guids|hybrid|align-end|move-main-table|move-backup-table|load-backup|gpttombr|new|largest-new|clear|transpose|replicate|sort|typecode|transform-bsd|partition-guid|disk-guid|zap|zap-all))'
then
  deny "sgdisk write options modify the partition table"
fi
if full && hit '(^|[^[:alnum:]_.-])parted([^[:alnum:]_.-]|$)' \
  && hit '((mklabel|mktable|mkpartfs|mkpart|rescue|resize)([[:space:]]|$)|(rm|set|toggle|name|move|resizepart)[[:space:]]+[0-9]|disk_(set|toggle)[[:space:]])'
then
  deny "parted write commands modify the partition table"
fi
# growpart rewrites the partition entry to enlarge it. Its dry
# run is the only read-only form, and the exemption is scoped
# the same way as every other one here.
if full && hit_without '(^|[^[:alnum:]_.-])growpart([^[:alnum:]_.-]|$)' \
  '(^|[[:space:]])(-N|--dry-run)([[:space:]]|$)'; then
  deny "growpart rewrites the partition table to resize a \
partition"
fi
# FreeBSD and macOS GUID partition table editor. show is the
# read-only verb and stays allowed.
if full && hit '(^|[^[:alnum:]_.-])gpt[[:space:]]+(create|destroy|add|remove|modify|migrate|recover|resize|restore|boot|label|set|unset)([^[:alnum:]_-]|$)'
then
  deny "gpt write verbs modify the partition table"
fi
# macOS: the tool people actually partition with. Verbs are
# case-insensitive, hence hit_i.
if hit_i '(^|[^[:alnum:]_.-])diskutil([^[:alnum:]_.-]|$)' \
  && hit_i '(erasedisk|erasevolume|eraseoptical|zerodisk|randomdisk|secureerase|partitiondisk|splitpartition|mergepartitions|resizevolume|reformat|deletecontainer|deletevolume|erasecontainer|destroycontainer|resizecontainer|appleraid[[:space:]]+(delete|create))'
then
  deny "diskutil erase and partition verbs destroy data or the \
partition map"
fi
if full && hit 'gpart[[:space:]]+(create|add|delete|destroy|modify|resize|bootcode|recover|set|undo|commit)'
then
  deny "gpart write verbs modify the partition table"
fi
# Windows, as WSL reaches it. Names are matched without regard to
# case, as Windows reads them. diskpart runs its verbs from a
# prompt or a script file, so no read-only form of it can be
# shown; Get-Disk, Get-Partition and Get-Volume inspect instead.
if [ -n "$WIN" ] \
  && hit_i '(^|[^[:alnum:]_.-])diskpart(\.exe)?([^[:alnum:]_.-]|$)'; then
  deny "diskpart edits disks and partition tables, and none of \
its forms can be shown to be read-only - inspect with Get-Disk, \
Get-Partition or Get-Volume"
fi
if [ -n "$WIN" ] \
  && hit_i '(^|[^[:alnum:]_-])(clear-disk|initialize-disk|set-disk|new-partition|remove-partition|resize-partition|set-partition|format-volume|new-volume|remove-virtualdisk|remove-storagepool)([^[:alnum:]_-]|$)'
then
  deny "this Storage cmdlet erases a disk or changes its \
partition table"
fi
# bcdedit only reads with /enum and /v, and bare or with /store
# alone it lists too. Every other option edits the boot
# configuration, so the exemption holds only while each argument
# up to the next ; & or | is one of those or no option at all:
# bcdedit /v /set ... still edits. A quote or backtick in front
# of an option is dropped before bcdedit sees it, so "/set" is
# still /set.
if [ -n "$WIN" ] \
  && hit_without '(^|[^[:alnum:]_.-])bcdedit([.]exe)?([^[:alnum:]_.-]|$)' \
  "^[^[:alnum:]]?bcdedit([.]exe)?([[:space:]]+[\"'\`]*(/(enum|v|store|[?])[\"'\`]*|[^/[:space:];&|\"'\`-][^[:space:];&|]*))*[[:space:]]*([;&|]|\$)" i
then
  deny "bcdedit beyond /enum and /v rewrites the boot \
configuration and can leave the machine unbootable"
fi
# mbr2gpt rewrites the partition table unless it only validates.
if [ -n "$WIN" ] \
  && hit_without '(^|[^[:alnum:]_.-])mbr2gpt(\.exe)?([^[:alnum:]_.-]|$)' \
  '(^|[[:space:]])[/-]validate' i; then
  deny "mbr2gpt without /validate converts the partition table"
fi
if [ -n "$WIN" ] \
  && hit_i '(^|[^[:alnum:]_.-])format(\.com)?["'"'"']?[[:space:]]+["'"'"']?[a-z]:'; then
  deny "format erases the volume on that drive letter"
fi
# cipher /w overwrites all free space on the volume that holds
# its directory, so nothing deleted there can be recovered.
if [ -n "$WIN" ] \
  && hit_i '(^|[^[:alnum:]_.-])cipher(\.exe)?[[:space:]]+([^;&|]*[[:space:]])?["'\''`]*[/-]w(:|[[:space:]]|["'\''`]|$)'
then
  deny "cipher /w wipes the free space of a whole volume"
fi
# wsl --unregister (wslconfig /u) deletes a distribution together
# with the virtual disk that holds its whole filesystem.
if [ -n "$WIN" ] \
  && hit_i "${WSL}([^;&|]*[[:space:]])?(--unregister|/(u|unregister))([[:space:]]|\$)"
then
  deny "wsl --unregister deletes the distribution and its whole \
virtual disk"
fi
if full && hit '(^|[^[:alnum:]_-])dd([^[:alnum:]_-]|$)' \
  && hit 'of=["'\'']?/dev/'; then
  deny "dd onto a raw device overwrites disk content and \
partition table"
fi

# --- Raw-device wipers ----------------------------------------
# These leave the partition table intact and destroy everything
# it points at, which is the same effect by another route.
if full && hit '(^|[^[:alnum:]_.-])blkdiscard([^[:alnum:]_.-]|$)'; then
  deny "blkdiscard discards every block on the device"
fi
if full && hit '(^|[^[:alnum:]_.-])nvme[[:space:]]+(format|sanitize|write|delete-ns|create-ns|attach-ns|detach-ns|security-send|copy|dsm|zns)'
then
  deny "this nvme subcommand overwrites or destroys namespace \
data"
fi
if full && hit '(^|[^[:alnum:]_.-])hdparm([^[:alnum:]_.-]|$)' \
  && hit '(--security-(erase|erase-enhanced|set-pass|unlock|disable)|--trim-sector-ranges|--make-bad-sector|--write-sector|--dco-(restore|setmax)|--repair-sector)'
then
  deny "this hdparm option erases the drive or writes raw \
sectors"
fi
# badblocks -w is the destructive read-write test. -n and -sv
# are non-destructive and stay allowed.
if full && hit '(^|[^[:alnum:]_.-])badblocks([^[:alnum:]_.-]|$)' \
  && hit '(^|[[:space:]])-[[:alnum:]]*w'; then
  deny "badblocks -w overwrites the device while testing it"
fi
if full && hit '(^|[^[:alnum:]_.-])shred([^[:alnum:]_.-]|$)' \
  && hit "$DEV"; then
  deny "shred on a disk device overwrites the whole device"
fi

fi # the disk precheck, up to shred

# --- Storage: repair denied, changes asked ---------------------
# rules/storage.md sorts storage commands into three tiers. Its
# repair-and-destroy tier is denied here: a repair tool decides on
# its own what is damaged and drops it, a ZFS rewind discards the
# last transactions, and the rest remove a volume, an array, a pool
# or the metadata that finds them. On a NAS a stock tool also does
# not know the vendor's records. Its change tier goes to the ask
# tier, and its read tier passes.
#
# Each dry run and LVM's test mode are exempt per invocation, as
# every read-only form here is, and so is HELP. One case arm per
# tool family, and for zpool, zfs and midclt only on the verbs that
# write, so a read such as zpool status or zfs list runs no grep.
stor_deny() {
  GUARD_ROUTE="A repair or a destroy is a step for the user: name the \
command and what it can destroy, and the user runs it at a console \
(rules/storage.md - When Storage Is Failing)."
  deny "$1"
}
stor_ask() {
  ask_for "this storage change" "can lose data or cannot be undone \
(rules/storage.md)" "Check the device, the state of the array or \
pool, and the backup before approving."
}
# A short-option cluster holding n: e2fsck -fn, xfs_repair -n,
# zpool import -Fn, zfs destroy -rn.
STORDRY='(^|[[:space:]])-[[:alnum:]]*n[[:alnum:]]*([[:space:]]|$)'
LVMTEST='(^|[[:space:]])(-t|--test)([[:space:]]|$)'
# btrfs takes global options before its command (--format and
# --log with a value of their own), and any unique
# prefix of a command: btrfs c is check, btrfs resc is rescue,
# btrfs dev del is device delete.
BTRFS='(^|[^[:alnum:]_.-])btrfs([[:space:]]+(--format|--log)[[:space:]]+[^[:space:]]+|[[:space:]]+-[^[:space:]]+)*[[:space:]]+'
MDADM='(^|[^[:alnum:]_.-])mdadm([[:space:]][^;&|]*)?[[:space:]]'
ZPOOL='(^|[^[:alnum:]_.-])zpool[[:space:]]+'
# macOS: diskutil's repair verbs run fsck_apfs or fsck_hfs, or
# rewrite the partition map (repairDisk); verifyVolume and
# verifyDisk only read. Windows: chkdsk only reads without a fixing
# switch, and Repair-Volume only with -Scan; Get-Help and
# Get-Command in front of it only look it up. Like the diskutil and
# Windows rules above, these apply in every scope.
case "$TEXT" in
*[Dd][Ii][Ss][Kk][Uu][Tt][Ii][Ll]*)
  if hit_i '(^|[^[:alnum:]_.-])diskutil([^[:alnum:]_.-]|$)' \
    && hit_i '(repairvolume|repairdisk)'; then
    stor_deny "diskutil repairVolume and repairDisk repair a volume or \
rewrite the partition map"
  fi ;;
esac
if [ -n "$WIN" ] \
  && hit_i '(^|[^[:alnum:]_.-])chkdsk(\.exe)?[[:space:]]+([^;&|]*[[:space:]])?["'\''`]*/(f|r|x|b|spotfix|offlinescanandfix|forceofflinefix)(:|[[:space:]]|["'\''`]|$)'
then
  stor_deny "chkdsk with a fixing switch repairs the volume"
fi
if [ -n "$WIN" ] \
  && hit_without '(^|[^[:alnum:]_-])((get-help|get-command|gcm|help)[[:space:]]+(-name[[:space:]]+)?)?repair-volume([^[:alnum:]_-]|$)' \
    '^[^[:alnum:]]?(get-help|get-command|gcm|help)[[:space:]]|(^|[[:space:]])-scan([[:space:]]|$)' i; then
  stor_deny "Repair-Volume beyond -Scan repairs the volume"
fi
if full; then
  case "$TEXT" in
  *fsck*|*xfs_repair*|*ntfsfix*)
    # fsck, fsck.ext4, fsck_ffs, e2fsck, dosfsck, xfs_repair and
    # ntfsfix, which repairs NTFS and resets its journal. -N is
    # util-linux fsck's own dry run, --no-action ntfsfix's long one,
    # -n everyone's.
    if hit_without '(^|[^[:alnum:]_.-])(fsck([.][[:alnum:]]+|_[[:alnum:]]+)?|e2fsck|dosfsck|xfs_repair|ntfsfix)([^[:alnum:]_.-]|$)' \
      "$STORDRY|(^|[[:space:]])(-N|--no-action)([[:space:]]|\$)|$HELP"; then
      stor_deny "a file system check without -n repairs, and a repair \
decides on its own what to throw away"
    fi
    ;;
  esac
  case "$TEXT" in
  *btrfs*)
    # btrfs check only reads unless one of these asks it to write.
    if hit "(${BTRFS}c(h(e(c(k)?)?)?)?|(^|[^[:alnum:]_.-])btrfsck)([[:space:]][^;&|]*)?[[:space:]]--(repair|init-csum-tree|init-extent-tree|clear-space-cache|clear-ino-cache)"
    then
      stor_deny "btrfs check with a write option repairs the file \
system"
    fi
    if hit_without "${BTRFS}resc(u(e)?)?([[:space:]]|\$)" "$HELP"; then
      stor_deny "btrfs rescue rewrites the file system's metadata"
    fi
    # subvolume delete removes a subvolume and everything in it. A
    # snapshot looks the same on the command line, so it is denied
    # like zfs destroy of a dataset; snapper and timeshift prune
    # their own snapshots.
    if hit_without "${BTRFS}su(b(v(o(l(u(m(e)?)?)?)?)?)?)?[[:space:]]+d(e(l(e(t(e)?)?)?)?)?([[:space:]]|\$)" \
      "$HELP"; then
      stor_deny "btrfs subvolume delete removes a subvolume and all \
the data in it"
    fi
    # A scrub rewrites damaged blocks from a verified copy: asked,
    # as zpool scrub is; status and cancel read or stop.
    if hit "${BTRFS}((d(e(v(i(c(e)?)?)?)?)?[[:space:]]+(a(d(d)?)?|rem(o(v(e)?)?)?|d(e(l(e(t(e)?)?)?)?)?)|rep(l(a(c(e)?)?)?)?[[:space:]]+star(t)?|sc(r(u(b)?)?)?[[:space:]]+(star(t)?|r(e(s(u(m(e)?)?)?)?)?))([[:space:]]|\$)|b(a(l(a(n(c(e)?)?)?)?)?)?[[:space:]][^;&|]*convert=)"
    then
      stor_ask
    fi
    ;;
  esac
  case "$TEXT" in
  *debugfs*)
    if hit '(^|[^[:alnum:]_.-])debugfs([[:space:]][^;&|]*)?[[:space:]]-[[:alnum:]]*w'
    then
      stor_deny "debugfs -w writes file system metadata directly"
    fi
    ;;
  esac
  case "$TEXT" in
  *sync_action*)
    # md's repair and resync rewrite every mismatch from one copy of
    # their own choosing, with no checksum to say which is right;
    # check only counts them, idle and frozen stop. A redirect or
    # tee is how the word reaches the file.
    if hit '(^|[^[:alnum:]_-])(repair|resync)([^[:alnum:]_-][^;&|]*)?>[[:space:]]*[^[:space:];&|]*sync_action' \
      || { hit '(^|[^[:alnum:]_.-])(tee|sponge)[[:space:]]([^;&|]*[[:space:]])?[^[:space:];&|]*sync_action' \
           && hit '(^|[^[:alnum:]_-])(repair|resync)([^[:alnum:]_-]|$)'; }
    then
      stor_deny "a repair or resync through sync_action rewrites the \
array from a copy md picks"
    fi
    ;;
  esac
  case "$TEXT" in
  *mdadm*)
    # Creating, building, growing or rewriting an array's superblock,
    # an assemble forced past its own checks, and the repair and
    # resync actions, which rewrite every mismatch from a copy md
    # picks. A cluster counts: mdadm -Cv is --create. --detail,
    # --examine, --query and --action=check read; the manage verbs
    # are asked.
    if hit "${MDADM}(-[[:alpha:]]*[CBG][[:alpha:]]*|--(create|build|grow|zero-superblock|update)|--action([[:space:]]+|=)(repair|resync))([[:space:]=]|\$)"
    then
      stor_deny "this mdadm mode creates, grows or rewrites an array's \
metadata or data"
    fi
    if hit "${MDADM}((--assemble|-[[:alpha:]]*A[[:alpha:]]*)([[:space:]][^;&|]*)?[[:space:]](--force|-f)|(--force|-f)([[:space:]][^;&|]*)?[[:space:]](--assemble|-[[:alpha:]]*A[[:alpha:]]*)|-[[:alpha:]]*(A[[:alpha:]]*f|f[[:alpha:]]*A)[[:alpha:]]*)([[:space:]]|\$)"
    then
      stor_deny "a forced mdadm assemble overrides the array's own \
consistency checks"
    fi
    if hit_without "${MDADM}(-[arfS]|--(add|re-add|add-spare|remove|fail|set-faulty|replace|stop))([[:space:]=]|\$)" \
      "$HELP"; then
      stor_ask
    fi
    ;;
  esac
  case "$TEXT" in
  *pvcreate*|*pvremove*|*vgremove*|*lvremove*|*lvreduce*|*vgcfgrestore*|*pvck*|*vgck*)
    # Labelling a device, removing a PV, VG or LV, shrinking an LV,
    # restoring old metadata over the current one, and the checkers'
    # own repair modes. Each tool also runs as lvm <tool>.
    if hit_without '(^|[^[:alnum:]_.-])(pvcreate|pvremove|vgremove|lvremove|lvreduce|vgcfgrestore)([^[:alnum:]_.-]|$)' \
      "$LVMTEST|$HELP"; then
      stor_deny "this LVM command destroys a volume or the metadata \
that finds it"
    fi
    if hit '(^|[^[:alnum:]_.-])(pvck|vgck)([[:space:]][^;&|]*)?[[:space:]]--(repair|updatemetadata)([[:space:]=]|$)'
    then
      stor_deny "pvck and vgck with a repair option rewrite LVM \
metadata"
    fi
    ;;
  esac
  case "$TEXT" in
  *lvcreate*|*lvextend*|*lvresize*|*lvconvert*|*vgcreate*|*vgextend*|*vgreduce*|*pvmove*|*pvresize*)
    # lvresize shrinks with a negative size, and with an absolute one
    # below the current size, which the command line cannot show.
    # Only a size starting with + is known to grow; lvextend refuses
    # to shrink whatever it is given. The size may close a cluster:
    # lvresize -rL 10G.
    if hit_without '(^|[^[:alnum:]_.-])lvresize([[:space:]][^;&|]*)?[[:space:]](-[[:alpha:]]*[Ll]|--size|--extents)([[:space:]]+|=)?[^+=[:space:]]' \
      "$LVMTEST|$HELP"; then
      stor_deny "lvresize without a + size can shrink the volume like \
lvreduce - grow with lvextend or a size starting with +"
    fi
    # lvconvert --repair rebuilds a RAID or mirror LV and runs
    # thin_repair on a thin pool's metadata: a repair, not a change.
    if hit_without '(^|[^[:alnum:]_.-])lvconvert([[:space:]][^;&|]*)?[[:space:]]--repair([[:space:]=]|$)' \
      "$LVMTEST|$HELP"; then
      stor_deny "lvconvert --repair repairs a RAID, mirror or thin pool \
volume"
    fi
    if hit_without '(^|[^[:alnum:]_.-])(lvcreate|lvextend|lvresize|lvconvert|vgcreate|vgextend|vgreduce|pvmove|pvresize)([^[:alnum:]_.-]|$)' \
      "$LVMTEST|$HELP"; then
      stor_ask
    fi
    ;;
  esac
  case "$TEXT" in
  *zinject*)
    if hit '(^|[^[:alnum:]_.-])zinject([^[:alnum:]_.-]|$)'; then
      stor_deny "zinject injects faults into a live pool"
    fi
    ;;
  esac
  case "$TEXT" in
  *zpool*)
    # create formats its disks like mkfs; destroy and labelclear
    # remove a pool; -F, -X and -T rewind one, which import takes on
    # every release and clear up to OpenZFS 2.1, and so does import
    # --rewind-to-checkpoint; import -m drops a missing log device
    # with its transactions. upgrade asks only with a pool or -a:
    # bare, or with -v, it lists. import asks the same way: bare, or
    # with only options (-d dir), it lists what could be imported;
    # with a pool or -a it imports. export unmounts every dataset.
    case "$TEXT" in
    *create*|*destroy*|*labelclear*)
      if hit_without "${ZPOOL}(create|destroy|labelclear)([^[:alnum:]_-]|\$)" \
        "$STORDRY|$HELP"; then
        stor_deny "zpool create, destroy and labelclear erase the pool \
on their disks"
      fi
      ;;
    esac
    case "$TEXT" in
    *import*|*clear*)
      if hit_without "${ZPOOL}(import|clear)([[:space:]][^;&|]*)?[[:space:]](-[[:alnum:]]*[FXTm]|--rewind-to-checkpoint)" \
        "$STORDRY"; then
        stor_deny "a ZFS rewind discards the pool's last transactions \
for good"
      fi
      ;;
    esac
    case "$TEXT" in
    *scrub*)
      if hit_without "${ZPOOL}scrub([^[:alnum:]_-]|\$)" \
        "(^|[[:space:]])-[[:alnum:]]*[sp]([[:space:]]|\$)|$HELP"; then
        stor_ask
      fi
      ;;
    esac
    case "$TEXT" in
    *attach*|*detach*|*replace*|*offline*|*online*|*add*|*remove*|*split*|*upgrade*|*export*)
      if hit_without "${ZPOOL}((attach|detach|replace|offline|online|add|remove|split|export)([^[:alnum:]_-]|\$)|upgrade([[:space:]]+-[[:alnum:]]+)*[[:space:]]+(-a|[^-[:space:];&|]))" \
        "$STORDRY|$HELP"; then
        stor_ask
      fi
      ;;
    esac
    case "$TEXT" in
    *import*)
      # An option ending in c, d, o or R takes a value (-d dir,
      # -o prop, -c cachefile, -R root), which is not a pool name.
      if hit_without "${ZPOOL}import([[:space:]]+-[[:alnum:]]*[cdoR][[:space:]]+[^[:space:]]+|[[:space:]]+-[[:alnum:]]*[^cdoR[:space:];&|])*[[:space:]]+([^-[:space:];&|]|-[[:alnum:]]*a([[:space:]]|\$))" \
        "$STORDRY|$HELP"; then
        stor_ask
      fi
      ;;
    esac
    ;;
  esac
  case "$TEXT" in
  *zfs*)
    # destroy of a dataset or volume is its data, and so is -R on a
    # snapshot, destroy or rollback: it takes every dependent clone
    # with it, a dataset of its own and possibly outside the target's
    # tree. A snapshot or bookmark (@, #) otherwise, a rollback and
    # a receive change only what came after, and are asked.
    case "$TEXT" in
    *destroy*|*rollback*)
      if hit_without '(^|[^[:alnum:]_.-])zfs[[:space:]]+(destroy|rollback)([[:space:]]+-[[:alnum:]]+)*[[:space:]]+-[[:alnum:]]*R' \
        "$STORDRY|$HELP"; then
        stor_deny "zfs destroy or rollback with -R destroys every clone \
that depends on the snapshot"
      fi
      ;;
    esac
    case "$TEXT" in
    *destroy*)
      if hit_without "(^|[^[:alnum:]_.-])zfs[[:space:]]+destroy([[:space:]]+-[[:alnum:]]+)*[[:space:]]+[\"']?[^-@#[:space:];&|\"'][^@#[:space:];&|\"']*[\"']?([[:space:];&|]|\$)" \
        "$STORDRY|$HELP"; then
        stor_deny "zfs destroy of a dataset or volume deletes its data \
and every snapshot of it"
      fi
      ;;
    esac
    case "$TEXT" in
    *destroy*|*rollback*|*recv*|*receive*)
      if hit_without '(^|[^[:alnum:]_.-])zfs[[:space:]]+(destroy|rollback|receive|recv)([^[:alnum:]_-]|$)' \
        "$STORDRY|$HELP"; then
        stor_ask
      fi
      ;;
    esac
    ;;
  esac
  case "$TEXT" in
  *disk.wipe*|*pool.create*)
    if hit "${MIDCLT}(disk[.]wipe|pool[.]create)([^[:alnum:]_.-]|\$)"
    then
      stor_deny "TrueNAS disk.wipe and pool.create erase whole disks"
    fi
    ;;
  *pool.export*|*pool.dataset.delete*)
    # pool.dataset.delete is zfs destroy of a dataset, and pool.export
    # with destroy in its argument is zpool destroy: both denied like
    # the commands they stand for. A plain export only unmounts, and
    # is asked like zpool export.
    if hit "${MIDCLT}pool[.]dataset[.]delete([^[:alnum:]_.-]|\$)"
    then
      stor_deny "TrueNAS pool.dataset.delete deletes a dataset like zfs \
destroy"
    fi
    if hit "${MIDCLT}pool[.]export([^[:alnum:]_.-][^;&|]*)?destroy"
    then
      stor_deny "TrueNAS pool.export with destroy erases the pool like \
zpool destroy"
    fi
    if hit "${MIDCLT}pool[.]export([^[:alnum:]_.-]|\$)"
    then
      stor_ask
    fi
    ;;
  esac
fi

# The disk precheck again, for the rule that needs writes_to.
if [ -n "$DISK" ]; then
# A redirect, tee, cp or download onto a disk device does what
# dd of= does. /dev/null, /dev/stderr and /dev/disk/by-id are
# unaffected.
if full && { hit ">[[:space:]]*[\"']?$DEV" \
  || { hit "$DEV" && writes_to "${DEV}[[:alnum:]]*"; }; }
then
  deny "writing onto a raw disk device overwrites its content \
and partition table"
fi
fi # the disk precheck

# --- SSH keys and sshd_config ---------------------------------
# Deleting is only one way to lose a key. Renaming it away,
# truncating it to zero, or making it unreadable to sshd have
# the same effect, and the sshd_config rule below already
# reflected that while this one did not.
# KEY and SSHD are checked once and first: most commands name
# neither, and the key rules, the sshd_config rule and the
# interpreter rule need one (OpenMediaVault, uci and ProgramData
# keep prechecks of their own).
# Each needs a word as well: KEY authorized_keys, .ssh, /etc/,
# /conf/sshd or ProgramData, SSHD /etc/ or ProgramData.
# CLOBBER: tools that delete, move, re-permission or rewrite a
# file named on their command line. Both rules below use it; the
# sshd_config rule adds cp, since a copy onto it replaces it.
CLOBBER='rm|shred|unlink|truncate|mv|chmod|chown|install|ln|setfacl|patch'
HAS_KEY=0 HAS_SSHD=0
case "$TEXT" in
*authorized_keys*|*.ssh*|*/etc/*|*/conf/sshd*|*[Pp][Rr][Oo][Gg][Rr][Aa][Mm][Dd][Aa][Tt][Aa]*)
  hit "$KEY" && HAS_KEY=1 ;;
esac
case "$TEXT" in
*/etc/*|*[Pp][Rr][Oo][Gg][Rr][Aa][Mm][Dd][Aa][Tt][Aa]*)
  hit "$SSHD" && HAS_SSHD=1 ;;
esac
# A libguestfs copy into sshd's directory names no sshd path when
# the local file is called something else: `--copy-in x:/etc/ssh`.
# It opens the sshd rules all the same.
case "$CMD" in
*--copy-in*|*--upload*)
  [ "$HAS_SSHD" -eq 0 ] && image_sshd_dir && HAS_SSHD=1 ;;
esac
if [ "$HAS_KEY" -eq 1 ] \
  && { hit "(^|[^[:alnum:]_-])($CLOBBER)([^[:alnum:]_-]|\$)" \
       || hit '(^|[[:space:]])(-delete|--remove-s(ource|ent)-files)([[:space:]]|$)'; }
then
  if first_boot_only "$KEY"; then
    first_boot_ask "deleting, moving or re-permissioning SSH keys"
  else
    deny "deleting, moving or re-permissioning SSH keys is never \
allowed"
  fi
fi
# virt-sysprep deletes an image's SSH host keys by default (its
# ssh-hostkeys operation) and names no key path, so the rule above
# never sees it. Every invocation counts as that deletion: on an
# image opened with -a, alone on the line, it is the first-boot ask
# like any other key change in a guest that never ran; anywhere
# else it is denied. An --operations list without ssh-hostkeys is
# asked about all the same - the prompt costs one click, and
# telling the lists apart is a parser this hook does not need.
case "$TEXT" in
*virt-sysprep*)
  if hit '(^|[^[:alnum:]_.-])virt-sysprep([^[:alnum:]_.-]|$)'; then
    if first_boot_only "$KEY"; then
      first_boot_ask "removing an image's SSH host keys with virt-sysprep"
    else
      deny "virt-sysprep removes SSH host keys by default - only on a \
disk image opened with -a, alone on the line, and only with a prompt"
    fi
  fi ;;
esac
# KEYPRIV only ever matches where KEY does, so both rules below
# wait for HAS_KEY.
# A truncating redirect needs no command at all: : > key.
if [ "$HAS_KEY" -eq 1 ] \
  && hit ">[[:space:]]*[\"']?[^[:space:];|&]*$KEYPRIV"; then
  deny "redirecting onto an SSH key file truncates it"
fi
# ssh-keygen -f onto an existing private key overwrites it.
# Reading a .pub (for a fingerprint) stays allowed.
case "$TEXT" in
*ssh-keygen*)
  if [ "$HAS_KEY" -eq 1 ] \
    && hit '(^|[^[:alnum:]_-])ssh-keygen([^[:alnum:]_-]|$)' \
    && hit "$KEYPRIV"; then
    deny "ssh-keygen pointed at an existing key overwrites it - a \
fingerprint of a .pub runs in a call of its own, with no private \
key path in it"
  fi ;;
esac
# OpenMediaVault's ssh Salt state renders sshd_config and empties and
# rebuilds /var/lib/openmediavault/ssh/authorized_keys, naming
# neither path on the command line. It deploys through
# omv-salt deploy run with ssh among the state names, or through
# omv-salt stage run deploy, which renders every state. What
# --append-dirty deploys is invisible here; the appliance file
# (rules/appliance/openmediavault.md) covers it. Each word may be
# quoted, "/usr/sbin/omv-salt" too, escaped inside an ssh payload;
# segments() splits at the quotes, so only the whole line carries
# the words together. The case keeps the grep off every other Bash
# call.
case "$CMD" in
*omv-salt*)
  Q='[\"'\'']*'
  if hit "(^|[^[:alnum:]_.-])omv-salt${Q}[[:space:]]+${Q}(deploy|stage)${Q}[[:space:]]+${Q}run${Q}[[:space:]]([^;&|]*[[:space:]])?${Q}(ssh|deploy)$END"
  then
    deny "deploying the OpenMediaVault ssh state rewrites \
sshd_config and rebuilds the authorized_keys directory - the user \
changes SSH settings in the web UI"
  fi
  ;;
esac
if [ "$HAS_SSHD" -eq 1 ]; then
  if hit '>>?[[:space:]]*["'\'']?[^[:space:];|&]*'"$SSHD" \
    || { hit '(^|[^[:alnum:]_-])(sed|perl)([^[:alnum:]_-]|$)' \
         && hit '(^|[[:space:]])-i'; } \
    || hit "(^|[^[:alnum:]_-])$EDITOR([^[:alnum:]_-]|\$)" \
    || hit "(^|[^[:alnum:]_-])($CLOBBER|cp)([^[:alnum:]_-]|\$)" \
    || { hit "(^|[^[:alnum:]_.-])$IMAGETOOL([^[:alnum:]_.-]|\$)" \
         && hit "(^|[[:space:]])(--copy-in|--upload|--write|--edit|--ssh-inject|write|upload|copy-in|edit)([[:space:]]|=)" \
         && { image_write_targets | grep -Eq "$SSHD" || image_sshd_dir; }; } \
    || hit '(^|[^[:alnum:]_.-])(virt-edit|virt-copy-in)([^[:alnum:]_.-]|$)' \
    || writes_to "$SSHD"
  then
    if first_boot_only "$SSHD"; then
      first_boot_ask "writing sshd's configuration"
    else
      deny "modifying sshd_config or a file merged into it is \
never allowed (reading it is fine: cat, grep, sshd -T)"
    fi
  fi
fi
# Windows' OpenSSH files under ProgramData\ssh are changed by cmd
# and PowerShell verbs the two rules above do not know: del, erase,
# rd, move, ren, copy, takeown, attrib, Remove-Item, Set-Content
# and their aliases, reached over SSH without naming PowerShell.
# The verb counts in the invocation that names the path after it,
# or behind a pipe from a listing of it (gci ... | ri). icacls
# counts only with a flag that changes the ACL, since reading one
# is an audit. A copy out of the directory is denied too, as cp is
# above. Windows reads its commands in any case.
case "$CMD" in
*[Pp][Rr][Oo][Gg][Rr][Aa][Mm][Dd][Aa][Tt][Aa]*)
  WINCLOBBER='del|erase|rd|rmdir|move|ren|rename|copy|xcopy|robocopy|takeown|attrib|cacls|notepad|remove-item|ri|move-item|mi|rename-item|rni|copy-item|cpi|set-content|add-content|clear-content|clc|out-file|new-item|ni|set-acl|tee-object'
  WINVERB="(^|[^[:alnum:]_.-])($WINCLOBBER)(\\.exe)?"
  # The directory itself, not ssh-backups or ssh_notes beside it:
  # after it a separator, a quote, space or the shell's punctuation
  # (ssh>NUL, ssh)), or the end.
  WINSSHB="${WINSSHDIR}([^[:alnum:]_.-]|\$)"
  # A verb before the path, a listing of it piped to a verb, and an
  # icacls that changes the ACL: one grep for the three.
  WINDEL="${WINVERB}[[:space:]][^;&|]*${WINSSHB}"
  WINPIPE="${WINSSHDIR}([^[:alnum:]_.-][^;&]*)?\\|[[:space:]]*($WINCLOBBER)([^[:alnum:]_.-]|\$)"
  WINACL="(^|[^[:alnum:]_.-])icacls(\\.exe)?[[:space:]][^;&|]*${WINSSHB}[^;&|]*[[:space:]]/(grant|deny|remove|reset|setowner|inheritance|setintegritylevel|restore|substitute)"
  if hit_i "($WINDEL)|($WINPIPE)|($WINACL)"; then
    deny "deleting, moving, overwriting or re-permissioning Windows' \
OpenSSH files under ProgramData/ssh is never allowed (reading them \
is fine: type, Get-Content, icacls without a change)"
  fi
  ;;
esac
# OpenWrt changes /etc/config/dropbear through uci, which never
# names the file: uci set dropbear.@dropbear[0].Port=2222, then
# uci commit dropbear. A write verb followed by the config name
# is the change, whether uci carries it on its command line or
# reads it from a uci batch here-document. uci show, get, changes
# and export only read.
# A bare commit names no config and writes every staged one, a
# dropbear change someone else left in /tmp/.uci included. A bare
# import commits every package its input declares (uci_do_import
# in uci's cli.c), a backup's package dropbear too. Both are
# denied: as the last word of a uci invocation (a redirect or a
# comment after it changes nothing), or as a batch line of their
# own. uci commit <config> and uci import <config> stay ordinary
# work.
# The case is a builtin precheck: most commands never mention uci
# and skip every grep.
UCIW='(set|add|add_list|del_list|delete|rename|reorder|import|commit)'
case "$CMD" in
  *uci*)
    if hit '(^|[^[:alnum:]_.-])uci([^[:alnum:]_.-]|$)'; then
      if hit "(^|[[:space:]'\"])${UCIW}[[:space:]]+['\"]?dropbear([.=[:space:]'\"]|\$)"
      then
        deny "changing the dropbear configuration through uci modifies \
the SSH server config, which is never allowed (reading it is fine: \
uci show dropbear)"
      fi
      if hit '((^|[^[:alnum:]_.-])uci([[:space:]]+[^[:space:]]+)*[[:space:]]+|^[[:space:]]*)(commit|import)[[:space:]]*([0-9]*[<>]|#|$)'
      then
        deny "a bare uci commit or import writes every config it \
holds, dropbear included - name the config: uci commit firewall"
      fi
    fi
    ;;
esac

# --- Writes INTO an SSH key -----------------------------------
# Writing into a key file replaces it as surely as deleting it.
if [ "$HAS_KEY" -eq 1 ]; then
  if writes_to "($KEYFILE|$KEYDIR/?)"; then
    deny "writing into an SSH key file or a key directory \
replaces the keys there"
  fi
  # An in-place edit needs the key AFTER the tool in the same
  # invocation: in ssh -i ~/.ssh/id_ed25519 host "sed -i ..." the
  # key belongs to ssh, and the edit runs elsewhere.
  if hit "(^|[^[:alnum:]_.-])sed[[:space:]]([^;&|]*[[:space:]])?(-[[:alpha:]]*i|--in-place)[^;&|]*$KEYPRIV" \
    || hit "(^|[^[:alnum:]_-])${EDITOR}[[:space:]][^;&|]*$KEYPRIV"
  then
    deny "editing an SSH key file in place can delete keys from it"
  fi
fi

# --- Configuration management tools ---------------------------
# A playbook reaches every taboo above through modules whose names
# and arguments never spell a shell command: parted and filesystem
# write the partition table and make filesystems, lineinfile and
# template rewrite sshd_config, authorized_key replaces keys, and
# none of it is on the command line of ansible-playbook. So Hostwarden
# runs no playbook (rules/config-management.md: applying Ansible
# code is the user's step), except the forms that run no task at all:
# --syntax-check, --list-hosts, --list-tasks and --list-tags.
# ansible-pull applies a playbook from a repository in the same way,
# and ansible-console takes its commands from a prompt this hook
# never sees.
#
# An ad-hoc ansible call names its module and arguments, so it is
# judged like a shell command. The rules above have scanned its
# arguments already: -m shell -a "sed -i ... sshd_config" is a
# sed -i onto sshd_config wherever it runs. What they cannot see is
# the module itself:
#   - parted, filesystem, the Windows partition, format and
#     initialize modules, and shutdown, in any collection
#     (community.general.parted is parted);
#   - authorized_key and openssh_keypair, which write keys without
#     naming a key file, and generate_ssh_key with force (the user
#     module), which replaces the user's key;
#   - script, which runs a local file this hook cannot read, and
#     include_role, include_tasks, import_role and import_tasks,
#     which run tasks from files as a playbook does;
#   - any module but the ones that only read or run a command the
#     rules above have judged, once a key or sshd_config is named
#     in the invocation - outside --private-key, --key-file and
#     *private_key_file=, which only say how Ansible logs in.
# An invocation is a word whose last path component is ansible, to
# the end of its segment. Every word there that can name a module
# counts: the value of -m, of a run of short flags holding m (-bm
# parted, -mcopy), and of --module-name or an abbreviation of it.
# Ansible uses the last one, but the dequoted words cannot tell an
# -m of ansible from one inside -a, so judging all of them is the
# only reading that never passes a taboo module; grep -m1 inside
# -a counts as a module named 1, and --max-count reads the same.
# A value that is not a plain name, $MOD for one, counts as a
# writing module.
#
# terraform and tofu apply and destroy can replace or delete the
# server itself (rules/config-management.md), and Hostwarden never
# runs them, by any path. plan, show and state list only read.
#
# Full scope only: a development session reaches none of these
# tools (the shim refuses them), and this repository names them in
# rules, tests and commit messages all day.
case "$TEXT" in
*ansible*)
  if full; then
    if hit_without '(^|[^[:alnum:]_.-])ansible-playbook([^[:alnum:]_.-]|$)' \
      '^[^[:alnum:]]?ansible-playbook[^;&|]*[[:space:]]--(syntax-check|list-(hosts|tasks|tags))([[:space:]=]|$)'
    then
      deny "ansible-playbook applies whatever its tasks do, and this \
guard cannot read them - applying Ansible code is left to the \
user (rules/config-management.md); --syntax-check and --list-tasks, \
--list-hosts or --list-tags run nothing"
    fi
    if hit '(^|[^[:alnum:]_.-])ansible-(pull|console)([^[:alnum:]_.-]|$)'
    then
      deny "ansible-pull applies a playbook this guard cannot read, \
and ansible-console runs commands it never sees - the user runs \
them"
    fi
    # Per invocation, every module word without its collection
    # (command without one, unknown for a value that is not a
    # name), PATH when a key or sshd_config is named, and KEYGEN
    # for generate_ssh_key with force, which replaces the user's
    # key (the user module). The values of the --*-args options go
    # to ssh, sftp and scp, never to a module, and are cut while
    # their quotes still show where they end. Then the quotes go:
    # in ssh host 'ansible web -m parted' the quote is what stands
    # before ansible.
    AMODS=$(printf '%s\n' "${CMDQ:-${CMDJ:-$CMD}}" \
      | sed -E "s/--(ssh-common|ssh-extra|sftp-extra|scp-extra)-args(=|[[:space:]]+)(\"[^\"]*\"|'[^']*'|[^[:space:]]*)//g" \
      | tr -d "\"'" | tr ';&|`()' '\n' | K="$KEY|$SSHD" awk '
      {
        for (i = 1; i <= NF; i++) {
          t = $i; sub(/.*\//, "", t)
          if (t == "ansible") break
        }
        if (i > NF) next
        n = 0; rest = ""
        for (i++; i <= NF; i++) {
          w = $i; v = ""
          if (w ~ /^--(private-key|key-file)$/) { i++; continue }
          if (w ~ /^--(private-key|key-file)=/ || w ~ /private_key_file=/) continue
          if (w ~ /^--module-n[a-z-]*(=|$)/) {
            if (w ~ /=/) { v = w; sub(/^[^=]*=/, "", v) } else v = $(++i)
          } else if (w ~ /^-[A-Za-z]/ && index(w, "m")) {
            v = substr(w, index(w, "m") + 1); sub(/^=/, "", v)
            if (v == "") v = $(++i)
          } else { rest = rest " " w; continue }
          n++
          if (v !~ /^[A-Za-z0-9_.]+$/) v = "unknown"
          sub(/.*\./, "", v); print v
        }
        if (!n) print "command"
        if (rest ~ ENVIRON["K"]) print "PATH"
        # Ansible reads booleans in any case and from JSON too, so
        # force counts unless it is plainly false.
        lr = tolower(rest)
        if (lr ~ /generate_ssh_key/ && lr ~ /(^|[^a-z_])force([^a-z_]|$)/ \
            && lr !~ /(^|[^a-z_])force[[:space:]]*[=:][[:space:]]*(no|n|false|0|off)([^a-z0-9]|$)/)
          print "KEYGEN"
      }')
    AWRITE='' APATH=''
    for am in $AMODS; do
      case $am in
      PATH) APATH=1 ;;
      include_role|include_tasks|import_role|import_tasks)
        deny "this Ansible module runs tasks from files, which this \
guard cannot read - applying Ansible code is left to the user" ;;
      parted|filesystem|shutdown|win_partition|win_format|win_initialize_disk|win_shutdown)
        deny "this Ansible module writes a partition table, makes a \
filesystem or powers the host off" ;;
      authorized_key|openssh_keypair|KEYGEN)
        deny "this Ansible module writes SSH keys or authorized_keys, \
which is never allowed" ;;
      script)
        deny "the Ansible script module runs a local file this guard \
cannot read - run the commands through the shell or command module, \
where they are checked" ;;
      command|shell|raw|stat|find|slurp|setup|ping|win_command|win_shell|win_stat) ;;
      *) AWRITE=1 ;;
      esac
    done
    if [ -n "$AWRITE" ] && [ -n "$APATH" ]; then
      deny "an Ansible module that writes files, pointed at an SSH \
key or sshd_config, can replace it - read it with -m command \
and cat, or with -m stat"
    fi
  fi
  ;;
esac
case "$TEXT" in
*terraform*|*tofu*)
  # The verb is the first word after the global options, whose value
  # may be quoted (-chdir="my infra"): terraform output apply only
  # reads an output named apply.
  TFOPT='-[^[:space:]"'\'']*("[^"]*"|'\''[^'\'']*'\'')?[^[:space:]]*'
  if full && hit "(^|[^[:alnum:]_.-])(terraform|tofu)([[:space:]]+$TFOPT)*[[:space:]]+(apply|destroy)([^[:alnum:]_-]|\$)"
  then
    deny "terraform and tofu apply and destroy can replace or \
delete the server itself - the user runs them \
(rules/config-management.md)"
  fi
  ;;
esac

# --- Effects reached through an interpreter -------------------
# Every rule above recognizes a write by the way it is spelled: a
# redirect, tee, sed -i, an editor, rm/mv/chmod/truncate. A
# language runtime spells none of those and reaches the same
# effects through plain file I/O:
#
#   python3 -c "open('/etc/ssh/sshd_config','a').write(...)"
#   node -e "require('fs').unlinkSync('...authorized_keys')"
#   python3 -c "open('/dev/sda','wb').write(...)"
#
# Its command line is opaque to a pattern matcher -- read and
# write look alike from outside -- so the read-only exemption
# cannot be proven, and an unprovable exemption must not apply.
# A runtime carrying a protected path or a raw device is
# therefore a write. Issue #6.
#
# This enumerates RUNTIMES, not write syntaxes, on purpose. The
# set of ways to write a file grows with every language feature
# and can never be closed; the set of interpreters Hostwarden might
# meet on a server is small and moves slowly. It still is a list,
# so this rule is a backstop against the everyday mistake, not a
# sandbox: an interpreter that builds its target string at
# runtime, or downloads it, defeats any string matcher. Real
# isolation is the operator's job, not this hook's.
#
# Interpreters that shell out (os.system, %x, child_process) need
# no rule of their own: every check above scans the whole command
# string, so the taboo word inside is caught where it stands.
#
# Accepted false positive: any command that merely mentions an
# interpreter alongside one of these targets is blocked too, even
# when it only reads -- awk '/^Port/' /etc/ssh/sshd_config, or a
# cat of the file chained to an unrelated python call. Read with
# cat, grep, jq, stat or sshd -T instead, which is what the rule
# files use anyway.
if hit "$INTERP" || { [ -n "$WIN" ] && hit_i "$WININTERP"; }; then
  if [ "$HAS_KEY" -eq 1 ]; then
    deny "an interpreter with an SSH key path on its command \
line can overwrite or delete the key, and a pattern matcher \
cannot tell that from a read - read keys with cat, stat or \
ssh-keygen -lf instead"
  fi
  if [ "$HAS_SSHD" -eq 1 ]; then
    deny "an interpreter with sshd_config on its command line \
can rewrite it, and a pattern matcher cannot tell that from a \
read - read it with cat, grep or sshd -T instead"
  fi
  if full && hit "$DEV"; then
    deny "an interpreter with a raw disk device on its command \
line can overwrite the device, which destroys everything the \
partition table points at"
  fi
fi

# --- Guest stop and delete: ask, never silently allow ----------
# Stopping a container or VM powers that server off and deleting
# it destroys it (rules/system-containers.md), but managing guests
# on a host Hostwarden administers is legitimate work: the ask tier.
#
# Only the manager's own verb counts: a service stopped or a file
# deleted inside a guest through exec stays allowed, and so do
# snapshot, image, network and storage verbs, which carry a noun
# before theirs. The prefilter spares every command without a
# manager's name the greps.
#
# Beside the managers in GUESTMGRS, the forms of another shape:
# lxc-destroy; jail(8) with -r or -R among its
# options, which removes a running jail, -rc included (the restart
# is a stop first); and the rc scripts that stop or restart every
# jail of jail.conf, Bastille or iocage (service jail stop,
# onerestart and the rest, or /etc/rc.d/jail stop). lxc-stop has an exemption of its
# own below, and TrueNAS' API is read through MIDCLT, which carries
# its own leading boundary.
GUESTFORMS='lxc-destroy|jail[[:space:]]+(-[[:alpha:]]+[[:space:]]+([^-[:space:];&|][^[:space:];&|]*[[:space:]]+)?)*-[[:alpha:]]*[rR][[:alpha:]]*|(service[[:space:]]+|rc[.]d/)(jail|bastille|iocage)[[:space:]]+(one|fast|force|quiet)?(stop|restart)'
guest_ask() {
  ask_for "stopping or deleting a system container or VM" "powers \
off or destroys that server (rules/system-containers.md)" "Check the \
guest ID and the host before approving."
}
for gm in $GMWORDS midclt lxc-destroy jail; do
  case "$TEXT" in
  *"$gm"*)
    if full && hit_without "(^|[^[:alnum:]_.-])(${GMSTOP#|}|$GUESTFORMS)([^[:alnum:]_-]|\$)|${MIDCLT}(vm|virt[.]instance)[.](stop|delete)([^[:alnum:]_-]|\$)" \
      "$HELP"
    then
      guest_ask
    fi
    break ;;
  esac
done
case "$TEXT" in
*lxc-stop*)
  if full && hit_without '(^|[^[:alnum:]_.-])lxc-stop([^[:alnum:]_.-]|$)' \
    "(^|[[:space:]])(-r|--reboot)([[:space:]]|\$)|$HELP"
  then
    guest_ask
  fi
  ;;
esac

# --- The ask tier: decided last --------------------------------
# Guests, storage changes and first-boot writes, whichever the line
# holds, in one prompt.
[ -n "$ASKWHAT" ] && ask_decide

# No taboo matched: no decision, normal permission flow applies.
exit 0
