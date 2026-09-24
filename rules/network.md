# Network Profile

What Hostwarden records about a host's own network, and what
counts as a finding there. The profile answers five questions
before anyone touches the network:

1. **Who owns the configuration?** Which manager, which file,
   the hooks and scripts that run with it, and whether
   something regenerates it.
2. **What is the stack?** IPv4 and IPv6, which address ranges,
   static or dynamic.
3. **Does it work?** Default routes, name resolution, and
   outbound reachability per address family. Configured IPv6 is
   often broken IPv6.
4. **Does the outside agree?** A, AAAA and PTR records against
   the addresses the host really has.
5. **Which way does traffic run?** What comes in and goes out
   per family, through which NAT and policy rules, and which
   guest routes for whom.

Every probe for it is read-only.

## When

An `- IP:` that no longer matches stays with
`rules/dns-aliases.md`.

- **On connecting**, in the activity-check call
  (`rules/activity-check.md` → What rides in this call), to a
  host whose memory has no `- Network:` line, or one that is not
  a `managed by` line while its `network.md` has no
  `## Management`, or whose profile is marked
  `unchecked (needs root)` while memory records a working
  `Sudo: passwordless` or `Doas: passwordless`, or a `Sudo:`
  line that covers every command a section with reads marked so
  runs under `$SUDO`, as a rerun needs
  (`rules/privilege-escalation.md` → Stand-ins for sudo). The
  root SSH fallback is never tried for it, and where the probe
  finds that line no longer true, it corrects the line as that
  file says, which ends the retry.
  - **Linux:** the Linux probe's opening lines and sections A,
    B, C and F. They give `## Management`, and `## Traffic flow`
    where a trigger in the paragraph after this list applies.
    A workstation (`rules/role/workstation.md`) runs section A
    alone and gets Management alone.
  - **FreeBSD and macOS:** the family's probe, for
    `## Management`.
  - **An appliance or platform that owns its network** — every
    appliance with `Base: none`, and one whose file names its own
    tool or store as the owner (a web UI, middleware,
    `config.xml`, XAPI, Windows under WSL): no probe. The line
    names that owner: `- Network: managed by TrueNAS middleware`.
  - **Windows:** nothing is probed, written or looked for.

  What was not read for want of a privilege path, after the
  reruns sudo covers, is marked
  `unchecked (needs root)`, in the profile and on the line; a
  read that fails with one is `unread`. An overlay interface is
  named on the line (`overlay: wg0`); `rules/mesh-vpn.md` waits
  for the full profile. `Probed:` names what the profile
  records, `Probed: 2026-09-23 (Management, Traffic flow)`, and
  no list means the whole probe ran.
- **Full profile:** when the user asks about the host's
  addresses, IPv6, DNS resolution, outbound reachability or a VPN,
  and when a failure points at the network — a package mirror,
  `curl` or a DNS lookup that times out, or a stall in one address
  family only. Where `Probed:` names a part, it runs the whole
  probe, whatever the date.
- **On an onboarding the user asked for** (`hostwarden-onboard`),
  a first connection or a full re-probe (`rules/os-detection.md` →
  On subsequent connections): the full profile, its probe of the
  host in the activity-check call in place of any part On connecting
  would run there. A family or appliance On connecting probes nothing
  on gets nothing here either.
- **Before a change** to addresses, routes, interfaces, DNS
  resolution or the network manager: only who owns it. That is
  the Linux probe up to the end of section A, plus the first four
  commands of section D for a DNS change, or the family's `sysrc`
  or `networksetup` lines; then Before changing the network
  below.
- **Before a change** to NAT, forwarding, a bridge or policy
  routing, and before switching on anything that loads
  `br_netfilter` or sets `bridge-nf-call-*` to 1 on a host
  with bridged guests — a hypervisor's own firewall, a
  container engine, Kubernetes: the Traffic flow section,
  from the Linux probe without sections D and E, and every
  bridged NAT rule in it reported first (Findings).
- **After a change**, on a host whose memory has a profile: run
  again what its `Probed:` line covers, and update it in the same
  step.

A profile has a `## Traffic flow` section when the probe
shows any of: forwarding on in either family, a bridge with
guest ports, a NAT rule in any backend, `ip rule` beyond the
defaults, or a hook line or script that sets routes, rules or
filters. Otherwise it has none, and says nothing about traffic
flow.

A profile whose `Probed:` date is older than 90 days is refreshed
before it is relied on. The probes are in
`rules/network-probe.md`, one call per family.

A full profile is then folded into `memory/topology.md`
(`rules/network-topology.md`); the light profile On connecting
builds is not.

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

Before a full profile, the line names the manager and its
hooks:

```markdown
- Network: netplan → systemd-networkd, cloud-init, no hooks —
  see network.md
```

With a Traffic flow section, the line names the guest that
routes and the netfilter backend:

```markdown
- Network: dual-stack, inbound v4 to guest 100 (DNAT),
  iptables-legacy — see network.md
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
- Hooks: none
- Conflicts: none

## Interfaces
- Uplink: eth0, MTU 1500, physical
- Overlay: wg0 · Container interfaces: 3

## IPv4
- 203.0.113.10/32 static, public
- Default: via 192.0.2.1 dev eth0, MAC 00:00:5e:00:53:01

## IPv6
- 2001:db8:1:2::1/64 static, GUA
- Default: via fe80::1 dev eth0, static, MAC 00:00:5e:00:53:01
- RA: networkd (userspace), kernel accept_ra 0
- Forwarding: 0 · Temporary addrs: none

## DNS
- resolv.conf: symlink → systemd-resolved stub
- Upstream: 2 v4 + 1 v6 on eth0, link-provided
- Own name: hostname -f resolves to itself
- mDNS responder: none

## Public DNS (from workstation)
- A: matches · AAAA: matches
- PTR v4: host.example.com, forward-confirmed
- PTR v6: missing

## Findings
- INFO: no PTR for 2001:db8:1:2::1
```

The `Default:` lines carry the gateway's link-layer address where
the probe's neighbour read gave one, as `rules/network-probe.md`
reads it under Reading B, and `MAC not known` otherwise.

A mesh VPN interface or agent in the probe loads
`rules/mesh-vpn.md`, which adds a `## Mesh VPN` section.

On a host whose memory has a `Dynamic routing:` line
(`rules/network-topology.md` → Dynamic routing), the `## Stack`
and `## Traffic flow` sections describe the routing table as of
`Probed:`, and the profile says so with one line in `## Summary`:
`- Routing: dynamic (FRR: bgpd) — routes as of Probed:`.

Where When above calls for it, `## Traffic flow` follows
`## IPv6`, and `## Management` names every hook line that sets
something, with the script behind it. A hypervisor whose guest
firewall takes the public IPv4 traffic looks like this:

```markdown
## Management
- Manager: ifupdown2
- Source: /etc/network/interfaces
- Hooks: vmbr2 post-up/post-down → /usr/local/sbin/wan.sh
  (DNAT, MASQUERADE, policy routing); vmbr3 post-up (IPv6
  and ARP off)

## Traffic flow
- Forwarding: v4 on, v6 on
- Bridges: vmbr0 (eno1; host 192.168.1.10/24; guests 101,
  102) · vmbr1 (no port; host 10.0.0.1/30; guest 100) ·
  vmbr2 (eno2; host 203.0.113.10/32 peer 203.0.113.1,
  2001:db8:5::10/128; guest 100) · vmbr3 (no port; no host
  address; guest 100)
- Netfilter: iptables-legacy, nft empty; bridge-nf-call v4 0,
  v6 0
- Inbound v4: DNAT on vmbr2 to 10.0.0.2 (guest 100), except
  tcp/22 and tcp/8006 to the host
- Inbound v6: to the host, INPUT policy ACCEPT, no rules;
  web DNAT to 2001:db8:5:1::2 (0 packets)
- Outbound v4: host direct via vmbr2; 10.0.0.0/30
  masqueraded out vmbr2
- Outbound v6: direct via vmbr2
- Policy routing: from 192.168.1.10 to 10.0.0.0/8,
  100.64.0.0/10 → table fw, via 10.0.0.2 (guest 100)
- Router: guest 100 (DNAT target, next hop of table fw)
```

Name a guest only as Reading F of the probe ties it to a port.
A guest's own public address on a bridge is invisible from the
host; record it only when the user or the guest's memory says
so.

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
- `v4 + ULA`: IPv6 addresses from `fd00::/8` only. Without an
  IPv6 default route, IPv6 stays inside the site and has no
  global egress by design: record the failed IPv6 egress test,
  but the stack is not broken. With one, a router is meant to
  translate it (NAT66, NPTv6), which the host cannot see.
- Append `v6 broken` when an IPv6 default route exists, with a
  global address or a ULA, but the IPv6 egress test fails, and
  `no v6 route` when a global address exists without a default
  route.

Address ranges that are easy to misread:

- `100.64.0.0/10` is carrier-grade NAT on an uplink, and
  Tailscale's range on `tailscale0`, where it is an overlay.
- `169.254.0.0/16` as the only IPv4 address means DHCP failed.
- `fc00::/8` is undefined (only `fd00::/8` is ULA), and
  site-local, 6to4 and Teredo addresses are legacy.
- `192.0.2.0/24`, `198.51.100.0/24`, `203.0.113.0/24`,
  `2001:db8::/32` and `3fff::/20` are reserved for documentation
  and never belong on a real host: one there was copied from an
  example.

## Findings

The one list for the profile's `## Findings` section and for any
workflow that reports on a host's network. Severities follow the
housekeeping report format. A finding one of the user's decisions
settles is none (`rules/decisions.md` → Rating findings).

**CRITICAL**

- Name resolution fails: no egress target resolves in any
  family.
- **Bridged NAT with bridge-nf-call on:** a NAT rule of the
  host's own that a frame crossing a bridge with guest ports
  can match, while `bridge-nf-call` for that family is `1`.
  That is a DNAT or REDIRECT for traffic in on the bridge
  (`-i`, `iifname`, or no interface at all) not limited to
  the host's own addresses — by `-d` or `daddr`, a set of
  them, `-m addrtype --dst-type LOCAL` or
  `fib daddr type local` — or an SNAT or
  MASQUERADE out the bridge not limited to the sources the
  host routes (`-s`, `saddr`) — on the rule itself or on the
  jump that leads to it. The rule then rewrites the guests'
  own traffic across that bridge. The fix limits it: the
  host's address or the routed sources, or
  `-m physdev ! --physdev-is-bridged` in iptables.

A firewall that filters IPv4 but not IPv6 is the security audit's
finding, at its severities
(`.agents/skills/hostwarden-security/references/firewall.md` →
IPv6). That includes a host whose inbound IPv4 goes to a guest
firewall by DNAT while IPv6 reaches the host itself: the
Traffic flow lines show the split, and the audit rates what
listens behind it.

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
- The bridged NAT above while `bridge-nf-call` for that
  family is `0` or `absent`. It waits for whatever sets it
  to `1`: loading `br_netfilter`, which a container engine
  or Kubernetes may do, or a hypervisor firewall such as
  `pve-firewall` (`rules/appliance/proxmox-ve.md` → Replace:
  Firewall).
- NAT, a policy rule or a routing table that nothing the
  probe found restores at boot — no manager, hook, `unit`
  line or saved rule file (Reading B and F of the probe),
  and no firewall manager that holds it in its permanent
  configuration (firewalld's, `rules/firewalld.md`; ufw's
  `/etc/ufw/before.rules`, each read through `sed -E "${fc:?}"`,
  `rules/secrets.md` → Commands That Leak): it is gone after the
  next
  reboot. Ask the user what sets it before calling it
  hand-made.

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
- The whole rule set is in iptables-legacy and `nft` shows no
  tables. Record it under Netfilter: a check that reads only
  `nft` sees no rules there. Legacy rules next to
  nf_tables are the security audit's finding
  (`.agents/skills/hostwarden-security/references/firewall-nftables-docker.md`
  → Mixed frameworks).
- A NAT rule of the host's own, not one a container engine or
  hypervisor writes, with no match since it was loaded, or
  whose target is routed back out the interface the rule
  matched on (`route-to`): it does nothing, and neither do
  the FORWARD rules written for its target.

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
