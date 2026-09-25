---
id: 20260925-service-name-is-a-cname
status: accepted
supersedes:
superseded-by:
waiting-on:
tags: [dns]
---

# A service name is a CNAME to its host's FQDN

## Context

Decided in the design of #270, from the maintainer's requirement of
2026-09-24 that an address be kept in one place only. A host rename
(#253) or a move changes the host's address records; every other
record that repeats the address has to be found and changed with
them, and one that is missed points at the wrong machine.

## Decision drivers

- An address kept in one record changes in one place.
- A rename must not have to search every zone for the old address.
- DNS itself forbids an alias in some places.

## Considered options

### A CNAME to the host's FQDN, A/AAAA only where DNS requires it — chosen

The exceptions are the zone apex, an MX, NS or SRV target, and
resolver records whose product does not follow the CNAME. At the
apex, a provider's own mechanism (flattening, ALIAS) is proposed
where Hostwarden sees the provider. Against it: a lookup costs one
more step, and resolver records sometimes keep the address twice
anyway.

### A and AAAA records for services

Lost: the address is kept in every record, and a move or a rename
has to find all of them.

## Decision

A service name is proposed as a CNAME to its host's FQDN, and as A
and AAAA only where DNS or the product requires it, saying so.

## Consequences

`rules/dns.md` → The record convention carries the rule and its
exceptions; its Checks give an INFO hint where a CNAME would do,
never in a zone the provider flattens or proxies. A proposal to
write service addresses directly is answered with this record.

## Confirmation

A rename whose proposal has to change address records other than
the host's own is the sign it stopped holding.
