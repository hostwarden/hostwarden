---
name: hostwarden-adopt
argument-hint: "[path to the old Heinzel checkout]"
description: Take over an existing Heinzel installation — copy its
  memory, access lists and custom rules into this Hostwarden clone,
  rename what is found by name, and build a per-host inventory of the
  scripts, configs, units and cron jobs Heinzel left on the servers.
  Can run host by host, with the shared state moved first. Use when
  the user says "übernimm mein altes Heinzel", "migrate my Heinzel
  setup", "mein Heinzel liegt in <pfad>, mach es dir zu eigen", "nimm
  erstmal nur server X mit", or points at a Heinzel directory and asks
  to take it over. Touches no server. Needs an explicit request —
  a session that merely mentions Heinzel is not one.
---

# hostwarden-adopt

One-time takeover of a Heinzel installation. Everything happens in
this clone and in the old checkout — **no server is contacted, no
remote file is touched**. What lives on the hosts is written down as
an inventory that the first connection to each host verifies later
(`rules/heinzel-legacy.md`).

**Only on an explicit request** — the user naming their old checkout,
or `/hostwarden-adopt <path>` in Claude Code. A session that merely
mentions Heinzel is not a request, and neither is a question about
what adoption would do: answer it, don't start.

What makes this safe is not the trigger but the gates: the old
checkout is only read, anything this clone already holds is reported
before it would be overwritten, no server is contacted, and the one
write into the old tree (step 6) needs its own yes.


## Why an inventory instead of a migration

Heinzel's own rules cover config backups, scratch directories and the
journal tag. They do not cover what agents improvised on the way —
the shapes are listed in `rules/heinzel-legacy.md` § "What to look
for", which is also what the first connection probes for, so the two
sides cannot drift apart. Those artifacts differ per host, and the
only local trace is what the session wrote into
`memory/servers/<host>/` and its changelog.

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
   exception is step 6, which the user approves explicitly.

3. **Copy the state.** `bin/hostwarden-adopt <path>` does it: shared
   state — access lists, service policy, custom rules, network and
   housekeeping notes — then every server's memory, then
   `bin/hostwarden-migrate` for the `heinzel-<skill>.md` →
   `hostwarden-<skill>.md` renames. It keeps this clone's version of
   anything that already holds user data and says so; `--list` shows
   the plan without copying.

   **Host by host** if the user wants to move gradually:
   `--server <host>` (repeatable) takes single hosts,
   `--shared` takes only the shared state. The shared state comes
   along on the first run either way — the blacklist and the
   read-only list decide whether a host may be touched at all, so
   moving a host without them is not a partial migration but an
   unsafe one. Say which hosts are still in the old checkout after a
   partial run, and that the old one stays authoritative for them.

4. **Leave the facts in memory alone.** A memory line naming
   `/var/backups/heinzel/` or a `heinzel-backup.sh` on a host is a
   true statement about that host — the path is still there. Rewriting
   it would turn a fact into a lie. Only the greeting line in
   `user.md` (`Greeting: … Heinzel`) is about this tool rather than
   about a host: point it out and ask whether to change it.

5. **Build the inventory.** This is the part no script can do. It
   covers every host the run named: listed as copied,
   `already adopted: memory/servers/<host>`, or
   `kept memory/servers/<host> — …`. A repeat or interrupted run
   copies nothing, and a kept host is one whose leads sit in the old
   checkout's records — both would otherwise end up with no leads at
   all. A selection that is a DNS alias means
   the canonical host it points at (`rules/dns-aliases.md`): take
   that one, drop the alias. Never every host under
   `memory/servers/`, or a `--shared` run builds inventories for
   hosts nothing was adopted for. Skip a host that already has an
   inventory file.

   For each host in that set, read `memory.md` and `changelog.log`
   and collect every path, unit, cron job or script a Heinzel session
   created or configured — the shapes are listed in
   `rules/heinzel-legacy.md` § "What to look for",
   `references/inventory.md` has the file format and what does not
   count. Write it to `memory/servers/<host>/heinzel-inventory.md`.
   Its existence is what makes the first connection check the leads;
   no status line is needed for that.

   Read the **old checkout's** copy of a host's files whenever this
   clone kept its own — the leads live in the records that were not
   copied.

6. **Offer the coexistence rules.** Ask whether Heinzel stays in use
   during the transition. If it does, offer to copy the three files
   from `contrib/heinzel-coexistence/` into that checkout's
   `memory/custom-rules/`, the way its README § Install describes —
   never replacing a file, and reporting what has to be merged by
   hand. Without them Heinzel reads only its own journal tag, so
   Hostwarden's work stays invisible to it and its memory drifts.
   This writes into the old tree, so it needs an explicit yes. On a
   no, say the directory is there when they change their mind.

7. **Report.** Per host one line: state copied, inventory entries
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

   Say which of the two states each host is in: Hostwarden alone, or
   both tools in parallel. In the parallel case the first connection
   reports what Heinzel left but does not move it
   (`rules/heinzel-legacy.md`).

## Who owns what

Taking over Heinzel is one feature split across two mechanisms,
because its two halves are triggered by different things:

- **This skill** — the old checkout. The user asks for it by name,
  and again for each further piece: a migration moved host by host
  is several requests, one per run. It reads their Heinzel
  directory, copies memory, access lists and custom rules into
  this clone, and writes down what Heinzel appears to have left on
  each host.
- **`rules/heinzel-legacy.md`** — the host. Step 8 of the
  first-connection pipeline, so it fires without anyone asking:
  on the first connection to a machine, while anything is still
  unresolved, and whenever the activity check turns up `heinzel`
  entries — which is what catches Heinzel touching a host again
  after the question was settled. It detects; it never moves.
- **`rules/heinzel-adoption.md`** — what to do about a detection.
  Also a reflex. Every path that would *move* something ends in a
  question, because moving files on a live server is a change.
  The path that moves nothing does not ask: while Heinzel is
  still in use, adoption is premature, and that one reports and
  records a deferral instead.

Nothing is stated twice: this file describes the checkout, the
rules describe the hosts, and each names the other rather than
summarizing it.

## What this skill does not do

- **No server contact.** Not even a read-only probe. The
  first-connection pipeline owns that.
- **No renaming on hosts.** A script keeps its name until every
  caller is known — see `rules/heinzel-adoption.md` § "An improvised
  script keeps its name".
- **No scheduled runs.** Cron lines and timers on the workstation
  that call `bin/heinzel-*` are reported by the legacy check in local
  mode, and changed only with explicit approval.
- **No secrets.** If the old tree holds key material or a file with
  credentials, report the path and leave it (`rules/secrets.md`).
