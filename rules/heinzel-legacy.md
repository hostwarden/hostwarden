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

That is what heinzel's own rules prescribe. It is
not what a host actually carries.

## What sessions improvised

heinzel sessions wrote scripts, config files, units
and cron jobs under names they invented on the spot.
They differ per host, they are not in any rule, and
some of them do real work every night. Typical
shapes:

- a script in `/usr/local/bin/`, `/opt/` or
  `/root/bin/`
- a config file or directory, often `/etc/heinzel/`
- a systemd unit or timer, a file in
  `/etc/cron.d/`, a crontab line, a FreeBSD periodic
  script, a launchd plist on macOS
- a log or dump directory the script writes to

The name is no guide: half of them say "heinzel",
half say "backup" or "cleanup". What identifies them
is that a heinzel session created them — and the
record of that is in the server's memory and
changelog, not on the host.

## Detect

**First, read the leads.** If
`memory/servers/<hostname>/heinzel-inventory.md`
exists, it lists what memory and changelog say this
host carries (written by the `hostwarden-adopt`
skill). Each entry is a lead, not a fact
(`rules/verify-before-reporting.md`): check whether
it is there, gone, or different.

**Then the fixed paths,** one read-only command
after OS detection:

```
ls -d /var/backups/heinzel ~/.heinzel-backups \
  /root/heinzel-scratch ~/heinzel-scratch \
  /etc/heinzel /opt/heinzel 2>/dev/null
```

**Then a bounded scan** of the places a session
would have put something, never the whole
filesystem:

```
ls -1 /etc/cron.d 2>/dev/null | grep -i heinzel
systemctl list-unit-files 2>/dev/null \
  | grep -i heinzel
crontab -l 2>/dev/null | grep -i heinzel
```

Use the OS's own equivalents where these do not
exist (`rules/freebsd.md`, `rules/macos.md`). A
hit here is a lead like any other.

Nothing listed, no inventory file, and no `heinzel`
entries in the activity check: record
`- heinzel legacy: none` in
`memory/servers/<hostname>/memory.md` and move on
without saying anything. Silence is the normal case
on a host heinzel never touched.

## What is not ours

A file with "heinzel" in its name that no session
created belongs to someone else — a colleague's
script, a customer's note. Being named after the
tool is not ownership. If neither the inventory nor
the changelog claims it, report it and leave it
alone.

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

## Adopting is not renaming

For the four fixed paths above, adopting means
moving them. For everything a session improvised,
adopting means **knowing about it and writing it
down** — not renaming it.

A script called `heinzel-backup.sh` that a cron file
invokes every night is not broken by the rename.
Renaming it breaks it, silently, and the failure
surfaces weeks later as a missing backup. The same
goes for a unit other units depend on, a config file
a script reads, a log directory a rotation config
names.

So the default is: keep the name, record the
ownership. Renaming happens only when the user asks
for it, and then it follows
`rules/file-naming-changes.md` in full — every
consumer found first, fixed in the same change,
verified afterwards. A rename whose callers were not
enumerated is not offered at all.

What always happens instead is that each confirmed
artifact goes into the host's memory, with its path,
what it does and when it runs. An improvised script
nobody remembers is the real risk here, not its
name.

## Adopt the fixed paths

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

Confirmed artifacts go into memory as facts of this
host, in its own words — what it is, where it is,
when it runs:

```markdown
- Backup script: /usr/local/bin/heinzel-backup.sh,
  nightly 03:00 via /etc/cron.d/heinzel-backup
```

Keep the old name in the path, because that is the
path. Leads the host did not confirm are struck from
`heinzel-inventory.md` with a one-line note; a
script memory claims and the host lacks usually
means somebody removed it on purpose. When every
lead is resolved, the inventory file is deleted and
the `heinzel legacy:` line carries the outcome.

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
