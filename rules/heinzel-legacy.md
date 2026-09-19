# Adopting State heinzel Left Behind

hostwarden grew out of
[heinzel](https://github.com/wintermeyer/heinzel).
A host administered with heinzel carries state under
the old name. hostwarden reads it, and — once, with
the user's approval — takes it over.

Run this **on the first connection to a host**, as
part of the first-connection pipeline. Never on
every connection: the answer is recorded in server
memory.

## What heinzel leaves on a host

- Journal entries tagged `heinzel` — the change
  history. Read, never migrated.
- `/var/backups/heinzel/` — config backups from
  privileged sessions. Offer to adopt.
- `~/.heinzel-backups/` — config backups from
  unprivileged mode. Offer to adopt.
- `/root/heinzel-scratch/`, `~/heinzel-scratch/` —
  probe output (`rules/secrets.md`). Offer to adopt.

Nothing else on a host belongs to heinzel. A file
that merely has "heinzel" in its name elsewhere is
someone else's — a customer's script, a user's note.
Never rename or move it, and never search the whole
filesystem for the word. This rule touches the four
paths above and nothing else.

## Detect

One read-only command, after OS detection:

```
ls -d /var/backups/heinzel ~/.heinzel-backups \
  /root/heinzel-scratch ~/heinzel-scratch \
  2>/dev/null
```

Nothing listed and no `heinzel` entries in the
activity check: record `- heinzel legacy: none` in
`memory/servers/<hostname>/memory.md` and move on
without saying anything. Silence is the normal case
on a host heinzel never touched.

## Report and ask

Anything found is reported in one line per path,
with the file count and the age of the oldest entry:

```
heinzel state on this host:
  /var/backups/heinzel/ — 24 files, oldest 61 days
Adopt into /var/backups/hostwarden/, or leave it?
```

Then ask. Moving files on a live production server
is a change, not a read, so it needs the user's word
— and the retention consequence below means the user
has something real to decide.

Offer three answers:

1. **Adopt** — move the files, keep the content.
2. **Leave** — nothing moves. hostwarden keeps
   reading the old paths (`rules/backups.md`).
3. **Ask again later** — record nothing and ask on
   the next first connection.

## The retention consequence — say it before asking

Config backups are cleaned by age:

```
find "$BACKUP_DIR" -type f -mtime +30 -delete
```

That `find` only ever runs in hostwarden's own
directory, so backups left in heinzel's directory
are never cleaned and grow forever. That is the
reason to adopt.

But `mv` preserves mtime. A backup older than the
retention window moves into a directory that *is*
cleaned, and the next cleanup deletes it. Name the
number before the user decides:

```
24 files, 9 of them older than 30 days — those 9
will be deleted by the next cleanup. Adopt anyway?
```

If the user wants the old ones kept, adopt the rest
and leave those, or raise the retention window for
this host in `memory/servers/<hostname>/rules.md`.
Do not silently move files that the next cleanup
eats.

## Adopt

Never overwrite. `mv -n` keeps a same-named file at
the destination, and what stays behind gets
reported rather than forced:

```
mkdir -p /var/backups/hostwarden
mv -n /var/backups/heinzel/* /var/backups/hostwarden/ 2>/dev/null
rmdir /var/backups/heinzel 2>/dev/null || \
  ls -1 /var/backups/heinzel
```

`rmdir` removes the old directory only when it is
empty; a non-empty one is listed instead of forced,
and those leftovers are reported to the user. The
same pattern applies to `~/.heinzel-backups/` →
`~/.hostwarden-backups/` and to the scratch
directories.

Scratch directories hold probe output, which may
contain secrets (`rules/secrets.md`). Move the
directory, never read its contents into the
conversation, and offer to shred the files if the
user wants them gone.

Verify after the move: the destination holds the
expected file count, and the source is gone or
listed as leftover. Report the result in one line.

## Record

In `memory/servers/<hostname>/memory.md`:

```markdown
- heinzel legacy: adopted 2026-09-20 (24 backups, 0 left)
```

or `- heinzel legacy: left in place (/var/backups/heinzel/)`
or `- heinzel legacy: none`.

A recorded line means the check does not run again.
"Left in place" is a decision, not a to-do: don't
re-ask on every connection. The user can ask for
adoption at any time.

Log the change like any other
(`rules/changelog.md`):

```
logger -t hostwarden "Adopted heinzel state: \
  /var/backups/heinzel -> /var/backups/hostwarden \
  (24 files)"
```

## The journal stays as it is

Journal entries tagged `heinzel` are history, and
history is not rewritten. `rules/activity-check.md`
reads both tags, so earlier work stays visible.
hostwarden writes only its own tag.

## On the workstation (local mode)

The local machine may carry scheduled runs from
heinzel — a crontab line, a systemd timer, a
`heinzel-housekeeping.service`, a log at
`~/heinzel-cron.log`, a lock in `/tmp` — all
pointing at `bin/heinzel-*` scripts that no longer
exist under that name in a hostwarden clone
(`rules/scheduled-housekeeping.md`). A broken
scheduled run fails silently: nobody gets the
report they think they are getting.

Report what points at the old paths and offer to
fix it. Editing a crontab or a unit file changes
standing configuration, so it needs explicit
approval each time — never rewrite one in passing.
Key material under `~/heinzel-keys/` is never
touched, moved, or re-permissioned
(`CLAUDE.md` → Absolute taboos); report the path
and let the user move it.
