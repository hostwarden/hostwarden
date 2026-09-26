# tests/hooks/guard-taboos/block.sh — taboos blocked outright:
# disks, power, exemptions per invocation. Sourced by
# tests/hooks/guard-taboos.sh, in its order, into the one shell
# every part shares; never run on its own.
# shellcheck shell=sh

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
