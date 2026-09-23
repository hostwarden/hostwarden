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

# Scheduled jobs that look like backups: the keyword and the file,
# and the absolute paths those lines name, for the run evidence
# below, never the line (rules/secrets.md → Commands That Leak);
# commented-out lines are not jobs
systemctl list-timers --all 2>/dev/null \
  | grep -iE 'backup|borg|restic|rsnapshot|dump|rclone'
KW='backup|restic|borg|dump|rclone|rsync'
PA="(^|[[:space:]>=])/[^[:space:]\"';|&<>]+"
# a path shows only where its directory exists here: an argument
# that only looks like one can be a token. One whose directory is
# gone shows as "(path missing under <nearest that exists>)", one
# this user cannot test (permission, a stale mount behind the
# timeout) as "(path not readable)", never as its value
ex() { while IFS= read -r w; do w=${w#[[:space:]>=]}; w=${w%%::*}
  case $w in /*) d=${w%/*}; d=${d:-$w}; timeout 5 test -e "$d"; r=$?
    if [ $r -eq 1 ] && LC_ALL=C ls -d "$d" 2>&1 | grep -q 'No such file'
    then a=${d%/*}; while [ -n "$a" ] && ! timeout 5 test -e "$a"
      do a=${a%/*}; done; w="(path missing under ${a:-/})"
    elif [ $r -ne 0 ]; then w='(path not readable)'; fi ;; esac
  printf '%s%s\n' "$1" "$w"; done; }
for f in /etc/crontab /etc/cron.d/* /etc/cron.daily/* \
  /etc/cron.weekly/* /etc/periodic/*/*; do
  grep -v '^[[:space:]]*#' "$f" 2>/dev/null | grep -iE "$KW" \
    | grep -oiE "$KW|$PA" | ex "$f:"
done | sort | uniq -c
crontab -l 2>/dev/null | grep -v '^[[:space:]]*#' | grep -iE "$KW" \
  | grep -oiE "$KW|$PA" | ex | sort | uniq -c

# Filesystem snapshots (no zpool without /dev/zfs: it would load
# the module, rules/storage-inventory.md → Detection)
test -e /dev/zfs && zpool list 2>/dev/null && \
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
directories, which the cron lines name where their
directory exists, the creation date of the newest
snapshot. A `(path not readable)` line is evidence
this user could not check: "unknown", not "none". A
`(path missing under /mnt)` line is a target that is
not there: an unmounted disk or share, a repository
that was moved, or an argument that only looked like a
path; name the job and ask.

Two caveats to carry into the report:

- A snapshot on the **same** disk or pool is not an
  off-host backup. Report it, but say so explicitly.
- On a hypervisor host, ask the manager for the
  guests' snapshots: the probes above see a ZFS or
  LVM one, but a Proxmox qcow2 or Incus dir-storage
  snapshot only its manager knows
  (`pct listsnapshot <vmid>` and `qm` per guest,
  `incus info <ct>`). A snapshot named `hostwarden-…`
  with no open `todo.md` item is left over: report it
  and offer to delete it
  (`rules/system-containers.md` → Snapshots).
- restic/borg env and password files (e.g.
  `/root/.restic-env`) contain repository
  credentials — inspect names and mtimes only,
  never `cat` them. See `rules/secrets.md`.

## macOS Probes

```
tmutil destinationinfo
tmutil latestbackup 2>/dev/null
tmutil listbackups 2>/dev/null | tail -1
P='backup|arq|restic|ccc'
G=$(who | awk '$2 == "console" {print $1}' | sort -u |
  while read -r u; do echo "gui/$(id -u "$u")"; done)
for D in system $G; do
  if L=$({ <Enabled services listing of "$D">; } 2>/dev/null); then
    printf '%s\n' "$L" | grep -iE "$P"
  else
    echo "$D unread"
  fi
done
ls /Applications 2>/dev/null \
  | grep -iE 'arq|carbon copy|backblaze'
```

`<Enabled services listing of "$D">` is `rules/os/macos.md` →
Service Manager → Enabled services, with `"$D"` as its domain: the
system daemons, then the agents of every user logged in at the
screen (`who` lists them on `console`), where a backup tool can run
as a LaunchAgent whoever the SSH user is. With nobody logged in no
agent runs, and only `system` is read. An `unread` domain makes the
backup "unknown", not "absent", when nothing else is found.

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
# and the absolute paths those lines name, never the line
# (rules/secrets.md → Commands That Leak); commented-out lines
# are not jobs
KW='backup|restic|borg|zfs send|syncoid|zrepl|dump|rclone|rsync'
PA="(^|[[:space:]>=])/[^[:space:]\"';|&<>]+"
# a path shows only where its directory exists here: an argument
# that only looks like one can be a token. One whose directory is
# gone shows as "(path missing under <nearest that exists>)", one
# this user cannot test (permission, a stale mount behind the
# timeout) as "(path not readable)", never as its value
ex() { while IFS= read -r w; do w=${w#[[:space:]>=]}; w=${w%%::*}
  case $w in /*) d=${w%/*}; d=${d:-$w}; timeout 5 test -e "$d"; r=$?
    if [ $r -eq 1 ] && LC_ALL=C ls -d "$d" 2>&1 | grep -q 'No such file'
    then a=${d%/*}; while [ -n "$a" ] && ! timeout 5 test -e "$a"
      do a=${a%/*}; done; w="(path missing under ${a:-/})"
    elif [ $r -ne 0 ]; then w='(path not readable)'; fi ;; esac
  printf '%s%s\n' "$1" "$w"; done; }
for f in /etc/crontab /etc/cron.d/* /usr/local/etc/cron.d/*; do
  grep -v '^[[:space:]]*#' "$f" 2>/dev/null | grep -iE "$KW" \
    | grep -oiE "$KW|$PA" | ex "$f:"
done | sort | uniq -c
crontab -l -u root 2>/dev/null | grep -v '^[[:space:]]*#' \
  | grep -iE "$KW" | grep -oiE "$KW|$PA" | ex | sort | uniq -c
# periodic settings count only when their last value, the local
# file's where it sets one, is YES
cat /etc/periodic.conf /etc/periodic.conf.local 2>/dev/null \
  | grep -iE '^[[:space:]]*[a-z0-9_]*(backup|snapshot)[a-z0-9_]*=' \
  | awk -F= '{ sub(/^[[:space:]]+/, "", $1); v[$1] = $2 }
      END { for (k in v) if (tolower(v[k]) ~ /^["\047]?yes/) print k }' \
  | grep -oiE 'backup|snapshot' | sort | uniq -c
P='zrepl|sanoid|bacula|bareos'; <Enabled services listing> | grep -iE "$P"
# root's crontab needs root: as a normal user, sudo -n crontab …

# ZFS snapshots, newest last
test -e /dev/zfs && zfs list -H -t snapshot -o name,creation -s creation \
  2>/dev/null | tail -3
```

`<Enabled services listing>` is the loaded OS file's Service
Manager → Enabled services, with `P` set first.

**Recent-run evidence:** the creation date of the
newest snapshot, the mtimes of backup logs and repo
directories, which the cron lines name. `zrepl status` and a sanoid/syncoid log
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
