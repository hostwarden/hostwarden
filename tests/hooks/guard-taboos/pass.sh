# tests/hooks/guard-taboos/pass.sh — commands that must pass.
# Sourced by tests/hooks/guard-taboos.sh, in its order, into the
# one shell every part shares; never run on its own.
# shellcheck shell=sh

# --- must pass -------------------------------------------------
check pass 'fdisk -l'
check pass 'sfdisk -l /dev/sda'
check pass 'sfdisk -d /dev/sda'
check pass 'gdisk -l /dev/sda'
check pass 'sgdisk -p /dev/sda'
check pass 'parted -l'
check pass 'gpart show ada0'
check pass 'gpart status'
check pass 'disklabel wd0'
check pass 'disklabel -r wd0'
check pass 'disklabel -t sd0'
check pass 'disklabel -hA sd0'
check pass 'mbrlabel -r wd0'
check pass 'fmthard -i -s vtoc.txt /dev/rdsk/c1t0d0s2'
check pass 'raidctl -s raid0'
check pass 'raidctl -g /dev/wd0e raid0'
check pass 'raidctl -p raid0'
check pass 'raidctl -S raid0'
check pass 'bioctl sd4'
check pass 'bioctl -h softraid0'
check pass 'bioctl -qv sd0'
check pass 'ssh root@h "disklabel wd0"'
check pass 'ssh root@h "raidctl -s raid0"'
check pass 'ssh root@h "bioctl sd4"'
check pass 'ssh -F /x/memory/ssh_config root@h "raidctl -s raid0"'
check pass 'ssh -i /x/key root@h "disklabel wd0"'
check pass 'ssh -l root h "bioctl sd4"'
check pass 'ssh -w 0 root@h "mbrlabel -r wd0"'
check pass 'disklabel wd0 | grep -i size'
check pass 'bioctl -a get mfi0'
check pass 'raidctl -l'
check pass 'raidctl -l c0t0d0'
check pass 'ssh root@h "set -e; disklabel wd0"'
check pass 'ssh root@h "disklabel -r wd0 | grep -E x"'
check pass 'ssh root@h "bioctl sd4; ls -l /dev"'
check pass 'lsblk -f'
check pass 'diskutil list'
# Boot entries are read freely; the write forms are taboos
# (tests/hooks/guard-taboos/boot.sh).
check pass 'efibootmgr -v'
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

# The long-job recipe (rules/ssh-connections.md → Long jobs): the
# job file written by a here-document, the retention find with
# rm -r of a finished job, and the stop by process group and tree.
check pass "ssh h 'sh -s' <<'EOS'
export LC_ALL=C
set -e
umask 077
mkdir -p ~/.hostwarden-jobs
find ~/.hostwarden-jobs -mindepth 2 -maxdepth 2 \\
  -name status -mtime +7 | while read -r s; do
  rm -r \"\${s%/status}\"; done
d=\$(mktemp -d ~/.hostwarden-jobs/\$(date +%Y%m%d-%H%M%S)-upgrade.XXXXXX)
cat >\"\$d/cmd\" <<'CMD'
apt-get -y dist-upgrade
CMD
cat >\"\$d/run\" <<'RUN'
d=\${0%/*}
sh \"\$d/cmd\" >\"\$d/out\" 2>\"\$d/err\" &
echo \$! >\"\$d/pid\"; trap \"\" TERM
wait \$!; echo \$? >\"\$d/status\"
RUN
(nohup sh \"\$d/run\" </dev/null >/dev/null 2>\"\$d/launch\" &)
i=0
while [ ! -s \"\$d/pid\" ] && [ \$i -lt 5 ]; do
  sleep 1; i=\$((i+1))
done
[ -s \"\$d/pid\" ] || { cat \"\$d/launch\" >&2
  echo \"job not seen to start: \$d\" >&2; exit 1; }
EOS"
check pass 'ssh h "ps -A -ww -o pgid= -o args= | grep -F ~/.hostwarden-jobs/x | grep -vF \"grep -F\""'
check pass 'ssh h "kill -TERM -4242"'
check pass 'ssh h "k() { for c in \$(ps -A -o pid= -o ppid= 2>/dev/null | awk -v p=\"\$1\" \"\\\$2==p{print \\\$1}\"); do k \"\$c\"; done; kill -TERM \"\$1\"; }; k 4242"'

check pass 'command cp -p /etc/nginx/nginx.conf /var/backups/hostwarden/'
check pass 'command rm /var/tmp/old.log'
check pass 'ssh root@h "command mv -n /var/tmp/a /var/tmp/b"'
