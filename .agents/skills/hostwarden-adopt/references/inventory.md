# Building the Per-Host Inventory

What to collect from `memory/servers/<host>/heinzel-memory.md` —
Heinzel's `memory.md` as adopted — and `changelog.log`, and how to
write it down.

## What counts as a lead

Anything a Heinzel session created, configured or scheduled on that
host, whether or not its name says "heinzel". The shapes are listed in
`rules/heinzel-legacy.md` § "What to look for" — the same list the
first connection scans for, so that the collect side and the detect
side cannot drift apart.

A changelog line like "Created backup script, nightly at 03:00" is a
lead even when it names no path. Write it down with the path unknown;
the host connection resolves it.

## What is not a lead

- Packages installed from the distro's repositories. They are
  managed by the package manager, not by Heinzel.
- Settings changed inside a file that already existed — `sshd_config`,
  `nginx.conf`, a sysctl value. Those are the host's own files. Note
  them only if the changelog says Heinzel added a drop-in file of its
  own.
- Anything the user or a colleague made that a session merely looked
  at. If the changelog does not say a session created it, it is not
  ours.

## File format

`memory/servers/<host>/heinzel-inventory.md`, one lead per line,
grouped by kind. Keep the changelog's own words — they carry the
reason, which no path does:

```markdown
# heinzel leads on web1.example.com

Collected from memory and changelog on 2026-09-20 by
hostwarden-adopt. Not verified against the host.

## Scripts
- /usr/local/bin/heinzel-backup.sh — nightly pg_dump,
  changelog 2026-03-11 "Created backup script, 03:00 via cron"
- path unknown — changelog 2026-05-02 "Added log cleanup script"

## Scheduled
- /etc/cron.d/heinzel-backup — 03:00 daily, calls the script above

## Config
- /etc/heinzel/backup.conf — retention 14 days

## Accounts
- deploy — created 2026-04-01 for the CI deployment

## Facts
- Maintenance window Sunday 02:00–04:00, from Heinzel's
  auto-memory (maintenance-windows.md, 2026-08-17)
- Planned: move the database to db2 (user, 2026-08-20)
```

`## Facts` holds what the adoption sorted out of Heinzel's other
memory for this host (the skill's step 4): facts, decisions and open
plans, not leads. Each keeps its source file and date. The Heinzel
check does not probe for them; the first connection writes them into
`memory.md` and removes the section (`rules/heinzel-adoption.md` →
Heinzel's memory).

## Verification is the host's job

The inventory is a worklist, never a fact. The first connection checks
each lead against the host (`rules/heinzel-legacy.md` → Detect),
moves what is confirmed into the host's `memory.md`
(`rules/heinzel-adoption.md` → Record), and deletes the file once it
is empty.
