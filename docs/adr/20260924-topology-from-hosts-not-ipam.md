---
id: 20260924-topology-from-hosts-not-ipam
status: accepted
supersedes:
superseded-by:
waiting-on:
tags: [network, memory]
---

# Network topology comes from host data, never an external IPAM

## Context

Decided in the design of #233, reviewed by the maintainer on
2026-09-24. Hostwarden had every host's own addresses with prefix
lengths and default routes, but no picture of which ranges exist,
which site and gateway each belongs to, and how they interconnect.
A network change on a gateway needs that picture, and so does a
naming scheme. Every fleet Hostwarden manages is small; many run
no IPAM at all, and the shared workspace already makes API
credentials a burden.

## Decision drivers

- The first overview must need nothing set up beyond the SSH
  login Hostwarden already has.
- An integration that has to be kept working is a liability in a
  shared workspace.
- The record must be a picture of now, kept incrementally, not a
  snapshot regenerated from the whole fleet.

## Considered options

### A read-only store built from the hosts' own profiles — chosen

The full network profile already reads addresses, prefixes and
default routes; a wider route capture, the gateway's MAC and the
VLAN tags are added to it, and each profile folds its facts into
`memory/topology.md`. An appliance adds its configuration where its
file reads one. Against it: the store knows only what onboarded
hosts show, so a range with no host in Hostwarden has no site
until the user names one.

### An external IPAM (NetBox, phpIPAM) as the source of truth

Lost: it makes the overview depend on a system many users do not
run, and on an API integration that breaks with its releases and
needs a credential in the workspace. A user's own IPAM may become
a read source later; it is never a requirement.

### DHCP leases as the source of truth

Lost: a lease is a fact about a device at a moment, and reading
leases would make the ranges churn on every renewal. A lease only
ever proves that a DHCP server exists; the configured scope is the
fact about the network.

### A synced network diagram, or a topology recomputed on demand

Lost: a diagram needs regeneration logic and goes stale, and can be
rendered from stored facts when wanted. Recomputing on demand
means re-probing the whole fleet for one question, where memory
already works incrementally.

## Decision

The topology store is `memory/topology.md`, fed by each
host's full network profile and by an appliance's configuration
read, and by nothing outside the fleet. It depends on no external
IPAM, reads no leases and keeps no diagram.

## Consequences

`rules/network-topology.md` carries the store's schema and when it
is fed and pruned; `rules/network-probe.md` the captures. A range
nobody in Hostwarden sits on is known only as a route destination.
A proposal to require or sync an external IPAM is answered with
this record.

## Confirmation

Nothing would tell us on its own. A rule that reads an IPAM's API
before it can show ranges, or a credential for one in the
workspace, is the moment to reread this record.
