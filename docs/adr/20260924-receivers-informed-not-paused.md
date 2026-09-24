---
id: 20260924-receivers-informed-not-paused
status: accepted
supersedes:
superseded-by:
waiting-on:
tags: [coordination, multi-host]
---

# A receiver is informed once, never held

## Context

Decided in the design of #226, reviewed by the maintainer on
2026-09-24, and built by the pull request that added `impact.sh`'s
receiver check. Once a session announces a disruptive step, other
sessions on hosts in its radius keep issuing commands against those
hosts while the step runs — a hypervisor reboot with a dozen guests
is the case that motivated the whole design.

## Decision drivers

- One announce must not stall every other session on the radius.
- A session left guessing is worse off than one told plainly what
  is happening.
- The hooks are a mechanical backstop, not an approval system that
  holds a command for someone else's decision.

## Considered options

### Refuse once, inform, let the retry through — chosen

The first command a session aims at a radius host during an active
impact is denied with the origin, the kind and the end time; a
marker remembers the refusal so every later command on that host
passes. The receiving session's own user decides what to do with
the information — wait, proceed, or ask the origin session.

### Pause the receiver until the impact ends

Rejected: it blocks every other session on the radius for the
length of the step, which for a slow multi-step change or a wide
radius could be minutes. `rules/borrowed-rights.md` also rules out
one session holding another's work on the other's behalf — that
decision belongs to the receiving session's own user, not to a hook
acting for them.

## Decision

`impact.sh` refuses a receiver's first command into an active
impact's radius once and lets every later one through unchecked.
Nothing in the hooks or in `bin/hostwarden-impact` ever blocks a
session for longer than the time to read one refusal.

## Consequences

`rules/coordination.md` → The hooks documents the refuse-once
behaviour, and `rules/borrowed-rights.md` → What stays allowed
names an ack the same way: information for the session that reads
it, never a hold or a permission. The coordinator planned for a
later pull request (#226, PR 4) may relay a notice to an idle
session's user, but even there it only informs — the receiving
session decides what to do.

## Confirmation

`scripts/coordination-test.sh` denies a receiver's first command
into an active impact and lets the identical retry through; a
design that paused the receiver instead would have that second
call fail too, and the test would need rewriting to expect it.
