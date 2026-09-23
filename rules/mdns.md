# mDNS and .local Names

A name ending in `.local` can be answered by multicast DNS (mDNS,
RFC 6762) on the local link and by a unicast DNS server as well,
and the two can name different machines. The system resolver of
`rules/dns-aliases.md` → Detection step 1 gives the address ssh
takes, not where it came from. So ask each source on its own, on
the workstation, for the name ssh connects to — the `hostname`
line of `ssh -G` — in one call.

## Asking Each Source

On macOS, where mDNSResponder always runs. `dns-sd` never exits on
its own, so it gets two seconds:

```
dig +short +time=2 +tries=1 A <name>; echo "dig-exit=$?"
dns-sd -G v4 <name> & sleep 2; kill $!
```

The address lines from `dig` are unicast DNS. A `dns-sd` `Add`
line with a non-zero `IF` column came from the link; `IF` 0 is
unicast DNS again.

On Linux, the system resolver asks mDNS only through a module on
the `hosts:` line of `/etc/nsswitch.conf`: an `mdns` one
(`mdns4_minimal`, `mdns4`, …) asks avahi-daemon, and `resolve`
asks systemd-resolved on the links where `resolvectl mdns` says
`yes` or `resolve`, as long as its `Global` line does not say
`no`. systemd-resolved's own stub, `127.0.0.53`, would answer
`dig` over mDNS too, so `dig` asks the first upstream server
resolved lists, where it runs:

```
n='<name>'
s=$(awk '$1=="nameserver"{print $2; exit}' \
  /run/systemd/resolve/resolv.conf 2>/dev/null)
d=$(dig +short +time=2 +tries=1 ${s:+@$s} A "$n")
echo "dig-exit=$?"
printf '%s\n' "$d" | grep -E '^[0-9.]+$' | sed 's/^/dns /'
h=$(grep '^hosts:' /etc/nsswitch.conf); echo "$h"
case $h in *mdns*)
  avahi-resolve -4 -n "$n"; echo "avahi-exit=$?" ;;
esac
case $h in *resolve*)
  m=$(resolvectl mdns 2>/dev/null); echo "$m"
  if printf '%s\n' "$m" | grep -qE '^Link .*: (yes|resolve)$' &&
     ! printf '%s\n' "$m" | grep -qE '^Global: no$'; then
    resolvectl query -4 -p mdns "$n"; echo "resolvectl-exit=$?"
  fi ;;
esac
grep -m1 '^#' /etc/resolv.conf
```

The `dns` lines are unicast DNS; the `avahi-resolve` and
`resolvectl` lines are mDNS. Where neither module asks it, ssh
never gets an mDNS answer on this workstation, and no mDNS line
appears. Under WSL, where the last line names WSL as the author
of `/etc/resolv.conf`, `dig` asks Windows, which can answer a
`.local` name over mDNS itself: the `dns` lines are then no
proof of unicast DNS.

A source is unread, not silent, when its tool is missing (exit
127) or `dig-exit` is not 0. On any other workstation both sides
are unread. `Daemon not running` from `avahi-resolve` is no
failure to read: with avahi-daemon stopped, the system resolver
cannot ask mDNS either and falls through to DNS, so mDNS is not
asked here.

## Comparing

Compare the IPv4 addresses as in `rules/dns-aliases.md` →
Detection step 1.

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
  machine gets a `HostName` in `memory/ssh_hosts`
  (`rules/ssh-config.md` → Adding a Block).
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
`<host>-2.local`, `-3` and so on while one answers; an answer with
an address in `- IP:` is the host in memory under its new name,
and IP Verification's question names that.

Ask for the one name only; never browse the link for services
(`avahi-browse`, `dns-sd -B`). Whether the server itself answers
mDNS is its network profile's `mDNS responder:`, which Reading D
of `rules/network-probe.md` records.
