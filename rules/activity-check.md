# Activity Check

On **every** connection to a server (remote or
local), check for recent Hostwarden activity in the
system journal. This keeps the user informed about
changes made by other team members or previous
sessions.

## When to run

After reading the server memory file and before
starting any requested work. This applies to every
connection, not just the first of the day.

## How to check

Read both tags: `hostwarden`, and `heinzel` for entries
written before the rename. Heinzel is the project
Hostwarden grew out of, and its entries stay in the
journal of every server it touched. Write only
`hostwarden`.

Run the read-back from the loaded OS file's `## Logs`
section. Where it has none and systemd runs — every
Linux family but Alpine — read the journal:

```
journalctl -t hostwarden -t heinzel --since "7 days ago" \
  --no-pager -q
journalctl --no-pager -q -o short-iso | head -1
```

As a non-root user outside the `systemd-journal` /
`adm` groups, `journalctl` silently shows only the
user's own entries. When connected as non-root, run
both lines as `sudo -n journalctl …` first. If sudo
is unavailable, run the first line without `-q`,
watch for the "not seeing messages from other users"
hint, and tell the user the check may be incomplete.

Without a `## Logs` section and without systemd, tell
the user the check could not run.

If the command returns nothing — and it actually ran,
and nothing limited what it can see —
skip silently: no activity to report.

An empty result only means "no activity" when the
command succeeded. If it errored, was shadowed by a
shell alias, or you sent its stderr to `/dev/null`,
you have no result at all — tell the user the check
did not run, rather than reporting silence. A failed
check that reads as a clean host is how a concurrent
session's work goes unnoticed.

## How far back it reached

Every read-back prints, in the same call, the oldest
entry its source still holds: the journal's second
line above, and the equivalent line in each `## Logs`
section. Rotation, a size cap, a vacuum or a log
kept in RAM can each leave less than seven days
behind, and the oldest entry shows the reach
whichever of them applied. A note in a Logs section
about a RAM disk or `df /var/log` explains why the
reach is short; the oldest entry decides how short.

- **Older than seven days:** the read-back covered
  the whole window.
- **Inside the seven days:** an empty result covers
  only the time since that entry. Tell the user how
  far back the check reached, and read the local
  changelog for the time before it.
- **Nothing printed:** the source holds no entries
  this user may read, and the check did not run. Say
  so, as for any failed check, and read the local
  changelog for the whole seven days.

Syslog lines in the BSD format
(`Sep 22 14:32:07 host …`) carry no year. The
read-backs that print them also print `date`: take
the server's current year, or the year before where
that would put the entry in the future. An old entry
can then read as recent, which for the bound only
shortens the reach and costs a changelog read; a
recent one never reads as old. For a `heinzel` entry
it matters more, see below.

## A fresh Heinzel entry means a live session

An entry tagged `heinzel` from the last 15 minutes is
not history — a Heinzel session is probably working
on this host right now. Both tools administer the
same machines during a transition, and the journal is
the only signal they share.

Where the timestamp has no year, an entry from a year
ago looks just as fresh, and neither the entry nor
its file can tell the two apart. Report it as
possibly live, say that its year is unknown, and
handle it like a live one.

Say so before making any change, and let the user
decide whether to go ahead, wait, or do it in the
other tool. Read-only work needs no pause. Name the
tool when entries from both tags appear: "Installed
nginx" reads differently once the user knows which
session did it.

`contrib/heinzel-coexistence/` holds the overrides
that teach Heinzel the same thing from its side.
Another Hostwarden session that is changing the same
host shows up in the host's session register instead
(`rules/parallel-sessions.md`). Unless the OS file's
`## Logs` section says otherwise, read it in the same
call as the journal, with the server's own clock,
since entries carry the server's time:

```
if [ -e /tmp/hostwarden ]; then ls -1 /tmp/hostwarden
else echo "no register"; fi; date +%s
```

`no register` is normal; an error is a failed check,
like any other here. A live entry means a session is
changing the host right now. Mention it even when this
session only reads, so the user knows what an audit
may catch mid-change; registering is still only for
writers.

## Ansible runs

Ansible logs every module it runs on a host, whoever started it:
under the journal's own process name with the message
`ansible-<module> Invoked with …`, or under the identifier
`ansible-<module>` where it falls back to syslog. On a host with
systemd, read them in the same call as the journal, with the same
privileges:

```
{ journalctl --since "7 days ago" --no-pager -q -o short-iso 2>&1 \
    || echo "check failed: journalctl exit $?"; } \
  | sed -nE -e '/^check failed:/p' -e 's/^([^ ]+|[A-Z][a-z]{2} +[0-9]+ [0-9:]+) [^ ]+ ([^ ]+\[[0-9]+\]: )?(ansible-[A-Za-z0-9_.]+):? Invoked with .*/\1 \3/p' \
  | tail -n 50
```

Where the OS file's `## Logs` section reads a syslog file instead —
`/var/log/messages` on FreeBSD and Alpine — run the same `sed` over
that file. Elsewhere this read does not run; say so only when the
host's memory has a `Config management: ansible` line.

The `sed` keeps the time and the module name and drops the rest:
the arguments after `Invoked with` can carry values the module did
not mark secret (`rules/secrets.md`), so never print the raw lines.
A `check failed:` line is a failed check, like any other here.

Nothing is logged for a module with `no_log`, or where the run set
`no_target_syslog`, so silence is not proof that Ansible never ran.

Report runs as activity: how many module runs, first and last time,
and the last module. A run inside the last 15 minutes may still be
going on — treat it like a live Heinzel entry above before making a
change. Runs on a host whose memory has no `Config management:` line
send you to `rules/config-management.md`.

## What to show

If there are entries, show a brief summary to the
user:

```
Recent activity (last 7 days):
- [2026-04-12 14:32] [hostwarden] [alice as root]
  Installed nginx, opened port 443 — because static
  site launch
- [2026-04-11 09:15] [heinzel] [bob as bob] Updated
  Node.js 22.14 → 22.15
```

The heading is neutral and every line names its
journal tag. A host can carry entries from before the
rename and from a Heinzel session running right now,
and labelling either as Hostwarden's would credit
this tool with work it did not do.

- Group related entries when possible.
- Keep it concise — summarize, don't dump raw logs.
- If there are more than 10 entries, summarize the
  oldest and show the most recent 5 in detail.

## No activity

Only when the journal has no entries under *either*
tag, say nothing. Do not report "no recent activity"
— silence means no news. Entries tagged `heinzel`
alone are activity like any other: they are what a
host looked like before the rename, and suppressing
them would hide the very history the dual-tag read
exists for.
