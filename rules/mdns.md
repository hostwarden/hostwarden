# mDNS and .local Names

A name ending in `.local` can be answered by multicast DNS (mDNS,
RFC 6762) on the local link and by a unicast DNS server as well,
and the two can name different machines. The system resolver of
`rules/dns-aliases.md` → Detection step 1 gives the address ssh
takes, not where it came from. So ask each source on its own, on
the workstation, for the name ssh connects to — the `hostname`
line of `ssh -G` — in one call.

## Asking Each Source

Unicast DNS is asked at the server this workstation uses for the
name, split DNS included — a VPN can send a whole domain, a
`corp.local` among them, to a server of its own — whether or not
the system resolver would reach DNS for it before mDNS.

On macOS, where mDNSResponder always runs, the resolver that
`scutil --dns` lists for the longest domain the name ends in
answers for DNS, and `dig` asks the primary one where none does.
`dns-sd` never exits on its own, so it gets two seconds:

```
set -- $(scutil --dns | awk -v n='<name>' '
  function pick() {
    if (a != "" && d != "" && length(d) > b &&
        (n == d || substr(n, length(n) - length(d)) == "." d)) {
      b = length(d); s = a " " p }
    d = a = p = "" }
  /^DNS configuration \(for scoped/ { pick(); exit }
  /^resolver/ { pick() }
  $1 == "domain" { d = $3; sub(/\.$/, "", d) }
  $1 == "nameserver[0]" { a = $3 }
  $1 == "port" { p = $3 }
  END { pick(); print s }')
echo "== dns ${1:-primary}"
dig +short +time=2 +tries=1 ${1:+@$1} ${2:+-p} $2 A <name>
echo "dns-exit=$?"
echo "== mdns"
dns-sd -fmc -G v4 <name> & sleep 2; kill $!
```

The address lines under `== dns` are unicast DNS. `-fmc` keeps
`dns-sd` to multicast, so each `Add` line it prints is an mDNS
answer, except one ending `No Such Record`, which is none. The
`IF` column names the interface, not the protocol. One exception:
where `/etc/hosts` holds the name (the `awk` under Comparing),
mDNSResponder answers from that file and never asks the link, so
the mDNS side is unread.

On Linux, the system resolver asks mDNS only through a module on
the `hosts:` line of `/etc/nsswitch.conf` or through resolved's
full stub: an `mdns` module (`mdns4_minimal`, `mdns4`, …) asks
avahi-daemon, and `resolve` on that line, or `127.0.0.53` in
`/etc/resolv.conf`, asks systemd-resolved on the links where
`resolvectl mdns` says `yes` or `resolve`, as long as its
`Global` line does not say `no`. Its proxy stub `127.0.0.54`
asks DNS only. Where the system resolver goes through a running
systemd-resolved — `resolve` on that line, or its stub
`127.0.0.53` or `127.0.0.54` in `/etc/resolv.conf` — resolved's
own routing picks the DNS server, and `dig` at the stub would get
mDNS answers too, so `resolvectl` asks DNS alone, without
`/etc/hosts` or its cache. Elsewhere `dig` asks the servers of
`/etc/resolv.conf`:

```
n='<name>'
h=$(grep '^hosts:' /etc/nsswitch.conf); echo "$h"
st=; grep -qE '^nameserver 127\.0\.0\.5[34]$' /etc/resolv.conf && st=1
q=; case $h in *resolve*) q=1 ;; esac
grep -qE '^nameserver 127\.0\.0\.53$' /etc/resolv.conf && q=1
r=$st$q
m=$(resolvectl mdns 2>/dev/null) || r= q=
if [ -n "$r" ]; then
  echo "== dns resolved"
  resolvectl query -4 -p dns --synthesize=no --cache=no "$n"
elif [ -n "$st" ]; then
  echo "== dns unread: resolved's stub, no resolvectl"
else
  echo "== dns dig"
  dig +short +time=2 +tries=1 A "$n"
fi
echo "dns-exit=$?"
case $h in *mdns*)
  echo "== mdns avahi"
  avahi-resolve -4 -n "$n"; echo "avahi-exit=$?" ;;
esac
if [ -n "$q" ]; then
  echo "$m"
  if printf '%s\n' "$m" | grep -qE '^Link .*: (yes|resolve)$' &&
     ! printf '%s\n' "$m" | grep -qE '^Global: no$'; then
    echo "== mdns resolved"
    resolvectl query -4 -p mdns --synthesize=no --cache=no "$n"
    echo "resolvectl-exit=$?"
  fi
fi
grep -m1 '^#' /etc/resolv.conf
```

Where no mDNS block appears, ssh never gets an mDNS answer on
this workstation. Under WSL, where the last line names WSL as the
author of `/etc/resolv.conf`, `dig` asks Windows, which can answer
a `.local` name over mDNS itself: the `dns` answers are then no
proof of unicast DNS.

A source is unread, not silent, when its tool is missing (exit
127), when `dig` fails (`dns-exit` not 0), and under
`== dns unread`. Of `resolvectl`'s failures, some are answers.
For both sources, `'<name>' does not have any RR of the requested
type` is an answer with no IPv4 address. For DNS:
`Name '<name>' not found`, DNS answering with nothing, and
`No appropriate name servers or networks for name found`,
this workstation having no DNS server for the name because no
routing domain covers it. For mDNS, which has no negative answer:
`All attempts to contact name servers or networks failed`, no
responder on the link, and `No appropriate name servers or
networks for name found`, no link that can ask, so mDNS is not
asked here. Any other failure, a timeout or an option
an older systemd does not know included, leaves the source
unread. `Daemon not running` from
`avahi-resolve` is no failure to read either: with avahi-daemon
stopped, the system resolver cannot ask mDNS and falls through to
DNS, so mDNS is not asked here. On any other workstation both
sides are unread.

## Comparing

Compare the IPv4 addresses as in `rules/dns-aliases.md` →
Detection step 1. This file's own sources stay IPv4-only
(`dns-sd -G v4`, `dig ... A`, `resolvectl query -4`),
unlike Detection step 1's dual-stack collection: a
`.local` name ssh reaches over an IPv6 address gets no
mDNS-versus-DNS disambiguation here.

- **Both sources answer and share no address: stop and tell the
  user**, with the name and each source's addresses, and ask
  which machine is meant. This question replaces IP
  Verification's; the difference is neither an alias nor a
  migration. Name the likely cause: a unicast DNS zone named
  `local`, which older Active Directory domains use and RFC 6762
  Appendix G advises against, or a name conflict on the link,
  where a host that finds its name taken renames itself
  (`<host>-2.local`) and `<host>.local` is another machine than
  the one in memory. Where the system resolver gives the machine
  the user names, record its source as below; otherwise that
  machine gets a `HostName` in `memory/ssh_hosts` as
  `rules/ssh-config.md` → Adding a Block says, gated by A
  Self-Resolved Address there: the address came from mDNS, never
  the user. A decline there leaves the name resolving to the other
  machine, never to nothing: run `ssh -G` again before the first
  connection, and stop if it still does not show the address the
  user meant, rather than let the session reach the wrong host.
- **A source is unread,** or WSL leaves the `dns` lines open, or
  the system resolver's address is in no source's answer and
  `/etc/hosts` does not give it: tell the user what could not be
  told apart, and record `- Resolved via: unknown (<name>)`. The
  addresses `/etc/hosts` gives the name, on active lines and
  matched exactly:

  ```
  awk -v n='<name>' '$1 !~ /^#/ {
    for (i = 2; i <= NF && $i !~ /^#/; i++) if ($i == n) print $1 }' \
    /etc/hosts
  ```
- **Otherwise** record the source whose addresses include the
  system resolver's: `- Resolved via: mDNS (<name>)`, `DNS`, or
  `DNS and mDNS` where both do, and `hosts file` for an address
  `/etc/hosts` gave.

The line goes into the `memory.md` the name ends up in, one per
`.local` name ssh connects to, whichever of the host's names
leads there. It says what the workstation that wrote it saw, and
is written again only when IP Verification finds no overlap.

Where only mDNS answers and IP Verification found no overlap, a
name conflict can be the cause as well: the host in memory may
have renamed itself. Ask the same mDNS source for
`<host>-2.local`, `-3` and so on while one answers — on macOS
with `dns-sd -fmc -G v4` as above, read the same way; an answer with
an address in `- IP:` is the host in memory under its new name,
and IP Verification's question names that.

Ask for the one name only; never browse the link for services
(`avahi-browse`, `dns-sd -B`). Whether the server itself answers
mDNS is its network profile's `mDNS responder:`, which Reading D
of `rules/network-probe.md` records.
