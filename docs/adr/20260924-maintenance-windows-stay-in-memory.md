---
id: 20260924-maintenance-windows-stay-in-memory
status: accepted
supersedes:
superseded-by:
waiting-on:
tags: [coordination, multi-host]
---

# A maintenance window is a plan, never a scheduled action

## Context

Decided in the design of #226, reviewed by the maintainer on
2026-09-24. A blast radius known ahead of time also answers when a
disruptive step should run and who needs telling first. The window
has to survive from planning to a run weeks later, by a session
that never saw the conversation, on a workspace that may be shared
and whose `/tmp` state does not survive a reboot.

## Decision drivers

- A yes given while planning covers nothing once the radius may
  have changed.
- A workspace can be shared; a server's own state cannot carry a
  future plan reliably (a reboot clears `/tmp`, an image can be
  rebuilt).
- Restarts and reboots need a person to say yes at the time they
  run, not at the time they were planned.

## Considered options

### A plan in `memory/plans/`, run only when asked — chosen

The window is `Hosts:`, `Window:`, `Kind:`, `Affected:` and
`Notify by:` lines plus steps, in a plan file. A later session
recomputes the radius before running it and asks again. Against
it: nothing starts a window on the day itself without a session
being asked to.

### Write the window onto the affected servers in advance

A cron entry or a marker file on each host would survive whichever
session runs it. Rejected: breaks the register's name-only
contract, a host's own state is not a workspace, and a host
rebuilt from an image between planning and the window loses it
silently.

### Start the window automatically (a timer or scheduled agent)

The window's own time would trigger the run unattended. Rejected:
an unattended run that only reads and reports, a fleet read or a
scheduled housekeeping check, is not the same as one that carries
out a step a person has not seen that day. A reboot or restart
needs a yes at the time it runs, which the plan is not.

## Decision

A maintenance window lives only as a plan in `memory/plans/`. It is
read and re-verified, never trusted, and run only when a user asks
for it by name.

## Consequences

`rules/maintenance-windows.md` owns the plan format, the `Downtime:`
and `Downtime notice:` lines, and the re-verification steps a run
takes before touching anything. Nothing in Hostwarden starts a
window by itself; the scheduled-agent path some users configure for
housekeeping (`references/scheduled.md`) only ever reports, and
running a plan's steps stays a request a user makes by name.

## Confirmation

A pull request that adds a scheduler or a server-side marker for a
planned window and skips the re-read-and-ask step would contradict
this; nothing else would catch it.
