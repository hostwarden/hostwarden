---
name: hostwarden-adopt
argument-hint: "[path to the old heinzel checkout]"
description: Take over an existing heinzel installation — copy its
  memory, access lists and custom rules into this hostwarden clone,
  rename what is found by name, and build a per-host inventory of the
  scripts, configs, units and cron jobs heinzel left on the servers.
  Use when the user says "übernimm mein altes heinzel", "migrate my
  heinzel setup", "mein heinzel liegt in <pfad>, mach es dir zu
  eigen", or points at a heinzel directory and asks to take it over.
  Touches no server. Never run automatically.
---

# hostwarden-adopt

One-time takeover of a heinzel installation. Everything happens in
this clone and in the old checkout — **no server is contacted, no
remote file is touched**. What lives on the hosts is written down as
an inventory that the first connection to each host verifies later
(`rules/heinzel-legacy.md`).

**Only on an explicit request** — the user naming their old checkout,
or `/adopt-heinzel <path>` in Claude Code. A session that merely
mentions heinzel is not a request, and neither is a question about
what adoption would do: answer it, don't start.

What makes this safe is not the trigger but the gates: the old
checkout is only read, anything this clone already holds is reported
before it would be overwritten, no server is contacted, and the one
write into the old tree (step 8) needs its own yes.

## Why an inventory instead of a migration

heinzel's own rules cover config backups, scratch directories and the
journal tag. They do not cover what agents improvised on the way: a
script under `/usr/local/bin/`, a directory `/etc/heinzel/`, a
systemd unit, a cron file, a log rotation config. Those exist, they
differ per host, and the only local trace is what the session wrote
into `memory/servers/<host>/` and its changelog.

Memory says what was true when it was written. It is a lead, not a
finding (`rules/verify-before-reporting.md`) — this skill collects the
leads, the host confirms them.

## Workflow

1. **Locate the old checkout.** Take it from the argument, or ask for
   the path. Verify it is one: a `VERSION` file, a `memory/`
   directory, and `bin/heinzel-*` or `rules/`. If `memory/` is empty,
   say so and stop — there is nothing to adopt.

2. **Never write into the old tree.** The old checkout is the user's
   fallback. Read from it, copy out of it, change nothing in it. Say
   this once, so the user knows the original stays intact. The single
   exception is step 8, which the user approves explicitly.

3. **Check what this clone already holds.** Anything under `memory/`
   beyond the shipped templates means this is not a fresh clone. List
   what would be overwritten and ask before touching it. Default to
   keeping this clone's file and reporting the conflict.

4. **Copy the state.** From the old `memory/` into this one:
   `user.md`, `blacklist.md`, `readonly.md`, `service-policy.md`,
   `network.md`, `housekeeping.md`, `opencode.json`, `custom-rules/`,
   and all of `servers/`. Skip `*.example` files — this clone ships
   its own. Copy, do not move.

5. **Rename what is found by name.** Run `bin/hostwarden-migrate`; it
   renames `memory/custom-rules/heinzel-<skill>.md` to
   `hostwarden-<skill>.md`, which is how skill overrides are located.
   Per-server `rules.md` files keep their name and need no change.

6. **Leave the facts in memory alone.** A memory line naming
   `/var/backups/heinzel/` or a `heinzel-backup.sh` on a host is a
   true statement about that host — the path is still there. Rewriting
   it would turn a fact into a lie. Only the greeting line in
   `user.md` (`Greeting: … Heinzel`) is about this tool rather than
   about a host: point it out and ask whether to change it.

7. **Build the inventory.** For each host under `memory/servers/`,
   read `memory.md` and `changelog.log` and collect every mention of a
   path, unit, cron job or script that heinzel created or configured.
   See `references/inventory.md` for what counts and the file format.
   Write it to `memory/servers/<host>/heinzel-inventory.md` and add to
   `memory.md`:

   ```markdown
   - heinzel legacy: pending (see heinzel-inventory.md)
   ```

   That line makes the first connection to the host run the legacy
   check with the inventory in hand instead of a blind scan.

8. **Offer the coexistence rules.** Ask whether heinzel stays in use
   during the transition. If it does, offer to copy the three files
   from `contrib/heinzel-coexistence/` into the old checkout's
   `memory/custom-rules/`. Without them heinzel reads only its own
   journal tag, so hostwarden's work stays invisible to it and its
   memory drifts. This writes into the old tree, so it needs an
   explicit yes; an existing `all.md` is appended to, never
   overwritten. On a no, say the directory is there when they change
   their mind.

9. **Report.** Per host one line: state copied, inventory entries
   found. Then the totals, and the one thing the user has to decide:
   nothing on any server has changed yet, and the first connection to
   each host will report what it finds there and ask.

   ```
   Adopted 7 hosts from /Users/x/heinzel
   web1.example.com   — memory, 3 changelog entries, 4 leads
   db1.example.com    — memory, 0 leads
   ...
   Nothing on the servers was touched. The first connection to
   each host verifies its leads and asks before moving anything.
   ```

   Say which of the two states each host is in: hostwarden alone, or
   both tools in parallel. In the parallel case the first connection
   reports what heinzel left but does not move it
   (`rules/heinzel-legacy.md`).

## What this skill does not do

- **No server contact.** Not even a read-only probe. The
  first-connection pipeline owns that.
- **No renaming on hosts.** A script keeps its name until every
  caller is known — see `rules/heinzel-legacy.md` and
  `rules/file-naming-changes.md`.
- **No scheduled runs.** Cron lines and timers on the workstation
  that call `bin/heinzel-*` are reported by the legacy check in local
  mode, and changed only with explicit approval.
- **No secrets.** If the old tree holds key material or a file with
  credentials, report the path and leave it (`rules/secrets.md`).
