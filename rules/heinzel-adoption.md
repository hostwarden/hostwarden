# Adopting What Heinzel Left Behind

Read this when `rules/heinzel-legacy.md` found
something on a host. Moving files on a live server is
a change, not a read, so all of it ends in a
question.

## Report, then ask

One line per find. For a directory of backups or
scratch output: path, file count, age of the oldest
entry. For a script, unit, cron file or config
directory a session created: path, and what calls it
as far as the inventory and the probe show:

```
heinzel state on this host:
  /var/backups/heinzel/ — 24 files, oldest 61 days
  /usr/local/bin/heinzel-backup.sh — called by
    /etc/cron.d/heinzel-backup, 03:00 daily
```

Four answers:

1. **Adopt and rename** — move Heinzel's fixed paths
   (below) and give every artifact whose name says
   `heinzel` its Hostwarden name, with every
   reference to it (§ Rename to Hostwarden's name).
2. **Adopt, keep the names** — move the fixed paths;
   scripts, units, cron files and config directories
   keep their names and are recorded as they are.
3. **Leave** — nothing moves; Hostwarden keeps
   reading the old paths (`rules/backups.md`).
4. **Later** — record a dated deferral (below) so
   the question comes back on request, not on every
   connection.

When only fixed paths turned up, the first two are
the same answer: offer three. Before offering the
rename, say in one line how many names change, that
every reference to them is searched for and
rewritten first, and that a job that still points at
an old name would fail on its next run, which the
next connection checks.

`memory/user.md` may carry the user's answer from the
takeover (`hostwarden-adopt` skill):
`Heinzel names on hosts: rename` makes answer 1 the
recommended one, `keep` answer 2; without the line,
neither is. Ask all the same: every host is its own
change.

Before asking about config backups, say how many are
past the retention window: `mv` keeps mtime, so those
are deleted by the next cleanup
(`rules/backups.md` → Moving a backup into
`$BACKUP_DIR`).

```
24 files, 9 of them older than 30 days — those 9
will be deleted by the next cleanup. Adopt anyway?
```

Use the retention window that is actually configured
for this host, not the default. If the user wants the
old ones kept, adopt the rest and leave those, or
raise the window in
`memory/servers/<hostname>/rules.md`.

## Not while Heinzel is still in use

If the user says both tools are in use, adoption is
premature — Heinzel recreates its backup directory on
its next run. Report the find, say why it waits, and
record a deferral. Recent Heinzel entries in the
activity check do not settle it: hosts often move over
right after their last Heinzel session, so ask whether
Heinzel still runs before deferring.

Point the user at `contrib/heinzel-coexistence/`:
three rule overrides for their Heinzel checkout that
make it read both journal tags, treat its memory as a
lead, and leave Hostwarden's files alone.

## A host and its guests

When a hypervisor host registers its guests in the
same session, the host's finds and every registered
guest's make one report and one question, asked where
`rules/hypervisors.md` → Registering Guests places
it. A machine without finds is not listed:

```
heinzel state on pve1.example.com and 3 of its guests:
  pve1.example.com:
    /var/backups/heinzel/ — 24 files, oldest 61 days
  web1.example.com:
    /var/backups/heinzel/ — 6 files, oldest 12 days
  db1.example.com:
    /root/heinzel-scratch/ — 2 files, oldest 40 days
  app1.example.com:
    heinzel entries in the journal, last 3 days ago
```

One answer covers every machine listed, or the user
answers per machine, as in `rules/hypervisors.md` →
Stopped Guests; whether Heinzel still runs is asked
once the same way. Each machine's memory records its
own outcome line (Record, below).

Leaving and waiting are recorded in each machine
now. Adopting, with the names renamed or kept, runs
now on the host only: registration never changes a
guest, so a guest keeps that answer as a deferral
that says which of the two it was. Its next
connection that may change it asks again, for that
guest alone, with the recorded answer as the
recommended one:

```markdown
- heinzel legacy: deferred 2026-09-20 (answered at registration: adopt)
- heinzel legacy: deferred 2026-09-20 (answered at registration: rename)
```

## Move the fixed paths

Never overwrite. `mv -n` keeps a same-named file at
the destination, and leftovers are reported rather
than forced:

```
mkdir -p /var/backups/hostwarden
find /var/backups/heinzel -mindepth 1 -maxdepth 1 \
  -exec mv -n {} /var/backups/hostwarden/ \;
rmdir /var/backups/heinzel 2>/dev/null || \
  ls -1A /var/backups/heinzel
```

`find` rather than a `*` glob, and `ls -1A` rather
than `ls -1`: a backup of a dotfile is named
`.env.<timestamp>`, which a glob does not match and a
plain `ls` does not show — it would stay behind and
not even be reported. `rmdir` removes the old
directory only when it is empty. The same pattern
covers `~/.heinzel-backups/` →
`~/.hostwarden-backups/` and the scratch
directories. Scratch output may contain secrets: move
it, never read it into the conversation, and offer to
shred it (`rules/secrets.md`).

Verify afterwards — destination count, source gone or
listed as leftover — and report it in one line.

## Rename to Hostwarden's name

On answer 1, or when the user asks for it on a host
already settled. The rename follows
`rules/file-naming-changes.md` → Renaming scripts,
units and cron files, with `heinzel` as both the old
stem and the rename map's scheme.

The name part `heinzel` becomes `hostwarden` and
nothing else changes:
`/usr/local/bin/heinzel-backup.sh` →
`/usr/local/bin/hostwarden-backup.sh`,
`/etc/heinzel/` → `/etc/hostwarden/`,
`heinzel-backup.timer` → `hostwarden-backup.timer`.
An artifact whose name does not say `heinzel` keeps
it; there is no old name to shed. Also never renamed:
what neither the inventory nor the changelog claims
(`rules/heinzel-legacy.md` → What is not ours), and
journal history and changelog entries.

A script that logs with `logger -t heinzel` gets its
own name as the tag (`hostwarden-backup`), never the
bare `hostwarden`: the activity check reads that tag
as a session's work (`rules/activity-check.md`), and
a nightly job would pass for one.

Afterwards the host's memory names the new paths —
they are what is true now.

## Record

Confirmed artifacts become facts of this host in
`memory/servers/<hostname>/memory.md`, with the path
as it is:

```markdown
- Backup script: /usr/local/bin/heinzel-backup.sh,
  nightly 03:00 via /etc/cron.d/heinzel-backup
```

Then one line for the outcome of the check:

```markdown
- heinzel legacy: adopted 2026-09-20 (24 backups, 0 left)
- heinzel legacy: renamed 2026-09-20 (24 backups, 3 names)
- heinzel legacy: left in place (/var/backups/heinzel/)
- heinzel legacy: deferred 2026-09-20 (heinzel still in use)
- heinzel legacy: deferred 2026-09-20 (privileged paths unread)
```

The first three settle it and the check does not run
again; a renamed job's first run is followed up in
`todo.md` (`rules/file-naming-changes.md` →
Renaming scripts, units and cron files). A deferral
does not: while that line reads
`deferred`, the check runs on every connection — but
it only speaks up when the deferral's own reason has
changed. `rules/heinzel-legacy.md` lists those
conditions, and they are checked before any of the
report-and-ask flow above runs.

Note the reason in the line, as the examples do.
Without it there is nothing to re-check against, and
the question comes back every time.
Leads the host did not confirm move into the same
memory file as a one-line note when they matter (a
script memory claims and the host lacks usually means
somebody removed it on purpose); the inventory file
is a worklist and gets deleted once it is empty.

Log the change like any other (`rules/changelog.md`):

```
logger -t hostwarden "Adopted heinzel state: \
  /var/backups/heinzel -> /var/backups/hostwarden \
  (24 files)"
logger -t hostwarden "Renamed heinzel artifacts: \
  3 names, 2 references; map in \
  /var/backups/hostwarden/heinzel-rename-map-20260920-1412.txt"
```

## On the workstation (local mode)

The local machine may carry scheduled runs from
Heinzel — a crontab line, a systemd timer, a
`heinzel-housekeeping.service`, `~/heinzel-cron.log`,
a lock in `/tmp` — that change into the Heinzel
checkout and start `claude` there. Read the directory
each one changes into before reporting it. If that
checkout is gone, the job fails silently: nobody gets
the report they believe they are getting. If it is
still there, the job runs — on Heinzel's rules and
Heinzel's memory, not this clone's.

Report what points at the old checkout and offer to
point it at this one (the `hostwarden-housekeeping`
skill, scheduled). A crontab or unit file is standing
configuration, so each edit needs its own approval. Key material
under `~/heinzel-keys/` is reported, never touched,
moved or re-permissioned (`AGENTS.md` → Critical
Safety Rules).
