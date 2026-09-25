# DNS

Where the fleet's names come from, how Hostwarden proposes the
records a host or a service needs, and what it checks, read-only,
across the servers that answer them. Hostwarden writes no DNS record
itself: every record set it proposes goes to the user, whatever the
name space's line in `memory/dns.md` allows.

A host's own A, AAAA and PTR records against its addresses stay with
`rules/network-probe.md` → Public DNS view, and `- IP:` with
`rules/dns-aliases.md` → IP Verification.

## When

- **Onboarding a host that runs a DNS server** (`hostwarden-onboard`
  step 5): Reading a DNS server below, which writes its name spaces
  into `memory/dns.md` and its `DNS server:` line.
- **Housekeeping on a host with a `DNS server:` line:** the same
  read, which keeps its lines current, and the checks of Checks →
  Where they run.
- **A proposal is due:** `hostwarden-new-guest` → Name, a rename
  (`rules/host-rename.md` → The Order), and a network-facing service
  the user asked to install that needs a name of its own. The record
  convention and The proposal below.
- **The fleet audit:** the comparison of a resolver set
  (`.agents/skills/hostwarden-fleet-audit/references/probes.md` →
  DNS resolver sets). It reads `memory/dns.md` and writes nothing to
  it.
- **On request:** the DNSSEC chain of a zone, a provider's zone, or
  a name space nobody has described yet.

## Where a name comes from

A **name space** is a zone, or the part of one that a given source
answers. Each has exactly one of three sources, and the source
decides what a record there is and how it can be changed:

1. **A zone on an authoritative server.** It has SOA and NS records,
   a serial, transfers to secondaries, and it can be signed. The
   server is the user's own — BIND, PowerDNS, Knot, NSD, an Unbound
   `auth-zone`, Windows DNS — or a provider's: Cloudflare, Hetzner,
   INWX, or the registrar. Resolvers reach it by recursion, or by a
   forward or stub zone (conditional forwarding).
2. **Records injected into a resolver:** Unbound `local-data`,
   dnsmasq `host-record` and `address=`, Pi-hole's local DNS, AdGuard
   Home rewrites, the host overrides of OPNsense and pfSense, the
   local records of UniFi. They have no zone, no serial, no transfer
   and no signature, and nothing keeps two resolvers' copies alike.
3. **Names that DHCP registers.** dnsmasq, Pi-hole and OPNsense
   register client names themselves, or Kea sends dynamic updates to
   a zone. Nobody wrote them by hand.

A name space may also be answered in **views**: one server gives
internal clients other answers than external ones (BIND views,
Unbound views). **Split-brain** is the same zone name on two separate
servers, one internal and one public. Both are recorded view by view.

## The inventory

`memory/dns.md`, created on first need, shared in team mode
(`rules/server-memory.md` → Personal versus shared). Current facts
only, one line per name space, in the shape of `memory/network.md`'s
entries, and a findings section:

```markdown
# DNS

## Name spaces
- example.com — zone at Cloudflare (NS *.ns.cloudflare.com) ·
  signed by Cloudflare, DS at the registrar · managed: Cloudflare
  UI (user, 2026-09-24) · Hostwarden: propose — from NS records;
  2026-09-24
- int.example.com — zone on ns1.int.example.com (BIND, primary,
  static file), secondary ns2.int.example.com · views: internal
  (10.0.0.0/8), external (any) · signed on ns1, keys in
  /var/lib/bind, DS in example.com · resolved by pihole1, pihole2
  (forward to ns1) · managed: ns1 (Hostwarden) · Hostwarden: write
  (user, 2026-09-24) — from ns1, pihole1, pihole2; 2026-09-24
- home.arpa — resolver records on pihole1, pihole2 (Pi-hole local
  DNS), DHCP names from pihole1 · unsigned · resolved by pihole1,
  pihole2 (local data) · managed: pihole1, pihole2 (Hostwarden) ·
  Hostwarden: propose — from pihole1, pihole2; 2026-09-24

## DNS findings
- WARN: pihole1 answers wiki.int.example.com from a local record
  (10.0.0.30); ns1.int.example.com, which it forwards
  int.example.com to, answers 10.0.0.31 (housekeeping, 2026-09-24).
```

The fields, in this order. A field whose value is not known reads
`<field> not known`, so that a missing fact is never read as a
negative one; only `views:` is left out, where the server has none.

- **source:** one of the three above. For a zone: its primary and
  secondaries, whether the primary is hidden, and how the server
  holds the zone — static file, dynamic, inline-signed, database.
  For resolver records: every resolver that carries them — together
  a **resolver set**, which the fleet audit compares. For DHCP
  names: the server that registers them.
- **views:** each view and the clients it matches.
- **DNSSEC:** `unsigned`, or who signs and where the keys are — the
  location only, never key material — and whether a DS stands at
  the parent.
- **resolved by:** the resolvers clients use for this name space, and
  how each answers it: from local data, by forwarding it to a
  server, or by recursion. From the reads of those resolvers (a
  forward zone, a stub zone, a local record), and from an appliance
  file's configuration read where it names the DNS servers its DHCP
  hands out.
- **managed:** where the user changes the name space — a web UI, an
  API, code (Terraform or OpenTofu, octoDNS, DNSControl, Ansible), or
  a host Hostwarden manages. Observed where a host shows it — a
  `Config management:` line, or a header in the zone file that names
  a tool (`rules/config-management.md`) — and otherwise asked once,
  when the name space's first proposal is due.
- **Hostwarden:** `propose`, the default, or `write`, set only on the
  user's word, per name space, with who and the date. It records what
  the user allows, not what Hostwarden does (the opening of this
  file). A name space managed as code is never `write`: a direct
  change would drift from the code, and the next `apply` would undo
  it.
- **from:** the hosts and appliances the line was read from, or
  `NS records` for a provider's zone, and the newest date.

**Every value is observed or asked, never inferred.**

- A public zone's NS records name its provider
  (`dig +short NS example.com` from the workstation:
  `*.ns.cloudflare.com` is Cloudflare). Nothing else names one: not
  an address range, not a registrar's name in WHOIS.
- A DNS server Hostwarden manages is read as Reading a DNS server
  says.
- A name space nobody has described is asked about when it is first
  needed: a proposal is due in it, or the user asks. Ask for the
  source, and for a provider's zone where it is managed; write the
  line with `(user, <date>)` on each answer. A run with nobody at the
  keyboard asks nothing: the field reads `not asked`, and the next
  interactive run that needs it asks.

**Who keeps the lines current.** Onboarding and housekeeping rewrite
the lines of the DNS servers they read: the fields that server
shows, and its name under `from:`. A provider's zone is checked only
on request, since no host run covers it.

**Pruning.** A read that no longer shows a name space takes the
server off that line's `from:` in the same edit. A line with nothing
left under `from:` is not deleted silently: `managed:` and `Hostwarden:` are
the user's words. Report it, and delete it on the user's word. A
host's memory directory going away takes the host off every line in
the same edit.

**Staleness.** An answer or a proposal that rests on a line whose
newest `from:` date is over 90 days old says so, with its age and the
run that refreshes it, in the form `rules/server-memory.md` →
Onboarded and stale lines gives; one that has to be right reads the
server again first.

`## DNS findings` holds the findings of the reads that keep the
lines, rewritten from them as they now stand: a finding whose cause
is gone goes with it.

## Reading a DNS server

Read-only, as root or through `$SUDO`
(`rules/privilege-escalation.md` → Stand-ins for sudo), in one call
where the products allow it. Configuration files hold TSIG keys, API
keys and password hashes: every command below prints named options
or zone data, never a whole file (`rules/secrets.md`).
`named-checkconf -p` in particular prints every `secret`, so it is
only ever read through the `sed` below. Check each command against
the host's `--help` first (`AGENTS.md` → Verify Before Running): the
forms below are those of BIND 9.20, Unbound 1.22, NSD 4.12, Knot 3,
PowerDNS 4.9 and Pi-hole 6.

**Detection,** by program name, and what listens on port 53. It
rides in a call the run already makes. Pi-hole and AdGuard Home in a
container or a snap are found by the probe of
`rules/service-class-check.md` → Installer and container members,
and read through `docker exec`:

```bash
r='named|pdns_server|knotd|nsd|unbound|dnsmasq|pihole-FTL'
r="$r|AdGuardHome|kea-dhcp4|kea-dhcp6"
ps -Ao comm= 2>/dev/null | sed 's|.*/||' | sort -u | grep -xE "$r"
ss -Hlnu 'sport = :53' 2>/dev/null || sockstat -l -p 53 2>/dev/null ||
  netstat -lnu 2>/dev/null | grep -E '[:.]53 ' ||
  netstat -an -p udp 2>/dev/null | grep -E '[.]53 '
```

`netstat -lnu` is the BusyBox path, on Alpine without `iproute2`;
`netstat -an -p udp` is macOS's, where `-l` and `-u` mean other
things. A
product that listens on loopback alone serves only its host: it gets
no line and no `DNS server:` line.

A router appliance (an `Appliance:` line) is read through its
appliance file's configuration read, for its host overrides and DHCP
names, where that file has one. Where it has none, and for any other
product — pdns-recursor, Knot Resolver, Windows DNS — the name spaces
come from the user, the host gets no `DNS server:` line, and the
checks of its records report `not checkable` rather than guess a
command.

**BIND.** The zones with class, view and type (`primary`,
`secondary`, `forward`, `stub`, `static-stub`, `mirror`); the
clients each view matches, with the ACLs they name; the forwarders;
the signing policy; and for each primary or secondary zone the lines
of `rndc zonestatus` that say how it is held and whether it is
signed. A server without views names its view `_default`:

```bash
named-checkconf -l
named-checkconf -p | sed -n -e '/^acl /,/^}/p' -e '/^view "/p' \
  -e '/match-clients {/,/}/p' -e '/^[[:space:]]*zone "/p' \
  -e '/forwarders {/,/}/p' -e '/dnssec-policy/p' \
  -e '/inline-signing/p' -e '/key-directory/p'
named-checkconf -l | while read -r z c v t; do
  case $t in primary|secondary) ;; *) continue ;; esac
  echo "@zone $z $v"
  rndc zonestatus "$z" "$c" "$v" |
    grep -E '^(type|files|dynamic|secure|inline signing):'
done
```

**Unbound.** Local zones and records, forward and stub zones, auth
zones and views, from the files, and from the files an `include`
line names outside the directory, one level deep. On FreeBSD's base
system the directory is `/var/unbound`, from ports
`/usr/local/etc/unbound`:

```bash
k='include|include-toplevel|local-zone|local-data|local-data-ptr'
k="$k|forward-zone|stub-zone|auth-zone|view|name|forward-addr"
k="$k|forward-host|stub-addr|stub-host|domain-insecure"
k="$k|access-control-view|trust-anchor-file|auto-trust-anchor-file"
d=/etc/unbound
f=$(grep -rhE '^[[:space:]]*include(-toplevel)?:' "$d" |
  sed -E 's/^[^:]*:[[:space:]]*"?([^"]*)"?[[:space:]]*$/\1/')
t='[[:space:]]+(([0-9]+|IN)[[:space:]]+)*(A|AAAA|CNAME)[[:space:]]'
q="[\"'][^[:space:]\"']+"
grep -rE "^[[:space:]]*($k):" "$d" $f |
  sed -E -e "/local-data:[[:space:]]*$q$t/b" \
    -e "s/(local-data:[[:space:]]*$q).*/\1 (value withheld)/"
```

`$f` stays unquoted so that a glob in an `include` line expands. An
`include` line in those files names a further file, which is listed
for the user rather than read. A `local-data` record of any type but
A, AAAA and CNAME prints its name alone: a TXT record can carry a
token (`rules/secrets.md` → Commands That Leak).

**dnsmasq.** It also serves `/etc/hosts` unless `no-hosts` is set,
and the files `addn-hosts` names:

```bash
k='address|host-record|cname|server|local|domain|auth-zone'
k="$k|auth-server|dhcp-range|addn-hosts|expand-hosts|no-hosts"
grep -hE "^($k)(=|$)" /etc/dnsmasq.conf /etc/dnsmasq.d/* 2>/dev/null
```

**Pi-hole.** Its records, CNAMEs, conditional forwarding, upstreams,
local domain, DHCP, and the dnsmasq lines it adds, one full key each
(`.agents/skills/hostwarden-housekeeping/references/service-checks.md`
→ Pi-hole). Before FTL 6.1 the domain key is `dns.domain`. Where
`misc.etc_dnsmasq_d` is `true`, `/etc/dnsmasq.d` is read as for
dnsmasq above:

```bash
for k in dns.hosts dns.cnameRecords dns.revServers dns.upstreams \
    dns.domain.name dhcp.active misc.etc_dnsmasq_d; do
  echo "@$k"; pihole-FTL --config "$k"
done
k='address|host-record|cname|server|local|domain|auth-zone'
echo "@misc.dnsmasq_lines"
pihole-FTL --config misc.dnsmasq_lines | grep -oE "($k)=[^\"',]*"
```

`misc.dnsmasq_lines` holds any dnsmasq line the user added, a
`txt-record=` among them, so only the keys dnsmasq's read takes come
out of it.

**AdGuard Home.** Rewrites, and upstreams that forward one domain
(`[/int.example.com/]10.0.0.2`), with `C` set as its housekeeping
section says:

```bash
grep -A2 -E '^ +- domain:' "$C"
grep -E "^ +- '?\[/" "$C"
```

**NSD** (`/usr/local/etc/nsd/nsd.conf` on FreeBSD). `zones` is a
special value of `-o` that lists the configured zones
(nsd-checkconf(8)), not an option of that name:

```bash
nsd-checkconf -o zones /etc/nsd/nsd.conf
nsd-checkconf -z int.example.com -o zonefile /etc/nsd/nsd.conf
```

**Knot:**

```bash
knotc conf-read zone.domain
knotc conf-read zone.dnssec-signing
knotc zone-status
```

**PowerDNS:** `pdnsutil list-all-zones`, and `pdnsutil show-zone
<zone>` for whether it is signed; the keys it prints are public.

**Kea** (`/usr/local/etc/kea` on FreeBSD). It sends dynamic updates
only where `enable-updates` in its `dhcp-ddns` section is `true`, and
not for a scope whose `ddns-send-updates` is `false`; the zone they
go to follows from `ddns-qualifying-suffix`. `kea-dhcp-ddns.conf`
holds TSIG secrets and is not read, and neither is the rest of these
two files:

```bash
k='enable-updates|ddns-send-updates|ddns-qualifying-suffix'
grep -nE "\"($k)\"" /etc/kea/kea-dhcp4.conf /etc/kea/kea-dhcp6.conf \
  2>/dev/null
```

A subnet or shared network can set `ddns-send-updates` and
`ddns-qualifying-suffix` over the global values, and a line alone
does not show which scope it belongs to. Where either appears more
than once in a file, name the values to the user and ask which zones
receive updates, rather than read one scope's value as the whole
server's.

**What is recorded.** For each name space the server holds: its
line as The inventory says, the server under `from:`. A forward
or stub zone is not a name space of this server: it adds this server
to the `resolved by:` of the line it points at, the target named by
the host whose `- IP:` holds the address, or by the address where no
host does. The host's `memory.md` gets one line, owned by this file.
It says that the host answers name spaces for others, where
`DNS resolver:` (`rules/service-class-check.md`) names only the
product installed:

```markdown
- DNS server: BIND — name spaces in memory/dns.md (read 2026-09-24)
```

A read that finds no DNS server any more removes the line, and
takes the host off `memory/dns.md` as Pruning says.

### Records

The checks read the records themselves, not only the name spaces:
A, AAAA and CNAME records, one `name type value` line each, and
nothing else of a zone. A zone's other records can carry a token — a
TXT for an ACME challenge or a site verification — so every zone
read below is piped through the type filter on the host, and nothing
else of it is printed (`rules/secrets.md` → Commands That Leak):

```bash
grep -E '[[:space:]](A|AAAA|CNAME)[[:space:]]'
```

The records stay on the host: a check filters them there, in the
same call, and prints only what it reports, with a count of the
rest, since a zone of thousands of names would otherwise fill the
conversation.

- **BIND:** `named-checkzone -D -j -o - <zone> <file>`, the file from
  the zone's `files:` line; a secondary's file is usually raw, read
  with `-f raw` as well.
- **Unbound, dnsmasq, Pi-hole, AdGuard Home:** the `local-data`,
  `address`, `host-record`, `cname`, `dns.hosts`, `dns.cnameRecords`
  and rewrite lines the read above printed, and for dnsmasq
  `/etc/hosts` and each `addn-hosts` file unless `no-hosts` is set,
  their comments cut:
  `sed -e 's/#.*//' -e '/^[[:space:]]*$/d' /etc/hosts`.
- **Knot:** `knotc zone-read <zone>`. **PowerDNS:**
  `pdnsutil list-zone <zone>`. **NSD:** the zone file
  `nsd-checkconf` named, through `named-checkzone -D -o -` where it
  is installed.
- **A router appliance:** what its appliance file's configuration
  read gives; without one, the checks report `not checkable`.
- **DHCP names:** dnsmasq's lease file
  (`/var/lib/misc/dnsmasq.leases` on Debian) and Pi-hole's
  (`/etc/pihole/dhcp.leases`), address and name only:
  `cut -d' ' -f3,4`.

## The record convention

**A host's own name:** A and AAAA for its FQDN, in the fleet's
domain where memory records a naming scheme, and otherwise in the
domain its `- FQDN:` line observed (`rules/dns-aliases.md` → The
FQDN). A PTR goes in a reverse zone the user runs. Resolvers serve
the private reverse zones (`10.in-addr.arpa`, `168.192.in-addr.arpa`,
`d.f.ip6.arpa`, …) empty by default (RFC 6303), so a PTR for a
private address needs a local reverse zone or a resolver record, and
the proposal says which.

**A service name:** a CNAME to the host's FQDN, so that the address
is kept in one record, and a rename or a move changes one target.
The exceptions, where it is A and AAAA:

- **The zone apex.** A CNAME cannot share a node with other data
  (RFC 1034 §3.6.2, RFC 2181 §10.1), and the apex always holds SOA
  and NS. Where Hostwarden sees a provider or server with a
  mechanism for it — from the NS records or a host it manages — it
  proposes that instead:
  - Cloudflare flattens a CNAME at the apex on every plan, and every
    CNAME on paid plans;
  - PowerDNS has ALIAS from 4.1, where the server sets `resolver`
    and `expand-alias=yes`;
  - DNSimple and NS1 have ALIAS;
  - a Route 53 alias works only to AWS resources or to records in
    the same hosted zone.

  It never guesses a provider's mechanism from anything else.
- **An MX or NS target** must not be an alias (RFC 2181 §10.3), and
  neither may an **SRV target** (RFC 2782).
- **Resolver records** (source 2) follow a CNAME only as far as the
  product does: dnsmasq and Pi-hole answer one only to a name they
  know themselves. Where the target is not a name the resolver
  carries, the proposal is an A or AAAA record, and it says that the
  address is then kept twice.

**A dynamic address.** Where the user says, or memory records, that
the address of a site's uplink is dynamic, its record is kept by a
DDNS client on the router or the host, not written once. Service
names stay CNAMEs to that name, so nothing else changes when the
address does. The proposal says so, rather than proposing an A record
that goes stale.

**Views.** Every proposed record names its view. A private address —
RFC 1918, a ULA (`fc00::/7`), `100.64.0.0/10` — goes into internal
views only. One proposed for an external view or a public zone is
refused and named, unless the user confirms it outright.

## The proposal

The exact record set, ready to paste, and nothing else: name, type,
target or address, view, zone, and every server it goes to, in the
form the name space's `managed:` field takes. A name space managed as
code gets it in that code's terms where the user shows the file, and
as the record set otherwise.

```text
int.example.com, view internal — on ns1.int.example.com (primary;
ns2 follows by transfer):
  web2.int.example.com.  A      10.20.0.10
  wiki.int.example.com.  CNAME  web2.int.example.com.
10.in-addr.arpa, local reverse zone — on ns1.int.example.com:
  10.0.20.10.in-addr.arpa.  PTR  web2.int.example.com.
```

A resolver set gets the same lines once per member, each member
named, since nothing copies them from one to the next.

- **Where no line describes the name space,** it is asked about first
  (The inventory).
- **Hostwarden writes none of it,** in any name space: the user adds
  the records, and says when. Then the name is resolved through the
  resolvers the `resolved by:` field names, not only at the
  authoritative server. A name that was asked for before it existed
  stays a negative answer in a resolver's cache until the SOA's
  negative TTL runs out (RFC 2308): the report says so, rather than
  that the name does not resolve.
- **Only the records the set-up needs,** never one Hostwarden thinks
  up beside them.
- **A rename** (`rules/host-rename.md` → The Order) gets two sets:
  the new name's records to add, and later the old name's to remove,
  the PTR's new target, and every CNAME that targets the old name,
  retargeted. Those CNAMEs are the ones the Records below show on the
  DNS servers memory names; the set says that others, at a provider
  or on a server Hostwarden does not read, are the user's to find.

## Checks

Findings with the severities of the housekeeping report format. A
finding a decision settles is none (`rules/decisions.md` → Rating
findings).

**CRITICAL**

- No DS at the parent matches a key of the zone. Every validating
  resolver then fails the whole zone. A key tag only names a key, so
  the comparison is the whole DS: from the workstation, the parent's
  DS set, and the DS records derived from the zone's DNSKEY set at
  one of its own servers, in every digest type the parent uses:

  ```bash
  dig +short +nosplit DS int.example.com
  dig +noall +answer DNSKEY int.example.com @ns1.int.example.com |
    dnssec-dsfromkey -a SHA-1 -a SHA-256 -a SHA-384 \
      -f - int.example.com 2>/dev/null | cut -d' ' -f4-
  ```

  Each line is key tag, algorithm, digest type and digest; compare the
  digests without regard to case. CRITICAL when no parent line equals
  a derived one. A parent line that matches nothing, beside one that
  does, is left over from a key rollover: INFO. Without
  `dnssec-dsfromkey` on the workstation (it comes with BIND's tools),
  `delv int.example.com SOA` through a validating resolver that
  reaches the zone decides instead: `fully validated`, or the broken
  chain. With neither, the check reports `not checkable`.

**WARN**

- The members of a resolver set (The inventory → source) answer the
  same name differently. Nothing syncs them, so the answer depends
  on which resolver a client asks.
- A resolver record shadows a name in a zone the same resolver
  forwards, with a different answer: its record against
  `dig +short @<forward target> <name> <type>`, every such name in
  the same call.
- A private address in a public zone or an external view: the
  records of a view whose clients are not internal only (`any`, or a
  public range), of a zone at a provider, and the glue a public zone
  holds for a delegated subdomain, checked against the ranges The
  record convention → Views names. Glue the user confirmed for an
  internal delegation (Internal domain and DNSSEC) is settled by that
  answer, recorded as a decision (`rules/decisions.md`).

**INFO**

- A static record collides with a name DHCP registered on the same
  server: same name, another address.
- A service name is A or AAAA with a host's `- IP:` address, where a
  CNAME to that host's FQDN would do: never where The record
  convention makes an exception. A zone the provider flattens or
  proxies is not checkable: a client sees A and AAAA there, and
  behind Cloudflare's proxy not even the host's address. It is
  reported as `not checkable`, never as a hint.

**Where they run:**

- **Housekeeping on a host with a `DNS server:` line:** the checks
  of its own name spaces — shadowing, a private address in an
  external view, the DHCP collision, the CNAME hint — from its
  Records.
- **The fleet audit:** resolvers of one set.
- **The workstation, on request:** the DNSSEC chain, and a
  provider's zone, whose records are read by name at one of its NS,
  for the names the request is about or every host in memory under
  that zone, with the address-only filters of `rules/dns-aliases.md`
  (a bare `dig +short` can return a CNAME target).

## Internal domain and DNSSEC

**The domain.** A new internal domain is the one the fleet's naming
scheme records where memory has one; otherwise the user names it.
What to tell them about DNSSEC with each kind:

- **A subdomain of a domain the user owns** (`int.example.com`) is
  the only kind that can be signed with a public chain of trust.
- **`home.arpa`** (RFC 8375, meant for home networks) has an insecure
  delegation, so validating resolvers accept local answers without
  any extra configuration.
- **`.internal`** (meant for an organisation) is not in the root. The
  root proves its absence, signed, so a validating resolver that does
  not serve it itself needs an exception: `domain-insecure` in
  Unbound, or a negative trust anchor.
- Both can be signed, and then validate only with a trust anchor
  configured on the user's own resolvers. A client that validates
  itself does not know that anchor.

**Internal DNSSEC,** where the user wants it, is a **delegated
subdomain** (`int.example.com`):

- The zone is signed on the internal server, with its own keys.
- The public zone gets the NS records, the DS, and glue — A and
  AAAA records for each nameserver named inside the subdomain
  (`ns1.int.example.com`), without which nothing outside can find
  it. A DS is a hash, not a secret. Glue publishes the nameserver's
  address: a private one is a private address in a public zone, named
  and proposed only on the user's outright word (The record
  convention → Views). A nameserver named outside the subdomain needs
  no glue, but its own A and AAAA records publish the same address.
- Internal resolvers reach the zone by a forward or stub zone to the
  internal server, so they never depend on the public glue, and
  validate the whole chain from the public DS. From outside, queries
  to the internal nameservers time out, which does no harm. The
  public zone does name them, so their names should give nothing
  away.

Validation happens at the resolver. Internally almost always only
the resolver validates, so internal DNSSEC mostly protects the path
from the resolver to the authoritative server.

**Split-brain under one zone name** has three ways, and Hostwarden
names them without choosing for the user:

- one signer for both views, with the provider as secondary of a
  pre-signed zone;
- the same KSK on both signers. This works, and the ZSKs may differ,
  but the key that can forge the public zone then lies on two
  machines;
- multi-signer (RFC 8901).

**Never by Hostwarden:** a change of the DS at the registrar, moving
or copying a DNSSEC private key, and a key rollover. A rollover is a
credential rotation (`AGENTS.md` → Critical Safety Rules), and its
steps are the user's, as is copying a key for any of the ways above.

## Setting up a DNS server

Installing one is an ordinary install: `rules/version-check.md`,
`rules/service-class-check.md` and `rules/firewall-changes.md`. What
this file adds is the design it proposes:

- **A real zone** (source 1) where the user wants DNSSEC, has several
  resolvers, or has more than a handful of names. The resolvers then
  forward the zone to it.
- **Resolver records** (source 2) for a small network with a single
  resolver.
- The domain as Internal domain and DNSSEC says, and the records as
  The record convention says.

Once it runs, it is read as Reading a DNS server says, and its name
spaces join `memory/dns.md`.
