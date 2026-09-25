---
id: 20260925-appliances-read-over-ssh-allow-list
status: accepted
supersedes:
superseded-by:
waiting-on:
tags: [network, appliances, secrets]
---

# Router configuration is read over SSH through an allow-list

## Context

Decided in the design of #273, from the maintainer's requirements
of 2026-09-24. The topology store of #233 had a slot for what a
firewall or gateway console knows about its networks, and nothing
filled it. OPNsense and pfSense keep everything in
`/conf/config.xml`, UniFi OS in its Network database, and
Hostwarden already logs into all three over SSH as root. OPNsense
grants API privileges per page, not per method; pfSense CE has no
REST API; UniFi's View Only admin reads only through a password.

## Decision drivers

- The first complete overview must need nothing set up beyond the
  SSH login Hostwarden already has.
- None of the three offers an API credential that is truly
  read-only.
- `config.xml` holds a Wi-Fi passphrase and a DDNS key inside the
  sections the read needs.
- A lease churns on every renewal; the scope is the fact.

## Considered options

### An allow-listed read over SSH — chosen

A program run with the product's own loader prints only named
keys, withholding any value that is not an address, a name or a
number; UniFi's query projects on the server and again on the
workstation. Against it: root could change anything, so the read
rests on the program's text, and element names move between
releases, so a moved one reads as not read until the file follows.

### An API account as a precondition

Lost: too high a hurdle for the first overview, and not safer.
OPNsense's read endpoints can need "All Pages", its read-only
config privilege has had bypasses, and pfSense's "Deny Config
Write" stops config writes but not other actions. UniFi's View
Only API stays an alternative path, never a requirement.

### Section-level reads of `config.xml`

Lost: printing `<interfaces>` or the DHCP section whole leaks the
passphrase and the key. A deny-list filter behind it is the same
mistake `rules/management-controller.md` rejects for `lan print`.

### DHCP leases as the source

Lost: a lease is a device at a moment, and the store would change
on every renewal. The configured scope describes the network.

## Decision

Each appliance file's `## Network configuration read` reads over
SSH with an allow-list of keys, prints nothing whole, and never
reads firewall or NAT rules, leases or secrets. No API account is
a condition for it.

## Consequences

`rules/appliance/opnsense.md`, `pfsense.md` and `unifi-os.md`
carry the reads, `rules/network-topology.md` the fold. A new field
is a new key in the allow-list, never a wider section. The element
and field names need a live appliance to confirm, and one that
moves shows as `not read`.

## Confirmation

A read that prints a whole element, or an appliance file that asks
for an API account before its first read, is the moment to reread
this record.
