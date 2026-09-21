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

**systemd (Linux):**

```
journalctl -t hostwarden -t heinzel --since "7 days ago" \
  --no-pager -q 2>/dev/null
```

As a non-root user outside the `systemd-journal` /
`adm` groups, `journalctl` silently shows only the
user's own entries. When connected as non-root, try
`sudo -n journalctl -t hostwarden -t heinzel ...` first. If sudo
is unavailable, run the command without `-q` and
watch for the "not seeing messages from other
users" hint. When visibility is limited, tell the
user the activity check may be incomplete — do not
stay silent.

**macOS:**

```
/usr/bin/log show --last 7d \
  --predicate 'process == "logger"' --info 2>&1 \
  | grep -E "hostwarden|heinzel"
```

Two details that are not optional here:

- **Call `/usr/bin/log` by absolute path.** `log` is a
  common shell alias or function (git log wrappers,
  oh-my-zsh plugins). A shadowed `log` fails with
  something like `(eval):log:1: too many arguments`,
  which looks nothing like a missing-entries result.
- **Never redirect stderr to `/dev/null`.** With
  `2>/dev/null` a shadowed or failing `log` produces
  empty output, and "no activity" is exactly what
  empty output means below — so a broken check reads
  as a clean host. Keep `2>&1` and treat any line that
  is not a log entry as a failed check, not silence.

`senderImagePath CONTAINS "logger"` also works but
matches more broadly; `process == "logger"` is the
narrower predicate.

**FreeBSD:**

```
grep -hE "hostwarden|heinzel" /var/log/messages.0 \
  /var/log/messages 2>/dev/null | tail -20
```

Note: this shows the last 20 matches, not a strict
7-day window, and only reaches one rotation back
(`messages.0`). Older rotated logs are usually
compressed; mention the limitation if relevant.

If the command returns nothing — and it actually ran,
and journal visibility is not limited (see above) —
skip silently: no activity to report.

An empty result only means "no activity" when the
command succeeded. If it errored, was shadowed by a
shell alias, or you sent its stderr to `/dev/null`,
you have no result at all — tell the user the check
did not run, rather than reporting silence. A failed
check that reads as a clean host is how a concurrent
session's work goes unnoticed.

## A fresh Heinzel entry means a live session

An entry tagged `heinzel` from the last 15 minutes is
not history — a Heinzel session is probably working
on this host right now. Both tools administer the
same machines during a transition, and the journal is
the only signal they share.

Say so before making any change, and let the user
decide whether to go ahead, wait, or do it in the
other tool. Read-only work needs no pause. Name the
tool when entries from both tags appear: "Installed
nginx" reads differently once the user knows which
session did it.

`contrib/heinzel-coexistence/` holds the custom rules
that teach Heinzel the same thing from its side.
Another Hostwarden session that is changing the same
host shows up in the host's session register instead
(`rules/parallel-sessions.md`). Read it in the same
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
