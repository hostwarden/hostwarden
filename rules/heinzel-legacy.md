# Finding State heinzel Left Behind

hostwarden grew out of
[heinzel](https://github.com/wintermeyer/heinzel).
A host that heinzel administered carries state under
the old name.

This file is the detection half, run **on the first
connection to a host**. On a hit, read
`rules/heinzel-adoption.md` for what to do with what
was found. No hit, no second file, nothing recorded,
nothing said — that is the normal case.

## What to look for

heinzel's own rules prescribe four things:

- journal entries tagged `heinzel` — history, read
  by `rules/activity-check.md`, never migrated
- `/var/backups/heinzel/` — config backups
- `~/.heinzel-backups/` — config backups from
  unprivileged mode
- `/root/heinzel-scratch/`, `~/heinzel-scratch/` —
  probe output (`rules/secrets.md`)

Sessions improvised the rest: a script in
`/usr/local/bin/`, `/opt/` or `/root/bin/`, a
directory like `/etc/heinzel/`, a systemd unit or
timer, a `/etc/cron.d/` file, a crontab line, a
FreeBSD periodic script, a launchd plist, a log or
dump directory. Those differ per host and the name
is no guide — half say "heinzel", half say "backup".
What identifies them is that a heinzel session
created them, and that record is in the server's
memory and changelog, not on the host.

## Detect

**Read the leads first.**
`memory/servers/<hostname>/heinzel-inventory.md`, if
it exists, holds what memory and changelog say this
host carries; the `hostwarden-adopt` skill writes it
when a heinzel installation is taken over. Every
entry is a lead, not a fact
(`rules/verify-before-reporting.md`).

**Then probe the host in one call,** batched into
the OS-detection call where possible
(`rules/ssh-connections.md` — one call per logical
step):

```
echo "##paths"; ls -d /var/backups/heinzel \
  ~/.heinzel-backups ~/heinzel-scratch \
  /root/heinzel-scratch /etc/heinzel 2>/dev/null
echo "##cron"; ls -1 /etc/cron.d 2>/dev/null \
  | grep -i heinzel; crontab -l 2>/dev/null \
  | grep -i heinzel
echo "##units"; systemctl list-unit-files 2>/dev/null \
  | grep -i heinzel
```

Split the output on the markers. Use the OS's own
equivalents where these commands do not exist
(`rules/freebsd.md`, `rules/macos.md`).

`/root/heinzel-scratch` and `/var/backups/heinzel`
are usually unreadable as an ordinary user, and
`2>/dev/null` makes "permission denied" look exactly
like "not there". As a non-root user, run the paths
line through `sudo -n` if sudo is available
(`rules/privilege-escalation.md`); if it is not, the
privileged half of the check did not run — say so,
and record nothing, so a later privileged session
still looks.

Nothing found, no inventory file, no `heinzel`
entries in the activity check, and nothing left
unread: say nothing, record nothing, continue. The
check is first-connection only — plus any connection
to a host whose memory carries a
`heinzel legacy: deferred` line — so it does not come
back on its own.

## What is not ours

A file with "heinzel" in its name that no session
created belongs to someone else — a colleague's
script, a customer's note. Being named after the
tool is not ownership. If neither the inventory nor
the changelog claims it, report it and leave it.

## On a hit

Read `rules/heinzel-adoption.md`. It covers the
report, the question, moving the fixed paths, why an
improvised script keeps its name, and what gets
recorded in server memory.
