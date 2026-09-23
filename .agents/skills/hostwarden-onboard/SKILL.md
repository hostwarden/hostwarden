---
name: hostwarden-onboard
argument-hint: "<hostname> [more hostnames]"
description: Onboard a host into Hostwarden explicitly and read-only,
  as its first connection — the full OS and hardware probe, its
  memory, the network profile where the host has one, on a hypervisor
  the guest inventory and registration, then what it lacks against the
  server baseline, and a report. A host Hostwarden already knows is
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
rather than whenever the host is next needed, and ends with where the
host stands against `rules/baseline.md`. A host that already has a
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
   connection adds what registration leaves out, the baseline
   measurement among it. Where nothing but its host reaches it, its
   report line says `registered through <host>, not measured`.

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

4. **Where the host stands.** For a host reached over SSH or in local
   mode, run `hostwarden-baseline` steps 1 and 2 — its overrides and
   the measurement, read-only — and not its question. A decision the
   pipeline offers to record is asked before the measurement, so a
   section it settles is not listed as missing. A guest registered
   through its host is measured on its first SSH connection or by
   housekeeping. A Proxmox VE node without a `Baseline template:` line
   (`rules/appliance/proxmox-ve.md` → Guests) has that on its report
   line: a container created there starts without the baseline.

5. **Close the host.** Any other question whose answers only get
   recorded — stopped guests, anything else the pipeline's rules
   offer to record — is asked once the measurement has run, in the
   order its rules give, so the answers are in its memory before the
   next host starts. The
   journal line rides in the host's last call, and its changelog
   entry and commit follow (`rules/changelog.md`):

       read-only: onboarded — the server's details recorded and
       checked against the server baseline, nothing changed

6. **Report.** One block for the run, then the question.

   ```
   Onboarded 3 hosts, read-only
   pve1.example.com — Proxmox VE 9.0.3, 11 guests: 9 registered
     baseline: missing automatic security updates, backup;
     no baseline template for containers
   web1.example.com — Debian 13, known host re-probed:
     OS: Debian 12 in memory, Debian 13 now
     baseline: complete
   db1.example.com — not onboarded: SSH timeout
   Written: memory.md and a read-only journal line for each onboarded
     host, network.md for pve1 and web1, guests.md for pve1, the
     workspace committed
   Nothing on the servers was changed.
   ```

   Then, where a host has gaps, ask which to take on first: one option
   per host with gaps, one per node without a baseline template, and
   "not now". A host in read-only mode — on the read-only list,
   through a read-only host, or by its family, as Windows is
   (`rules/access-control.md` → Read-Only Servers) — gets no option:
   its gaps go into the modification report that section gives. A
   host picked starts `hostwarden-baseline` at its step 3, with this
   measurement; a node starts building its template
   (`hostwarden-new-guest`).

`hostwarden-heinzel-takeover` runs this skill for the hosts it
takes over from Heinzel; where it adds to a step, its step 9 says
so.

## What this skill does not do

- **No change on a host.** Closing a baseline gap, starting a stopped
  guest, moving what Heinzel left — each is its own question under
  its own rule, after the report.
- **No guest creation.** A new guest is `hostwarden-new-guest`, which
  registers it as it goes.
- **No scheduled runs.** It needs a user to answer the first
  connection's questions.
