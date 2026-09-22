# Network Probes

The read-only probes behind `rules/network.md`, one call per
family, and how to read what they print. Load this file only
when that rule says to build or refresh a profile.

Nothing needs root except the netplan grep. Its `S` stands for
the privilege path `rules/privilege-escalation.md` found (`sudo
-n`, or the stand-in that file names); without one it prints
`unknown(needs-root)`.

BusyBox `ip` has no `-br`, and Alpine ships no `ss` or `curl`
by default: where a section comes back empty for that reason,
say which, and do not read the gap as a finding.

## Probe — Linux

One call. `n` names the container and VM interfaces
that are counted, never listed; extend it in one
place when a new kind turns up. Set `T` first when
an override names the egress target (see Egress
test).

```bash
n='veth|cali|cni|flannel|vnet|tap|fwbr|fwpr|fwln|lxc'
n="$n|docker|br-[0-9a-f]{12}"
up=$(ip -4 route show default \
  | sed -n 's/.* dev \([^ ]*\).*/\1/p' | head -1)
[ -n "$up" ] || up=$(ip -6 route show default \
  | sed -n 's/.* dev \([^ ]*\).*/\1/p' | head -1)
# No default route at all: take the link SSH came in on.
[ -n "$up" ] || up=$(ip route get "${SSH_CONNECTION%% *}" \
  2>/dev/null | sed -n 's/.* dev \([^ ]*\).*/\1/p')
echo "uplink=$up"
[ -e "/sys/class/net/$up/device" ] && echo "uplink-physical=yes"
if [ "$(id -u)" = 0 ]; then S=""
elif sudo -n true 2>/dev/null; then S="sudo -n"
else S=-; fi

echo "### A manager"
for u in systemd-networkd NetworkManager networking \
         network wicked systemd-resolved resolvconf \
         dhcpcd connman; do
  printf '%s=%s\n' "$u" \
    "$(systemctl is-active "$u" 2>/dev/null)"
done
ls -d /etc/netplan/*.yaml /etc/network/interfaces \
  /etc/network/interfaces.d/* /etc/systemd/network/* \
  /etc/sysconfig/network-scripts/ifcfg-* \
  /etc/sysconfig/network/ifcfg-* 2>/dev/null
grep -hE '^[[:space:]]*(auto|allow-hotplug|iface) ' \
  /etc/network/interfaces \
  /etc/network/interfaces.d/* 2>/dev/null
if command -v networkctl >/dev/null 2>&1; then
  networkctl list --no-pager --no-legend \
    | grep -vE " ($n)"
  networkctl status "$up" --no-pager -n0 2>/dev/null \
    | grep -E 'Network File|State:|Address|Gateway|DNS'
fi
if command -v nmcli >/dev/null 2>&1; then
  nmcli -t -f DEVICE,TYPE,STATE,CONNECTION device \
    2>/dev/null | grep -vE "^($n)"
  c=$(nmcli -g GENERAL.CONNECTION device show "$up" \
    2>/dev/null)
  [ -n "$c" ] && nmcli -g ipv4.method,ipv6.method \
    connection show "$c"
fi
if ls /etc/netplan/*.yaml >/dev/null 2>&1; then
  if [ "$S" = - ]; then echo "netplan=unknown(needs-root)"
  else $S grep -HE \
    '^[[:space:]]*([a-z0-9_.@-]+:[[:space:]]*$|(renderer|dhcp4|dhcp6|accept-ra):)' \
    /etc/netplan/*.yaml
  fi
fi
if command -v cloud-init >/dev/null 2>&1; then
  echo "cloud-id=$(cloud-id 2>/dev/null)"
  echo "cloud-init-unit=$(systemctl is-enabled \
    cloud-init.service 2>/dev/null)"
  [ -e /etc/cloud/cloud-init.disabled ] \
    && echo "cloud-init=disabled"
  grep -rlsE 'config:[[:space:]]*disabled' \
    /etc/cloud/cloud.cfg /etc/cloud/cloud.cfg.d/
fi

echo "### B links"
ip -br link | grep -vE "^(lo|$n)"
echo "container-ifs=$(ip -br link | grep -cE "^($n)")"
for t in bond vlan wireguard; do
  printf '%s: ' "$t"
  ip -o link show type "$t" 2>/dev/null \
    | cut -d: -f2 | tr -d ' ' | tr '\n' ' '
  echo
done
ip -o addr show | grep -vE " (lo|$n)[^ ]* "
ip -4 route show default; ip -6 route show default
ip -4 rule; ip -6 rule

echo "### C sysctl"
echo "ip_forward=$(cat /proc/sys/net/ipv4/ip_forward)"
for i in all "$up"; do
  for k in disable_ipv6 accept_ra forwarding; do
    echo "$i/$k=$(cat "/proc/sys/net/ipv6/conf/$i/$k" \
      2>/dev/null)"
  done
done

echo "### D dns"
ls -l /etc/resolv.conf
grep -m3 '^#' /etc/resolv.conf
grep -E '^(nameserver|search|domain|options)' \
  /etc/resolv.conf
[ -L /etc/resolv.conf ] || lsattr /etc/resolv.conf \
  2>/dev/null
if command -v resolvectl >/dev/null 2>&1; then
  resolvectl dns 2>/dev/null \
    | grep -E "^(Global|Link [0-9]+ \($up\))"
  resolvectl domain 2>/dev/null \
    | grep -E "^(Global|Link [0-9]+ \($up\))"
  resolvectl status --no-pager 2>/dev/null \
    | grep -E 'resolv.conf mode|Protocols' | sort -u
fi
grep '^hosts:' /etc/nsswitch.conf
ss -lnu 'sport = :53' | tail -n +2
ss -lnt 'sport = :53' | tail -n +2
hostname -f
getent hosts "$(hostname -f)"
echo "dns64=$(getent ahostsv6 ipv4only.arpa \
  | grep -v '^::ffff:' | head -1)"

echo "### E egress"
pe=$(env | grep -ciE '^(https?|all)_proxy=')
pa=$(apt-config dump 2>/dev/null \
  | grep -ciE '^Acquire::https?::Proxy ')
pd=$(grep -hciE '^proxy[[:space:]]*=' \
  /etc/dnf/dnf.conf /etc/yum.conf 2>/dev/null \
  | grep -c '^[1-9]')
pz=$(grep -c '^PROXY_ENABLED=\"yes\"' \
  /etc/sysconfig/proxy 2>/dev/null)
px=$((pe + pa + pd + ${pz:-0}))
echo "proxy-env=$pe proxy-apt=$pa proxy-dnf=$pd proxy-suse=${pz:-0}"
# Active lines only, credentials dropped, port kept.
[ -n "$T" ] || T=$(grep -rhE '^[[:space:]]*[^#[:space:]]' \
  /etc/apt/sources.list /etc/apt/sources.list.d/ \
  /etc/yum.repos.d/ /etc/zypp/repos.d/ /etc/apk/repositories \
  2>/dev/null \
  | grep -oE 'https?://[^/ "]+' | sed 's|//[^@/]*@|//|' \
  | sort -u | head -3)
[ -n "$T" ] || echo "egress=no-target"
gw=; command -v wget >/dev/null 2>&1 \
  && ! wget --help 2>&1 | grep -q BusyBox && gw=1
d4=; d6=
for t in $T; do
  h=${t#*://}; h=${h%%:*}   # the port stays in $t, not in $h
  v4=$(getent ahostsv4 "$h" | head -1)
  v6=$(getent ahostsv6 "$h" | grep -v '^::ffff:' | head -1)
  echo "resolve $h: v4=${v4%% *} v6=${v6%% *}"
  for f in 4 6; do
    if [ "$f" = 4 ]; then [ -n "$d4" ] && continue; a=$v4
    else [ -n "$d6" ] && continue; a=$v6; fi
    # A proxy resolves names itself, so try it without an address.
    if [ -z "$a" ] && [ "$px" = 0 ]; then
      c=no-address
    elif command -v curl >/dev/null 2>&1; then
      c=$(curl -"$f" -sS -o /dev/null --connect-timeout 3 \
        -m 5 -w '%{http_code}' "$t/" 2>/dev/null)
    elif [ -n "$gw" ]; then
      wget -"$f" -q -t 1 -T 5 --spider "$t/" 2>/dev/null
      c="wget-exit=$?"
    else
      c=no-client
    fi
    echo "egress$f $t=$c"
    # Only an answer decides a family; a dead mirror moves on.
    case $c in
      000|no-address|no-client|wget-exit=[1-7]) ;;
      *) if [ "$f" = 4 ]; then d4=1; else d6=1; fi ;;
    esac
  done
  [ -n "$d4" ] && [ -n "$d6" ] && break
done
```

Reading **A (manager)**:

- `networkctl status` names the `.network` file in
  use. A path under `/run/systemd/network/` with
  `netplan` in its name means netplan generated it:
  the source of truth is the YAML.
- `networking=active` alone is not ifupdown in
  charge: Debian runs the unit even when
  `/etc/network/interfaces` configures only `lo`.
  The `iface` lines decide.
- `network=active` is the legacy initscripts service
  (RHEL 8 and older); `wicked` is SUSE's manager.
- **cloud-init** owns the network when it is
  installed, enabled, and nothing disables its
  network config. It renders the configuration on
  the first boot of every new instance and, for some
  datasources, on every boot; hand edits to its
  output can vanish. `cloud-init=disabled` or a
  masked unit means it was switched off (the family
  file's cloud-init section, where it has one).
- **Conflict:** two managers that both show the same
  interface as managed (networkctl `configured` and
  nmcli `connected`, or an ifupdown `iface` stanza
  plus either).

Reading **B (links, addresses, routes)**:

- The uplink is the device of the default route. Every other
  interface that is not a container or VM one is listed with its
  addresses too, so a multihomed host shows all of them; `wg*`,
  `tailscale0`, `zt*` and `tun*` among them are overlays.
- **Dynamic addresses** carry `dynamic` and a finite
  `valid_lft`: in practice DHCP for IPv4, SLAAC or
  DHCPv6 for IPv6. `proto kernel_ra` marks an
  address the kernel built from a Router
  Advertisement; a /128 with `dynamic` is usually
  DHCPv6. Confirm with the manager's view (A).
- `temporary` marks an RFC 4941 privacy address,
  `mngtmpaddr` the address it is derived from,
  `deprecated` one that is no longer preferred.
- **Interface ID from the MAC (EUI-64):** the last 64
  bits contain `ff:fe` in the middle and match the
  link's MAC with the seventh bit flipped.
- `ip rule` beyond the defaults (local, main and
  default for IPv4; local and main for IPv6) is
  policy routing. `wg-quick` and Tailscale add their
  own rules; name the owner.
- A default route with `proto ra` and `expires`
  lives only as long as Router Advertisements keep
  arriving.

Reading **C (kernel)**:

- `disable_ipv6=1` on `all` or the uplink: IPv6 is
  off.
- `accept_ra`: `0` the kernel ignores RAs, `1` it
  accepts them unless forwarding is on, `2` it
  accepts them even with forwarding. The uplink's
  own value counts; `all/accept_ra` does not
  override it. ifupdown defaults to `2` for
  `inet6 auto` but to `1` for `inet6 dhcp`
  (interfaces(5)).
- **Who handles RAs.** systemd-networkd always sets
  the kernel's `accept_ra` to 0 and processes RAs
  itself. `accept_ra=0` with a `proto ra` default
  route therefore means a userspace manager does the
  work; only `accept_ra` 1 or 2 puts the kernel in
  charge.
- Whether forwarding itself is acceptable is the
  security audit's call
  (`hostwarden-security` → `references/kernel-os.md`).

Reading **D (DNS)** — `/etc/resolv.conf` tells you
who writes it:

- Symlink to `stub-resolv.conf`: systemd-resolved,
  applications ask the stub on 127.0.0.53.
- Symlink to `/run/systemd/resolve/resolv.conf`:
  resolved writes the upstream servers directly.
- Symlink to `/run/NetworkManager/…`, or header
  `Generated by NetworkManager`: NetworkManager.
- Symlink to `/run/resolvconf/…` or a resolvconf
  header: resolvconf or openresolv.
- Symlink to `/run/netconfig/…`: SUSE netconfig.
- A plain file without a generator header: static,
  by hand or by cloud-init. An `i` in `lsattr` means
  someone made it immutable to stop a manager.

Also:

- Servers on the uplink that the manager's config
  does not set came from DHCP or from RDNSS in a
  Router Advertisement. Write "link-provided" unless
  the config shows the source.
- A listener on port 53 is a local resolver. Name it
  with the DNS resolver class of
  `rules/service-class-check.md`.
- An IPv6 answer for `ipv4only.arpa` comes from a
  DNS64 resolver and carries the NAT64 prefix. The
  `grep -v '^::ffff:'` drops the IPv4-mapped
  addresses glibc adds for names without AAAA.
- `127.0.1.1` for the own name comes from
  `/etc/hosts`: Debian's default, not a finding. It
  matters only for a service that must announce its
  public name (an MTA, for instance).

## Probe — FreeBSD

```bash
sysrc -a | grep -E \
  -e '^(ifconfig_|ipv6_|defaultrouter|rtsold|gateway_enable)' \
  -e '^(resolv|local_unbound|dhclient|cloudinit|nuageinit)'
ifconfig -a | grep -E '^[a-z]|inet6? |nd6 options|status:'
netstat -rn -f inet | grep '^default'
netstat -rn -f inet6 | grep '^default'
sysctl net.inet.ip.forwarding net.inet6.ip6.forwarding \
  net.inet6.ip6.accept_rtadv
grep -E '^(nameserver|search|domain|options)' \
  /etc/resolv.conf
```

- `rc.conf` is the source of truth.
  `ifconfig_<if>="DHCP"` (or `SYNCDHCP`) is DHCP;
  `ifconfig_<if>_ipv6="inet6 accept_rtadv"` together
  with `rtsold_enable="YES"` is SLAAC.
- `nd6 options` on each interface: `ACCEPT_RTADV`
  accepts RAs, `IFDISABLED` means IPv6 is off.
- With `ip6.forwarding=1` FreeBSD ignores RAs by
  default. Check `sysctl -d net.inet6.ip6.rfc6204w3`
  on the host before relying on that knob.

## Probe — macOS

```bash
networksetup -listnetworkserviceorder
scutil --nwi
ifconfig | grep -E '^[a-z]|inet6? '
route -n get default 2>/dev/null \
  | grep -E 'gateway|interface'
route -n get -inet6 default 2>/dev/null \
  | grep -E 'gateway|interface'
scutil --dns | grep -E '^resolver|nameserver|search domain|if_index' \
  | head -40
sysctl net.inet.ip.forwarding net.inet6.ip6.forwarding
```

Then `networksetup -getinfo "<service>"` for the
primary service: the one whose `Device:` in
`-listnetworkserviceorder` is the first interface
in `scutil --nwi`. It says DHCP or manual for IPv4,
Automatic, Manual or Off for IPv6.

- `ifconfig` flags on IPv6 addresses: `autoconf`
  (SLAAC), `temporary` (privacy address), `secured`
  (stable, not from the MAC).
- `scutil --dns` shows the resolver order, including
  per-domain resolvers set by VPN clients.

## Egress test

One request per address family to a host the machine
already talks to, so the test adds no new third
party: on Linux the first answering repository host
(section E of the probe), on FreeBSD the host of the
`pkg` repository (`pkg -vv | grep url`, with `pkg+`
and the path dropped: `https://pkg.FreeBSD.org/`),
on macOS Apple's update host `swscan.apple.com`. On
FreeBSD use `fetch -4` / `fetch -6` with
`-q -T 5 -o /dev/null`; on macOS `curl` as in the
Linux probe.

Hosts behind an internal mirror or a strict egress
filter override the target (`rules/overrides.md`): a
`## Replace: Egress test target` section in
`memory/custom-rules/network-probe.md` (fleet-wide) or in
`memory/servers/<hostname>/rules.md`. On Linux, set
`T` to that URL before the probe.

Reading the result:

- **Any HTTP status** (even 403 or 404), or
  `wget-exit=0` or `8`: the family reaches the
  internet. curl `000`, any other wget exit, or a
  fetch error: it does not.
- `no-client`: neither curl nor GNU wget (BusyBox
  wget cannot choose a family). Egress is
  `unchecked`, not broken.
- `no-address`: `getent` found no address of that
  family, and the probe tries the next target for
  it. For IPv6 on a host without a global or unique
  local address, glibc asks for no AAAA at all: that
  is the host having no IPv6, not the target. Where
  no target has AAAA on a host that has IPv6, ask
  the user for one.
- **Both families fail** on every target: check the
  repositories before calling egress dead.
- `egress=no-target`: no repository host found (a
  distro without apt, dnf, zypper or apk). Set `T` through
  the override and run again.
- **A proxy is configured** (any `proxy-*` count
  above 0): direct egress may be blocked on
  purpose. Record `Egress: via proxy` and do not
  report a failed direct test as a finding. The
  request then runs even where `getent` found no
  address, because the proxy resolves the name, and
  an empty `resolve` line is no resolution failure
  on such a host.

Finding out the public address behind NAT needs an
external echo service. Do that only when the user
asks.

## Public DNS view

Run on the **workstation**, not on the server: it
shows what clients see. Use the address-only filters
from `rules/dns-aliases.md` (a bare `dig +short` can
return a CNAME target):

```bash
dig +short A <hostname> | grep -E '^[0-9.]+$'
dig +short AAAA <hostname> | grep ':'
dig +short -x <each public address>
```

Resolve each PTR name the same way to confirm it
points back. The check of the A record against
`- IP:` stays with `rules/dns-aliases.md` → IP
Verification; here compare A and AAAA with every
address section B listed, not the uplink's alone: a
public address often sits on a second interface.

- An A or AAAA pointing at an address the host does
  not have breaks inbound connections for clients
  of that family. On a host whose own address is
  private, that record may instead be a NAT, a
  reverse proxy or a load balancer in front of it,
  or simply stale: report the mismatch and what the
  host has, and record which of them it is only
  once the user says, or a configuration on the
  host shows it.
- A generic PTR from the provider's pool
  (`dynamic-…pool.<isp>`) is not the host's own name;
  for a mail host it counts as missing.
- A GUA without an AAAA record is normal for a host
  that only connects outwards.

