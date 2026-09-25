# DNS

Where the fleet's names come from, how Hostwarden proposes the
records a host or a service needs, what it checks, read-only, across
the servers that answer them, and, only where the user has said so,
how it writes them. A record set it proposes goes to the user unless
the name space's line in `memory/dns.md` reads `Hostwarden: write`
(Writing).

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

`memory/dns.md`, created on first need, shared in a shared
workspace (`rules/server-memory.md` → Personal versus shared). Current facts
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
  forward zone, a stub zone, a local record), and from a router
  appliance's `## Network configuration read` where it prints the
  DNS servers its DHCP hands out (Reading a DNS server). Where none
  does, the user is asked, as for a name space nobody has described.
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

A router appliance (an `Appliance:` line) is read through the
`## Network configuration read` of its appliance file where that
read prints its host overrides, its DHCP names or the DNS servers its
DHCP hands out. Those of `rules/appliance/opnsense.md`, `pfsense.md`
and `unifi-os.md` print none of them. Where no read prints them, and
for any other product — pdns-recursor, Knot Resolver, Windows DNS —
the name spaces come from the user, the host gets no `DNS server:`
line, and the checks of its records report `not checkable` rather
than guess a command.

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
  -e '/inline-signing/p' -e '/key-directory/p' -e '/update-policy/p'
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
p="[\"'][0-9A-Fa-f.:]+([[:space:]]+[0-9]+)?[[:space:]]+[A-Za-z0-9._-]+[\"']"
grep -rE "^[[:space:]]*($k):" "$d" $f |
  sed -E -e 's/[[:space:]]+#.*//' -e "/local-data:[[:space:]]*$q$t/b" \
    -e "/local-data-ptr:[[:space:]]*$p[[:space:]]*\$/b" \
    -e "s/(local-data(-ptr)?:[[:space:]]*$q).*/\1 (value withheld)/"
```

`$f` stays unquoted so that a glob in an `include` line expands. An
`include` line in those files names a further file, which is listed
for the user rather than read. A comment after a value is cut; the
`#` of a TLS name in `forward-addr` (`@853#dns.example.com`) has no
space before it and stays. A `local-data` record of any type but A,
AAAA and CNAME prints its name alone: a TXT record can carry a token
(`rules/secrets.md` → Commands That Leak). A `local-data-ptr` line
prints whole only as an address, an optional TTL and a name, and
otherwise its address alone.

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
sed -nE "/^ *dnsmasq_lines = \[\$/,/^ *\]/s/^ *\"(($k)(=[^\"]*)?)\",?\$/\1/p" \
  /etc/pihole/pihole.toml
```

`misc.dnsmasq_lines` holds any dnsmasq line the user added, a
`txt-record=` among them, so only whole lines with a key dnsmasq's
read takes come out of it. They come from `pihole.toml`, one quoted
line per row: `pihole-FTL --config` joins the array with `, ` and
strips the quotes, so a `, ` inside a `txt-record=` value would look
like the next line. A line with an escaped quote does not print.

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
awk '$4 ~ /^(A|AAAA|CNAME)$/'
```

Every form below puts the type in field 4 (Knot: zone, name, TTL,
type; the others: name, TTL, class, type). A match anywhere in the
line would also hit a TXT value such as `"token A x"`.

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
  is installed. The file as written puts the type in no fixed field,
  so without that tool NSD's records are `not checkable`.
- **A router appliance:** the host overrides its
  `## Network configuration read` prints; otherwise the checks
  report `not checkable`.
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

**A dynamic address.** Whether a site's uplink address is dynamic
comes from the `IPv4 lifetime:` of the site's uplink sub-entry in
`memory/topology.md` (`rules/network-topology.md` → Uplinks), and
where the site has several, of the one that carries the address. A
dynamic address's record is kept by a DDNS client on the router or
the host, not written once. Service names stay CNAMEs to that name,
so nothing else changes when the address does. The proposal says so,
rather than proposing an A record that goes stale. Where the
lifetime is not known, or the entries do not show which uplink
carries the address, the proposal says that too: a record written
once holds only while the address does. For an AAAA record it is
never known: an entry records a delegated prefix by its length
alone, never whether an address lies in it.

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
- **A name space whose line reads `Hostwarden: write`** is written
  as Writing below says, once the user agrees to this exact set.
  Every other name space is handed to the user instead: they add the
  records, and say when. Either way, the name is then resolved
  through the resolvers the `resolved by:` field names, not only at
  the authoritative server, as Writing → Verify says.
- **Only the records the set-up needs,** never one Hostwarden thinks
  up beside them.
- **A rename** (`rules/host-rename.md` → The Order) gets two sets:
  the new name's records to add, and later the old name's to remove,
  the PTR's new target, and every CNAME that targets the old name,
  retargeted. Those CNAMEs are the ones the Records below show on the
  DNS servers memory names; the set says that others, at a provider
  or on a server Hostwarden does not read, are the user's to find.

## Writing

Only in a name space whose `memory/dns.md` line reads
`Hostwarden: write`, and only after asking each time with the exact
record set The proposal gives, every server it touches named. Any
other name space is handed to the user, as The proposal already
says; `write` is never assumed from write access alone (The
inventory → Hostwarden).

Before the change, back it up (`rules/backups.md`): the zone file
for a static zone, on the host in `$BACKUP_DIR` as usual. A dynamic
or inline-signed BIND zone, PowerDNS, or any product that keeps
records in a database rather than a file backs up an export of the
records there instead — the file alone is stale the moment there is
a journal or a backend beside it — the same read Reading a DNS
server → Records already takes for the product
(`named-checkzone -D -j -o -`, which merges the journal;
`pdnsutil list-zone`).

**A zone managed as code is never written directly.** The
inventory's `managed:` field says so. Hostwarden proposes the change
in that code's terms where the user shows the file — a Terraform or
OpenTofu resource, an octoDNS source, a DNSControl zone, an Ansible
variable — and otherwise hands over the record set, exactly as for a
name space with no `write`. A direct write would drift from the
code, and the next `apply` would undo it.

**Never by Hostwarden, even where `write` is set:** a change of the
DS at the registrar, moving or copying a DNSSEC private key, and a
key rollover (Internal domain and DNSSEC → Never by Hostwarden).

### Over SSH

On a DNS server Hostwarden manages (The inventory → source, 1 or 2),
in the reach Reading a DNS server already uses. The method follows
how the server holds the zone; check each command against `--help`
or the man page first (`AGENTS.md` → Verify Before Running), since a
version can move a flag from the one below.

- **A static zone file** (BIND, a `primary` zone with `files:` set
  and `dynamic: no` in `rndc zonestatus`). Where the same
  `rndc zonestatus` also reads `secure: yes`, with neither `dynamic`
  nor `inline signing` at `yes`, the zone is signed offline: a plain
  edit adds a record with no signature inside a signed zone, which a
  validating resolver rejects along with the rest of it (Checks →
  CRITICAL). Hostwarden hands this name space's set to the user
  instead, exactly as one with no `write` line; the bullet below
  covers a zone that signs itself. An unsigned static zone is
  written directly: raise the SOA serial, and add, change or remove
  lines in the view's own file — its `files:` line, from
  `rndc zonestatus <zone> <class> <view>`, `_default` where the
  server has none (Reading a DNS server → BIND) — check it, then
  reload that zone and view alone:

  ```bash
  named-checkzone example.net /etc/bind/zones/internal/example.net.zone
  rndc reload example.net IN internal
  ```

  `rndc reload <zone> [class [view]]` fails, "found in multiple
  views", when a zone with views is named alone; the class — `IN`
  unless the zone says otherwise — and the record's own view (The
  proposal) make it specific. A failed check leaves the old file in
  place from the backup, and nothing is reloaded.
- **A dynamic or inline-signed BIND zone** (`dynamic: yes`, or
  `inline signing: yes` in `rndc zonestatus`) is never edited as a
  file: its journal (`<zone>.jnl`) would then disagree with it at
  the next reload. `nsupdate -l` binds to localhost and signs with
  the session key `update-policy local;` makes named write — check
  for exactly that policy in the zone's `update-policy` line of
  Reading a DNS server → BIND's own filtered read before running
  it, never a fresh `named-checkconf -p` of the whole file, which
  can also print a TSIG `secret` (`rules/secrets.md`). A zone made
  dynamic by another policy (TSIG
  keys, a plain `allow-update`) needs credentials Hostwarden does
  not hold, not this session key: the set goes to the user instead,
  exactly as a signed offline static zone does. On a server with
  views, `-l` also binds its source to localhost, so named picks
  whichever view's `match-clients` matches it first, in the file's
  view order — not necessarily the record's own view (The
  proposal). Where more than one view could match localhost, or the
  one that does is not the record's, the set goes to the user
  instead too. Where the policy is `local` and the view is not in
  doubt, run it on the primary itself:

  ```bash
  nsupdate -l <<'EOF'
  zone int.example.com
  update add web2.int.example.com. 3600 A 10.20.0.10
  update add wiki.int.example.com. 3600 CNAME web2.int.example.com.
  send
  EOF
  ```

  A rename's second set (The proposal) removes the old name's
  records with `update delete <name> [type]` lines the same way.
  Retargeting an existing PTR or CNAME to a new value takes a
  `delete` for the old value and an `add` for the new one in the
  same transaction, never `add` alone, which would leave both.
- **PowerDNS:** `pdnsutil`, on the host, or its API where the host's
  configuration shows one is enabled:

  ```bash
  pdnsutil add-record int.example.com web2 A 3600 10.20.0.10
  pdnsutil add-record int.example.com wiki CNAME 3600 web2.int.example.com.
  pdnsutil increase-serial int.example.com
  pdns_control notify int.example.com
  ```

  `pdnsutil` writes straight to the backend and does not notify
  secondaries by itself; `pdns_control notify <zone>` does.
  `pdnsutil delete-rrset <zone> <name> <type>` removes a record,
  notified the same way. Retargeting an existing PTR or CNAME uses
  `pdnsutil replace-rrset <zone> <name> <type> [ttl] <content>`
  instead of `add-record`, which replaces the value outright rather
  than adding a second one beside it.
- **Knot:** a transaction, one zone at a time, aborted rather than
  committed on any failure of the product's own check:

  ```bash
  knotc zone-begin int.example.com
  knotc zone-set int.example.com web2 3600 A 10.20.0.10
  knotc zone-set int.example.com wiki 3600 CNAME web2.int.example.com.
  knotc zone-commit int.example.com
  ```

  `zone-unset <zone> <owner> [type [rdata]]` removes a record before
  the commit; `zone-abort <zone>` drops the transaction instead.
  Retargeting an existing PTR or CNAME unsets the old value before
  setting the new one, in the same transaction, never `zone-set`
  alone.
- **Resolver records** (source 2, on a host reached over SSH), each
  product's own way to make the change take effect — a reload that
  only clears a cache, never the products' configuration itself, is
  not enough for two of them:
  - **Unbound:** edit `local-data`/`local-data-ptr` in its files,
    `unbound-checkconf`, then `unbound-control reload`, which
    rereads them and clears the cache, as `rules/service-reload.md`
    already has it.
  - **dnsmasq:** edit `address=`/`host-record=`/`cname=` in its
    files. Its `SIGHUP` — `rules/service-reload.md`'s reload —
    reloads only `/etc/hosts` and the files `--addn-hosts` and
    `--dhcp-hostsfile` name, never the configuration file itself
    (dnsmasq(8)): this is always a restart instead, asked as
    `rules/service-reload.md` says for one, not a reload that would
    leave the new line unapplied with no error anywhere.
  - **Pi-hole:** `pihole-FTL --config dns.hosts` and
    `dns.cnameRecords` each replace the whole array, never append —
    the current one is read first (Reading a DNS server → Pi-hole),
    the one line added, changed or removed, and the array set back
    whole. Then `systemctl restart pihole-FTL`, the same as
    dnsmasq, never a reload.
  - **AdGuard Home:** its own control API on the host —
    `POST /control/rewrite/add` and `/control/rewrite/delete`, each
    with `domain` and `answer` — never a hand edit of
    `AdGuardHome.yaml`. The running process periodically rewrites
    that file from its own state, and can silently drop an edit made
    to it while it runs. Retargeting an existing rewrite deletes the
    old `answer` before adding the new one, never `add` alone, which
    would leave both.

  A router appliance's host overrides are written through its own
  API instead (Through an API), never this way. A resolver set is
  written one member after another,
  never in parallel (`rules/multi-host.md` → Order), since nothing
  else keeps two members' copies alike. Where
  a member fails partway, the write stops there: the report names
  which members now carry the change and which still hold the old
  records, and offers the rollback from the backup on each changed
  member, rather than going on to members that would then differ for
  a different reason.
- **Secondaries.** After any of the methods above, where the name
  space has one or more (The inventory → source, the provider's
  secondary among them where it has one), each one's SOA serial is
  read afterward and compared with the primary's — for a hidden
  primary this is the only way a client's actual answer is checked
  at all, since nothing ever reaches the primary directly, and it
  matters just as much for a visible one, since PowerDNS and BIND
  alike can leave a secondary stale with no error anywhere in the
  chain (PowerDNS above):

  ```bash
  dig +short SOA int.example.com @ns2.int.example.com
  ```

  The report names any secondary whose serial still trails, so the
  user knows a client reaching it sees the old answer until the next
  transfer.
- **Windows DNS**, AD-integrated included: report-only, like every
  Windows write (`rules/os/windows.md`). The record set goes to the
  user; Hostwarden never attempts it.

### Through an API

A provider's zone (source 1), or the host overrides or local DNS
records a router appliance keeps behind its own API (source 2,
OPNsense, pfSense, UniFi OS). Neither reaches a server over SSH;
both reuse the requests, the markers and the secret filter of
`rules/appliance-api.md` rather than repeat them.

- **A provider's zone:**
  - **The credential file is `~/hostwarden-keys/dns/<zone>/<file>`**
    (`rules/secrets.md` → API Credentials on the Workstation),
    `<zone>` the name space's own name in `memory/dns.md`: a zone has
    no host to key the directory by. Everything else that section
    says — the empty file created first, the mode check, the stdin
    channel — applies unchanged.
  - **A token scoped to the one zone, where the provider offers it.**
    Cloudflare does: a token with Zone → DNS → Edit and Zone → Zone →
    Read, bound to that zone alone, one token per zone. Where the
    provider has no such scope — Hetzner's tokens reach a whole
    project, INWX's an account unless the user has set up a
    domain-scoped sub-account — the user is told plainly what the
    token reaches before it is used, and decides. Noted beside the
    name space's own `Hostwarden: write` line in `memory/dns.md`
    (The inventory), so it is asked once, not on every write: a zone
    has no host of its own for `rules/decisions.md` to file this
    under. Never a token wider than the provider's narrowest
    offering for the task, and never one Hostwarden asks the user to
    widen.
  - **Back up first**, the zone's own export
    (`rules/backups.md` → State behind an API).
  - **The request** goes from the workstation, in the shape
    `rules/appliance-api.md` → Reaching the API gives an appliance's
    own API call — one login, one batch, its own markers — but never
    pinned: `rules/tls-pinning.md` is for an appliance's self-signed
    certificate, and a provider's is publicly trusted, so ordinary
    TLS validation runs, no `-k`. The write's body comes from a
    file, never inline (`rules/appliance-api.md` → Writing), and the
    object is read back afterwards and compared with what the
    proposal said. Look the provider's current endpoint and body up
    before the call (`AGENTS.md` → Verify Before Running): a
    provider's API moves between its own versions the same as an
    appliance's.
  - **Never a CNAME at an MX, NS or SRV record's target, and never
    at the zone apex** — The record convention's own exceptions,
    which an A or AAAA record at those names never needs — except
    through the mechanism The record convention names for that
    provider. A body carrying anything the record set did not ask
    for — a page rule, a Worker route, a setting beside the record —
    is never sent, whatever the endpoint would also accept.
- **A router appliance's host overrides:**
  - **Through the appliance's own write access**
    (`rules/appliance-api.md` → Access levels): an account with the
    narrowest role the appliance offers for this alone, and only
    where the user has set one up. Where none exists, the record set
    from The proposal goes to the user as menu steps instead — never
    a reason to ask the user to create write access just for this.
  - **The method is each appliance's own**, since none of the three
    shares one: `rules/appliance/opnsense.md` → API,
    `rules/appliance/pfsense.md` → API,
    `rules/appliance/unifi-os.md` → Network API → Writing.
  - **Views still apply**: a host override or local record for a
    private address is fine in the internal views these appliances
    serve, and refused, as The record convention → Views says, for
    one the appliance would answer externally.
  - **Wherever the write path covers more than one record type at a
    name** — UniFi's does, CNAME, MX and SRV among them, unlike
    OPNsense's and pfSense's A/AAAA-only host overrides — the same
    two rules above apply: never a CNAME at an MX, NS or SRV target
    or the zone apex, and back up every record already at the name
    before a write that changes what is there, not only the type
    being written.

### Verify

Through the resolvers clients use for this name space — the
`resolved by:` field's list (The inventory) — never only at the
authoritative server, every resolver's lookups in one call to it:
`dig +short <type> <name> @<resolver>` for each record added or
changed, its new value compared with the proposal; the same for each
record a rename's second set removes, expecting no answer. A name
asked for before this write existed is held at a resolver as a
negative answer until the SOA's negative TTL runs out (RFC 2308); a
record just removed is cached instead, under its own TTL, until that
runs out. Either way, where a lookup shows it, the report says so
and gives the wait, rather than that the name does not resolve or
the removal failed. Where the resolver is
one Hostwarden reaches and offers a targeted flush —
`rndc flushname <name> [view]` on BIND, `unbound-control flush
<name>` on Unbound — it is offered after asking, never run unasked;
other products, and a resolver Hostwarden does not reach, just wait
out the TTL.

## Checks

Findings with the severities of the housekeeping report format. A
finding a decision settles is none (`rules/decisions.md` → Rating
findings).

**CRITICAL**

- The parent has a DS set, and no DS in it matches a key of the
  zone. Every validating resolver then fails the whole zone. A key
  tag only names a key, so the comparison is the whole DS: from the
  workstation, the parent's answer with its status, and the DS
  records derived from the zone's DNSKEY set at one of its own
  servers, in every digest type the parent uses:

  ```bash
  dig +nosplit +noall +comments +answer DS int.example.com |
    awk '/status:/ { sub(/,/, "", $6); print $6 }
      $4 == "DS" { print $5, $6, $7, $8 }'
  dig +noall +answer DNSKEY int.example.com @ns1.int.example.com |
    dnssec-dsfromkey -a SHA-1 -a SHA-256 -a SHA-384 \
      -f - int.example.com 2>/dev/null | cut -d' ' -f4-
  ```

  The first line is the status. `NOERROR` with no DS line after it
  is an insecure delegation, which is valid: resolvers take the
  zone's answers unvalidated. The check then reports `unsigned` and
  compares nothing (a zone with keys all the same: INFO). Any other
  status — `NXDOMAIN` for a zone the public tree
  does not delegate, `SERVFAIL` — is reported as it stands, and the
  check as `not checkable`. No status line at all means the query
  got no answer (`no servers could be reached`): `not checkable`,
  never an empty DS set. Otherwise each line is key tag,
  algorithm, digest type and digest; compare the digests without
  regard to case. CRITICAL when no parent line equals a derived one.
  No derived line at all is CRITICAL only where
  `dig +short SOA int.example.com @ns1.int.example.com` prints the
  SOA record, so the zone is served without keys; where it prints
  `;;` lines instead, the server did not answer: `not checkable`.
  A parent line that matches nothing, beside one that does, is left
  over from a key rollover: INFO. Without `dnssec-dsfromkey` on the
  workstation (it comes with BIND's tools), `delv int.example.com
  SOA` through a validating resolver that reaches the zone decides
  instead: `fully validated`, `unsigned answer` for the insecure
  delegation, or the broken chain. With neither, the check reports
  `not checkable`.

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
  answer, noted beside the name space's own line in `memory/dns.md`
  (The inventory) rather than asked again: the delegated subdomain
  has no host of its own for `rules/decisions.md` to file it under.

**INFO**

- A static record collides with a name DHCP registered on the same
  server: same name, another address.
- A service name is A or AAAA with a host's `- IP:` address, where a
  CNAME to that host's FQDN would do: never where The record
  convention makes an exception. A zone the provider flattens or
  proxies is not checkable: a client sees A and AAAA there, and
  behind Cloudflare's proxy not even the host's address. It is
  reported as `not checkable`, never as a hint.
- A zone that has keys (a derived line above) while its parent has
  no DS: it is signed, but only a resolver holding a trust anchor
  for it validates it (Internal domain and DNSSEC).

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
scheme records where memory has one (`rules/naming-scheme.md` → The
store, its `Domain:` line); otherwise the user names it, guided by
`rules/naming-scheme.md` → The best-practice proposal, which lists
the same three kinds below in the same order of preference. What to
tell them about DNSSEC with each kind:

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
