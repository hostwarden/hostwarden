---
id: 20260924-sites-by-co-presence-not-vpn-hop
status: accepted
supersedes:
superseded-by:
waiting-on:
tags: [network, memory]
---

# Sites are proposed from co-presence, never from a VPN hop

## Context

Decided in the design of #233, reviewed by the maintainer on
2026-09-24. A site groups the ranges at one place. The brief
proposed that ranges clustered behind the same VPN concentrator
form a candidate site. Hostwarden's fleets span home racks,
colocation and cloud VMs, joined by hub-and-spoke VPNs and mesh
overlays, with third-party concentrators in between.

## Decision drivers

- In a hub-and-spoke VPN every spoke sits behind one hub.
- A route says a range is reachable, not that it is here.
- A site is a proposal for the user to confirm, never an
  assignment.

## Considered options

### Group by co-presence on one host — chosen

A host with addresses on two ranges, on interfaces that are not
tunnels, puts both where it is; the connected components of that
relation are the candidate groups. A WAN edge marks a boundary and
never groups. Against it: a range seen only as a route destination
has no site until a host on it is onboarded or the user names one.

### Group by a shared VPN concentrator or WAN next hop

Lost: it merges every spoke of a hub-and-spoke VPN into one site,
and every customer of a third-party concentrator with them. A
policy-based IPsec tunnel has no interface to read, and an MPLS or
leased line on a plain NIC looks like a LAN hop.

### Derive the site from a naming convention

Lost: a hostname prefix or a domain suffix is a convention the
user has not confirmed, and some fleets have none. Once the user
confirms a scheme, its site code may propose one, since that
applies the user's own rule.

## Decision

Candidate sites are the connected components of hosts' addresses
on non-tunnel interfaces; routes, VPN hops and names never form
one. The user confirms each site at the host's first full profile
with a person present.

## Consequences

`rules/network-topology.md` → Sites carries the proposal and the
question. A range with no host in Hostwarden stays without a site;
a stretched L2 shows as one range with two site answers, an INFO
finding.

## Confirmation

A site proposed from a next hop, or hosts grouped by the tunnel
they share, is the moment to reread this record.
