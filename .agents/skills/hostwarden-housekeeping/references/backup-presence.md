# Backup Presence

Answers the most basic question housekeeping can ask:
**does this host have ANY data backup mechanism?**
Runs on **every** housekeeping run, on every OS,
regardless of what `memory.md` lists — unlike
`service-checks.md`, which only verifies backups the
user already configured.

"No backup" is the most common real-world disaster.
A missing answer here outranks almost everything
else in the report.

## Step 0 — Check Memory First

Look for a `Backup:` line in
`memory/servers/<hostname>/memory.md`:

- **Names a detectable mechanism** (e.g.
  `- Backup: restic via systemd timer`): skip
  discovery, verify recent-run evidence only (below).
- **User acknowledgment** (e.g.
  `- Backup: provider snapshots (Hetzner),
  confirmed 2026-06-10`): emit one INFO line, do not
  re-probe or nag. If the confirmation date is older
  than ~180 days, add INFO: "backup confirmation is
  stale — re-confirm with the user".
- **`- Backup: none — user accepts risk, confirmed
  <date>`**: INFO instead of CRITICAL, same 180-day
  re-ask.

If a mechanism is later detected despite a "none"
line, update the line and tell the user.

## Linux Probes

All read-only; group into one parallel batch. Per
"Verify Before Running", `--help`-check any
version-dependent flags before relying on them.

```
# Backup tools on PATH
for t in restic borg borgmatic rsnapshot duplicity \
         rclone kopia bacula-fd bareos-fd; do
  command -v "$t" >/dev/null && echo "$t"
done

# Scheduled jobs that look like backups
systemctl list-timers --all 2>/dev/null \
  | grep -iE 'backup|borg|restic|rsnapshot|dump|rclone'
grep -riE 'backup|restic|borg|pg_dump|mysqldump|rclone|rsync' \
  /etc/cron.d /etc/cron.daily /etc/cron.weekly \
  /etc/crontab /etc/periodic 2>/dev/null
crontab -l 2>/dev/null \
  | grep -iE 'backup|restic|borg|dump|rsync'

# Filesystem snapshots
zpool list 2>/dev/null && \
  zfs list -t snapshot -o name,creation -s creation \
    2>/dev/null | tail -3
command -v snapper >/dev/null && snapper list-configs
lvs 2>/dev/null | awk '$3 ~ /^s/'

# DB dump jobs and their output
dpkg -l autopostgresqlbackup automysqlbackup \
  2>/dev/null | grep '^ii'
ls -lt /var/backups/ 2>/dev/null | head -5
```

**Recent-run evidence:** the `LAST` column of
`list-timers`, mtimes of backup logs and repo
directories, the creation date of the newest
snapshot.

Two caveats to carry into the report:

- A snapshot on the **same** disk or pool is not an
  off-host backup. Report it, but say so explicitly.
- restic/borg env and password files (e.g.
  `/root/.restic-env`) contain repository
  credentials — inspect names and mtimes only,
  never `cat` them. See `rules/secrets.md`.

## macOS Probes

```
tmutil destinationinfo
tmutil latestbackup 2>/dev/null
tmutil listbackups 2>/dev/null | tail -1
launchctl list | grep -iE 'backup|arq|restic|ccc'
ls /Applications 2>/dev/null \
  | grep -iE 'arq|carbon copy|backblaze'
```

With `Full disk access: off` in memory, the `tmutil`
lines are skipped (`rules/os/macos.md` → Privacy
Protection (TCC)); the backup is "unknown", not
"absent".

## FreeBSD Probes

```
# Backup tools on PATH (packages install to /usr/local)
for t in restic borg borgmatic rsnapshot duplicity \
         rclone kopia zrepl syncoid zfs-autobackup \
         bacula-fd bareos-fd; do
  command -v "$t" >/dev/null && echo "$t"
done

# Scheduled jobs that look like backups: the keyword and the file,
# never the line, which may carry a password or a token
grep -oiE 'backup|restic|borg|zfs send|syncoid|zrepl|dump|rclone|rsync' \
  /etc/crontab /etc/cron.d/* /usr/local/etc/cron.d/* \
  2>/dev/null | sort | uniq -c
crontab -l -u root 2>/dev/null \
  | grep -oiE 'backup|restic|borg|zfs|dump|rsync' | sort | uniq -c
grep -oiE 'backup|snapshot' /etc/periodic.conf \
  /etc/periodic.conf.local 2>/dev/null | sort | uniq -c
service -e | grep -iE 'zrepl|sanoid|bacula|bareos'
# root's crontab needs root: as a normal user, sudo -n crontab …

# ZFS snapshots, newest last
zfs list -H -t snapshot -o name,creation -s creation \
  2>/dev/null | tail -3
```

**Recent-run evidence:** the creation date of the
newest snapshot, the mtimes of backup logs and repo
directories. `zrepl status` and a sanoid/syncoid log
name the last replication where one is set up.

The same-disk caveat under Linux applies: a snapshot
in the host's own pool is not an off-host backup
until something sends it elsewhere (`zfs send` in a
cron job, `syncoid`, `zrepl` with a remote target).

## Severity

- **CRITICAL** — no mechanism found and no
  acknowledgment in memory. The report line MUST
  include: "Provider-level snapshots (Hetzner, AWS,
  Proxmox, …) cannot be detected from inside the
  server — does one exist?" Then ask the user and
  record the answer (below).
- **WARN** — a mechanism exists but shows no run
  evidence within the last 7 days. (Deliberately
  looser than the 25 h / 48 h thresholds in
  `service-checks.md`, which apply only to backups
  the user explicitly configured in memory.)
- **OK / INFO** — mechanism plus fresh evidence.
  One line in Services, e.g.
  `Backups  OK — restic systemd timer, last run 6h ago`.

## Recording the Answer

After the user answers the CRITICAL question, append
exactly one `Backup:` line to `memory.md` — update
it on change, never duplicate:

```
- Backup: provider snapshots (Hetzner), confirmed 2026-06-10
- Backup: none — user accepts risk, confirmed 2026-06-10
- Backup: restic to <repo host>, verified 2026-06-10
```
