# Freeing Disk Space

A full disk is the moment deleting looks cheap and costs the most.
Sort every candidate by what it takes to get it back, before
anything is removed. **The question is never whether something is
a cache; it is what has to happen to bring it back.** Nothing moves
to a cheaper class on the agent's own reading of its name, its age
or the fact that nothing uses it right now.

## Measure First

Read-only, and one file system at a time (`-x` stays off other
devices; on Linux a bind mount of the same file system is still
walked, so read the mount table, `findmnt` or `/proc/mounts`, and
count its content once).
`df` names the full one; `<mount>` below is its mount point, which
is `/var` or `/home` where that is a mount of its own:

```sh
df -h
df -i
du -xk -d 1 <mount> | sort -rn | head -15
```

`df -i` shows inodes: a disk with free bytes and no free inodes is
full too. Descend into the largest directory with the same `du`
until a candidate has a name. `lsof +L1` lists files deleted but
still held open, whose space returns only when the process closes
them or restarts; a restart is its own question
(`rules/service-reload.md`). Without root, `du` and `lsof` skip
what the user cannot read and print the errors: the sizes are then
a lower bound, and the report says so
(`rules/privilege-escalation.md`). Where `lsof` is not installed,
the report says held-open files were not checked.

A filled ZFS pool, Btrfs file system or thin pool reports space
differently from `df`; read it from its own tool
(`zfs list -o space`, `btrfs filesystem usage <path>`, `lvs`;
`.agents/skills/hostwarden-housekeeping/references/zfs-btrfs.md`).
Log reads stay bounded as `rules/log-queries.md` says.

Report the sizes per class (below) before proposing any deletion.

## The Four Classes

- **Re-downloadable:** bandwidth and a wait. Package manager
  caches, tagged container images a registry still serves.
- **Rebuildable:** CPU, sometimes an hour. Build caches,
  thumbnails, language package caches.
- **Gone:** nothing brings it back. User data, databases, mail,
  container volumes, log files, core dumps.
- **A capability, not a file:** nothing is lost, and the option is
  closed. Snapshots, old kernels, journal history.

**Re-downloadable** is proposed as a group, with the sizes and one
question. **Rebuildable** is proposed with the cost named. An item
whose source is gone or unreachable (a private mirror that is down,
a package withdrawn upstream, an image built on this host) is not
re-downloadable, and a build cache whose Dockerfile, context or
downloads are gone is not rebuildable. The question for either
class names that assumption: that the repositories still serve the
packages, that the build inputs exist. Package files installed
from a local file (`dpkg -i`, `rpm -i` of a downloaded package)
may be the only copy: ask where they came from before the clean.

**Gone** is never proposed for deletion on the agent's own reading,
not as an option, a candidate or a footnote with a size. The sizes
appear in the report as findings, with who owns them. When the user
names one, it goes by name, one at a time, and `rules/backups.md`
comes first: is there a copy, and when did it last run?

**A capability** is always its own question, never an item inside
another option. Nothing countable is lost, so say what stops being
possible: the boot into the kernel that worked, the rollback to
before the upgrade, the log that shows who did what. It goes ahead
only on a yes to that trade.

## Where Things Fall

Re-downloadable, each after the group question:

- apt: `apt-get clean`; dnf: `dnf clean packages`; yum:
  `yum clean packages`; zypper: `zypper clean`; FreeBSD: `pkg clean`; Alpine:
  `apk cache clean`
- tagged images no container uses: list them, keep those with a
  registry digest that the host reaches, read with
  `docker image inspect --format '{{.RepoDigests}}'` and never a
  bare inspect (`rules/containers.md` → List and Inspect), and
  remove those by name with `docker image rm`. `prune -a` takes
  every unused image, local builds too, so it is not used here.
  Images share layers: report the unique size of the named images
  (`docker system df -v`), a lower bound of what removal frees: a
  layer shared only among the removed images is freed too

Rebuildable, each with its cost named:

- a container build cache: `docker builder prune`
- Homebrew: `brew cleanup` also removes old versions of installed
  formulae, so the rollback to one is gone: say so in the question
- `/var/cache`, `~/.cache`, thumbnails: the owning program's own
  clean command, not `rm`

Gone, reported and never proposed:

- dangling container images: one may be the only copy of a local
  build whose Dockerfile or context is gone, which only the owner
  can say
- container volumes, mail queues and mailboxes, log files and
  rotated log files (the evidence; the journal is a capability,
  below), core dumps (a crash nobody has read yet)
- `/tmp` and `/var/tmp`: a program may keep state there, and
  `/var/tmp` survives a reboot on purpose

Capability, each its own question:

- journal history: `journalctl --vacuum-time=<d>` or
  `--vacuum-size=<n>`
- old kernels: the distribution's package remove
- LVM, ZFS, Btrfs, VM and provider snapshots: below

A volume is not a cache, whatever its name or age or whether a
container uses it now: it holds a database as often as not.
`volume rm` and `prune` delete data
(`rules/containers.md` → Changes). A volume the user names as
disposable goes by name, one at a time. A file that
`logrotate` or `journald` already bounds is not the problem: find
what keeps growing and why, and tell the user before trimming its
output.

**Old kernels** are a capability because the previous one is the
rollback target if the booted one fails; keep the running kernel
and at least one older. Removing them is a package change that
also touches the boot loader. A full `/boot` is this case.

**Snapshots** cost space by what changed since they were taken.
Name each one with its age and the size it holds
(`zfs list -t snapshot -o name,used,creation`, `lvs`,
`snapper list`), and whether a backup or replication reads it. A
ZFS snapshot is destroyed one at a time, an ask
(`rules/storage.md`). Removing an LVM snapshot, a Btrfs subvolume
or a ZFS snapshot with `-R` is an absolute taboo there: name the
snapshot and what it holds, and leave the removal to the user. A guest's
snapshots made by its host are the host's to name
(`rules/system-containers.md` → Snapshots).

**Journal history** is the audit trail and journald bounds its own
size, so vacuuming it is a question of its own, not a deletion of
log files. Check
`journalctl --disk-usage` and whether the journal is persistent;
before vacuuming, say how far back it reaches now and how far back
it will after, and that incidents older than that cannot be
investigated. A size limit set in `journald.conf` is a config
change (`rules/backups.md`), not a deletion.

## Asking and Doing

1. Report: free space now, then per class the candidates with sizes
   and owners.
2. Ask: one question for the re-downloadable group; one each for
   everything else, naming what stops being possible.
3. Run only what was approved. A path the user protects
   (`rules/access-control.md` → Protected Paths) stays out of it.
4. Read `df` again and compare. If the space did not come back, a
   held-open file, another mount or a reserved block is the cause;
   check before cleaning more.
5. Log what was freed, per class, with the sizes, in the host's
   journal line and the local changelog (`rules/changelog.md`).

A disk that fills again within days has a cause, such as a log with
no rotation, a job without cleanup or a snapshot schedule without
retention. Name it, and leave the fix to the user rather than
deleting on repeat.
