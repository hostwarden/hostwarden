# Taking Over What Heinzel Left Behind

Read this when `rules/heinzel-legacy.md` found
something on a host. Moving files on a live server is
a change, not a read, so all of it ends in a
question.

## Report, then ask

One line per find. For a directory of backups or
scratch output: path, file count, age of the oldest
entry. For a script, unit, cron file or config
directory a session created: path, and what calls it
as far as the inventory and the probe show. A script
the activity check found logging under a session tag
says so (`rules/activity-check.md` → Sessions and
watchers):

```
heinzel state on this host:
  /var/backups/heinzel/ — 24 files, oldest 61 days
  /usr/local/bin/heinzel-backup.sh — called by
    /etc/cron.d/heinzel-backup, 03:00 daily; logs
    under the session tag heinzel
```

Four answers:

1. **Take over and rename** — move Heinzel's fixed
   paths (below) and give every artifact whose name
   says `heinzel` its Hostwarden name, with every
   reference to it (§ Rename to Hostwarden's name).
2. **Take over, keep the names** — move the fixed
   paths; scripts, units, cron files and config
   directories keep their names and are recorded as
   they are.
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
takeover (`hostwarden-heinzel-takeover` skill):
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
will be deleted by the next cleanup. Take them over anyway?
```

Use the retention window that is actually configured
for this host, not the default. If the user wants the
old ones kept, take over the rest and leave those, or
raise the window in
`memory/servers/<hostname>/rules.md`.

## Not while Heinzel is still in use

If the user says both tools are in use, a takeover is
premature — Heinzel recreates its backup directory on
its next run. Report the find, say why it waits, and
record a deferral. Recent Heinzel entries in the
activity check do not settle it: hosts often move over
right after their last Heinzel session, so ask whether
Heinzel still runs before deferring. A `watcher:` line
under `heinzel` settles nothing either: it is a script
Heinzel left, which runs whether Heinzel does or not.

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
now. Taking over, with the names renamed or kept,
runs now on the host only: registration never
changes a guest, so a guest keeps that answer as a
deferral that says which of the two it was. Its
next connection that may change it asks again, for
that guest alone, with the recorded answer as the
recommended one:

```markdown
- heinzel legacy: deferred 2026-09-20 (answered at registration: keep)
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
as a session's work (`rules/activity-check.md` →
Sessions and watchers), and a nightly job would pass
for one wherever its unit and its text do not give
it away. A `watcher:` line under `heinzel` is a lead
to such a script like any other.

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
- heinzel legacy: taken over 2026-09-20 (24 backups, 0 left)
- heinzel legacy: renamed 2026-09-20 (24 backups, 3 names)
- heinzel legacy: left in place (/var/backups/heinzel/)
- heinzel legacy: deferred 2026-09-20 (heinzel still in use)
- heinzel legacy: deferred 2026-09-20 (privileged paths unread)
```

The first three settle it and the check does not run
again, but for an `unverified` entry still in
`deployed.md` (Heinzel's copies, below); a renamed
job's first run is followed up in
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
logger -t hostwarden "[<operator> as <unix-user>] Took over heinzel state: \
  /var/backups/heinzel -> /var/backups/hostwarden \
  (24 files)"
logger -t hostwarden "[<operator> as <unix-user>] Renamed heinzel artifacts: \
  3 names, 2 references; map in \
  /var/backups/hostwarden/heinzel-rename-map-20260920-1412.txt"
```

## Heinzel's memory

A host taken over from Heinzel
(`hostwarden-heinzel-takeover`) arrives with
Heinzel's `memory.md` as
`memory/servers/<hostname>/heinzel-memory.md` and no
`memory.md`. Its first connection — the takeover's
onboarding, or whichever session reaches it first —
is a first connection in every step of
`rules/first-connection.md`, and writes `memory.md`
in the form of `rules/server-memory.md`. A guest
registered through its host (`rules/hypervisors.md`
→ Registering Guests) is written the same way, its
network profile read inside it through the host in
one call, like its other steps.

`heinzel-memory.md` is a worklist, like the
inventory: never edited, never read as the host's
current state, and split up by that first connection
— nothing of it is left as prose. Once `memory.md` is
written and each part below has its place, delete
it. The workspace keeps it in its history, since the
takeover committed it. The Heinzel entries in
`changelog.log` stay as they are, the start of the
host's history.

Write `memory.md` from these sources, and only
these:

1. **What this connection probed** — every field
   `rules/server-memory.md` lists, and on a
   hypervisor what `rules/hypervisors.md` adds. A
   value Heinzel remembered is never written in
   place of a probed one, and a field no probe could
   read is `unknown`. Where the two differ, say so
   in one line: `OS: Debian 12 in Heinzel's memory,
   Debian 13 now`. Heinzel's `IP:` is checked as
   `rules/dns-aliases.md` → IP Verification checks
   `- IP:`: no address in common, and you stop and
   tell the user before anything else.
2. **Standing facts that are still true**, one line
   each:
   - Flags for other admins, and what only a person
     could have told Heinzel: the host's purpose,
     its owner, a maintenance window. A fact the
     host can show is checked against this
     connection's probes first; one only a person
     knows keeps the date of its record.
   - The `Flags:` and `Rollback:` lines of
     `changelog.log` that no later entry lifts or
     undoes (`rules/changelog.md` → Standing lines).
   - Ways in other than the one this session took,
     as `- Other ways in (heinzel, untested): …`,
     until `rules/ssh-safety-net.md` → Which way in
     tests them and writes `Access:`.
   - Paths, script names and units exactly as
     Heinzel wrote them. A true fact about a host
     path is never rewritten, even where it names
     Heinzel.
3. **What the Heinzel check confirmed** — Record
   above.
4. **The inventory's `## Facts`** — what the
   takeover sorted out of Heinzel's other memory for
   this host, under the same test as the standing
   facts of 2; a decision there goes the way of the
   decisions below. An open plan becomes
   `- Planned: <what> (<operator>, <date>)`
   (`rules/ssh-user.md` → Operator), removed once it
   is done or the user drops it. Once written, the
   section leaves the inventory, which is then empty
   when no lead is left.

Two kinds of standing text are not facts and never
go into `memory.md`. Collect them from
`heinzel-memory.md` and the inventory's `## Facts`,
and offer them in one list once the user's request is
answered, written only on a yes; the user drops or
moves items in the answer:

- **Decisions the user made** — an entry each, in
  the place and form `rules/decisions.md` gives,
  carried over from Heinzel. Heinzel's reasoning
  where it runs longer than the entry holds, the
  options weighed and the numbers, goes into the
  entry's `Details:` file rather than being lost
  with the prose.
- **How to work on this host** — a warning before a
  risky step, a procedure that differs from the
  shipped one: an override block in the host's
  `rules.md`, under the shipped file whose moment it
  belongs to (`rules/overrides.md`). A decision that
  changes what Hostwarden does gets its block the
  same way, with its `Decision:` pointer
  (`rules/decisions.md` → Decisions and overrides).

History is not carried: incidents, what was done
when, versions that were current then, how a problem
was solved. `changelog.log` has it, and the
workspace's history has the prose. The ~30 lines of
`rules/server-memory.md` hold: what does not fit and
is not standing is history.

Two kinds of fact have another place:

- **The host's own network** — bridges, VLANs, VPN,
  addresses, resolvers. This first connection runs
  the full network profile (`rules/network.md`), and
  Heinzel's notes on it are leads the profile
  confirms or contradicts; a contradiction is one of
  its findings.
- **Facts that belong to no single host** — a shared
  gateway, a VPN subnet, the backup target on
  another host, which UPS powers the machine, a
  controller's address. They go to
  `memory/network.md` (`rules/server-memory.md` →
  Cross-server facts) once this connection or the
  user confirms them; an unconfirmed one is named in
  the report and not recorded.

## Heinzel's copies

The takeover rebuilds the copies Heinzel kept of
files on its hosts into masters, each recorded as an
unverified entry (`rules/deployed-files.md` →
Unverified entries; `hostwarden-heinzel-takeover`,
`references/masters.md`). The Heinzel check settles
them from the host (`rules/heinzel-legacy.md` →
Detect); nothing on the host changes for that. Per
entry:

- **Owned by a configuration management tool** —
  its path lies in the scope of this host's
  `Config management:` line, or this connection's
  marker probe found the file
  (`rules/config-management-changes.md`). The tool's
  repository is its master, and a second one here
  would be a second truth (`rules/deployed-files.md`
  → What gets a master): the entry is removed, and
  Heinzel's copy moves to the host's `notes/` as a
  superseded copy, as below. This is checked first.
- **Same hash as the master.** The entry gets the
  host's mode, owner and hash, and the date of the
  Heinzel changelog entry that deployed it, or
  today's where none does.
- **Another hash.** The host's file becomes the
  master, and the entry is recorded from it as
  above. For a fleet master other hosts list, that
  is this host's variant under its own `files/`
  (`rules/deployed-files.md` → Where the master
  lives), and the fleet master stays. Otherwise
  Heinzel's copy first moves to the host's `notes/`
  as `<file name>.heinzel-superseded-<date>`, with
  `-2` and on where that is taken, never dropped: it
  may hold an intent the host lost. Then read every
  such host file in one call, as root or through
  `sudo -n` where needed, into its master's place
  without printing it, and hash each against the
  probe.
  This is no drift resolution in the sense of
  `rules/deployed-files.md` → Drift, which never
  settles a difference on its own: Heinzel's copy
  was never recorded as deployed, so there is no
  deployed state for the host to have drifted from,
  and the host's file is the only one known to run.
  A host file `rules/secrets.md` counts as a secret
  is not read: its entry is removed, and so is
  Heinzel's copy, which holds the same credential and
  never goes into `notes/` or anywhere else in the
  workspace; the old checkout keeps it, untouched.
  `memory.md` gets `- Note: not copied: <old
  checkout>/memory/<path> (holds a credential)`, and
  the report names the file as one to rebuild under
  `rules/deployed-files.md` → Secrets.
- **Missing on the host.** The entry is removed, and
  the master moves to the host's `notes/` with the
  date in its name — a fleet or cluster master only
  once no entry lists it. Its absence is a lead the
  host did not confirm (Record, above).
- **Unread.** The entry stays unverified, and the
  check records the deferral for privileged paths
  (`rules/heinzel-legacy.md` → Detect).

This connection's changelog entry names each note
these write, which keeps it (`rules/server-memory.md`
→ Notes and evidence).

A file Heinzel wrote carries no marker; it gets one,
like its own log tag, the next time its master
changes and is deployed.

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

## On an operations host

Heinzel may also run headless on a machine of its own, with
timers or cron jobs that start a Heinzel checkout there: a
nightly fleet housekeeping, often other workers, perhaps a
remote-control session. On the fleet's hosts it leaves a
forced-command wrapper that a key line in root's authorized keys
names (`command="/usr/local/sbin/heinzel-…"`), often a signers
file under `/etc/heinzel/`, and daily journal lines under the tag
`heinzel`.

Report it; change nothing unasked:

- **On that machine,** each unit or cron job, what it starts and
  when. It is Heinzel still in use, so the machine's
  `heinzel legacy:` line is a deferral,
  `(heinzel still in use, runs from this host)`. Stopping or
  disabling a job is a service change, and the operator's call.
  Heinzel's checkout, keys and secret files stay where they are
  (`rules/secrets.md`).
- **Jobs that are not housekeeping** — a mailbox triage, a
  remote-control session — are the operator's own automation
  (`.agents/skills/hostwarden-fleet-read/references/operations-host.md`
  → What it is not): recorded in that machine's memory, and left
  running.
- **On each fleet host,** the wrapper, the signers file, and how
  many key lines name the wrapper, read with `grep -c` only. None
  of it is renamed, moved or removed while a key line names it: a
  rename would have to change the key line, which only the
  operator writes. It is recorded as a fact of the host.

Then offer to point the fleet at Hostwarden, each step its own
yes:

1. An operations host of Hostwarden's, on the same machine or
   another
   (`.agents/skills/hostwarden-fleet-read/references/operations-host.md`
   → Setting one up).
2. Fleet read on each host (`hostwarden-fleet-read` skill), beside
   Heinzel's wrapper: the operator adds a second key line, and both
   work at once.
3. A `--dry-run` of the fleet run, compared with Heinzel's last
   report.
4. The operator stops Heinzel's timers, then removes Heinzel's key
   lines. Once `grep -c` finds none naming the old wrapper, it and
   its signers file are Heinzel leftovers on that host, removed
   when the user agrees.

Until step 4 both runs write to every journal, Heinzel under
`heinzel` and Hostwarden under `hostwarden`.
