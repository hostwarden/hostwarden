---
id: 20260924-ssh-ca-audit-and-consistent-use
status: accepted
supersedes:
superseded-by:
waiting-on:
tags: [ssh, security]
---

# Trust an existing SSH CA, never build one

## Context

Decided 2026-09-23 while porting Heinzel's SSH CA design
(heinzel#14/#16/#31). The prior stance, set with the workspace
`known_hosts` design
([20260924-one-shared-known-hosts-file](20260924-one-shared-known-hosts-file.md),
PR #166), was "CA: supported, docs only, never recommended".
Heinzel's whole point in #16 was that Hostwarden drives a CA it
manages consistently, and the accounts-on-demand work that follows
needs that vocabulary in place first.

## Decision drivers

- Hostwarden manages hosts it did not provision; many already run
  a CA of their own.
- The sshd taboo forbids touching a running server's configuration.
- heinzel#16's accounts-on-demand needs a CA already integrated.

## Considered options

### Audit read-only, then use it everywhere — chosen

Detect trust, principals, the KRL and host-certificate expiry
without writing anything, and once a CA is found, extend it to new
guests, the workstation's known-hosts coverage, the baseline's
gap reports and outgoing clients. Against it: nobody asking
Hostwarden to create a CA from nothing gets one.

### Docs only, never recommended (the prior stance)

Mention CA support in documentation but never touch or suggest it.
Lost: it made the accounts-on-demand port impossible to build on,
since that work assumes a CA Hostwarden actually integrates with.

### Build a CA setup assistant now

Let Hostwarden create a CA where none exists. Dropped for now: an
audit plus consistent use of an existing CA covers what was asked;
generating and custodying a new signing key raises questions nobody
has answered yet.

## Decision

An SSH CA the user already runs is first-class: Hostwarden audits
it read-only, then uses it everywhere it writes SSH trust — new
guests at first boot, workstation known-hosts coverage, baseline
gap reports, outgoing clients, and a guard-protected KRL. Hostwarden
never creates, runs or holds a CA's signing key.

## Consequences

`rules/ssh-ca.md` carries the audit rules and the taboo boundary
(no signing, no key access, no write to a running sshd);
`rules/host-keys.md` and `rules/baseline.md` cite it for
workstation coverage and gap reporting.

## Confirmation

A request to build a CA from scratch, or a proposal to return to
"docs only, never recommended", is the moment to reread this
record.
