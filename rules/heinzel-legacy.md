# Finding State Heinzel Left Behind

Hostwarden grew out of
[Heinzel](https://github.com/wintermeyer/heinzel).
A host that Heinzel administered carries state under
the old name.

This file is the detection half, run **on the first
connection to a host**. On a hit, read
`rules/heinzel-adoption.md` for what to do with what
was found. No hit, no second file, nothing recorded,
nothing said — that is the normal case.

## When this ends

The transition is over once no host memory carries a
`heinzel legacy:` line, no `heinzel-inventory.md` is
left, and `memory/user.md` has neither an
`Adopted from heinzel:` nor a
`Heinzel names on hosts:` line. At that point delete
this file and `rules/heinzel-adoption.md`, drop step
8 from `rules/first-connection.md`, the `heinzel` tag
from `rules/activity-check.md`, the old backup paths
from `rules/backups.md`, the `heinzel-*` rename loop in
`bin/hostwarden-migrate`, and the `hostwarden-adopt`
skill, together with what names Heinzel's
checkout or `heinzel-memory.md` in
`rules/hypervisors.md` → Registering Guests,
`rules/dns-aliases.md` and `rules/first-connection.md`
step 6. Written down here because a transition nobody
ends becomes permanent by default.

**Not the `MAP` table in that script.** Those rows move
overrides whose topic changed address in a Hostwarden
release, which has nothing to do with Heinzel and
everything to do with how far behind a given installation
is. One clean checkout says nothing about the next user to
upgrade. Rows come out at a release boundary that states
which versions can still upgrade directly, not when this
machine stops seeing Heinzel.

## What to look for

Heinzel's own rules prescribe four things:

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
What identifies them is that a Heinzel session
created them, and that record is in the server's
memory and changelog, not on the host.

## Detect

**Read the leads first.**
`memory/servers/<hostname>/heinzel-inventory.md`, if
it exists, holds what memory and changelog say this
host carries; the `hostwarden-adopt` skill writes it
when a Heinzel installation is taken over. Every
entry is a lead, not a fact
(`rules/verify-before-reporting.md`), except those
under `## Facts`: they are no artifacts to probe for,
and `rules/heinzel-adoption.md` → Heinzel's memory
takes them.

**Then probe the host in one call,** in the activity
check's call where possible
(`rules/activity-check.md` → What rides in this
call):

```
echo "##paths"; ls -d /var/backups/heinzel \
  ~/.heinzel-backups ~/heinzel-scratch \
  /root/heinzel-scratch /etc/heinzel /opt/heinzel \
  2>/dev/null || true
echo "##cron"; { ls -1 /etc/cron.d 2>/dev/null \
  | grep -i heinzel; crontab -l 2>/dev/null \
  | grep -i heinzel; } || true
echo "##units"; systemctl list-unit-files 2>/dev/null \
  | grep -i heinzel || true
```

The inventory's leads join the same call: each path
it names on the `##paths` line, each unit under
`##units`, each cron file or crontab line under
`##cron`. A lead is text from memory, never shell or
an option: each goes in as one single-quoted argument
after `--` (`ls -d -- '<path>'`,
`systemctl list-unit-files --no-legend -- '<unit>'`,
`grep -F -e '<cron text>'`), and one that holds a
single quote or a newline is not probed but
reported as open. A unit lead is an exact unit name:
one with a character other than letters, digits and
`:_.@-`, or starting with `-`, is reported as open
too — `systemctl` reads `*` and `?` as a pattern and
would confirm units the lead never meant. A lead that names no path is
looked for by what its record does name — the
schedule, the command, the directory it writes to —
and stays open when nothing matches: report it, and
record it as `rules/heinzel-adoption.md` → Record
says.

Every search ends in `|| true`: `ls` and `grep`
report "nothing found" with a non-zero status, and on
a clean host — the normal case — that would mark the
whole probe as a failed command and send the session
looking for an SSH problem that is not there.

Split the output on the markers. Use the OS's own
equivalents where these commands do not exist
(`rules/os/freebsd.md`, `rules/os/macos.md`).

`/root/heinzel-scratch` and `/var/backups/heinzel`
are usually unreadable as an ordinary user, and
`2>/dev/null` makes "permission denied" look exactly
like "not there". As a non-root user, run the paths
line through `sudo -n` if sudo is available
(`rules/privilege-escalation.md`).

If it is not available, the privileged half of the
check did not run. Say so and record

```markdown
- heinzel legacy: deferred 2026-09-20 (privileged paths unread)
```

A deferral is the one outcome that keeps the check
eligible on later connections
(`rules/heinzel-adoption.md` → Record), so the next
session that does have root actually looks. Recording
nothing would not: the check is otherwise
first-connection only.

Nothing found, no inventory file, no `heinzel`
entries in the activity check, and nothing left
unread: say nothing, record nothing, continue. The
check runs on the first connection, and after that
only while the host's memory carries a
`heinzel legacy: deferred` line or an unresolved
`heinzel-inventory.md`, and whenever the user asks
for it, whatever the line says.

On a deferred host the probe runs but the question
does not come back by itself. Check the deferral's
reason against what is true now, and stay silent
unless it changed:

- `heinzel still in use` — the activity check no
  longer shows Heinzel entries.
- `privileged paths unread` — this session can read
  them, through sudo or as root.
- `answered at registration: …` — this session may
  change the guest: it is not a registration, and the
  guest is not read-only, which through its host
  includes the host's entry
  (`rules/first-connection.md` → Via-host mode,
  `rules/heinzel-adoption.md` → A host and its
  guests).
- `answered at onboarding: …` — this session is not
  an adoption's onboarding, which asks it again itself
  once its report is out (`hostwarden-adopt`).
- any reason — the user asks, or the recorded date is
  more than 90 days old.

None of those: say nothing, leave the line as it is,
carry on. Re-offering an unchanged answer on every
connection is what the deferral exists to prevent.

## What is not ours

A file with "heinzel" in its name that no session
created belongs to someone else — a colleague's
script, a customer's note. Being named after the
tool is not ownership. If neither the inventory nor
the changelog claims it, report it and leave it.

## On a hit

Read `rules/heinzel-adoption.md`. It covers the
report, the question, moving the fixed paths,
giving what a session created Hostwarden's name when
the user chooses it, and what gets recorded in
server memory.
