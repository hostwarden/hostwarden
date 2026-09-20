# Adopting What heinzel Left Behind

Read this when `rules/heinzel-legacy.md` found
something on a host. Moving files on a live server is
a change, not a read, so all of it ends in a
question.

## Report, then ask

One line per find — path, file count, age of the
oldest entry:

```
heinzel state on this host:
  /var/backups/heinzel/ — 24 files, oldest 61 days
Adopt into /var/backups/hostwarden/, or leave it?
```

Three answers:

1. **Adopt** — move the files, keep the content.
2. **Leave** — nothing moves; hostwarden keeps
   reading the old paths (`rules/backups.md`).
3. **Later** — record a dated deferral (below) so
   the question comes back on request, not on every
   connection.

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

## Not while heinzel is still in use

If the activity check shows heinzel entries from the
last days, or the user says both tools are in use,
adoption is premature — heinzel recreates its backup
directory on its next run. Report the find, say why
it waits, and record a deferral.

Point the user at `contrib/heinzel-coexistence/`:
three rule overrides for their heinzel checkout that
make it read both journal tags, treat its memory as a
lead, and leave hostwarden's files alone.

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

## An improvised script keeps its name

Adopting a script, unit, cron file or config
directory means recording it, not renaming it. A
cron file calls that script tonight; renaming it
breaks the job silently, and the failure surfaces
weeks later as a missing backup.

Rename only if the user asks, and then under
`rules/file-naming-changes.md` in full — every
consumer found first and fixed in the same change. A
rename whose callers were not enumerated is not
offered.

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
- heinzel legacy: left in place (/var/backups/heinzel/)
- heinzel legacy: deferred 2026-09-20 (heinzel still in use)
- heinzel legacy: deferred 2026-09-20 (privileged paths unread)
```

The first two settle it and the check does not run
again. A deferral does not: while that line reads
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
```

## On the workstation (local mode)

The local machine may carry scheduled runs from
heinzel — a crontab line, a systemd timer, a
`heinzel-housekeeping.service`, `~/heinzel-cron.log`,
a lock in `/tmp` — pointing at `bin/heinzel-*`
scripts that a hostwarden clone does not have
(the `hostwarden-housekeeping` skill, scheduled). They fail
silently: nobody gets the report they believe they
are getting.

Report what points at the old paths and offer to fix
it. A crontab or unit file is standing configuration,
so each edit needs its own approval. Key material
under `~/heinzel-keys/` is reported, never touched,
moved or re-permissioned (`CLAUDE.md` → Absolute
taboos).
