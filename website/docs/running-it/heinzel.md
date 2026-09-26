---
sidebar_position: 6
description: Taking over an existing Heinzel installation instead of
  starting fresh.
---

# Moving over from Heinzel

Hostwarden is a new clone, not an update of your Heinzel checkout.
Your state moves with the backup script, which both projects share:

```bash
cd /path/to/heinzel && bin/heinzel-backup
cd /path/to/hostwarden && \
  bin/hostwarden-backup --restore /path/to/heinzel-backup-<host>-<ts>.tar.gz
bin/hostwarden-migrate
```

The migration renames skill overrides in `memory/custom-rules/` from
`heinzel-<skill>.md` to `hostwarden-<skill>.md`.

## What changed

- Environment variables are now `HOSTWARDEN_*`. `HEINZEL_NO_UPDATE`
  still works; the guard only honours `HOSTWARDEN_GUARD_DISABLE`.
- New journal entries on your servers use the tag `hostwarden`. The
  activity check reads `heinzel` entries as well, so earlier work
  stays visible.
- SSH sockets live in `~/.cache/hostwarden`.
- Heinzel's version tags are not carried over. `--pin` only knows
  Hostwarden releases.

## Taking over your memory

```
 ❯ My Heinzel is in ~/heinzel, take it over.
```

Point Hostwarden at your old checkout, or run
`/hostwarden-heinzel-takeover ~/heinzel` in Claude Code. The copy
itself is a script — `bin/hostwarden-heinzel-takeover <path>` moves
access lists, overrides, the host keys in `memory/known_hosts` and
every server's memory across and renames what is found by name.
Heinzel's memory of a host arrives as `heinzel-memory.md`, unchanged,
until the host's onboarding splits it up; the workspace's history
keeps the original. A `user.md` you already have gains the lines it
lacks, and a value the two set differently is shown to you, not
chosen. Whatever else your old `memory/` holds — Claude's
auto-memory from Heinzel sessions, notes — is sorted item by item
into overrides, decisions, the network notes or a host's memory,
with one question. The skill then reads it and the changelogs into a
per-host list of leads: the scripts, configs, units and cron jobs
your sessions improvised, and asks whether those should get
Hostwarden's names on the servers too: rename, keep, or decide per
host. None of that contacts a server.

Host keys come from `memory/known_hosts`
([Host keys](../features/ssh/host-keys.md)).
`bin/hostwarden-heinzel-takeover` copies the host keys your Heinzel
checkout kept there. Without them, each host's key is imported from
the known_hosts files your own ssh reads, such as
`~/.ssh/known_hosts`, on its first connection.

## Files your sessions wrote

The copies your Heinzel sessions kept of the files they wrote onto
servers — a `scripts/` directory under a host, a tool at the top of
`memory/`, wherever they ended up — are always rebuilt into
[masters](../features/changes/deployed-files.md): each file at its
host path under the host's `files/`, one deployed to several hosts
under `memory/fleet/`, workstation scripts in `memory/tools/`, open
plans in `memory/plans/`, evidence in the host's `notes/`. A file
with credentials stays in the old checkout. Each master is recorded
as unverified until the host's first connection compares it; where
the host's file differs, the host's version becomes the master and
Heinzel's copy is kept in the host's `notes/`.

## Onboarding each host

Then, unless you choose "only copy", the skill onboards each host the
way a first connection would have: read-only, host by host. It
writes the host's memory in Hostwarden's form from what it finds,
with your notes carried over, offers your earlier decisions as
decision records, runs the network profile, checks the leads, and on
a hypervisor inventories and registers the guests — and takes over
the guests still in your Heinzel checkout together with it, if you
say so. It ends with what each host lacks against the baseline and
asks which to take on first. With "only copy", the first connection
to each host does the same later, or `/hostwarden-onboard <host>`
when you choose.

## Keeping Heinzel around

Keeping Heinzel around during the switch?
`contrib/heinzel-coexistence/` holds three overrides for your
Heinzel checkout so it reads both journal tags, treats its server
memory as a lead rather than a fact, and leaves Hostwarden's files
alone. Hostwarden warns in the other direction when a Heinzel
journal entry is minutes old, and leaves a host alone that Heinzel
still uses. A script your Heinzel sessions left that logs under
`heinzel` counts as neither: it is reported as a watcher and offered
a tag of its own.

## What Heinzel left on your servers

On the first connection to a host, Hostwarden reports what Heinzel
left there — config backups, scratch directories, and the scripts,
units, cron files and config directories your sessions created — and
offers to move it under the new name. It asks first, and it says
which old backups the retention cleanup would then delete. On a
hypervisor whose guests it registers, it asks once for the host and
the guests together; a guest answered with "take over" is moved on
its next connection that may change it, after one more question. New
config backups go to `/var/backups/hostwarden/`, or the directory an
appliance's rules name.

Renaming a script or unit also rewrites every reference to it on that
host. Hostwarden keeps a rename map and backups to go back by, and
checks on a later connection that each job ran under its new name.

## Scheduled runs and headless Heinzel

Scheduled runs (cron, systemd timers) need the new path and script
names.

Heinzel running headless on a machine of its own, reading your
servers through a forced-command wrapper, is reported as such and
left running. Hostwarden offers to set up its own operations host and
fleet read beside it, one asked step at a time; you stop Heinzel's
timers and remove its key lines when the new run has proved itself,
and only then is the old wrapper removed from your servers.
