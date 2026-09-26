# Backups Before Modifying Config Files

Before editing any config file, back it up:

```
BACKUP_DIR="/var/backups/hostwarden"
mkdir -p "$BACKUP_DIR"
cp /etc/some/config.conf \
  "$BACKUP_DIR/config.conf.$(date +%Y%m%d-%H%M%S)"
# Clean backups older than 30 days
find "$BACKUP_DIR" -type f -mtime +30 -exec rm -f {} \;
```

Where the loaded OS file names another backup
directory, use that one as `$BACKUP_DIR`; where it
names its own backup and cleanup commands, they
replace the block above.
The cleanup uses `-exec rm` rather than `-delete`, which
some busybox builds leave out (`rules/busybox.md`).

A file with a master in the workspace
(`rules/deployed-files.md`) needs no backup only when
the workspace history really holds the version on the
host: its host copy matches the hash in `deployed.md`,
and the master committed at `HEAD` has that same hash,
checked before the new master is written (`sha256sum`
where the workstation has no `shasum`):

```
git -C memory ls-files --error-unmatch <path-in-memory> &&
git -C memory show HEAD:<path-in-memory> | shasum -a 256
```

Everything else is backed up as above: a host copy that
no longer matches, a master not yet committed, and every
file on the local machine, whose memory directory the
workspace never commits (`rules/machine-memory.md` →
Personal versus shared).

In unprivileged mode, use `~/.hostwarden-backups/` for
user-owned files. System config files cannot be
edited — defer those to the sysadmin report.

On a container or VM whose host Hostwarden can reach
and change, prefer a snapshot before a risky change. It covers
the guest's snapshottable storage, not everything the guest
sees: read its mount points first and back up by file what the
snapshot leaves out — a bind or device mount point, a volume
with `backup=0`, an Incus disk device on a host path
(`rules/system-containers.md` → Snapshots).

Backups made before the rename from Heinzel sit in
`/var/backups/heinzel/` and `~/.heinzel-backups/`.
Look there too when restoring, but write new backups
only to the paths above. The retention `find` never
reaches those directories, which is why the first
connection to a host offers to take them over
(`rules/heinzel-legacy.md`).

## State behind an API

Configuration an appliance keeps behind its API, not
in a file, is backed up the same way before a change:
GET the object and keep the response on the
workstation as
`~/hostwarden-keys/<hostname>/api-backups/<object>.<YYYYmmdd-HHMMSS>.json`,
directory mode 700, file mode 600. Such a copy holds
the secrets a read filter drops (`rules/secrets.md` →
API Credentials on the Workstation), so it never goes
under the repo and is never printed; the local
changelog names the file. Restoring is a write of that
object, after asking.

A provider's DNS zone (`rules/dns.md` → Writing through
an API) follows the same shape, keyed by the zone
instead of a host, kept the same way: the backup is the
zone's own export where the provider's API has one —
Cloudflare's returns a BIND zone file — and otherwise
every record at the name the write touches, whatever its
type: a write that changes a name's type, an A record
replaced by a CNAME among them, would otherwise back up
the new type and lose the old. Read back as JSON first,
landing as
`~/hostwarden-keys/dns/<zone>/api-backups/<zone>.<YYYYmmdd-HHMMSS>.<ext>`.

## Moving a backup into `$BACKUP_DIR`

Retention goes by mtime, and `mv` keeps it. A file
moved into `$BACKUP_DIR` can therefore be past the
window the moment it arrives, and the next cleanup
deletes it — whether it comes from a drop-in
directory (below), from Heinzel's old directory, or
from anywhere else.

So before moving backups in, count how many are older
than the window and say that number. Then move, or
`touch` the ones worth keeping, or raise the window
for this host in `memory/machines/<hostname>/rules.md`
— but never silently move a file that the next
cleanup eats.

## Never back up in place inside drop-in directories

Several Linux config systems read **every** file in a
directory and parse them. A backup left next to the
original gets parsed too, often with a warning at best
and broken behaviour at worst.

Affected paths include (but are not limited to):

- `/etc/apt/apt.conf.d/`
- `/etc/apt/sources.list.d/`
- `/etc/cron.d/`
- `/etc/systemd/system/*.d/`
- `/etc/ssh/sshd_config.d/`
- `/etc/sudoers.d/`; on FreeBSD `/usr/local/etc/sudoers.d/`
  and `/usr/local/etc/cron.d/`
- `/etc/nginx/conf.d/`, `sites-enabled/`,
  `modules-enabled/`
- `/etc/logrotate.d/`
- `/etc/profile.d/`
- `/etc/config/` (OpenWrt: every file there is a UCI
  config)
- `/data/on_boot.d/` (UniFi OS: every file there runs
  at boot)

When editing a file in one of those directories, write
the backup to `$BACKUP_DIR` only. Never leave
it in the source directory, not even with a `.bak` or
timestamped suffix:

- `apt` logs daily warnings about
  `50unattended-upgrades.bak.YYYYMMDD` files (invalid
  filename extension) and silently ignores them.
- `sshd` refuses to start with stray files in
  `sshd_config.d/`.
- A forgotten `/etc/sudoers.d/old.bak` can rescind
  privileges silently if its parser pass fails.

If a session uncovers an existing in-place backup in
one of those directories, move it to `$BACKUP_DIR`
rather than leaving it where it is.

## Verify cross-backups at the receiver, not the source

A cross-backup (host A's dumps copied to host B) is only
real when the dump **files** exist and are intact **on
the receiver**. A running pull job, a present cron line,
or a directory that looks populated prove nothing. When
asked whether a host holds a copy, go look on that host:
list the actual `*.sql.gz` (or equivalent), confirm the
newest matches the source's newest, and run an integrity
check (`gzip -t`, or the tool's own verify). "The job is
scheduled" is not "the data is there."

**Silent-failure gotcha — out-of-jail symlinks.** A
common pattern exposes dumps for pulling via a symlink in
the puller's reach, e.g. `outbox/dbbackup ->
/var/lib/dbbackup`, where the target is **outside** an
`rrsync -ro <dir>` jail. A plain `rsync -a` pull copies
that symlink **verbatim**: on the receiver it becomes a
dangling (or misleading) symlink and **zero data
transfers — with no error and no warning email**. The
pull must pass `--copy-unsafe-links` so the *sender*
follows the link and ships the real files. If one source
in a mesh works and another doesn't, diff their pull
commands for this flag first.

**Dry-run must be verbose.** To preview what a pull would
transfer, use `rsync -n -v`. A bare `rsync -n` lists
nothing and reads as "0 files would transfer", which
will mislead you into the wrong conclusion. Confirm by
grepping the `-nv` output for the specific files you
expect (e.g. the database name).
