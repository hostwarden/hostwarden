# Network Topology

What Hostwarden records about the networks its hosts share: which
IP ranges exist, which site and gateway each belongs to, whether
DHCP serves it, which DNS suffix applies there, and how the ranges
reach each other. It is read-only, built from what the hosts
already report and from the wider route capture in
`rules/network-probe.md`, and it depends on no external system.
An appliance that owns a network — a firewall, a gateway console —
adds what its own configuration says, where its appliance file's
configuration read supplies the fields; the store stands without
one, since every field has a value for "not known" that host data
alone can produce.

The store is `memory/topology.md`, a file of its own beside
`memory/network.md` (`rules/server-memory.md` → Cross-server
facts), so that a session looking up one shared fact does not load
the fleet's topology with it: current facts only, one line per
item, each with its sources and a date, created on first need.

## When

- **A host's full network profile** (`rules/network.md` → When)
  is folded into the store, as Folding a profile below says.
- **An appliance's configuration read,** where its appliance file
  has one, folds the appliance's ranges, VLANs, DHCP scopes and
  static routes the same way, and its WAN interfaces into the
  site's uplinks, at the moments that file names (Folding a
  configuration read below).
- **Never the fleet audit.** It writes no memory
  (`hostwarden-fleet-audit`), and it does not read the store.

## The store

Four sections, each in the shape of `## Management controllers`:

```markdown
## Sites
- home — the house and the garage rack (user, 2026-09-24)
  - uplink fw1 wan: dual-stack · IPv4 100.64.12.7 on the WAN,
    provider CGNAT (user) · IPv4 dynamic (changed 2026-09-20) ·
    IPv6 /56 delegated, dynamic (user) — from fw1 config;
    2026-09-24
- colo-fra — rented rack, Frankfurt (user, 2026-09-24)
  - uplink: dual-stack · IPv4 public on web1, web2, no NAT ·
    IPv4 static (user) · IPv6 prefix not known — from web1, web2;
    2026-08-30

## Ranges
- 192.0.2.0/24 — site home · VLAN 10 · static only (DHCP off) ·
  suffix corp.example.com (DHCP option) · gateway 192.0.2.1
  (fw1.example.com), MAC 00:1a:2b:3c:4d:01 — from fw1 config,
  pve1, nas1; 2026-09-24
- 198.51.100.0/28 — site colo-fra · VLAN not known · DHCP not
  known (hosts: 2 static) · suffix colo.example.com (observed,
  2 of 2 hosts) · gateway 198.51.100.1 (web1), MAC not known —
  from web1, web2; 2026-08-30
- 192.168.122.0/24 — host-internal on pve2 (virbr0, no port) —
  from pve2; 2026-09-10
- 192.168.1.0/24 — site not known · VLAN not known · DHCP seen
  (cam1 has a lease) · suffix not known · gateway 192.168.1.1
  (cam1), MAC 00:1a:2b:3c:4d:02 — from cam1; 2026-09-20

## Topology
- 192.0.2.0/24 → 10.8.0.0/24 via 192.0.2.5, LAN hop — from nas1;
  2026-09-24
- 192.0.2.0/24 → 10.8.0.0/24 on wg0, WAN — from pve1;
  2026-09-10
- 192.0.2.0/24 → 172.16.0.0/16 via 192.0.2.9, LAN hop, dynamic
  (bgp, as of 2026-09-24) — from rtr1
- 192.0.2.0/24, from 192.0.2.10 → 10.20.0.0/16 via 192.0.2.2,
  table fw, LAN hop — from pve1; 2026-09-19

## Topology findings
- WARN: nas1 routes 10.8.0.0/24 via 192.0.2.5 (pve1), and pve1's
  IPv4 forwarding is off (profile of 2026-09-10).
```

**`## Sites`** holds site names, the user's own words about each,
and each site's uplinks as sub-entries (Uplinks below), and
nothing else. The hosts at a site are found through
their `Site:` lines, and its ranges through their site field; a
host list here would be a second copy that drifts.

## Ranges

The fields of a `## Ranges` line, in this order. Each has a value
for "not known", so that a missing fact is never mistaken for a
negative one.

- **prefix:** an IPv4 or IPv6 prefix — the network of a host's
  address, its host bits cleared, at the address's prefix length,
  for every address Excluded from the store below leaves.
- **scope:** `site <name>` · `site not known` ·
  `host-internal on <host> (<bridge>, no port)`.
- **VLAN:** `VLAN <id>`, from an appliance or from the host's own
  tagged interface (the address sits on `eth0.10`, or on a bridge
  whose port is one) · `untagged`, from an appliance only ·
  `VLAN not known`. Both values, and a finding, where an appliance
  and a host disagree.
- **addressing, IPv4:** from an appliance, `DHCP <start>–<end>`,
  `DHCP on` where no range is readable, or `static only
  (DHCP off)`. From hosts alone, `DHCP seen (<host> has a lease)`
  or `DHCP not known (hosts: <n> static)`.
- **addressing, IPv6:** `SLAAC` · `DHCPv6` · `static`, per host
  from Reading B of the probe, with counts where the hosts
  differ.
- **suffix:** `suffix <domain> (DHCP option)` ·
  `suffix <domain> (observed, <n> of <m> hosts)` ·
  `suffix not known`. Both values, and a finding, where they
  differ.
- **gateway:** `gateway <address> (<host>), MAC <mac>`, naming
  the host where memory knows which one holds the address, and the
  link-layer address a later fold needs for Range identity (a); or
  `MAC not known`. From the appliance, or from the hosts' default
  routes whose next hop is inside the prefix, with the MAC from
  Reading B's neighbour read. An IPv6 default route's usual next
  hop is link-local (`fe80::…`), never inside the prefix: it is the
  gateway of the IPv6 range on the device the route leaves
  through, and is recorded with that device, since a link-local
  address means nothing without one:
  `gateway fe80::1 (link-local, eth0 on web1), MAC …`, with the
  holder in front where memory knows it,
  `gateway fe80::1 (fw1; link-local, eth0 on web1)`. With several
  gateways, each with its host count and MAC. Otherwise
  `no gateway seen`. A gateway that
  moves between hosts (Dynamic routing below) carries
  `(VRRP — moves between hosts)` after its MAC, which stays the
  VRRP group's virtual one regardless of which host holds it.
- **sources:** every host and appliance the line came from, and
  the newest date.

**Hosts alone never give `static only`.** A server with a fixed
address on a LAN that DHCP serves is the normal case, so hosts
with static addresses say nothing about whether the range has a
DHCP server. A lease proves that one exists (an address marked
`dynamic` in Reading B). Only an appliance proves that none does.

**The DNS suffix** comes from the DHCP domain option, where an
appliance sets one. Otherwise it is observed: the domain shared
by the `- FQDN:` lines (`rules/dns-aliases.md` → The FQDN) of the
hosts on the range, counted as `<n> of <m>`. It is never inferred
from an address. The DHCP option is often wrong or unset, so a
difference between the two is a finding, not a silent pick.

- It never feeds a host's own `- FQDN:` line, which stays what
  `rules/dns-aliases.md` makes it: the host's or the resolver's
  answer, or `none`/`unknown`.
- Its only consumer is the short-name candidate of
  `rules/dns-aliases.md` → Detection.
- A suffix is not a site signal. One fleet has one internal
  domain across every site and puts the site into a hostname
  prefix; another does the reverse, or neither. The suffix and
  the site are recorded as separate facts, and neither is derived
  from the other.

### Range identity

Two observations of the same prefix are one line only when:

- (a) they share the gateway address **and** its link-layer
  address — for a host, from the gateway MAC Reading B gives; for
  an appliance, from its own interface MAC — and neither host has
  a confirmed `Site:` that contradicts the other's;
- (b) the hosts are at the same site, confirmed by the user;
- (c) the user says the two are one network.

A link-local gateway counts for (a) by its address and MAC alone:
the device beside it is each host's own name for the link.

Observations that meet none of the three stay separate lines, each
marked
`same prefix as the line from <host>, not shown to be one
network`. A wrong split costs a question; a wrong merge pulls a
host at one site into the site, and the blast radius, of a router
at another. libvirt's `virbr0` is 192.168.122.0/24 on every
libvirt host, and consumer routers hand out 192.168.1.0/24 at
countless sites.

Some HA gateway pairs move one address between machines without a
virtual MAC (keepalived by default). A host then shows two MACs
for one gateway address. The line notes
`same gateway address, different MAC — an HA pair, or two
networks`, and the user is asked once.

Two hosts with confirmed, different `Site:` answers can still show
the same gateway address and MAC — two sites reusing one VRRP VRID,
for instance. (a) never merges them on that alone: they stay
separate lines, each marked
`same gateway address and MAC, sites <a> and <b> confirmed — ask`,
and the user is asked once. Neither host's `Site:` is touched.

A host-internal range — a bridge with no physical port (Reading F
of the probe), or libvirt's NAT network — is never merged and
never counts as a conflict.

### Excluded from the store

- every address of a `Role: workstation` host: a laptop's current
  Wi-Fi is not part of the fleet;
- an address on an interface of the tunnel class (Sites below): an
  overlay's entry in `memory/network.md` (`rules/mesh-vpn.md`)
  already is its topology entry;
- an address on `lo` or on a container or VM interface the probe
  leaves out (`$n` in the Linux probe);
- a `/32` or `/128` address, which is a host and not a range, and a
  link-local one.

### Topology findings

The only findings the store raises, with the severities of the
housekeeping report format:

- WARN: a route's next hop is a host in memory whose forwarding is
  off in that family (Reading C of the probe). The route cannot
  deliver.
- WARN: two sources give different prefix lengths for one range —
  hosts that satisfy identity (a), or an appliance and a host.
  Hosts on the range then disagree about which neighbours are on
  the link.
- INFO: the DHCP suffix and the observed suffix differ, or the
  VLAN from an appliance and the VLAN from a host differ.
- INFO: hosts on one range carry different `Site:` answers. That
  is a stretched L2 or a mistake, so ask; it is never an error.

These are **not** findings: a route that only one host has, two
hosts with different next hops to the same destination, and the
same prefix at two sites. Asymmetric visibility is two true facts,
recorded as such and never reconciled.

## Sites

A site is a place. `- Site: home (user)` is a plain memory line in
`memory.md`, owned by this file (`rules/server-memory.md` → Who
writes which line), in the same category as `Runs on:`. It is not
a decision (`rules/decisions.md`): it settles no finding and rules
out no proposal.

Two tiers only. A **LAN** is the network within a site. A **WAN**
is whatever links sites: a VPN today, historically a leased line
or MPLS. Nothing Hostwarden asks or records has a third tier.

**What Hostwarden can infer. Both are proposals, never
assignments:**

- **Together.** A host with addresses on two ranges, both on
  interfaces that are not tunnels, puts those ranges in one place:
  where the host is. The candidate groups are the connected
  components of that relation. An appliance's non-WAN interfaces
  count, because they are all on the appliance; a guest counts,
  because it sits at its host's site; overlay and host-internal
  ranges never join a group; an appliance's WAN interfaces never
  join one, since they face the ISP or another site, not the LAN.
  A component is confirmed only where every range already in it
  agrees on one site; a dual-homed host that joins ranges of two
  already-confirmed, different sites gives its component none, and
  The question below offers nothing from it.
- **Apart.** When a host terminates a tunnel and sends traffic for
  a range into it, that range lies on the far side of a WAN link
  from the host.

**Routes never form groups.** A route says a range is reachable,
not that it is here: behind the hub of a hub-and-spoke VPN sit
every spoke's ranges, a policy-based IPsec tunnel shows no
interface, and a leased line on a plain NIC looks like a LAN hop.
A range seen only as a route destination has no site until a host
on it is onboarded or the user names one. A stretched L2 (VXLAN,
or gretap in a bridge) is one range at two sites, the INFO finding
above.

The tunnel class is the overlay pattern `o` of `rules/mesh-vpn.md`
→ Probe (no root) plus `vxlan`, `gretap`, `geneve`, `gre`, `vti`
and `ipsec`.

**A guest's site is its host's.** A guest never gets a `Site:`
line of its own; its `Runs on:` line is read each time, as
`Management: guest (Runs on)` reads it, and for the same reason: a
copied value goes stale when the guest migrates.

### The question

- **When:** at a host's first full network profile, or an
  appliance's first configuration read, with a person present —
  onboarding, or a full profile or read of a host that has no
  `Site:` line yet.
- **What it offers,** never more than the three-option picker of
  `rules/ssh-user.md` → Interview format allows, and never more
  than one named site: the confirmed site of the host's component,
  where it has one — "web2 shares 192.0.2.0/24 with pve1 — at home
  too?" — or, with no confirmed component, the newest line in
  `## Sites` — "home?"; "another site"; "don't know". Where
  `## Sites` is empty and the host has no confirmed component,
  "another site" takes the first option's place and the picker has
  two options.
- **How:** `AskUserQuestion`, or the interview format of
  `rules/ssh-user.md` as the fallback. "Another site" asks for the
  name in the same exchange, listing every other known site to
  pick from and accepting a new one; a new name writes its
  `## Sites` line with the user's words. "Don't know" records
  `Site: unknown (user)`, as `Runs on: unknown (user)` does. That
  line is asked again only when the user names a site, or once
  when co-presence later gives the host's component a confirmed
  site it did not have at the time.
- **Never asked:**
  - on a run with nobody at the keyboard (a scheduled run, an
    agent of `rules/multi-host.md`): it writes
    `Site: unknown (not asked)`, as `Management:` does, and the
    next interactive full profile asks;
  - for a `Role: workstation` host;
  - for a guest;
  - on a plain connection.

## Uplinks

How a site reaches the internet, found out once and kept, so that a
later conclusion reads it here instead of probing again. Each uplink
is a sub-entry of its site's `## Sites` line: `uplink <router>
<interface>` for a router's WAN interface, one each where a site
has several (fibre and LTE, say), or `uplink` where only hosts were
seen. Its fields, in this order, each with a value for "not known":

- **stack:** `dual-stack` · `IPv4 only` · `IPv6 only` ·
  `IPv6 with DS-Lite` (IPv4 through the provider's AFTR) ·
  `not known`. Hosts give a family only by working egress in it
  (`rules/network.md` → Stack): one host with IPv6 egress proves
  the site has IPv6, and a host without it proves nothing about the
  line, so hosts alone never give `IPv4 only`, only `IPv4, IPv6
  not known`.
- **IPv4:** `public <address>` on the router's WAN ·
  `public on <host>, no NAT`, naming each host seen with a public
  address on its own interface, which says nothing about the
  site's other hosts · `<address> on the WAN`, where it
  is private or in `100.64.0.0/10` · `DS-Lite` · `not known`.
- **IPv4 lifetime:** `IPv4 dynamic (changed <date>)` ·
  `IPv4 static (user)` · `IPv4 dynamic (user)` ·
  `IPv4 not known`. An address can be seen changing, never seen
  staying put, and a DHCP or PPPoE WAN can carry a fixed address:
  `static` comes from the user alone.
- **IPv6 prefix:** `IPv6 /<n> delegated`, with its lifetime as for
  IPv4 — some providers rotate prefixes — or
  `IPv6 prefix not known`.
- **sources:** `<router> config` or the hosts, and the newest date.

**What an address range proves: nothing, on its own**
(`rules/network.md` → Stack, for the ranges easy to misread;
networks also use `100.64.0.0/10` as private space). A private
address on the WAN means another NAT upstream, a device of the
user's, such as an ISP router in front of their own firewall, or
the provider's; which, the address does not say. So it is recorded
as observed. Whose NAT it is — `provider CGNAT`, or a router of the
user's, `double NAT` — comes only from the user,
`provider CGNAT (user)`. An echo the user allowed that shows another
public address proves a NAT upstream and not whose:
`another NAT upstream (echo <date>)`. Only an interface with the
WAN role counts, as the router's appliance file names it; an
overlay interface never does.

### Where the facts come from

In this order. A later source fills only what an earlier one left
not known; the user's word stands until the user changes it.

1. **The site's router, where it is in memory:** its WAN interfaces
   from its configuration read. A WAN address or delegated prefix
   other than the one recorded writes `dynamic (changed <date>)`.
2. **The hosts at the site:** their profiles' stack and egress
   lines (`rules/network.md`), and a public IPv4 address on a
   host's own interface, which gives `public on <host>, no NAT`
   for that host alone.
3. **The path hint** (`rules/network-probe.md` → Path hint), only
   where no router of the site is in memory: what it saw goes into
   the question below, never into the entry.
4. **The user**, asked once per site (below).
5. **An echo of the public address**, only where the user allows it
   for that site and names the service: it shows whether another
   NAT sits upstream of a WAN address that is private, never whose
   it is. It runs from a host at the site whose route there
   does not leave through an overlay, as the path hint checks.

### The uplink question

- **When:** in onboarding's step 6 (`hostwarden-onboard`),
  together with `Site:`, at the first onboarding at a site with a
  person present — where the site's entry has no field from the
  user yet — and never where The question above is never asked: a
  run with nobody at the keyboard records what sources 1 and 2
  show.
- **What:** what sources 1 to 3 found, then whether the IPv4
  address is static or dynamic, whose NAT sits upstream — none, a
  router of the user's, or the provider's — and, where the site has
  IPv6, whether its prefix is static. `AskUserQuestion`, or the
  interview format of `rules/ssh-user.md`. "Don't know" records
  `not known (user)`, which counts as asked.

`rules/firewall-changes.md` reads the entries before an inbound
exposure, and `rules/network.md` → Findings for a host that sends
mail directly.

## Edges

An edge is one line of `## Topology`: from-range, destination,
next hop or tunnel interface, tag, reporting host and date.

- **from-range** is the range of the reporting host's address on
  the egress interface.
- **The tag** describes that host's egress only:
  - `LAN hop`: the next hop is on a directly attached segment
    that is not a tunnel;
  - `WAN`: the host sends the traffic into a tunnel or overlay it
    terminates, into an IPsec table, or out an appliance's WAN
    interface.

  nas1's route via pve1 is a LAN hop, even though pve1 sends the
  traffic on over WireGuard. Both edges are recorded, and a reader
  follows the chain.
- **What else becomes an edge:**
  - a multipath (ECMP) route's several `nexthop` lines, joined to
    one prefix in the probe's output (Reading B), each become their
    own edge from the same from-range;
  - routes from the policy-routing tables, which Reading B already
    captures, with their selector: `from 192.0.2.10 → …, table fw`.
    A table's line beyond the first three (Reading B) becomes one
    edge, `<host>, table <t>: <n> routes, not fully recorded`,
    instead of its individual routes;
  - a route over a mesh VPN interface, only where it is a subnet
    route; per-peer routes do not, and the network's entry in
    `memory/network.md` holds the rest. An edge through a Tailscale
    subnet router carries the router's `SNAT on`, `SNAT off` or
    `SNAT not known` from its Mesh VPN line (`rules/mesh-vpn.md` →
    Per agent);
  - a `proto dhcp` or `proto ra` route, recorded as `(from DHCP)`
    or `(from RA)`: DHCP option 121 pushes such static routes.
- **Default routes are not edges.** They fill the gateway field of
  `## Ranges`.

## Dynamic routing

In scope: detection, and what a reader may conclude. Peering
state, areas and route redistribution are not recorded.

- **Per route, on Linux:** a route whose `proto` is `bgp`, `ospf`,
  `isis`, `rip`, `eigrp`, `babel`, `openr`, `zebra`, `bird`,
  `keepalived`, `gated`, `mrt`, `xorp`, `dnrouted` or `ntk` is
  dynamic. FreeBSD and macOS record no origin per route, and
  BusyBox `ip` prints none: there, every non-default route counts
  as dynamic where a routing daemon runs, and as static where
  none does.
- **Per host,** the routing-daemon lines of the probe, a process
  check in the shape `rules/mesh-vpn.md` uses for agents. A hit
  writes `- Dynamic routing:` in `memory.md`, owned by this file:

  ```markdown
  - Dynamic routing: FRR (bgpd, ospfd)
  - Dynamic routing: bird
  - Dynamic routing: keepalived (VRRP)
  ```

  `watchfrr` and `zebra` with any of `bgpd`, `ospfd`, `ospf6d`,
  `isisd`, `ripd`, `ripngd` or `babeld` are FRR, named with the
  daemons; `bird` or `bird6` is bird; `keepalived` and `vrrpd` are
  VRRP. A full profile that finds none removes the line.
- **VRRP moves addresses between machines.** A range whose
  gateway sits on a host with `keepalived (VRRP)`, or whose
  gateway MAC is `00:00:5e:00:01:<vrid>` for IPv4 or
  `00:00:5e:00:02:<vrid>` for IPv6 (the VRRP virtual MAC of RFC
  5798), gets `(VRRP — moves between hosts)` on its gateway field.
- **The signal for readers.** A dynamic edge reads
  `dynamic (<proto>, as of <date>)`. It says only that the path
  existed then. It is never evidence that a path does not exist,
  and at no age does it count as current: a consumer that needs
  the path as it is now reads the host live. A dynamic edge may
  add a host to a blast radius; a missing one never removes one.
  The 90-day rule applies in neither direction. The quick check
  of `rules/network.md` reads only default routes and does not
  notice a changed dynamic route.
- **More than 50 routes:** no edges are recorded for that host.
  Its `## Topology` line says
  `<host>: <n> routes, not recorded (dynamic)`. A full BGP table
  is not topology Hostwarden keeps.

## Folding a profile

After a host's full profile is written, from Reading B of the
probe and the profile itself, in one edit of `memory/topology.md`:

1. **Skip** what Excluded from the store lists.
2. **Ranges.** For each remaining address, one range with the
   fields Ranges lists, from this host's profile — the gateway's
   MAC from the `Default:` line Reading B's neighbour read wrote.
   A bridge without a physical port (Reading F) or libvirt's
   `virbr0` makes it host-internal; otherwise the scope is the
   host's `Site:` (a guest's: its host's, through `Runs on:`), or
   `site not known`.
3. **Identity.** Match each range against the lines of the same
   prefix already there, by Range identity: merge under (a), (b)
   or (c), otherwise add a line marked as separate, and ask the
   HA-pair question where a merged line's gateway shows a second
   MAC.
4. **Edges.** Each main-table route the probe printed, and each
   policy-table route, becomes an edge as Edges says; a host with
   the routes-count line over 50 gets the `not recorded` line
   instead, and a policy table beyond its first three routes gets
   the `not fully recorded` line.
5. **Dynamic routing.** Write or remove the `Dynamic routing:`
   line from the process check, and mark the edges and gateways
   Dynamic routing says.
6. **Uplink.** Where the host has a confirmed `Site:` (a guest:
   its host's), update the site's uplink entry from Uplinks →
   Where the facts come from, source 2.
7. **Findings.** Rewrite `## Topology findings` from the lines as
   they now stand: a finding whose cause is gone goes with it.
8. **Sources and date** on every line the host fed: the host's
   name, and today's date where it is the newest.

The host's old contributions are replaced, not appended: a range
or edge the profile no longer shows loses this host as a source
(Pruning below).

## Folding a configuration read

After an appliance's configuration read (its file's
`## Network configuration read`), in one edit of
`memory/topology.md`, with `<appliance> config` as the source.

**A read that did not run is not an appliance with no networks.**
Where OPNsense or pfSense printed `config=unknown(needs-root)`
(`rules/appliance/opnsense.md` → Network configuration read), or
UniFi's SSH read's `db` line carries an `exit` other than `0`
(`rules/appliance/unifi-os.md` → Over SSH), skip the fold for the
whole appliance this round: leave its existing ranges, edges and
uplink entry exactly as they stand, rather than pruning them for
lines the read never printed. Where UniFi's API read's
`rest/networkconf` or `rest/routing` call for one site comes back
under `missing` or with a `code` that is not `2xx`
(`rules/appliance-api.md` → Reading), skip the fold for that site
alone; the appliance's other sites fold as usual.

`"db": "none"` is not a failure of the SSH read: it is the trigger
for the fallback UniFi's Over SSH goes on to describe, which folds
as usual for the console's own site alone. Skip the fold for every
other site the console manages, which the fallback does not reach,
the same as a failed API call above, rather than pruning their
existing ranges, edges and uplink entries for a read that never
covered them.

1. **Ranges.** Each interface or network that the read shows
   enabled, is not a WAN and has an address gives one range, at the
   appliance's `Site:`:
   - VLAN `VLAN <tag>` where it sits on a VLAN, `untagged`
     otherwise;
   - IPv4 addressing from the scope of the DHCP server that runs,
     `DHCP <start>–<end>`, or `static only (DHCP off)` where that
     server has no enabled scope there or none runs; where the read
     could not tell which server runs, `DHCP not known`;
   - the scope's domain name as `suffix <domain> (DHCP option)`;
   - the appliance's own address on it as the gateway, with the
     interface's MAC where the read gives one.

   A UniFi console's other UniFi sites are places of their own:
   their ranges stay `site not known` until the user names each,
   and The question offers the UniFi site's name.
2. **Identity,** as Folding a profile step 3: the appliance's line
   and the hosts' lines of one range merge under (a), gateway
   address and MAC.
3. **Edges.** Each enabled static route, from the range of the
   interface its gateway lies on, tagged `LAN hop`, or `WAN` where
   that interface is a WAN or a tunnel.
4. **Uplinks.** Each WAN interface updates its uplink entry at the
   appliance's site, source 1 of Uplinks.
5. **Findings, sources and date,** as Folding a profile steps 7
   and 8.

The appliance's old contributions are replaced as a host's are.

## Pruning and staleness

- **A line with no source left is deleted,** in the edit that
  took the last one away: a fold that replaced it, or a host's
  memory directory going away, which takes the host off every line
  in the same edit, as `## Management controllers` does with its
  rows. A site with no host and no range left stays: it is the
  user's word. So does an uplink field the user gave; a field whose
  source is gone goes back to `not known`, and an uplink entry with
  no source and no field from the user left is deleted.
- **A host's `Site:` changes:** the site field of every line it
  feeds is rewritten in the same edit, and, for a line of the same
  prefix that stayed separate only for having no confirmed site to
  match (Range identity (b)), Identity runs again: a new match
  merges them as Folding a profile step 3 would, and the INFO
  finding for hosts on one range with different `Site:` answers is
  rewritten with the rest of `## Topology findings`.
- **Staleness.** A report or an answer that rests on a line whose
  newest source is over 90 days old says so as
  `rules/server-memory.md` → Onboarded and stale lines says, and
  one that has to be right refreshes that source's profile first.
  Dynamic edges are never current at any age (Dynamic routing
  above).
