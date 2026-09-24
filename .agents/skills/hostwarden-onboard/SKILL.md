---
name: hostwarden-onboard
argument-hint: "<hostname> [more hostnames]"
description: Onboard a host into Hostwarden explicitly and read-only,
  as its first connection — the full OS and hardware probe, its
  memory with what housekeeping would record, the network profile
  where the host has one, on a hypervisor the guest inventory and
  registration, then what it lacks against the server baseline, and
  a report. A host Hostwarden already knows is
  probed in full again and its memory refreshed. Use when the user
  says "onboard web1", "add this server to Hostwarden", "take db1 into
  Hostwarden", "set up pve1 in Hostwarden", "nimm web1 in Hostwarden
  auf", "übernimm den Server xyz in die Verwaltung", "richte db1 in
  Hostwarden ein", or names hosts to be onboarded. Makes no change on
  a server beyond one read-only line in each host's journal. Not for
  taking over a Heinzel installation (hostwarden-heinzel-takeover),
  and not for a new guest (hostwarden-new-guest).
---

# hostwarden-onboard

Runs a host's first connection on request, while the user is there,
rather than whenever the host is next needed, records what
housekeeping and the security audit would otherwise be first to
record, and ends with where the host stands against
`rules/baseline.md`. A host that already has a
`memory.md` gets a full re-probe instead (`rules/os-detection.md` →
On subsequent connections): the user asks for one by naming a known
host here, to refresh a record they no longer trust or one written
before a rule recorded more.

**Only in an operations checkout** (`AGENTS.md` → Development or
Operations). In a development checkout, say so, name the operations
checkout (`rules/server-check-handoff.md` → Find the operations
checkout) and stop.

## Workflow

1. **The hosts.** Take them from the argument, or ask. With several,
   the hosts whose memory, or the caller, names a hypervisor go
   first, the rest in the order given. A guest of the run that one of
   them registers keeps its turn, now as a known host: its own
   connection runs steps 4 to 6 here, and pipeline step 9
   (→ The first own login) does not. Where nothing but its host
   reaches it, its report line says
   `registered through <host>, not measured`.

2. **Announce each host** in one line before its first command:

       Onboarding 2/5: pve1.example.com — first connection, read-only
       Onboarding 3/5: web1.example.com — known host, full re-probe, read-only

3. **Run `rules/first-connection.md`** for it: on a new host as its
   first connection, with the full probe of
   `rules/first-detection.md` and `memory.md` in the form of
   `rules/server-memory.md`; on a known host as a known one, with the
   full re-probe in place of the short one. Either way it gets the
   full network profile where `rules/network.md` → When gives the
   host one, and on a hypervisor the full inventory
   (`rules/hypervisors.md`). A blacklisted host is not reached; its
   report line says so. A host that cannot be reached gets what
   `rules/ssh-unreachable.md` allows and no more, and the run moves on
   to the next one.

4. **Where the host stands.** For a host reached through its own way
   in (`rules/server-memory.md` → Onboarded and stale lines), run
   `hostwarden-baseline` steps 1 and 2 — its overrides and the
   measurement, read-only — and not its question. A decision the
   pipeline offers to record is asked before the measurement, so a
   section it settles is not listed as missing. The Host Certificate
   and User CA Trust probes of `rules/ssh-ca.md` run with it, and
   record what they find as its Memory section says. A guest
   registered through its host finishes onboarding on its first own
   login (→ The first own login). A Proxmox VE node without a
   `Baseline template:` line (`rules/appliance/proxmox-ve.md` →
   Guests) has that on its report line: a container created there
   starts without the baseline.

5. **What else memory holds.** The lines that otherwise only
   housekeeping or the security audit would write, each from the
   probe its reference gives, in the form it gives for the host's
   family, read-only and bundled with step 4's calls where the
   probes allow it. Onboarding records them; what a value means — a
   finding, its severity, an offer — stays with the skill that owns
   the probe.

   - `USB:` — housekeeping's
     `.agents/skills/hostwarden-housekeeping/references/usb-devices.md`:
     Probe, Reading the output and Memory. Not in a system
     container.
   - `Passthrough:` — housekeeping's
     `.agents/skills/hostwarden-housekeeping/references/passthrough.md`,
     on a host with guests, up to its Memory.
   - `Depends on:` — the probe of `rules/coordination.md` →
     Dependencies, and the entries it finds.
   - **The disks** in `storage.md` — `rules/storage-inventory.md` →
     Disks and When.
   - `Accounts:` — `rules/accounts-probe.md` → Probe, in a call of
     its own, written as `rules/accounts.md` → Memory says. Without
     root it says `sudo rules unchecked (needs root)`.
   - `Management:` — `rules/management-controller.md` → When it
     applies and Detection; a question it leaves joins step 6.
     Without root the host's report line says
     `Management: not settled (needs root)`.
   - `Backup:` — a mechanism step 4's Backup section found, written
     as housekeeping's
     `.agents/skills/hostwarden-housekeeping/references/backup-presence.md`
     → Recording the Answer writes one. Where it found none, that
     file's question joins step 6.
   - `Container registries:` — where a container engine runs, the
     image column of the `ps -a` line in housekeeping's
     `.agents/skills/hostwarden-housekeeping/references/containers.md`
     → Probe, read as the security audit's
     `.agents/skills/hostwarden-security/references/containers.md`
     → Registries says. Which registries to trust joins step 6.

6. **Close the host.** Any other question whose answers only get
   recorded — stopped guests, the questions step 5 hands on, the
   ones its references ask once (a UPS and what it powers, a serial
   adapter's far end, a reserved device no guest claims), anything
   else the pipeline's rules offer to record — is asked once the
   measurement has run, in the order its rules give, so the answers
   are in its memory before the next host starts. Once steps 3 to 5
   have run through the host's own way in, the host gets
   `- Onboarded: <date>` in place of any `SSH: untested`; on a known
   host the date moves. The
   journal line rides in the host's last call, and its changelog
   entry and commit follow (`rules/changelog.md`):

       read-only: onboarded — the server's details recorded and
       checked against the server baseline, nothing changed

7. **Report.** One block for the run, then the question.

   ```
   Onboarded 3 hosts, read-only
   pve1.example.com — Proxmox VE 9.0.3, 11 guests: 9 registered
     baseline: missing automatic security updates, backup;
     no baseline template for containers
   web1.example.com — Debian 13, known host re-probed, its record
     140 days old:
     OS: Debian 12 in memory, Debian 13 now
     baseline: complete; Management: not settled (needs root)
   db1.example.com — not onboarded: SSH timeout
   Written: memory.md and a read-only journal line for each onboarded
     host, network.md for pve1 and web1, guests.md for pve1, the
     workspace committed
   Registered guests finish onboarding on their first own login.
   Nothing on the servers was changed.
   Housekeeping keeps health and settings current, the fleet audit
     the drift between hosts; neither runs by itself.
   ```

   - A known host's line names the age of the record the re-probe
     replaced where it was stale (`rules/server-memory.md` →
     Onboarded and stale lines).
   - The line on registered guests stands where the run registered
     one that it did not reach through its own way in.
   - The last line always stands.

   Then, where a host has gaps, ask which to take on first: one option
   per host with gaps, one per node without a baseline template,
   "schedule housekeeping", and "not now". A host in read-only mode —
   on the read-only list, through a read-only host, or by its family,
   as Windows is (`rules/access-control.md` → Read-Only Servers) —
   gets no option: its gaps go into the modification report that
   section gives. A host picked starts `hostwarden-baseline` at its
   step 3, with this measurement; a node starts building its template
   (`hostwarden-new-guest`); scheduling follows
   `.agents/skills/hostwarden-housekeeping/references/scheduled.md`.
   Where no
   host has gaps, the question offers the schedule and "not now"
   alone.

`hostwarden-heinzel-takeover` runs this skill for the hosts it
takes over from Heinzel; where it adds to a step, its step 9 says
so.

## The first own login

A guest its hypervisor registered finishes onboarding on its first
own connection, whatever the task (`rules/first-connection.md`
step 9). Nobody is asked whether: finishing reads only, and costs
only time.

1. **Announce** it in one line, before the first command after the
   pipeline's own:

       web1.example.com: first own login — finishing onboarding,
       read-only, then the task

2. **Steps 4 to 6**, before the task, their questions included;
   the pipeline's OS detection was already the full re-probe
   (`rules/os-detection.md` → On subsequent connections). The
   journal line rides in the last call:

       read-only: onboarded on first own login — the server's
       details recorded and checked against the server baseline,
       nothing changed

3. **The task.**
4. **Baseline gaps after the task**, as one line with the offer,
   where the measurement found any and the guest is not in
   read-only mode:

       web1.example.com: baseline missing firewall, backup — take
       them on now? (hostwarden-baseline)

Where it runs in an agent (`rules/multi-host.md`), the agent returns
step 6's questions and the gaps line as notices naming this skill,
as it returns any skill's question. A run with nobody at the
keyboard, such as scheduled housekeeping
(`.agents/skills/hostwarden-housekeeping/references/scheduled.md`),
asks nothing, not even step 4's decision question: it finishes
steps 4 and 5, writes `Onboarded:`, names each unasked question in
its report as unsettled, and leaves its line missing for the next
interactive run to ask.

## What this skill does not do

- **No change on a host.** Closing a baseline gap, starting a stopped
  guest, moving what Heinzel left — each is its own question under
  its own rule, after the report.
- **No guest creation.** A new guest is `hostwarden-new-guest`, which
  registers it as it goes.
- **No scheduled runs.** It needs a user to answer the first
  connection's questions.
