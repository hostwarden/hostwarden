# Storage Maintenance

Checks `rules/baseline.md` → Storage Maintenance: whether TRIM, the
md RAID check and ZFS and btrfs scrubs are scheduled. What each
distribution enables by itself is the family file's Storage
Maintenance section; this file reads what the host runs. Runs on
every Linux and FreeBSD host except in a system container, whose
filesystems are its host's.

An appliance whose file says its storage belongs to its manager —
TrueNAS, QNAP, Synology DSM, UGOS, Unraid, OpenMediaVault —
schedules these in its
web UI, and its `## Housekeeping and Audits` section reads them:
report what that section finds, and never add a cron job or a
timer there. Every other appliance, Proxmox VE among them, is
checked as its base family.

## Read

One call, as root. Linux:

```sh
lsblk -rno FSTYPE,DISC-GRAN,MOUNTPOINT | grep -E '^(ext4|xfs|btrfs|f2fs) '
findmnt -rn -t ext4,xfs,btrfs,f2fs -o TARGET,OPTIONS
cat /proc/mdstat
for m in /sys/block/md*/md; do
  test -r "$m/mismatch_cnt" && echo "$m $(cat "$m/sync_action") $(cat "$m/mismatch_cnt")"
done
grep -sHE '^(MAILADDR|PROGRAM)' /etc/mdadm/mdadm.conf /etc/mdadm.conf
grep -sE '^(ENABLED|CHECK)=' /etc/sysconfig/raid-check
grep -rsHE '^[^#]*(fstrim|checkarray|mdcheck|raid-check)' /etc/cron.d /etc/crontab \
  /etc/periodic /var/spool/cron \
  | sed -E 's/^([^:]*):.*(fstrim|checkarray|mdcheck|raid-check).*/\1: \2/' | sort -u
```

and, with systemd,

```sh
systemctl is-enabled fstrim.timer mdcheck_start.timer raid-check.timer 2>&1
systemctl is-active mdmonitor.service 2>&1
```

The cron `grep` skips commented lines, and `sed` leaves only the
file and the command name it found, never the line: a crontab
line can carry a password (`rules/secrets.md`). On the RHEL
family, `raid-check.timer` runs a check only while
`/etc/sysconfig/raid-check` says `ENABLED=yes`; with `no`, the
timer counts as no schedule.
`lsblk -r` carries `DISC-GRAN` through partitions, LVM and
device-mapper, so each mounted filesystem shows whether the disk
below it accepts TRIM. `systemctl` prints one line per unit,
`not-found` for one the host does not have. Without systemd, the
family file's Service Manager says how to ask whether the md
monitor runs (on Alpine, `rc-service mdadm status`).

FreeBSD, in one call:

```sh
sysrc -f /etc/periodic.conf -n daily_scrub_zfs_enable daily_trim_zfs_enable
mount -p -t ufs | while read -r dev mnt rest; do
  echo "@ufs $dev $mnt"; tunefs -p "$dev" 2>&1 | grep trim
done
```

Only UFS on a flash disk (`rotationrate` `0` in
`rules/storage-inventory.md` → Disks) is rated below.

## TRIM

Flash needs to learn which blocks are free, or it slows down and
wears faster; a thin-provisioned virtual disk gives freed space
back only this way, so a VM counts too. ZFS is
`references/zfs-btrfs.md`'s: autotrim and its own TRIM schedule.

- **INFO** for an ext4, xfs, btrfs or f2fs filesystem whose
  `DISC-GRAN` is above `0B`, mounted without `discard`, on a host
  where neither `fstrim.timer` is enabled nor a cron or periodic
  entry runs `fstrim`.
- **FreeBSD:** **INFO** for UFS on flash whose `tunefs -p` says
  `trim: (-t) disabled`. Turning it on needs the filesystem
  unmounted or read-only (`rules/os/freebsd.md` → Storage
  Maintenance): a maintenance window, the user's.

## md RAID Check

A check reads every block of an array and compares the copies,
so a bad sector is found while redundancy can still repair it.

- **INFO** for a host with an array in `/proc/mdstat` and no
  enabled check timer or cron entry.
- **INFO** for an array whose `sync_action` is `check` or
  `repair`: a check is running; its result comes next run.
- `mismatch_cnt` above `0` after a check: **WARN** on RAID 4, 5
  or 6, where parity and data disagree. **INFO** on RAID 1 or 10,
  where swap or a file rewritten during the write can leave
  mismatches without damage
  ([md.rst](https://github.com/torvalds/linux/blob/master/Documentation/admin-guide/md.rst)).
  A repair is `rules/storage.md`'s taboo tier, never Hostwarden's
  step.
- **INFO** for an array nothing watches between runs: the md
  monitor not running, whatever `mdadm.conf` names. A degraded
  array then waits for the next housekeeping.
- **INFO** for a running monitor with no `MAILADDR` or `PROGRAM`
  in `mdadm.conf`: it notices a failure and tells no one.

## Scrubs

The scrub age of a ZFS pool or a btrfs filesystem is rated in
`references/zfs-btrfs.md`. Only where it is too old, read what
would schedule it, in the next call:

- **ZFS on Linux:** `systemctl list-units --all --no-legend
  'zfs-scrub-*@*.timer'`, and on Debian and Ubuntu
  `/etc/cron.d/zfsutils-linux` with
  `zfs get -H -o value org.debian:periodic-scrub <pool>`.
- **ZFS on FreeBSD:** `daily_scrub_zfs_enable` from the Read above.
- **btrfs:** `systemctl is-enabled btrfs-scrub.timer` and
  `BTRFS_SCRUB_MOUNTPOINTS` in `/etc/sysconfig/btrfsmaintenance`
  or `/etc/default/btrfsmaintenance`: a filesystem it does not
  name is not scrubbed even where the timer runs.

## What Is Missing

A missing schedule is a gap in `rules/baseline.md` → Storage
Maintenance: one recommendation line each, naming the mechanism
the family file gives and the command that turns it on — for
example `systemctl enable --now fstrim.timer`,
`systemctl enable --now zfs-scrub-monthly@<pool>.timer`,
`sysrc -f /etc/periodic.conf daily_scrub_zfs_enable=YES`, or the
filesystem's mount point in `BTRFS_SCRUB_MOUNTPOINTS`. The user
closes it with `hostwarden-baseline` or by asking; a scheduled run
only reports.

Turning one on is a change the user approves, and a scheduled
scrub is a scrub each time it runs (`rules/storage.md` → The Three
Tiers): the question says how long a scrub loads the disks. Where
configuration management owns the host, the change goes through
it (`rules/config-management-changes.md`).
