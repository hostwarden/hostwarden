---
id: 20260926-same-session-fallback-self-resolved-address
status: accepted
supersedes:
superseded-by:
waiting-on:
tags: [ssh-config, shared-workspace]
---

# Same-session fallback for a declined self-resolved address

## Context

`rules/ssh-config.md` → A Self-Resolved Address asks, in a shared
workspace, whether an address Hostwarden resolved itself is
reachable the same way from every workstation before writing it to
the shared `memory/ssh_hosts`; a decline writes nothing anywhere.
Its own example is "a guest's actual address before its DNS record
exists" — `hostwarden-new-guest`'s "Bridge the name" step, whose
remaining steps in the same run depend on the settled name
resolving. Its other callers, an mDNS conflict and a rename's
stopgap, have no such dependency: a decline there only costs future
convenience. Found rebasing that fix past the gate once #337 and
#424 had merged.

## Decision drivers

- The gate's existing two decline branches both mean nothing is
  written anywhere, which is right for a caller with no same-run
  dependency on the name.
- The one caller that depends on it would otherwise reintroduce the
  exact bug its own base pull request (#337) fixed.
- Hostwarden already reaches a host by an ad-hoc
  `HostName`/`HostKeyAlias` pair without touching any file; this
  costs one paragraph, not a new mechanism.

## Considered options

### Extend the gate with a same-session fallback — chosen

A decline still writes nothing to any file, but a caller whose own
remaining steps need the name may reach the guest with
`-o HostName=<address> -o HostKeyAlias=<settled name>` on each of
its own calls, for the rest of that run alone. Reusable by any
future load-bearing caller, not only this one; the gate carries the
provision once.

### Scope the fallback to the one skill

Let `hostwarden-new-guest` fall back to the bare address for the
rest of a declined run, memory landing under the address rather
than the settled name, a manual rename fixing it later. Cheapest,
but reintroduces #337's own bug in exactly the branch meant to guard
against a bad address, and a second load-bearing caller would need
the same carve-out written out again.

### Refuse to proceed on decline

Stop after the guest boots and ask the operator to resolve the
reachability question — confirm DNS already covers every
workstation, or accept address-based registration — before going
on. Never silently wrong, but stops a legitimately shared-but-fine
workspace on a cautious "not sure," and still leaves nothing for a
future load-bearing caller to reuse.

## Decision

`rules/ssh-config.md` → A Self-Resolved Address gains a
same-session fallback: on `only this workstation` or `not sure`, a
caller whose remaining steps in the same run need the name may
still reach the guest with an `-o HostName=`/`-o HostKeyAlias=` pair
of its own, written nowhere. `hostwarden-new-guest`'s "Bridge the
name" step uses it.

## Consequences

A load-bearing caller keeps working on every answer to the gate's
question, at the cost of one more clause in `rules/ssh-config.md`
and a small addition to that skill's own steps for the declined
case, open-ended over whichever of them still connect to the guest
rather than naming a fixed few. The report tells the operator
plainly that no other
session, and no later connection of this one, reaches the guest by
the settled name until DNS does — the same consequence the original
gate already accepts for its other callers, just said out loud for
this one too since it is otherwise easy to miss mid-flow.

## Confirmation

A second load-bearing caller of A Self-Resolved Address that finds
the fallback does not fit its own flow, or a report from a shared
workspace where the fallback masked a genuine cross-workstation
mismatch instead of catching it, is the moment to revisit.
