# tests/hooks/guard-taboos/storage.sh — storage repair and destroy
# denied, changes asked. Sourced by tests/hooks/guard-taboos.sh, in
# its order, into the one shell every part shares; never run on its
# own.
# shellcheck shell=sh

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
# A file system resizer shrinks with a size of its own: resize2fs
# takes no relative one, xfs_growfs -D sets one, and btrfs'
# follows lvresize.
check deny 'resize2fs /dev/vg0/data 20G'
check_mode deny default 'resize2fs -p /dev/vg0/data 500M'
check_mode deny default 'resize2fs -M /dev/vg0/data'
check_mode deny default 'xfs_growfs -D 262144 /srv'
check_mode deny default 'btrfs filesystem resize -5G /mnt'
check_mode deny default 'btrfs fi resize 1:20G /mnt'
# A lookup covers its own invocation, never the one after it.
check deny 'man fsck; fsck -y /dev/sdb1'
check deny 'which e2fsck && e2fsck -fy /dev/sdb1'
check deny 'command e2fsck -fy /dev/sdb1'
check deny 'diskutil help; diskutil repairVolume disk3s1'
check deny 'man zpool; zpool destroy tank'
check deny 'ssh -l man nas1.example.com e2fsck -fy /dev/sdb1'
check deny 'ssh root@nas1.example.com "which zfs && zfs destroy -r tank/home"'
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
  'btrfs filesystem balance start -dconvert=single /mnt' \
  'btrfs balance start /mnt' 'btrfs balance start -d -musage=50 /mnt' \
  'btrfs balance start --full-balance --bg /mnt' \
  'btrfs balance resume /mnt' 'btrfs balance /mnt' \
  'btrfs filesystem resize +10G /mnt' 'btrfs fi resize 2:max /mnt' \
  'resize2fs /dev/vg0/data' 'resize2fs -p /dev/vg0/data 2>&1' \
  'lvextend -L +10G vg0/data && resize2fs /dev/vg0/data' \
  'xfs_growfs /srv' 'xfs_growfs -d /srv' \
  'lvchange -an vg0/data' 'vgchange -a n vg0' \
  'lvchange --activate=n vg0/data' \
  'btrfs balance pool' 'btrfs balance --full-balance /mnt' \
  'btrfs balance -d /mnt' 'btrfs filesystem balance -m /mnt' \
  'btrfs balance -v /mnt' \
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
  'btrfs balance start -dusage=50 -musage=30 /mnt' \
  'btrfs balance pause /mnt' 'btrfs balance cancel /mnt' \
  'btrfs balance start --help' 'btrfs balance resume --help' \
  'resize2fs -P /dev/vg0/data' \
  'resize2fs --help' 'xfs_growfs -n /srv' \
  'lvchange -ay vg0/data' 'vgchange -ay' \
  'man fsck' 'man 8 e2fsck' 'which xfs_repair' 'command -v ntfsfix' \
  'man lvremove' 'whatis lvextend' 'tldr zinject' 'man resize2fs' \
  'man zpool destroy' 'tldr btrfs rescue' 'apropos zfs destroy' \
  'man mdadm --create' 'btrfs balance statu /mnt' \
  'btrfs balance -dusage=50 /mnt' 'ssh root@nas1.example.com man fsck' \
  'ssh -o BatchMode=yes root@nas1.example.com command -v lvremove' \
  'diskutil help repairVolume' 'ssh root@nas1.example.com "man fsck"' \
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
