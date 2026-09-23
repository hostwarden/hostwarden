# Storage Inventory: ZFS and Btrfs

A ZFS pool and a btrfs filesystem behave by their own settings.
A property set years ago decides whether a write the application
was told is safe really is (`sync`), how much RAM the pool needs
(`dedup`), and whether the boot loader and older systems can
still read it (feature flags). None of that shows in `df`. So a
host with either records its settings once, in
`memory/servers/<hostname>/storage.md`, and housekeeping compares
the host against that record
(`.agents/skills/hostwarden-housekeeping/references/zfs-btrfs.md`).

The record holds settings, never state: pool health, fill level,
errors and scrub age change by the hour and are read fresh by
housekeeping. Everything here only reads; which storage commands
change something, and which of those are the user's alone, is
`rules/storage.md` → The Three Tiers.

## Detection

The lines after `@storage` in the step-1 probe
(`rules/first-detection.md`), which housekeeping runs again:

- `/dev/zfs` listed: the ZFS module is loaded. Without it, no
  `zpool` or `zfs` command runs: on Linux they load the kernel
  module when it is missing, which is a change, not a read.
- A number above `0`: that many btrfs mounts. FreeBSD and macOS
  answer with an error, which means none.

The inventory is written for Linux and FreeBSD. On macOS,
`/dev/zfs` from OpenZFS on OS X is noted in memory and nothing
here runs. A system container (`Virtualization:` names a
container) sees its host's filesystems, not its own: record
nothing there. The host's inventory covers them.

## When

- **First connection:** the inventory rides in the activity-check
  call (`rules/activity-check.md` → What rides in this call) when
  `@storage` found either.
- **Housekeeping:** every run, and the first inventory of a host
  whose memory has no `Storage:` line.

## ZFS

In one bundled call (`rules/ssh-connections.md`). `zfs` and
`zpool` read without root on Linux and FreeBSD; on an appliance
whose file says otherwise (QNAP), run it as that file says.

```sh
zpool list -H -o name,size,cap,health,ashift,autotrim,compatibility,dedupratio
zpool status -t
for p in $(zpool list -H -o name); do
  echo "@ashift $p"; zpool get -H -o value ashift "$p" all-vdevs | sort | uniq -c
done
zpool get -H -o name,property,value all | grep 'feature@.*disabled' | cut -f1 | uniq -c
zfs get -H -t filesystem,volume -o name,property,value,source -s local,received \
  compression,atime,relatime,recordsize,dedup,sync,primarycache,secondarycache,special_small_blocks,logbias
zfs get -H -t filesystem -o name,property,value,source compression \
  | grep -w off | grep -v inherited
zfs list -H -t volume -o volblocksize | sort | uniq -c
zfs list -H -o name,encryptionroot,encryption,keyformat,keylocation,keystatus \
  | awk '$1 == $2 { sub(/:\/\/.*/, "://", $5); print }'
```

Read it as:

- **Layout**, from `zpool status`: each top-level vdev with its
  type (mirror, raidz1–3, draid, a single disk) and disk count,
  and the classes below the data vdevs — `logs` (SLOG), `cache`
  (L2ARC), `special`, `dedup` and `spares`.
- **ashift:** the pool property is the default for vdevs added
  later, `0` meaning ZFS detects it
  ([zpoolprops(7)](https://openzfs.github.io/openzfs-docs/man/master/7/zpoolprops.7.html)).
  What the vdevs have is the `@ashift` count, which needs OpenZFS
  2.2 or later
  ([vdevprops(7)](https://openzfs.github.io/openzfs-docs/man/master/7/vdevprops.7.html));
  older releases answer with an error, and the pool property is
  all there is.
- **autotrim** and **compatibility**: as printed. A
  compatibility set (`grub2`, `openzfs-2.1-linux`) limits which
  features the pool may enable, usually so a boot loader or an
  older system can still read it.
- **Features:** the count of `disabled` ones. `zpool status` says
  whether they matter: its `status:` line reads *Some supported
  and requested features are not enabled on the pool*, and counts
  only the features a compatibility set allows. Record the count
  and whether that line is there.
- **Set here:** each line of the first `zfs get`, by dataset. A
  property set on a pool's root dataset is inherited by
  everything under it and is recorded once, there. Default
  values are not recorded, with one exception: a filesystem whose
  `compression` is `off` without inheriting it, from the second
  `zfs get`. The default is `on` (lz4) from OpenZFS 2.2 and was
  `off` before, so a pool root on an older release shows there
  with the source `default`
  ([zfsprops(7)](https://openzfs.github.io/openzfs-docs/man/master/7/zfsprops.7.html)).
- **Zvols:** their count per `volblocksize`, which is fixed at
  creation and never shows as `local`.
- **Encryption:** each encryption root, with its cipher, key
  format, where the key comes from and whether it is loaded. A
  `keylocation` of `prompt` means someone types a passphrase
  after every reboot before the data is there. Of a `file://` or
  `https://` location only the scheme is printed and recorded: a
  URL can carry credentials, and the path says where the key
  lies. Never read the key (`rules/secrets.md`).

### ARC limits

The ARC is ZFS's read cache in RAM; its limits belong to the host,
not a pool.

**Linux:**

```sh
grep -H . /sys/module/zfs/parameters/zfs_arc_max \
  /sys/module/zfs/parameters/zfs_arc_min
grep -E '^(c_min|c_max|size) ' /proc/spl/kstat/zfs/arcstats
grep -rsH zfs_arc_m /etc/modprobe.d
grep -o 'zfs\.zfs_arc_m[a-z]*=[0-9]*' /proc/cmdline
```

`c_max` and `c_min` in `arcstats` are the limits in effect; a
parameter of `0` means the built-in default, which for the
maximum is half the RAM up to OpenZFS 2.2 and, from 2.3 on, the
larger of the RAM less 1 GiB and five eighths of it
([zfs(4)](https://openzfs.github.io/openzfs-docs/man/master/4/zfs.4.html)).
What is set at boot comes from an `options zfs zfs_arc_max=…`
line in `/etc/modprobe.d/` or the kernel command line; with the
root on ZFS, the initramfs carries its own copy. A value in
`/sys/module` that neither sets was changed at runtime and is
gone at the next boot: record it as such.

**FreeBSD**, where the default maximum follows the 2.3 rule
above and `vfs.zfs.arc_max` is the older name of the tunable:

```sh
sysctl vfs.zfs.arc.max vfs.zfs.arc.min \
  kstat.zfs.misc.arcstats.c_max kstat.zfs.misc.arcstats.c_min
grep -sH 'vfs\.zfs\.arc' /boot/loader.conf /boot/loader.conf.local \
  /etc/sysctl.conf
```

## Btrfs

Needs root. Unprivileged, `btrfs filesystem usage` prints no
per-device figures and `btrfs qgroup show` fails; what is missing
is recorded as `skipped: needs root`
(`.agents/skills/hostwarden-housekeeping/references/unprivileged.md`).
One filesystem is often mounted several times, once per
subvolume, so the loop reads each once, by UUID; `findmnt -l`,
unlike `-r`, leaves a space in a mount point as it is:

```sh
findmnt -rn -t btrfs -o UUID,TARGET,FSROOT,OPTIONS
findmnt -ln -t btrfs -o UUID,TARGET | sort -u -k1,1 | while read -r u m; do
  echo "@btrfs $u $m"
  btrfs filesystem usage -b "$m"
  btrfs qgroup show "$m" | head -n 3
done
```

Record per filesystem, by its UUID, which is what housekeeping
matches on; the heading names the mount point the loop read, and
a different one on a later run is not a change:

- **Devices:** the count of device lines under `Unallocated:`.
- **Profiles:** from the `Data,`, `Metadata,` and `System,` lines
  — `single`, `DUP`, `RAID0`, `RAID1`, `RAID1C3`, `RAID1C4`,
  `RAID10`, `RAID5`, `RAID6`. `mkfs.btrfs` makes data `single`
  and metadata `DUP` on one device, metadata `RAID1` on several
  ([mkfs.btrfs](https://btrfs.readthedocs.io/en/latest/mkfs.btrfs.html)).
  Two lines of one type with different profiles, which
  `Multiple profiles: yes` also says, are recorded as they are.
- **Mount options** that change behaviour
  ([btrfs(5)](https://btrfs.readthedocs.io/en/latest/btrfs-man5.html)):
  `compress` or `compress-force` with its algorithm and level
  (off unless set), `discard` (`async` by default on devices that
  support it from Linux 6.2), `nodatacow`, `nodatasum`,
  `autodefrag`, `ssd`. The same filesystem mounted with different
  options at different mount points is recorded per mount point.
- **Quotas:** on or off; with them off, `btrfs qgroup show`
  fails with *quotas not enabled*.

## storage.md

```markdown
# Storage on nas1.example.com

- Inventoried: 2026-09-23
- ARC: max 8 GiB (/etc/modprobe.d/zfs.conf), min default;
  RAM 32 GiB

## ZFS pool tank
- Layout: raidz2 × 6; special mirror × 2; logs mirror × 2;
  cache × 1; ashift 12 (all vdevs)
- Size 43.6T; autotrim off; compatibility off
- Features: 3 not enabled
- Set here: compression=lz4, atime=off (tank);
  recordsize=1M (tank/media); sync=disabled (tank/scratch,
  scratch data: user, 2026-09-23)
- Zvols: 12, volblocksize 16K
- Encrypted: tank/private (aes-256-gcm, passphrase, key
  prompt)

## btrfs /srv (uuid 0f5c3c2e-…)
- Devices: 2; data RAID1, metadata RAID1, system RAID1
- Mount: compress=zstd:3, discard=async
- Quotas: off
```

`memory.md` carries one line that names the file:
`- Storage: ZFS tank, rpool; btrfs /srv (storage.md)`.

A value the user explained — `sync=disabled` on scratch data,
dedup on a pool that earns it — carries the reason the way a
stopped guest does (`rules/hypervisors.md` → Stopped Guests): the
reason and `(user, <date>)` after the value, dropped when the
value changes.

## On an Appliance

The inventory reads the same way. An appliance that keeps its own
record of pools and datasets — TrueNAS, QNAP QuTS hero, Unraid,
and others whose file says so (`rules/appliance/<name>.md`) — has
a setting that housekeeping finds wrong changed in its web UI,
never with `zfs set` or `zpool set`.
