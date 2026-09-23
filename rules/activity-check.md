# Activity Check

On **every** connection to a server (remote or
local), check for recent Hostwarden activity in the
system journal. This keeps the user informed about
changes made by other team members or previous
sessions.

## When to run

After reading the server memory file and before
starting any requested work.

## What rides in this call

Other checks go into the read-back's call, so that none of them is
an SSH call of its own (`rules/ssh-connections.md` — one call per
logical step). This table is the one list of what rides along and
on which connection; each owner keeps its probe, the exact
condition, and what to do with the result.

| What is added | Connection | Owner |
| --- | --- | --- |
| The session register | every | this file, below |
| Ansible's module runs | every | this file, below |
| Agent directories and services | every | `rules/config-management.md` |
| Cron and marker probe | first; conditional | `rules/config-management.md` |
| Heinzel's leftovers | conditional | `rules/heinzel-legacy.md` |
| The guest listing | first; daily; re-probe | `rules/hypervisors.md` |
| A guest's link keys | conditional | `rules/hypervisors.md` |
| The storage inventory | first | `rules/storage-inventory.md` |
| Windows Version Detection | every but the first | `rules/os-detection.md` |
| Who manages the network | first; conditional | `rules/network.md` |

Where each condition is:

- **The session register:** where the OS file's `## Logs` section
  does not say otherwise (A fresh Heinzel entry means a live session,
  below).
- **Cron and marker probe:** the triggers in
  `rules/config-management.md` → Detect; the probe itself is in
  `rules/config-management-leads.md`. Fired by a lead the directory
  probe has just returned, it follows in the next call.
- **Heinzel's leftovers:** on the connections
  `rules/first-connection.md` step 8 names, and only where possible
  (`rules/heinzel-legacy.md` → Detect).
- **The guest listing:** on a host with a `Hypervisor:` line — the
  full inventory on the first connection and on a full re-probe the
  user asked for, the light listing at most once a day or when the
  request is about guests
  (`rules/hypervisors.md` → Inventory), and on a cluster member once
  for the whole cluster (`rules/hypervisors.md` → Clusters and
  Pools).
- **A guest's link keys:** on a VM or container whose memory has no
  `Runs on:` line (`rules/hypervisors.md` → Linking Guest and Host).
  A guest registered through its host reads them with OS detection
  instead (`rules/hypervisors.md` → Registering Guests).
- **The storage inventory:** where the `@storage` lines of the
  first probe found ZFS or btrfs (`rules/storage-inventory.md` →
  When); the disks and every later connection are housekeeping's.
- **Who manages the network:** on a host whose memory lacks it,
  and the full profile's probe on an onboarding the user asked for,
  as `rules/network.md` → When defines.
- **Windows Version Detection:** without its hardware part, unless
  memory lacks a `Virtualization:` or an `Arch:` line
  (`rules/os-detection.md` → On subsequent connections).

On a host without a register, the read-back runs again before each
change, with the `starting` marker in the same call
(`rules/parallel-sessions.md` → Hosts without a register); nothing
in the table rides in that one.

## How to check

Read both tags: `hostwarden`, and `heinzel` for entries
written before the rename. Heinzel is the project
Hostwarden grew out of, and its entries stay in the
journal of every server it touched. Write only
`hostwarden`.

Run the read-back from the loaded OS file's `## Logs`
section. Where it has none and systemd runs — every
Linux family but Alpine — read the journal, in the
verbose format, which names the unit each entry came
from:

```
journalctl -t hostwarden -t heinzel --since "7 days ago" \
  --no-pager -q -o verbose 2>&1 | awk "$C"
journalctl --no-pager -q -o short-iso | head -1
```

Every read-back, the journal's and each `## Logs`
section's but Windows', pipes what it read into
`awk "$C"`, oldest entry first: the classifier under Sessions and
watchers below, defined at the top of the same call.

As a non-root user outside the `systemd-journal` /
`adm` groups, `journalctl` silently shows only the
user's own entries. When connected as non-root, try
sudo and fall back in the same call. The test asks
for `journalctl` itself, since a sudoers rule may
allow it and nothing else:

```
if sudo -n journalctl -n 0 --no-pager >/dev/null 2>&1; then
  sudo -n journalctl -t hostwarden -t heinzel \
    --since "7 days ago" --no-pager -q -o verbose 2>&1 | awk "$C"
  sudo -n journalctl --no-pager -q -o short-iso | head -1
else
  echo "no sudo"
  journalctl -t hostwarden -t heinzel --since "7 days ago" \
    --no-pager -o verbose 2>&1 | awk "$C"
  journalctl --no-pager -q -o short-iso | head -1
fi
```

Where server memory's `Sudo:` line records sudo as
unavailable or unusable, run the `else` branch alone.
After `no sudo`, watch for the "not seeing messages
from other users" hint that the missing `-q` lets
through, and tell the user the check may be
incomplete.

Without a `## Logs` section and without systemd, tell
the user the check could not run.

If the command returns no `session:` line — and it
actually ran, and nothing limited what it can see —
say nothing about sessions. Do not report "no recent
activity": silence means no news.

An empty result only means "no activity" when the
command succeeded. If it errored, was shadowed by a
shell alias, or you sent its stderr to `/dev/null`,
you have no result at all — tell the user the check
did not run, rather than reporting silence. A failed
check that reads as a clean host is how a concurrent
session's work goes unnoticed.

## Sessions and watchers

Two kinds of writer use the two tags. A session,
Hostwarden's or Heinzel's, writes one headline per
change (`rules/changelog.md` → Entry format). A
watcher is a script, cron job or timer on the host
that logs under a session tag instead of its own
(`rules/deployed-files.md` → Naming on the host),
most often one a Heinzel session wrote. Only a
session's entry is activity. A watcher that logs
every few minutes would otherwise bury the sessions'
entries and look like somebody at work.

An entry is a session's when it passes all three
marks:

- **It opens with the prefix**
  `[<operator> as <unix-user>] `, which every session
  writes and no script does. Older Heinzel versions
  wrote none, so under `heinzel` an entry without it
  still counts as a session's unless one of the next
  two marks it as a watcher's.
- **Its unit is a login's**, on a host with the
  journal, which records the unit an entry came from
  and lets no writer set it: `session-<n>.scope`,
  `user@<uid>.service`, or the SSH server's own
  service where logins get no scope. Any other
  service, a timer's or `cron.service`, is a watcher,
  whatever its text says.
- **Its text does not recur.** An entry under
  `heinzel` without the prefix whose text, digits
  aside, appears three times or more in the window is
  a job's: a session's headlines do not repeat word
  for word. On a host without the journal, and for
  cron jobs that run in a login, as on RHEL, this and
  the prefix are all there is to go on.

The classifier applies these marks and prints one
line per finding:

```
earlier: 12 session entries
session: 2026-09-23 12:58 UTC hostwarden [alice as root] Installed nginx
watcher: heinzel cron.service 2016x, 2026-09-16 13:00 UTC to 2026-09-23 12:55 UTC, last: backup done: 4 files
other: 3 lines name a tag, last: … hostwarden-backup: done
```

- `session:` — the last 20 sessions' entries, oldest
  first; `earlier:` counts the ones before them.
- `watcher:` — one line per watcher: its tag, its
  unit, or `-` where the log names none, how many
  entries, the first and last, and the last text.
  Entries from one unit are one watcher; without a
  unit, entries whose text differs only in digits
  are. After ten, one line counts the rest.
- `other:` — lines that name a tag without being an
  entry under it: a watcher with its own tag
  `hostwarden-backup`, a login name in sshd's log.
  Neither activity nor a watcher on a session tag.
  Where every line of a read-back lands here, the
  classifier does not know that log's layout: read
  the lines without it, by their prefix.
- Any other line is what the read-back printed
  besides the log, such as the hint above or an
  error, and is passed through as it came. An error
  means the check did not run.

The classifier:

```
C='
  function keep(   o, n) {
    if (tag == "") return
    o = (u ~ /\.service$/ && u !~ /^(user@|(ssh|sshd|dropbear)[@.])/) ? u : "-"
    n = m; gsub(/[0-9]+/, "#", n); if (o != "-") n = ""
    N++; T[N] = ts; M[N] = m; K[N] = tag " " o " " n; cnt[K[N]]++
    tag = ""
  }
  BEGIN {
    re = "(^|[[:space:]])(hostwarden|heinzel)" \
      "(\\[[0-9]+\\]:|:|[[:space:]]+([0-9]+|-)[[:space:]])"
  }
  /^[^ ]+ [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9] .* \[s=[0-9a-f]+;/ {
    keep(); split($0, f, " "); ts = f[2] " " substr(f[3], 1, 5) " " f[4]
    tag = "?"; u = ""; m = ""; next
  }
  tag != "" && /^    SYSLOG_IDENTIFIER=/ { tag = substr($0, 23); next }
  tag != "" && /^    _SYSTEMD_UNIT=/ { u = substr($0, 19); next }
  tag != "" && /^    MESSAGE=/ { m = substr($0, 13); next }
  tag != "" && /^    / { next }
  match($0, re) {
    keep(); ts = substr($0, 1, RSTART); t = substr($0, RSTART, RLENGTH)
    m = substr($0, RSTART + RLENGTH); u = ""
    sub(/^[[:space:]]+/, "", t); tag = t; sub(/[^a-z].*/, "", tag)
    if (t !~ /:$/) {
      sub(/^[^ ]+ /, "", m)
      if (m ~ /^- /) m = substr(m, 3)
      else while (match(m, /^\[([^] =]+|[^]]*="[^]]*)\] ?/))
        m = substr(m, RLENGTH + 1)
    }
    sub(/^ /, "", m); sub(/^<[0-9]+>1 /, "", ts); sub(/[[:space:]]+$/, "", ts)
    sub(/ [a-z0-9]+\.(emerg|alert|crit|err|warning|notice|info|debug)$/, "",
      ts)
    keep(); next
  }
  NF { keep(); if (/hostwarden|heinzel/) { other++; last = $0 } else print }
  END {
    keep()
    for (i = 1; i <= N; i++) {
      k = K[i]
      if (k ~ /^[a-z]+ - / && (M[i] ~ /^\[[^]]+ as [^]]+\] / ||
          k ~ /^heinzel / && cnt[k] < 3)) { S[++s] = i; continue }
      if (!(k in F)) { F[k] = T[i]; Q[++q] = k }
      L[k] = T[i]; W[k] = M[i]
    }
    if (s > 20) print "earlier: " s - 20 " session entries"
    for (j = (s > 20 ? s - 19 : 1); j <= s; j++) {
      i = S[j]; split(K[i], f, " "); print "session: " T[i] " " f[1] " " M[i]
    }
    for (j = 1; j <= q && j <= 10; j++) {
      k = Q[j]; split(k, f, " ")
      print "watcher: " f[1] " " f[2] " " cnt[k] "x, " F[k] " to " L[k] \
        ", last: " W[k]
    }
    if (q > 10) print "watcher: " q - 10 " more"
    if (other) print "other: " other " lines name a tag, last: " last
  }'
```

It reads the journal's verbose format and the syslog
formats the `## Logs` sections produce: BSD, with or
without a pid, busybox's with facility and level,
ISO timestamps, and RFC 5424. A syslog line carries
no unit, so there the prefix and recurrence decide.

### What to do with a watcher

- **It is not activity**, and never a live session,
  however fresh its last entry.
- **Report it** in one line after the sessions'
  entries (What to show), with the span the
  classifier measured, not the window asked for:
  *"Watcher on the session tag heinzel:
  heinzel-backup.service, 2016 entries from
  2026-09-16 to 2026-09-23."* A prefixed entry from a
  service is a script that imitates a session: say
  so.
- **Stop once it is retagged.** A watcher whose last
  entry predates the change that gave it its own tag
  (`rules/changelog.md`, that change's entry) is
  history until the window lets go of it: leave it
  out.
- **Retagging it is a change** to the script: asked,
  and done as `rules/deployed-files.md` → Naming on
  the host says, or `rules/heinzel-takeover.md` for a
  script Heinzel left. Its unit, or its text, is the
  lead to the script.

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

A `session:` line tagged `heinzel` from the last 15
minutes is not history — a Heinzel session is
probably working on this host right now. Both tools
administer the same machines during a transition,
and the journal is the only signal they share. A
`watcher:` line is not one, however fresh.

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

Read Ansible's module runs in the same call as the journal, with the
same privileges, from the same source as the read-back above. Where
the loaded OS file's `## Logs` section defines the syslog stream,
Ansible's syslog fallback has written the identifier
`ansible-<module>` there, and the call defines `syslog_stream` as
that section gives it. Otherwise, with systemd, Ansible logs its runs
with the field `MODULE=basic.py`, or under the identifier
`ansible-<module>` where the host lacks Python's systemd bindings;
both are looked up in the journal's index, never by scanning it:

```
S='
  { ts = "" }
  $1 ~ /^[0-9][0-9][0-9][0-9]-/ { ts = $1; s = 3 }
  $1 ~ /^[A-Z][a-z][a-z]$/ && $3 ~ /^[0-9][0-9]:/ { ts = $1 " " $2 " " $3; s = 5 }
  $1 ~ /^<[0-9]+>1$/ && $2 ~ /^[0-9][0-9][0-9][0-9]-/ { ts = $2; s = 4 }
  ts != "" {
    if (/ Invoked with /) for (i = s; i <= s + 2; i++) if ($i ~ /^ansible-/) {
      m = $i; sub(/\[.*/, "", m); sub(/:$/, "", m)
      n++; if (f == "") f = ts; l = ts; lm = m
      break
    }
    next
  }
  /^[[:space:]]/ { next }
  NF { bad++ }
  END {
    if (bad) print "check failed: " bad " lines were not log entries"
    else if (n) print n " module runs, " f " to " l ", last " lm
  }'
r=
if command -v syslog_stream >/dev/null 2>&1; then
  r=1; printf 'syslog: '
  { syslog_stream 2>&1 || echo "syslog stream not read"; } \
    | grep -e " Invoked with " -e "^syslog stream not read" | awk "$S"
  echo
fi
if [ -d /run/systemd/system ]; then
  r=1; printf 'journal: '
  ids=$(journalctl -F SYSLOG_IDENTIFIER 2>&1 \
    | sed -n 's/^\(ansible-[A-Za-z0-9_.]*\)$/SYSLOG_IDENTIFIER=\1/p')
  journalctl --since "7 days ago" --no-pager -q -o short-iso \
    MODULE=basic.py ${ids:++} $ids 2>&1 | awk "$S"
  echo
fi
[ -n "$r" ] || echo "not read: no syslog stream and no journal"
```

Both sources are read where both exist, since a module with
systemd's Python bindings writes to the journal alone and one
without them to syslog. It prints one line per source, `syslog:` or
`journal:` followed by the count or by nothing, never a log line
itself: the arguments after `Invoked with` can carry values the
module did not mark secret (`rules/secrets.md`), and so can the
indented lines a multi-line message continues on, which are
skipped. Any other line
that is not an entry, an error included, is only counted. Only
identifiers made of letters, digits, dots and underscores become
matches, since any process can write an identifier and an unquoted
one with spaces would turn into options.
`+` joins the two kinds of match, so the entries come in time order.
The three timestamp rules are the journal's ISO lines, the BSD
syslog format, and RFC 5424 (`<14>1 2026-09-22T14:32:07+02:00 host
ansible-… …`), which OPNsense's log files and pfSense's optional
format write; without the last, every run there would be counted as
a line that is no entry.
A stream that could not be read adds `syslog stream not read`,
which is counted the same way, since its own error lines are
filtered out with every other line that is not a run. A
`check failed:` line means the read did not run. `not read:` —
macOS, and an appliance without either — is worth saying only when
the host's memory has a `Config management: ansible` line.

Report the line as activity. A last run inside the last 15 minutes
may still be going on: treat it like a live Heinzel entry above
before making a change. Runs on a host whose memory records no tool
for them, or only a `none` line dated before them, send you to
`rules/config-management.md`.

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
journal tag, so no Heinzel entry is credited to
Hostwarden. Only `session:` lines are listed; each
watcher follows as one line of its own (What to do
with a watcher).

- Group related entries when possible.
- Keep it concise — summarize, don't dump raw logs.
- If there are more than 10 entries, summarize the
  oldest and show the most recent 5 in detail.
