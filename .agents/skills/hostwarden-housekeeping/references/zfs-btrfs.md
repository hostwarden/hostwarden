# ZFS and Btrfs

Runs where `@storage` found ZFS or btrfs, or memory has a
`Storage:` line (`rules/storage-inventory.md` → Detection). The
inventory from that file runs in one call with the health reads
below; health is read fresh, and settings are compared with
`memory/servers/<hostname>/storage.md` and rated.

An appliance's `## Housekeeping and Audits` section owns each
health check it runs itself, and that check is skipped below:
pool state and errors where it reads `zpool status` or its API,
fill level where it reads `cap`, scrub age where it reads the
scan line or a scrub task, device errors where it reads
`btrfs device stats`. Every check it does not run comes from
here, and Settings runs everywhere.

## ZFS Health

The inventory's `zpool list` and `zpool status -t` carry it all.
Where `storage.md` records pools and `/dev/zfs` is missing, the
module is not loaded and no pool is imported: **WARN**, and no
`zpool` or `zfs` command runs (`rules/storage-inventory.md` →
Detection), so nothing below is read.

- **WARN** if a pool's `cap` > 80% — ZFS slows down well before
  it is full
- **CRITICAL** if a pool's `cap` > 95%
- **CRITICAL** for a pool that is not `ONLINE`, or whose
  `zpool status` lists read, write or checksum errors
- **INFO** if the `scan:` line shows the last scrub older than 35
  days, or none. The age answers for whatever schedules scrubs;
  on FreeBSD that is `daily_scrub_zfs_enable` in
  `/etc/periodic.conf`, off by default.
- **WARN** for a pool `storage.md` records that a `zpool list`
  which exited 0 no longer shows, handled as a guest that is not
  listed (`rules/hypervisors.md` → Changes Between Connections):
  its section gains `not listed <date>`. `zpool import` without a
  pool name lists the pools that could be imported and changes
  nothing; report whether it is among them. Importing is the
  user's step (`rules/storage.md` → The Three Tiers). Neither
  answer proves the pool destroyed — its
  disks may only be detached — so the section goes only when the
  user says the pool is gone.

## Btrfs Health

Per filesystem of the inventory loop, in the same call, as root:

```sh
btrfs device stats "$m" | grep -v ' 0$'
btrfs scrub status "$m"
```

Never `btrfs device stats -z`: it resets the counters, and they
are the only record of past errors.

- **WARN** for each counter `btrfs device stats` still prints —
  only those above `0` are left — with the device.
- **WARN** if `Device unallocated` in `btrfs filesystem usage` is
  below 1 GiB: btrfs allocates space in chunks, and a filesystem
  that cannot allocate a new metadata chunk fails with "no space
  left" while `df` still shows free space. The remedy is a
  filtered balance, which moves data and is the user's decision
  (`rules/storage.md` → Before a Change).
- **INFO** if the last scrub is older than 35 days, or none.
- **WARN** for a filesystem `storage.md` records that is no longer
  mounted, handled as the missing pool above.

## Settings

Compare what the inventory read with `storage.md`, report the
differences as `rules/hypervisors.md` → Changes Between
Connections does, and rewrite the file. A host without a
`storage.md` gets it written now and reports no differences; the
ratings below still run. Btrfs filesystems are matched by UUID,
pools by name:

    tank/db: sync standard → disabled
    tank: 2 more features not enabled

A value that carries a reason from the user is reported as
`accepted` with that reason, once, and not rated. Then rate:

**ZFS**

- **Features not enabled** — the `status:` line of `zpool status`
  says so ([zpool-upgrade(8)](https://openzfs.github.io/openzfs-docs/man/master/8/zpool-upgrade.8.html)):
  **INFO**, one line per pool. `zpool upgrade` is one-way and in
  the change tier of `rules/storage.md` → The Three Tiers.
  Once a feature is active, an older ZFS, a rescue system, a
  replication target on an older release, and a boot loader
  reading a boot pool may no longer import the pool. Never run it;
  say what would stop reading the pool, and the user decides. A
  boot pool with a `compatibility` set keeps to it.
- **Dedup** — any dataset with `dedup` other than `off`: read the
  table with `zpool status -D <pool>`. Its `dedup: DDT entries …`
  line gives the entries and the bytes each takes in core; their
  product is the RAM the table wants.
  - **WARN** if that exceeds half of the ARC's `c_max`, which
    also has to hold the data it caches: the table stops fitting,
    and writes wait for it to be read from disk. A pool with a
    `dedup` or `special` vdev keeps the table on flash: **INFO**
    there.
  - **INFO** if the pool's `dedupratio` is below 1.10x: dedup
    costs RAM and write speed and saves almost nothing here.
- **`sync=disabled`** on a dataset or zvol: **WARN**. ZFS then
  confirms a synchronous write before it is on disk; after a crash
  or a power cut, the last seconds of writes that a database, a
  mail server or a VM's filesystem were told were safe are gone,
  and the application can come back inconsistent. Where a user is
  at the keyboard, ask after the report what the dataset holds,
  in the shape of `rules/service-reload.md` → Prompt Shape When
  Asking, and record the answer (`rules/storage-inventory.md` →
  storage.md). A scheduled run only reports.
- **Compression off** — a filesystem the inventory lists with
  `compression` `off` not inherited, whose children inherit it
  unless they set their own: **INFO**, once per such dataset.
  `lz4` costs little CPU and gives up early on data that does not
  compress. A change applies to new writes only. A zvol is left
  alone: what it holds is its guest's business.
- **autotrim off on flash** — `zpool status -t` shows each
  vdev's TRIM state: `(trim unsupported)` for a disk that has
  none, `(untrimmed)` for one never trimmed, and
  `completed at <date>` for the last TRIM. **INFO** for a pool
  with autotrim `off`, a vdev that supports TRIM, and no TRIM
  completed in the last 35 days. A periodic trim — Debian's
  `zfsutils-linux` cron job, a `zfs-trim-monthly@<pool>` timer —
  shows here as a recent one and raises nothing.
- **Special or dedup vdev less redundant than the data vdevs** —
  a single disk in the `special` or `dedup` class of a mirror or
  raidz pool: **WARN**. The pool's metadata lives there and
  nowhere else, so losing that disk loses the pool; OpenZFS says
  the class's redundancy should match the data vdevs'
  ([zpoolconcepts(7)](https://openzfs.github.io/openzfs-docs/man/master/7/zpoolconcepts.7.html)),
  and `zpool add` refuses the mismatch unless forced.
- **ARC limit that was set at runtime only** (`storage.md`):
  **INFO**, the next boot reverts it.
- **ARC against guests**, on a host with a `Hypervisor:` line:
  add the memory of every running VM on this host and the ARC's
  `c_max`. **WARN** if the sum exceeds the host's RAM: the ARC
  can then grow only by pushing VMs into swap or the OOM killer,
  and it gives memory back more slowly than a starting VM takes
  it. The Linux default from OpenZFS 2.3 on nearly always trips
  this on a hypervisor (`rules/storage-inventory.md` → ARC
  limits). Containers do not count; their memory is the host's
  own.
  - Proxmox VE: the guest listing this run already made
    (`rules/appliance/proxmox-ve.md` → Guests): `maxmem` of each
    `qemu` entry that is `running` on this node.
  - libvirt: `balloon.maximum`, in KiB, per domain of
    `virsh -c qemu:///system domstats --list-running --balloon`.
  - vm-bhyve: the `MEMORY` column of running VMs in `vm list`.
  - Any other manager: not rated; say so in one line.

**Btrfs**

- **Two profiles for one type** — `Multiple profiles: yes` in
  `btrfs filesystem usage`, two `Data,` or two `Metadata,` lines:
  **WARN**. A conversion stopped halfway
  ([btrfs(5)](https://btrfs.readthedocs.io/en/latest/btrfs-man5.html)),
  or the filesystem was mounted degraded and wrote new chunks as
  `single`; either way part of the data has less redundancy than
  the rest.
- **Metadata or system `single` or `RAID0` on more than one
  device:** **WARN**. One lost device takes the whole filesystem.
- **`RAID5` or `RAID6`:** **WARN**, for data and metadata alike.
  The btrfs status page marks them unstable and not for
  production, and never for metadata, which belongs on `RAID1` or
  `RAID1C3`
  ([Status](https://btrfs.readthedocs.io/en/latest/Status.html)).

Fixing any of these is a change the user approves: `zfs set`,
`zpool set`, a mount option or an ARC limit as a configuration
change, a scrub, an import or a balance as `rules/storage.md`
sorts it. On an appliance it happens in its web UI
(`rules/storage-inventory.md` → On an Appliance).
