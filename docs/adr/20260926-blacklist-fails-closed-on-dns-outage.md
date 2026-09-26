---
id: 20260926-blacklist-fails-closed-on-dns-outage
status: accepted
supersedes:
superseded-by:
waiting-on:
tags: [access-control, resolver]
---

# A resolver outage fails the blacklist and read-only checks closed

## Context

`.claude/hooks/resolve.sh`'s shared lookup, used by
`bin/hostwarden-impact` and `bin/hostwarden-fleet-run` to check the
server blacklist and read-only list, could not tell a name that
genuinely has no address from a resolver it could not reach: both
gave the same empty result. An outage during the check was read as
a clean miss, in `hostwarden-fleet-run`'s unattended fleet read and
in `hostwarden-impact`'s team-telling alike.

## Decision drivers

- `rules/access-control.md` already errs on the side of caution for
  the interactive pipeline's own ambiguous case.
- `hostwarden-fleet-run` connects with no one watching to catch a
  wrong "not blacklisted".
- Coordination runs on every disruptive step fleet-wide, so blocking
  it too readily has its own cost.

## Considered options

### Fail closed — chosen

An unresolvable result is treated as a match: a blacklist check
refuses, a read-only check defaults to read-only. Against it: a
transient outage can pause coordination or skip a fleet-read host
until the resolver recovers.

### Fail open with a loud warning

Proceed as before, but note the outage prominently. Against it: an
IP- or alias-only blacklist entry that needs resolution to catch is
exactly what a fail-open default would miss during the one window
it matters.

## Decision

`hostwarden_resolve_ok` (`.claude/hooks/resolve.sh`) tells a
resolver-unreachable result and a missing `dig` apart from a clean
negative. Both check scripts treat either as a match: blocked and
skipped, never passed through as a clean miss.

## Consequences

A DNS blip can now block a disruptive step's coordination or skip a
fleet-read host that would otherwise have read cleanly.
`rules/access-control.md` carries the constraint.

## Confirmation

If fail-closed proves too disruptive in practice — coordination or
fleet read stalling on transient resolver hiccups more than the
blacklist gap ever bit — that would be the signal to revisit this
record.
