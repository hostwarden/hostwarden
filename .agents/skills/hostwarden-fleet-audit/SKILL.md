---
name: hostwarden-fleet-audit
argument-hint: "[hostname1 hostname2 ...]"
description: Compare key policies across all servers in
  memory/servers/ to surface silent drift. Makes no configuration
  changes; writes one audit-trail line to each host's journal.
  Probes unattended-upgrades, sshd effective config and SSH CA
  trust, firewall posture, MTA, network stack and resolver, time
  sync, auto-reboot behaviour, mesh VPNs and their SSH servers,
  accounts and sudo rules, and Ubuntu Pro/ESM coverage and
  needrestart mode. Use when
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
with hosts of the same appliance, and only where that
appliance file's `## Housekeeping and Audits` section says
how. Otherwise it goes on a "skipped: appliance not yet
supported" list, decided from memory before any probe runs.

Hosts are compared only within the same role and
platform as well (`Role:` and `Platform:` in memory): a
cell the platform file prescribes, such as WSL's firewall,
never differs from a native host's as drift. The
`## Housekeeping and Audits` sections of the family, platform
and role files apply to the probes (`rules/os-detection.md` →
Layers).

## Workflow

1. **Discover hosts.** List directories under
   `memory/servers/` whose name resolves to a real host,
   whose `memory.md` has a `Mode: via` line (reached
   through the host its `Runs on:` names, step 2), or a
   `Reached as:` line, which is then the destination, for
   the user lookup too, with `-p` and the
   `SSH port:` line where there is one (skip placeholders like
   `server1.example.com` and `192.168.64.20` unless the
   user names them explicitly).
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

   **Group the guests under their host.** A host whose
   `Runs on:` line (`rules/hypervisors.md` → Linking Guest
   and Host) names a directory in `memory/servers/` — the
   name before the brackets, an alias followed to its
   canonical host — is a guest of that hypervisor,
   whether it is reached over SSH or through the host. The
   hypervisor and its guests are one group, for the
   dispatch in step 3 and the columns in step 4; a guest
   that is itself a hypervisor heads a group of its own
   inside it. A cloud VM, a guest on a host `not managed`
   and an `unknown` one are in no group: a group stands for
   a machine Hostwarden probes, and two VMs at one provider
   do not even share one. A group decides no comparison:
   the appliance, role and platform limits above still do,
   so a Proxmox VE node heads its guests' group without
   being compared with them.

2. **Resolve SSH users.** Read `memory/user.md` for the
   per-host SSH user. Hosts without a mapping go on a
   "skipped: no SSH user known" list (do not prompt — just
   report). A host with `Mode: via` in its memory uses the
   SSH user of the host its `Runs on:` names and runs the
   probes through that host (`rules/first-connection.md` →
   Via-host mode). One whose `Runs on:` names no managed
   host and ID, which that section would ask about, is not
   asked about here: list it as "skipped: no host in
   `Runs on:`".

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

   - the hostname and the SSH user, and for a via-host
     guest its `Mode: via` and `Runs on:` lines;
   - which probe categories to run, and the journal line
     from step 6 with its prefix filled in
     (`rules/changelog.md` → Entry format). Not the probe
     commands: the agent reads `references/probes.md`
     itself, and a fleet of a dozen hosts would otherwise
     carry the same 8 KB thirteen times — once here and
     once per prompt — for commands this session never
     runs;
   - **that its row comes back keyed** by the row keys
     `references/probes.md` lists, which the agent reads
     there. Agents told only "return the structured row"
     return four different shapes, and step 4 cannot build
     a column out of that;
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

   **Two exceptions, and they are not about the targets.**
   Hosts behind a shared jump host, and guests with
   `Mode: via` beside their host, run in sequence as
   `rules/multi-host.md` → Order says.

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

   Only a probe whose status is `ok` or `partial` returns a
   row, and only such a host gets a column. A `skipped:`
   result joins the skipped lists from steps 2 and 3. A
   `blocked:` result carries no row, which is not a malformed
   one: put its decision to the user, then probe that host
   here as step 3 describes, or list it as skipped with the
   reason if they decline.

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

   Each probe returns its host's `decided:` and `decision:`
   lines with the warnings, as `.claude/agents/hostwarden-host-probe.md`
   → What you return describes them; probing one host after
   another here, write the same lines from each host's pipeline
   step 6. A disagreement a host's decision
   settles is no drift for that host, and it goes with the
   `decided:` lines into a "Decided" section after the two
   (`references/output-format.md` → Decided). A drift entry never
   suggests what a decision rules out.

   Do not change anything.

6. **Log to the system journal** on each audited host:

       logger -t hostwarden \
         "[<operator> as <unix-user>] fleet-audit: read-only policy probe"

   (One line per host — this is an audit trail, not a
   change record.) It rides the probe call from step 3 —
   a separate login for one log line is the round trip
   `rules/ssh-connections.md` exists to avoid. A subagent
   writes its own; do not reconnect to write it again.

7. **No audit result in memory.** What the pipeline owns,
   it still writes: `Last connected` for every host
   reached, because each was in fact connected to
   (`rules/server-memory.md`), a changed OS version
   where detection found one (`rules/os-detection.md`),
   and what `rules/network.md` → When writes on
   connecting.
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
  category (UA, sshd, firewall, MTA, network, time,
  auto-reboot, mesh VPNs, accounts and sudo).
- `references/output-format.md` — table layout and the
  "Drift detected" section format.

## Scope and limits

- Linux (Debian family) is fully covered, and Alpine, macOS
  and FreeBSD through their **Alpine**, **macOS** and
  **FreeBSD** variants in `references/probes.md`. RHEL/SUSE
  probes share the same shape but use
  `dnf`/`firewalld`/`zypper` equivalents. Windows hosts
  (`OS:` in memory names Windows) are skipped with a "Windows
  not yet supported" note, decided from memory before any
  probe runs.
- The audit does not check that running services are
  healthy (that is housekeeping's job). It only compares
  declared policy.
- BatchMode SSH means no password prompts. Hosts that need
  a passphrase get skipped — fix the agent setup
  separately.
