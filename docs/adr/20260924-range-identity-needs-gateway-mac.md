---
id: 20260924-range-identity-needs-gateway-mac
status: accepted
supersedes:
superseded-by:
waiting-on:
tags: [network, memory]
---

# Range identity needs the gateway MAC or the user's word

## Context

Decided in the design of #233, reviewed by the maintainer on
2026-09-24. The same prefix on two hosts is often not the same
network: libvirt's `virbr0` is 192.168.122.0/24 on every libvirt
host, a hypervisor's internal bridge repeats across nodes, and
consumer routers hand out 192.168.1.0/24 at countless sites. The
store merges observations into one line per range, so it needs a
rule for when two observations of one prefix are one network.

## Decision drivers

- A wrong merge puts a host at one site into the radius of a
  router at another; a wrong split costs a question.
- Hosts read their gateway's link-layer address without root.
- The user knows their network; the prefix does not.

## Considered options

### Merge on the gateway's address and MAC, or the user's word — chosen

Two observations are one line when they share the gateway address
and its link-layer address, when the user has confirmed both hosts
at one site, or when the user says they are one network.
Otherwise they stay separate, marked as the same prefix not shown
to be one network. Against it: an HA pair without a virtual MAC
shows two MACs for one gateway, and the user is asked once.

### Merge on the prefix alone

Lost: 192.168.122.0/24 on two libvirt hosts, and 192.168.1.0/24 at
two sites, would become one network, with a host at site B in the
radius of a router at site A.

## Decision

Two observations of one prefix are merged only on a shared gateway
address and MAC, on a confirmed shared site, or on the user's
word. A host-internal range is never merged and never a conflict.

## Consequences

`rules/network-topology.md` → Range identity carries the rule, and
the probe reads each default gateway's neighbour entry for it.
Unmerged lines cost a question each; a consumer counts them only
for their own sources.

## Confirmation

A host at one site listed under a range whose gateway sits at
another, or a merge rule that cites the prefix alone, is the
moment to reread this record.
