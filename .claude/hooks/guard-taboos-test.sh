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
      "$GUARD_TREES/$t/.claude/hooks/"
  done
  mkdir -p "$GUARD_TREES/ops/.git" "$GUARD_TREES/ops/memory"
  : > "$GUARD_TREES/ops/memory/.hostwarden-workspace"
  GUARD_OPS="$GUARD_TREES/ops/.claude/hooks/guard-taboos.sh"
  GUARD_DEV="$GUARD_TREES/dev/.claude/hooks/guard-taboos.sh"
  export GUARD_OPS GUARD_DEV
fi
HOOK=$GUARD_OPS

json_for() {
  # json_for <command> [tool] — a raw command string as PreToolUse
  # hook input for Bash, or for the tool named.
  if command -v jq >/dev/null 2>&1; then
    printf '%s' "$1" \
      | jq -Rs --arg t "${2:-Bash}" '{tool_name:$t,tool_input:{command:.}}'
  else
    printf '%s' "$1" | python3 -c 'import json,sys; \
print(json.dumps({"tool_name":sys.argv[1],"tool_input":\
{"command":sys.stdin.read()}}))' "${2:-Bash}"
  fi
}

verdict() {
  # verdict <expect> <command> [tool] [hook] — one fixture, one
  # line of output.
  OUT=$(json_for "$2" "$3" \
    | env -u HOSTWARDEN_GUARD_DISABLE sh "${4:-$HOOK}")
  if printf '%s' "$OUT" \
    | grep -q '"permissionDecision":"deny"'; then
    GOT=deny
  else
    GOT=pass
  fi
  if [ "$GOT" = "$1" ]; then
    echo ok
  else
    case "${3:-Bash}" in
    Bash) echo "FAIL [$1, got $GOT]${4:+ in development}: $2" ;;
    *) echo "FAIL [$1, got $GOT] $3${4:+ in development}: $2" ;;
    esac
  fi
}

# Child of the parallel drain at the bottom. Everything it needs
# is defined above; it must exit before the fixtures below, or
# each of the hundreds of children would queue the whole matrix
# again.
# An expectation with a dev- prefix is judged by the copy in the
# development tree (check_dev below).
if [ "$1" = "--verdict" ]; then
  case "$2" in
  dev-*) verdict "${2#dev-}" "$4" "$3" "$GUARD_DEV" ;;
  *) verdict "$2" "$4" "$3" ;;
  esac
  exit 0
fi

SELF="$CLAUDE_DIR/hooks/$(basename "$0")"
QUEUE=$(mktemp)
trap 'rm -rf "$QUEUE" "$GUARD_TREES"' EXIT INT TERM
NCHECKS=0
# One core is the floor, not the default: a machine that will not
# say how many it has still runs the matrix, just no faster.
JOBS=$(getconf _NPROCESSORS_ONLN 2>/dev/null || echo 1)

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
check pass 'mkswap /dev/sda2'
check pass 'rm /tmp/foo'
check pass 'systemctl restart nginx'
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
# Both Markdown fence characters count. A prohibited command in a
# ~~~ block was invisible to this matrix, which is the one place
# that cannot have a blind spot.
corpus_files | grep '\.md$' | grep -v '/CHANGELOG\.md$' \
  | tr '\n' '\0' | xargs -0 \
  awk -v dir="$BLOCKS" '
  /^[ \t]*(```|~~~)/ && !inb { inb = 1
                         fence = ($0 ~ /~~~/) ? "~~~" : "```"
                         if (/[ \t](operator|guard-off)[ \t]*$/) next
                         f = FILENAME; gsub(/\//, "_", f); n++
                         out = dir "/" f "." n; next }
  inb && $0 ~ ("^[ \t]*" fence "[ \t]*$") {
                         if (out) close(out); out = ""; inb = 0; next }
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
denied() { case "$1" in *'"permissionDecision":"deny"'*) true ;; *) false ;; esac; }

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
cp "$SGUARD" "$SET/.claude/hooks/"
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
  cp "$CSESSION" "$REPO/$d/.claude/hooks/"
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
  check_dev pass 'gh pr create --title "guard: catch parted mklabel" --body x'
  check_dev pass 'grep -n "dd if=" rules/os/debian.md'
  check_dev pass 'mkfs.ext4 -F /tmp/disk.img'
  if [ ! -d /run/systemd/system ]; then
    check_dev pass 'rg -n shutdown AGENTS.md'
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
cp "$GUARD_DEV" "$NOMODE/"
OUT=$(json_for 'mkfs.ext4 /dev/sda1' \
  | env -u HOSTWARDEN_GUARD_DISABLE sh "$NOMODE/guard-taboos.sh")
expect "the guard went local without mode.sh to tell its mode" \
  denied "$OUT"
rm -rf "$NOMODE"

# --- drain the queued fixtures ---------------------------------
# Failures are sorted rather than printed as they land, so two
# runs of the same broken tree read the same.
if [ "$NCHECKS" -gt 0 ]; then
  RESULT=$(xargs -0 -n3 -P "$JOBS" sh "$SELF" --verdict < "$QUEUE")
  XSTATUS=$?
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
