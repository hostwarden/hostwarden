---
id: 20260925-dns-propose-write-only-where-allowed
status: accepted
supersedes:
superseded-by:
waiting-on:
tags: [dns, memory]
---

# DNS records are proposed; written only where allowed

## Context

Decided in the design of #270, from the maintainer's requirements
of 2026-09-24. Hostwarden sets up hosts and services that need DNS
records, and it can often reach a DNS server over SSH. The fleets it
manages hold their names in very different places: a provider's
zone, a server of the user's own, records injected into a resolver,
names DHCP registers, and zones managed as code.

## Decision drivers

- Access to a zone is not consent to change it.
- A zone managed as code is overwritten by its next `apply`.
- Resolver records have no transfer: each copy drifts on its own.
- The user must see every record before it exists.

## Considered options

### Propose everywhere, write only with a per-name-space `write` — chosen

Each name space gets one line in `memory/dns.md` with its source and
`Hostwarden: propose` or `write`, the latter only on the user's
word, dated. A proposal is the exact record set. Against it: the
user adds records by hand wherever `write` is not set.

### Write wherever access exists

Lost: a zone reachable over SSH is not a zone the user wants
Hostwarden to write, and a direct write into a zone managed as code
is undone by the next `apply`.

### Treat resolver records like a zone

Lost: they have no serial, no transfer and no signature, and a set
of resolvers has to be written member by member.

## Decision

Hostwarden proposes the exact record set for every set-up that
needs one. It writes only in a name space whose line says `write`,
never in one managed as code, and asks each time.

## Consequences

`rules/dns.md` carries the inventory, the proposal and, as write
methods are added, the write path; the first pull request adds no
write method, so every record set goes to the user. A request to
write into a name space without `write` is answered with this
record.

## Confirmation

A write that happens in a name space whose line says `propose`, or a
zone managed as code that drifts from its code, is the moment to
reread this record.
