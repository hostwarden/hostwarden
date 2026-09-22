# Network Profile

What Hostwarden records about a host's own network, and what
counts as a finding there. The profile answers four questions
before anyone touches the network:

1. **Who owns the configuration?** Which manager, which file,
   and whether something regenerates it.
2. **What is the stack?** IPv4 and IPv6, which address ranges,
   static or dynamic.
3. **Does it work?** Default routes, name resolution, and
   outbound reachability per address family. Configured IPv6 is
   often broken IPv6.
4. **Does the outside agree?** A, AAAA and PTR records against
   the addresses the host really has.

Every probe for it is read-only.

## When

This file is not part of the connection pipeline, and an `- IP:`
that no longer matches stays with `rules/dns-aliases.md`.

- **Full profile:** when the user asks about the host's
  addresses, IPv6, DNS resolution, outbound reachability or a VPN,
  and when a failure points at the network — a package mirror,
  `curl` or a DNS lookup that times out, or a stall in one address
  family only.
- **Before a change** to addresses, routes, interfaces, DNS
  resolution or the network manager: only who owns it. That is
  the Linux probe up to the end of section A, plus the first four
  commands of section D for a DNS change, or the family's `sysrc`
  or `networksetup` lines; then Before changing the network
  below.
- **After a change**, on a host whose memory has a profile: run
  the probe again and update it in the same step.

A profile whose `Probed:` date is older than 90 days is refreshed
before it is relied on. The probes are in
`rules/network-probe.md`, one call per family.

## Quick check

Four read-only commands, no root, for a workflow that only needs
to know whether the network still matches the profile — or, on a
fleet, whether the hosts match each other. It decides nothing on
its own: the entries in Findings below do.

```bash
c='docker|br-[0-9a-f]{12}|veth|cni|flannel|vnet|tap|lxc'
c="$c|wg|tailscale|zt|nebula|tun|utun"
ip -o -6 addr show scope global | grep -vE " ($c)[0-9a-z.-]* "
ip -4 route show default | head -1
ip -6 route show default | head -1
ls -l /etc/resolv.conf; grep -m1 '^#' /etc/resolv.conf
```

The first command lists the global IPv6 addresses that are the
host's own: a container bridge or an overlay carries one too,
and neither says the host has IPv6 (see Stack). A ULA
(`fc00::/7`) on the uplink stays in the list; only such addresses
make the stack `v4 + ULA`. On FreeBSD and
macOS: `netstat -rn -f inet`, `netstat -rn -f inet6`,
`ifconfig -a inet6` and the same `/etc/resolv.conf` lines. macOS
resolves through `scutil --dns` instead of the file; the
resolver in use is the first one whose `flags` line does not say
`Supplemental`, since a VPN adds scoped resolvers above it.

What it answers: the stack (see below), a default route per
family, and who writes `/etc/resolv.conf` — the symlink target,
or the generator header of a plain file, which
`rules/network-probe.md` reads under Reading D. A difference is
the moment to build or refresh the full profile, not to guess.

## Where it goes

`memory/servers/<hostname>/network.md`, next to `memory.md`. It
is the host's own profile; `memory/network.md` holds the facts
several hosts share (`rules/server-memory.md`). `memory.md` keeps
its `- IP:` line, which `rules/dns-aliases.md` depends on, and
gains one summary line, which names a mesh VPN too:

```markdown
- Network: dual-stack, v6 egress OK, Tailscale — see network.md
```

`network.md` holds current facts only. Replace stale values; the
history is in `changelog.log`:

```markdown
# Network — host.example.com
Probed: 2026-09-19

## Summary
- Stack: dual-stack (v4 public, v6 GUA)
- Egress: v4 OK, v6 OK (deb.debian.org)

## Management
- Manager: netplan → systemd-networkd
- Source: /etc/netplan/50-cloud-init.yaml
- cloud-init: owns network config
- Conflicts: none

## Interfaces
- Uplink: eth0, MTU 1500, physical
- Overlay: wg0 · Container interfaces: 3

## IPv4
- 203.0.113.10/32 static, public
- Default: via 192.0.2.1 dev eth0

## IPv6
- 2001:db8:1:2::1/64 static, GUA
- Default: via fe80::1 dev eth0, static
- RA: networkd (userspace), kernel accept_ra 0
- Forwarding: 0 · Temporary addrs: none

## DNS
- resolv.conf: symlink → systemd-resolved stub
- Upstream: 2 v4 + 1 v6 on eth0, link-provided
- Own name: hostname -f resolves to itself

## Public DNS (from workstation)
- A: matches · AAAA: matches
- PTR v4: host.example.com, forward-confirmed
- PTR v6: missing

## Findings
- INFO: no PTR for 2001:db8:1:2::1
```

A mesh VPN interface or agent in the probe loads
`rules/mesh-vpn.md`, which adds a `## Mesh VPN` section.

Record only what a probe showed. Never infer a hosting provider
from an address range or a gateway; name one only when
`cloud-id` or the user said so. A proxy is recorded as set, never
with its URL, which can carry a password.

## Stack

Judge the stack from the uplink's addresses, the default routes
and the egress test. Container bridges do not count: Docker with
IPv6 puts a unique local address on its bridge on any host.

- `dual-stack`: usable IPv4 and an IPv6 global address, both
  with a default route.
- `v4-only`: IPv6 off, or link-local only.
- `v6-only`: no IPv4 default route. Add `+ NAT64` when the
  probe's DNS64 line answers, `+ 464XLAT` with an IPv4 address
  on a CLAT interface.
- `v4 + ULA`: IPv6 only inside the site (`fd00::/8`).
- Append `v6 broken` when a global address and a default route
  exist but the IPv6 egress test fails, and `no v6 route` when a
  global address exists without a default route.

Address ranges that are easy to misread:

- `100.64.0.0/10` is carrier-grade NAT on an uplink, and
  Tailscale's range on `tailscale0`, where it is an overlay.
- `169.254.0.0/16` as the only IPv4 address means DHCP failed.
- `fc00::/8` is undefined (only `fd00::/8` is ULA), and
  site-local, 6to4 and Teredo addresses are legacy.

## Findings

The one list for the profile's `## Findings` section and for any
workflow that reports on a host's network. Severities follow the
housekeeping report format.

**CRITICAL**

- Name resolution fails: no egress target resolves in any
  family.

A firewall that filters IPv4 but not IPv6 is the security audit's
finding, at its severities
(`.agents/skills/hostwarden-security/references/firewall.md` →
IPv6).

**WARN**

- `v6 broken` or `no v6 route`. Clients prefer IPv6 and hang or
  fall back slowly; `apt` and `curl` stall.
- **The RA and forwarding trap:** the kernel handles Router
  Advertisements (`accept_ra` 1) on the uplink, forwarding is on
  there (typically switched on later by Docker, libvirt or a
  VPN), and the IPv6 default route comes from RAs. The kernel
  then stops accepting RAs, and the route dies when its
  `expires` counter reaches zero, or already has. The fix is
  `accept_ra` 2 on the uplink, or a static IPv6 default route.
- Two managers claim the same interface.
- `/etc/resolv.conf` is a static file while the manager that is
  active also owns DNS: its settings are then silently ignored.
  It is not a finding where the manager hands DNS over by design
  — NetworkManager with `dns=none`, or systemd-resolved reached
  through `nss-resolve` in `nsswitch.conf` rather than through
  the file.
- Only nameservers of a family the host cannot reach, such as
  IPv6 resolvers on a host with broken IPv6.
- An A or AAAA record points at an address the host does not
  have; `rules/network-probe.md` → Public DNS view says what to
  record when the host's own address is private.
- IPv6 disabled by sysctl while an AAAA record is published or
  the manager configures IPv6.
- Several default routes in one family with equal metric.
- An address from the misread ranges above that has no place
  there.
- The uplink is down on a configured interface.
- No PTR, or a PTR without forward confirmation, on a public
  address of a host that sends mail (`memory.md` names an MTA).

**INFO**

- cloud-init owns the network configuration: edits go into
  `/etc/cloud/cloud.cfg.d/`, or cloud-init's network config is
  switched off first (the family file's cloud-init section).
- Temporary (privacy) IPv6 addresses on a server: the outgoing
  source address rotates and breaks allow-lists on the far side.
- An interface ID derived from the MAC (EUI-64): the address
  changes with the NIC and exposes the MAC.
- A server whose address depends on a DHCP lease.
- `/etc/resolv.conf` marked immutable.
- Only one upstream nameserver.
- No PTR on a public address of a host without an MTA.
- `hostname -f` does not return an FQDN, or it does not resolve.

## Before changing the network

The change goes through `rules/ssh-safety-net.md`, and the
loaded family file names the tool's check, apply and revert.
Beyond that:

- **Edit the owner's source, not its output:** the netplan YAML,
  not the generated `.network` file; the NetworkManager
  connection (`nmcli connection modify`), not
  `/etc/resolv.conf`; the cloud-init configuration when
  cloud-init owns the network.
- Know which way this session came in: a change to that
  interface or VPN is the one that cuts the session
  (`rules/ssh-safety-net.md` → Which way in).
