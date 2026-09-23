# Changing How Files Are Named or Where They Live

Retention settings, rotation schemes, backup suffixes
and directory moves all change *strings that other
code matches on*. The change itself is visible and
usually tested; the breakage it causes elsewhere is
silent. Two mandatory steps.

## 1. Find every consumer that matches by pattern

Before applying a naming or location change, search
the host for code that identifies those files by
pattern rather than by name:

```
grep -rn '<old-path-or-stem>' /etc /usr/local \
  /root /home/*/bin 2>/dev/null
```

Check at least: cleanup and deletion scripts, cron
jobs and systemd units, log shippers and parsers,
backup include/exclude lists, `find` invocations, and
monitoring checks. For each hit, ask whether its glob
or regex still matches after the change.

A deletion that no longer matches is the dangerous
case, because nothing fails: the command exits 0,
having deleted nothing, and the data it was supposed
to remove stays on disk under the new retention — the
longer retention you just configured. A cleanup
script written for numbered rotations
(`rm -f "$LOG" "$LOG".*`) silently stops covering
date-stamped ones (`app.log-20260731.gz` — hyphen,
not dot) the moment `dateext` is switched on.

Match the *thing*, not one spelling of it. Widen the
consumer's pattern in the same change that alters the
naming, never as a follow-up. Where the consumer
handles sensitive data, confirm afterwards that no
file survives under either spelling.

## 2. Dry-run any bulk rename, with collision checks

Never rename or move files in bulk in one pass. First
produce the full old→new list, count collisions, and
print it. Refuse to proceed while any collision
remains — a collision means the derivation rule is
wrong, not that one file is awkward.

Derive the new name from something authoritative, and
**verify the derivation against file content, not
just metadata**. Timestamps are suggestive, content is
proof: open the first and last record of a sample and
confirm they fall where the new name claims. Deriving
a log's date from mtime alone breaks on sparsely
written files, where mtime may sit either side of the
rotation window; the resulting duplicates are how you
find out the rule was wrong.

Write the mapping to `$BACKUP_DIR` (`rules/backups.md`) as
`<scheme>-rename-map-<timestamp>.txt` (new TAB old) so
the rename can be replayed backwards, and use
`mv -n` so an unforeseen collision cannot overwrite.

## 3. Deleting the subject also deletes its housekeeping

The mirror image of a glob that stopped matching: the
glob is fine, but the thing that *drives* it is gone.
Rotation and retention are almost always applied by a
loop over the live objects — databases, vhosts, units,
mailboxes — so removing an object silently orphans
whatever that loop used to prune for it. Its old files
then sit on disk forever under a retention that no
longer runs.

`autopostgresqlbackup` is the concrete case:
`db_purge` is called *inside* `for db in ${DBNAMES}`,
and with `DBNAMES="all"` that list comes from
`db_list`, i.e. the databases that exist right now.
Drop a database and its `daily/<db>/` and `weekly/<db>/`
directories are never visited again — 159 MB of dumps
that will outlive every retention setting, plus the
copies already pulled to the cross-backup hosts.

So when decommissioning anything: after the removal,
look for per-object directories, per-object config
fragments and per-object state that the tool creates
automatically, and decide explicitly whether they go
or stay. Never tell the user that leftovers "will
expire on their own" without checking that the pruning
loop still reaches them — read the tool's loop, don't
assume the retention is global.

## 4. Say what the retention now costs

When retention grows, state the measured volume per
day and the resulting total, and check it against free
space — measure from files already on disk, never
estimate. Two consequences deserve their own mention
to the user because they are easy to miss:

- **File count.** Daily rotation over years produces
  thousands of files per directory.
- **Personal data.** Web server access logs hold full
  client IP addresses. Extending retention extends how
  long those are kept, which is a data protection
  question, not a disk space one. Raise it; offer
  truncation at rotation time; let the user decide.

## 5. Renaming scripts, units and cron files

A cron file calls that script tonight: a rename that
misses one caller breaks the job silently, and the
failure surfaces weeks later as a missing backup.
§ 1 and § 2 apply in full; this is what a rename of
a script, unit, cron file or config directory adds.

Never renamed, whatever it is called: SSH
configuration and key material (`AGENTS.md` →
Critical Safety Rules), a file a configuration
management tool owns — that tool renames it or
nothing does (`rules/config-management.md`) — and
user accounts and groups, which own files, homes and
sudo rules far beyond one script.

**Search for the name, not only the paths you know.**
A sourcing script, a logrotate stanza or a backup
include list finds the file by a path nobody wrote
down, and a symlink or a runlevel link finds it by
a target that no content search reads. As root or
through `sudo -n`, in one call
(`rules/ssh-connections.md` → Bundle commands):

```
roots=""; plists=""
for d in /etc /usr/local/bin /usr/local/sbin /usr/local/etc \
  /usr/local/lib/systemd /opt /root /var/spool/cron \
  /var/cron/tabs /var/at/tabs /home/*/bin /home/*/.config \
  /Users/*/bin; do
  [ -d "$d" ] && roots="$roots $d"
done
for d in /Library/LaunchDaemons /Library/LaunchAgents \
  /Users/*/Library/LaunchAgents; do
  [ -d "$d" ] && plists="$plists $d"
done
echo "##roots$roots$plists"
echo "##content"; grep -rIl '<old-stem>' $roots; echo "##rc $?"
if [ -n "$plists" ]; then
  echo "##plists"; grep -rl '<old-stem>' $plists; echo "##rc $?"
fi
echo "##links"; find $roots $plists -type l -exec ls -l {} + \
  | grep '<old-stem>'; echo "##rc $?"
```

Only directories that exist reach `grep` and `find`
— a pattern that matches nothing stays as it is and
fails the `[ -d ]` test — so a path a host lacks
costs nothing, and neither command's errors are
hidden. Read each `##rc`: `0` found something, `1`
found nothing, anything else means a part was not
searched — say which, and rename nothing until it
has been. The launchd directories are searched
without `-I`: launchd reads binary plists too, and
`-I` would skip them.

The spool directories hold every user's crontab:
`/var/spool/cron/` with its `crontabs/` (Debian,
Ubuntu) and `tabs/` (SUSE) subdirectories, the
directory itself on RHEL and Fedora,
`/var/cron/tabs/` on FreeBSD, `/var/at/tabs/` on
macOS; Alpine's `/etc/crontabs/` is under `/etc`.
The launchd directories are macOS's
(`rules/os/macos.md` → Service Manager). Add the
scheduler's own places where `rules/os/<family>.md`
names more, such as FreeBSD's `periodic.conf`.
BusyBox `grep` has no `--exclude-dir` and BusyBox
`find` no `-lname`, which is why the search excludes
nothing and lists links through `ls -l`. `grep -r`
does not follow a link, so a link — in a user's
`bin`, or a plist linked into `LaunchAgents` — is
found only by the `find`.

`-l` prints file names only. Read the hits that can
be consumers, in one call. Never read a hit in key
material, a file `rules/secrets.md` names, a config
backup or a scratch directory — none of them runs
anything; the name is enough.

A reference that must not be rewritten keeps the
name it points at: a `command=` in an
`authorized_keys` file, a `ForceCommand` in sshd's
configuration, a line a configuration management
tool writes. Say which artifact stays and why before
touching the rest. Renaming it anyway breaks
whatever logs in through that key.

Then read each script being renamed for names it
derives from itself — `$0`, `basename`, a variable
holding the old stem — which move a lock file, a log
file or a journal tag without any reference saying
so.

A consumer can live on another host: a backup server
that pulls the dump directory, a monitoring check.
Search `memory/` on the workstation for each old
path. A hit elsewhere is part of the same change,
with that host's own question, or the rename waits.

**Pick the moment.** Nothing being renamed may run
meanwhile: the job is not active
(`systemctl is-active`) and its next run is not
minutes away. `pgrep -f` matches the shell SSH starts
for the probe, whose command line carries the same
name; bracket one letter so the pattern does not
match itself (`pgrep -f '[b]ackup.sh'`). Renaming a
service that runs all the time stops and starts it,
so ask as for a restart (`rules/service-reload.md`).

**Rename, then rewrite the references.** `mv -n`
each path from the § 2 map, and back up every file
whose content will change (`rules/backups.md`). In
every file the search found, replace each old path
and unit name as a whole string: the unit's
`ExecStart`, the cron line, the logrotate stanza, the
script that sources the config, and each symlink,
re-pointed. A user's crontab is rewritten through
`crontab -u <user>`, never by editing the spool file,
which cron may not reread. A comment that merely
mentions the old name stays.

A systemd unit comes back in the state it had, never
in a better one: a timer someone disabled on purpose
stays disabled, so the rename cannot start a job
that was meant to be dormant. Read both states of
each unit first, disable it before its file moves so
its `.wants/` links go, and restore exactly those
states under the new name. A masked unit is not
renamed at all: its file is a link to `/dev/null`,
and the mask is a decision someone made. A drop-in
directory (`<old>.service.d/`) moves with the unit.
A timer starts the service of its own name unless it
says `Unit=`, so a pair is renamed together, and each
of the two keeps its own states: a service can be
enabled into a target of its own besides being
started by the timer. A service without a timer is
handled the same way, and one that runs all the time
is stopped here too — the restart asked for above.
For a timer pair, both units in every command:

```
systemctl is-enabled <old>.timer <old>.service
systemctl is-active <old>.timer <old>.service
systemctl stop <old>.timer <old>.service
systemctl disable <old>.timer <old>.service
mv -n /etc/systemd/system/<old>.timer \
  /etc/systemd/system/<new>.timer
mv -n /etc/systemd/system/<old>.service \
  /etc/systemd/system/<new>.service
systemctl daemon-reload
```

Then `systemctl enable` each new unit whose old one
said `enabled`, and `systemctl start` each one that
said `active`; `static` and `disabled` get no
`enable`. OpenRC's runlevel links are restored the
same way: `rc-update del`, then `rc-update add` into
the runlevels `rc-update show` listed before
(`rules/os/alpine.md`).

A launchd job keeps its states too. launchd goes on
running the definition it loaded, whatever happens to
the file, so moving and rewriting a plist is not
enough. With the commands and the domain from
`rules/os/macos.md` → Service Manager: read whether
the job is loaded and whether it is disabled, unload
it from the old plist before the file moves, and
load the renamed plist only if it was loaded. The
`Label` changes with the name, and launchd records a
disabled job by its label, so a job that was disabled
is disabled again under the new one.

**Verify, in one call.** The changed files and the
renamed paths hold no old name except those left on
purpose; each changed script passes its shell's `-n`;
`systemd-analyze verify` accepts each renamed unit;
each unit and launchd job is back in the states read
before, and a timer that was active shows its next
run under the new name in `systemctl list-timers`, as
a cron job does in its crontab; a launchd job that
was loaded is found under its new label; the old
unit is gone from `systemctl list-unit-files`.
Report it in one line.
When a check fails, say which, and offer the way
back: the § 2 map replayed backwards, the backups
restored.

**The first run is the proof,** and it comes after
the session. For every job that will run, leave an
item in the host's `todo.md`
(`rules/server-memory.md` → Session to-do list) with
the job and when it next runs; a unit left disabled
gets none:

```markdown
- [ ] First run of db-dump.timer after rename, due 2026-09-21 03:00
```

The connection that finds it due reads the run — the
unit's result (`systemctl status`, `journalctl -u`
since the rename), cron's line in the system log, the
job's own log — and ticks the item when it
succeeded. A failure, or a complaint about a path
that no longer exists, is reported with the map and
the fix offered: the missed reference rewritten, or
the way back. Both are changes and are asked.
