---
name: hostwarden-fleet-audit
argument-hint: "[hostname1 hostname2 ...]"
description: Compare key policies across all servers in
  memory/servers/ to surface silent drift. Makes no configuration
  changes; writes one audit-trail line to each host's journal.
  Probes unattended-upgrades, sshd effective config, firewall
  posture, MTA, time sync, and auto-reboot behaviour. Use when
  the user asks to "fleet audit", "vergleiche alle server",
  "policy drift check", "are my servers configured the same?",
  or after a fix on one host to find which others carry the
  same bug.
---

# hostwarden-fleet-audit

Cross-server policy audit. Hostwarden knows every host
individually but has nothing that holds hosts against each
other. This skill closes that gap by probing the same set of
settings on every server in `memory/servers/` and rendering a
side-by-side comparison so silent drift becomes visible.

**No configuration changes.** The audit never alters any
host's configuration. The only write is a single audit-trail
line to each host's system journal (step 6 below). Acting on
findings is a separate step (hostwarden-housekeeping for
per-host fixes, or manual edits with explicit user approval).

**Never run automatically** — only on explicit user request.


## When to use

- "Run a fleet audit"
- "Vergleiche die Policies auf allen Servern"
- "Drift check across the fleet"
- After fixing a config bug on one host: "which other hosts
  have the same problem?"

Do NOT auto-invoke for generic phrases like "check my
servers" — that maps to single-host housekeeping.

A host with an `Appliance:` line in memory is compared only
with hosts of the same appliance, as that appliance file's
`## Housekeeping and Audits` section says — or skipped with
the note it gives.

## Workflow

1. **Discover hosts.** List directories under
   `memory/servers/` whose name resolves to a real host
   (skip placeholders like `server1.example.com` and
   `192.168.64.20` unless the user names them explicitly).
   **Skip entries that are symlinks** — those are DNS
   aliases of a canonical host already in the list
   (`rules/dns-aliases.md`), and auditing one twice would
   put the same machine in two columns.

   The user may pass an explicit subset as arguments — in
   that case audit only those, and audit an alias they
   named *as that alias*. The deduplication above is for
   the list this skill builds itself; a name the user typed
   is not a duplicate of anything, it may carry its own SSH
   user, and silently auditing the canonical host instead
   answers a question nobody asked.

2. **Resolve SSH users.** Read `memory/user.md` for the
   per-host SSH user. Hosts without a mapping go on a
   "skipped: no SSH user known" list (do not prompt — just
   report).

3. **Probe each host.** Hosts that time out or refuse the
   connection go on a "skipped: unreachable" list.

   **In Claude Code, give each host its own subagent.**
   Dispatch one `hostwarden-host-probe` per host, in a
   single message so they run concurrently. Each returns
   one row and keeps the raw command output out of this
   conversation — which is the point: a fleet of a dozen
   hosts otherwise fills the context with `sshd -T` dumps
   nobody reads.

   Each task prompt carries four things:

   - the hostname and the SSH user;
   - which probe categories to run, and the journal line
     from step 6. Not the probe commands: the agent reads
     `references/probes.md` itself, and a fleet of a dozen
     hosts would otherwise carry the same 8 KB thirteen
     times — once here and once per prompt — for commands
     this session never runs;
   - **the keys its row must come back with** — name them,
     one per probe category, using the row keys
     `references/probes.md` lists. Agents that are each
     told "return the structured row" and nothing more
     return four different shapes, and step 4 cannot build
     a column out of that. `unknown(needs-root)` is a
     value; a missing key is not;
   - **anything the user restricted this run to.** "Without
     sudo", "no journal entries", "only the firewall
     section" reach the agent only if you put them there —
     it cannot see what the user said to you. A constraint
     that does not make the trip is a constraint the audit
     breaks on every host at once.

   Parallelism across *different* hosts is safe. Rate
   limits and fail2ban count per host
   (`rules/ssh-connections.md`), and each host gets one
   agent, so nothing is competing. Never give one agent two
   hosts, and never give two agents the same host.

   **One exception, and it is not about the targets.**
   Hosts reached through a shared bastion all open a
   connection to that bastion as well
   (`rules/ssh-connections.md`), so a dozen agents are a
   dozen near-simultaneous logins to one machine, which is
   what rate limiting and fail2ban exist to stop — and
   being locked out of the jump host locks you out of
   everything behind it. Read `ssh -G <user>@<host>` for
   each target before dispatching — with the user from
   step 2, because a `Match user` block can select the
   jump host, and without it `ssh -G` reports a different
   config than the connection will use. Group the targets
   that share a `proxyjump`, and run each group in
   sequence.

   Elsewhere, and whenever a host needs a decision the
   agent cannot make alone, read `references/probes.md`
   here and do the same probing one host after another,
   bundled into as few SSH calls as the host allows, with
   the standard options from `AGENTS.md` → SSH Options. The
   tables come out identical; only the wall-clock and the
   context cost differ.

4. **Render comparison.** Build one table per probe category
   using the format in `references/output-format.md`. Hosts
   are columns, settings are rows. Cells that differ across
   columns get visual emphasis.

5. **Surface drift, then warnings.** After the tables, emit a
   short "Drift detected" section that lists each disagreement
   and the recommended fix (link to the relevant rule or skill).
   Then a "Warnings" section carrying every `warnings:` line the
   probes returned, grouped by host.

   The two sections answer different questions and neither
   covers the other. Drift is a comparison, and a fleet where
   every host has the same pending reboot or the same legacy
   iptables rules has none — the criteria that catch those judge
   one host at a time, they live in `references/probes.md`, and
   this session does not read that file. So a warning reaches
   the report only because the probe returned it. Never fold
   them into "Drift detected" and never let an empty drift
   section stand for an empty report.

   Do not change anything.

6. **Log to the system journal** on each audited host:

       logger -t hostwarden "fleet-audit: read-only policy probe"

   (One line per host — this is an audit trail, not a
   change record.) It rides the probe call from step 3 —
   a separate login for one log line is the round trip
   `rules/ssh-connections.md` exists to avoid. A subagent
   writes its own; do not reconnect to write it again.

7. **No audit result in memory.** What the pipeline owns,
   it still writes: `Last connected` for every host
   reached, because each was in fact connected to
   (`rules/server-memory.md`), and a changed OS version
   where detection found one (`rules/os-detection.md`).
   What the probes found goes nowhere near a memory file:
   the audit compares hosts, it does not own what any one
   of them records. A memory file that
   contradicts the live config goes in the "Drift detected"
   section for the user to decide on — as does anything a
   probe agent returned under `notices:`, which is where
   activity findings, Heinzel artifacts and pending
   `todo.md` items come back from the pipeline it ran.

## References

Read on demand:

- `references/probes.md` — the exact commands to run per
  category (UA, sshd, firewall, MTA, time, auto-reboot).
- `references/output-format.md` — table layout and the
  "Drift detected" section format.

## Scope and limits

- Linux (Debian family) is fully covered. RHEL/SUSE
  probes share the same shape but use `dnf`/`firewalld`/
  `zypper` equivalents. macOS hosts are skipped with a
  "macOS not yet supported" note — covering them is a
  separate effort.
- The audit does not check that running services are
  healthy (that is housekeeping's job). It only compares
  declared policy.
- BatchMode SSH means no password prompts. Hosts that need
  a passphrase get skipped — fix the agent setup
  separately.
