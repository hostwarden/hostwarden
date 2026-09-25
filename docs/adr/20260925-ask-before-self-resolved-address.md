---
id: 20260925-ask-before-self-resolved-address
status: accepted
supersedes:
superseded-by:
waiting-on:
tags: [ssh-config, shared-workspace]
---

# Ask before writing a self-resolved SSH address

## Context

Decided 2026-09-25, after Codex flagged PR #337's new-guest bridge
writing a resolved address into the shared `memory/ssh_hosts` file.
A reviewer sweep found the same pattern, unguarded, in
`rules/mdns.md`'s mDNS-conflict resolution: Hostwarden itself
determines an address and commits it to a file every workstation in
a shared workspace reads, with no check that the address is
reachable the same way from all of them. mDNS answers are
link-local by protocol (RFC 6762), so that instance is guaranteed
to misdirect a workstation on another segment, not merely unlucky.
`Adding a Block` already covers a user-told address; only
Hostwarden's own resolutions were unguarded.

## Decision drivers

- An mDNS-resolved address is link-local by protocol design, so
  caching it shared-wide misdirects other segments by construction.
- Existing precedent already routes a categorically-local value
  (`localhost:2222`) out of the shared file; this deserves the same
  caution, less mechanically decidable.
- `Adding a Block` already lets a user-told address in unguarded,
  since the user vouches for it; only Hostwarden's own guesses lack
  that.
- Hostwarden never writes the user's own `~/.ssh/config`, so a
  declined write has no silent fallback — the operator places it.

## Considered options

### Ask once, narrow scope — chosen

When Hostwarden itself resolves an address — never one the user
names — and the workspace is shared, ask whether it is reachable
the same way from every workstation before writing it to
`memory/ssh_hosts`. A no or unsure answer skips the shared write
and tells the operator to add it to their own `~/.ssh/config` if
they need it, the same fallback `A Port the User Names` already
gives a `localhost:2222` guest. No new file, no precedence change
in `bin/hostwarden-ssh-config`.

### Document the risk only

Add a warning to the affected files, no new question. Cheapest, but
leaves the mDNS case — structurally guaranteed to misdirect on
another segment, not just unlucky — silently wrong by default in
every shared workspace spanning more than one network path, with
nothing prompting an operator to notice before it does.

### New personal override file

A Hostwarden-managed per-workstation file, layered ahead of
`memory/ssh_hosts` in `bin/hostwarden-ssh-config`'s generation
order. Lets a declined address still resolve locally, but reorders
the shared SSH-routing precedence every session depends on, for a
risk that only bites teams with genuinely partitioned network
access to the same infrastructure — disproportionate to the actual
blast radius.

## Decision

`rules/ssh-config.md` gains `A Self-Resolved Address`: in a shared
workspace, before `Adding a Block` writes an address Hostwarden
determined itself, ask whether it is reachable the same way from
every workstation. `rules/mdns.md` and `rules/host-rename.md` point
to it. A no or unsure answer skips the shared write; the operator's
own `~/.ssh/config` is theirs to use instead.

## Consequences

Writing a Hostwarden-resolved address into `memory/ssh_hosts` in a
shared workspace now costs one three-option question; a user-told
address is unaffected. A workstation that declines the shared write
loses name resolution for that host until DNS exists or the
operator adds it locally — no worse than today's `localhost:2222`
case. `rules/ssh-config.md` carries the check; `rules/mdns.md` and
`rules/host-rename.md` reference it. A permanent no-DNS host's
block, once accepted, still leaves IP-drift verification blind for
its life — a separate problem from cross-workstation reachability,
not addressed here.

## Confirmation

A user reports a host reachable from one workstation and not
another where `memory/ssh_hosts` carries its `HostName`, or the
question fires often enough in solo-adjacent setups to read as
noise rather than a real check — either is the moment to revisit.
