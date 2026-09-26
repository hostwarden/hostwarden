# Storage: Repair, Rebuild, Grow

File systems, RAID arrays, LVM, ZFS pools and Btrfs hold the data
everything else on a host is for. A repair tool decides on its own
what is damaged and throws it away, a rewind discards the last
transactions, and a removed volume is gone. So this file sorts
every storage command into one of three tiers, and the guard
(`CLAUDE.md`) enforces the two that write.

## The Three Tiers

**Read: always allowed.** Nothing here changes a byte on disk:

- `cat /proc/mdstat`, `mdadm --detail`, `--examine`, `--query`
- `pvs`, `vgs`, `lvs`, `pvdisplay`, `vgdisplay`, `lvdisplay`,
  `pvck` and `vgck` without a repair option
- `zpool status`, `list`, `iostat`, `get`, `history`, `events`,
  `zpool import` with no pool, `-d <dir>` included (it lists what
  could be imported),
  `zfs list`, `zfs get`, `zdb`
- `btrfs device stats`, `btrfs filesystem show`, `btrfs check`
  without a write option (it opens read-only by default)
- the dry runs: `fsck -N`, `e2fsck -n`, `xfs_repair -n`,
  `fsck_ffs -n`, `ntfsfix -n` or `--no-action`, `zpool import -Fn`,
  `zpool create -n`, `zfs destroy -n`, `zfs receive -n`, and the
  resizers' own: `resize2fs -P`, `xfs_growfs -n`
- a lookup of any tool here: `man`, `info`, `whatis`, `apropos`,
  `tldr`, `which`, `whereis`, `type` or `command -v` in front of
  it, `--help` or `-h` after it, `diskutil help <verb>`
- `zfs snapshot`, which only adds; `zpool scrub -s`/`-p` and
  `btrfs scrub status`/`cancel`, which stop or read a scrub,
  and `btrfs balance status`, `pause` and `cancel`;
  `mdadm --action=check`, which counts mismatches and fixes none
- `diskutil verifyVolume` on macOS, `chkdsk` without a fixing
  switch and `Repair-Volume -Scan` on Windows

**Change: ask, and the guard asks too.** Routine work on a healthy
host, which the user approves command by command:

- LVM: `lvcreate`, `lvextend`, `lvresize` with a size starting
  with `+`, `lvconvert` (not `--repair`), `vgcreate`, `vgextend`,
  `vgreduce`, `pvmove`, `pvresize`, and `lvchange` or `vgchange`
  with `-an`, which takes the block device away from whatever
  mounts or uses it
- File systems, grown into the space under them: `resize2fs`
  without a size, `xfs_growfs` without `-D`, and
  `btrfs filesystem resize` with a size starting with `+` or `max`
- mdadm: `--add`, `--re-add`, `--remove`, `--fail`, `--replace`,
  `--stop`
- ZFS: `zpool attach`, `detach`, `replace`, `offline`, `online`,
  `add`, `remove`, `split`, `export`, and `import` or `upgrade`
  with a pool or `-a`;
  `zfs destroy` of a snapshot or bookmark (`@`, `#`) and
  `zfs rollback`, each without `-R`, and `zfs receive`, which
  writes a new snapshot or file system, and with `-F` first rolls
  the target back
- Btrfs: `btrfs device add`, `remove`, `delete`,
  `btrfs replace start`, and a balance that rewrites the whole
  file system or its profile: `btrfs balance start` with a
  `convert` filter or without any filter (a bare `-d`, `-m` or
  `-s` selects every chunk of its type), `btrfs balance resume`,
  the hidden `btrfs balance --full-balance <path>`, and the
  deprecated `btrfs balance [options] <path>` on the same terms as
  `start`. A filtered balance
  such as `-dusage=50` moves only the chunks it selects and runs
  without a question
- Scrubs, `zpool scrub` and `btrfs scrub start` or `resume`: they
  rewrite damaged blocks from a copy whose checksum verifies, which
  is self-healing and not a guess, but they load every disk for
  hours, which a degraded pool may not survive
- TrueNAS' middleware: `midclt call pool.export` without `destroy`
  in its argument

Some of these cannot be undone: `zpool add` puts a vdev into the
pool for good where `zpool remove` cannot take it out again (a
RAIDZ pool), and `zpool upgrade` enables features an older boot
loader or ZFS release cannot read. Say so in the question.

**Repair and destroy: absolute taboo.** `AGENTS.md` → Critical
Safety Rules; the guard denies them in every permission mode:

- `fsck`, `fsck.<type>`, `e2fsck`, `xfs_repair` (with `-L` it also
  zeroes the log), `fsck_ffs`, `fsck_apfs`, `fsck_hfs`, and
  `ntfsfix`, which resets the NTFS journal, each without `-n`
- `btrfs check --repair`, `--init-csum-tree`, `--init-extent-tree`,
  every `btrfs rescue`, and `btrfs subvolume delete`, which cannot
  tell a snapshot from a subvolume full of data (snapper and
  timeshift prune their own snapshots)
- `debugfs -w`
- a file system shrunk: `resize2fs` with a size (it takes no
  relative one, so any size may be below the current) or `-M`,
  `xfs_growfs -D`, and `btrfs filesystem resize` with a size not
  starting with `+`, like `lvresize` below
- mdadm: `--create`, `--build`, `--grow`, `--zero-superblock`,
  `--update`, `--assemble` with `--force`, and `--action=repair`
  or `resync`, by mdadm or written to `sync_action`: md has no
  checksum and rewrites each mismatch from a copy it picks
- LVM: `pvcreate`, `pvremove`, `vgremove`, `lvremove`, `lvreduce`,
  `lvresize` with any size not starting with `+` (an absolute
  size below the current one shrinks too), `vgcfgrestore`,
  `lvconvert --repair` (a RAID or mirror LV, a thin pool's
  metadata), `pvck` and `vgck` with `--repair` or
  `--updatemetadata`
- ZFS: `zpool create`, `destroy`, `labelclear`, a rewind —
  `zpool import` with `-F`, `-X`, `-T` or `--rewind-to-checkpoint`,
  `zpool clear -F` on the releases that still accept it —
  `zpool import -m`, which drops a missing log device with its
  transactions, `zinject`, `zfs destroy` of a dataset or volume,
  and `zfs destroy` or `rollback` with `-R`, which takes every
  clone of the snapshot with it
- TrueNAS' middleware: `midclt call disk.wipe`, `pool.create`,
  `pool.dataset.delete` (`zfs destroy` of a dataset) and
  `pool.export` with `destroy` in its argument (`zpool destroy`)
- macOS: `diskutil repairVolume` and `repairDisk`; Windows:
  `chkdsk` with `/f`, `/r`, `/x`, `/b`, `/spotfix` or
  `/offlinescanandfix`, and `Repair-Volume` beyond `-Scan`

## When Storage Is Failing

A degraded array, a pool with errors or a file system that will not
mount is the moment a repair looks most tempting and does the most
harm. The next step is always one of these, in this order:

1. **Read.** The tier above, plus `dmesg` or the journal for I/O
   errors and `smartctl` for the disks
   (`.agents/skills/hostwarden-housekeeping/references/smart.md`).
   Verify before naming a cause
   (`rules/verify-before-reporting.md`).
2. **Report what a backup would need.** Which data sits on the
   affected volume, whether a backup of it exists and when it last
   ran (`.agents/skills/hostwarden-housekeeping/references/backup-presence.md`
   finds the mechanism). A repair is only ever proposed after that
   question has an answer.
3. **Replace, don't repair,** where the array or pool has the
   redundancy for it: a failed disk leaves through the Change tier
   (`mdadm --fail`/`--remove`/`--add`, `zpool replace`,
   `btrfs replace start`), one approved command at a time.
4. **Hand the repair to the user.** Name the command and what it
   can destroy. The user runs it at a console, or relaunches with
   the guard off toward that host, as the `hostwarden-os-install`
   skill describes.
   Hostwarden never restarts its own session without the guard.

On an appliance, the vendor's storage manager does all of this
instead (`rules/appliance/<name>.md`): it keeps records of arrays
and volumes that a stock tool does not know, and a repair it did not
run can leave the volume unreadable to the vendor's own software.

## Before a Change

- **Name the device by what cannot move:** `/dev/disk/by-id/`, the
  serial from `smartctl -i`, the pool's GUID from `zpool status -g`.
  `/dev/sdX` names change between boots.
- **Read the state first** and put it in the question: an array
  that is already degraded, or a pool that is resilvering, turns a
  routine `--fail` or `offline` into the loss of the last copy.
- **One command, one approval.** A disk swap is several steps; the
  guard asks for each, and each one is checked before the next.
