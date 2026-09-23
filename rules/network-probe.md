# Network Probes

The read-only probes behind `rules/network.md`, one call per
family, and how to read what they print. Load this file only
when that rule says to build or refresh a profile.

Nothing needs root except the netplan grep, the hook scripts and
the netfilter reads in section F. Their `S` stands for the
privilege path `rules/privilege-escalation.md` found (`sudo -n`,
or the stand-in that file names); without one they print
`unknown(needs-root)`.

The probe reads hook scripts and never runs them, and it prints
only the lines of a script that change routes, rules, filters or
kernel settings: a line that names a key, a password, a token or
`ip xfrm` stays out, since such a script can carry a secret
(`rules/secrets.md`).

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
# One uplink per family: they are not always the same device.
up4=$(ip -4 route show default \
  | sed -n 's/.* dev \([^ ]*\).*/\1/p' | head -1)
up6=$(ip -6 route show default \
  | sed -n 's/.* dev \([^ ]*\).*/\1/p' | head -1)
# No default route in either family: the link SSH came in on.
up=${up4:-$up6}
[ -n "$up" ] || up=$(ip route get "${SSH_CONNECTION%% *}" \
  2>/dev/null | sed -n 's/.* dev \([^ ]*\).*/\1/p')
echo "uplink=$up uplink4=$up4 uplink6=$up6"
ups=$(printf '%s\n' "$up" $up4 $up6 | grep . | sort -u)
for i in $ups; do
  [ -e "/sys/class/net/$i/device" ] && echo "physical=$i"
done
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
ifs='/etc/network/interfaces /etc/network/interfaces.d/*'
grep -hE '^[[:space:]]*(auto|allow-hotplug|iface) ' $ifs 2>/dev/null
# Hooks: the stanza lines, the scripts they name, and the
# dispatcher scripts no package installed.
h='^[[:space:]]*(pre-up|up|post-up|down|pre-down|post-down)[[:space:]]'
x='xfrm|key|pass|secret|token|psk'
hl=$(grep -HnE "$h" $ifs 2>/dev/null)
echo "## hooks"
[ -n "$hl" ] && printf '%s\n' "$hl" | grep -viE "$x"
hs=$(printf '%s\n' "$hl" | cut -d: -f3- \
  | grep -oE '(^|[[:space:];&|])/[^[:space:];&|]+' | sed 's|^[^/]*||' \
  | grep -vE '^/(usr/)?s?bin/|^/(proc|sys|dev)/')
c=
for f in /etc/network/if-*.d/* /etc/NetworkManager/dispatcher.d/* \
  /etc/NetworkManager/dispatcher.d/*.d/* \
  /etc/networkd-dispatcher/*.d/* /etc/sysconfig/network/if-*.d/*; do
  [ -f "$f" ] && c="$c $f"
done
if command -v dpkg >/dev/null 2>&1; then
  o=$(dpkg -S $c 2>/dev/null | sed 's/^.*: //')
  for f in $c; do
    printf '%s\n' "$o" | grep -qxF "$f" || hs="$hs $f"
  done
else
  for f in $c; do
    rpm -qf "$f" >/dev/null 2>&1 || apk info -qW "$f" >/dev/null 2>&1 \
      || hs="$hs $f"
  done
fi
for f in /sbin/ifup-local /sbin/ifdown-local; do
  [ -f "$f" ] && hs="$hs $f"
done
hs=$(printf '%s\n' $hs | sort -u)
echo "scripts: $(printf '%s ' $hs)"
# Commands that change something, and assignments whose value is
# a netfilter tool, an address or an interface name.
p='^[[:space:]]*([a-z/]*/)?(ip6?tables(-legacy)?(-restore)?|nft|ip'
p="$p|sysctl|ebtables|bridge|brctl|tc)[[:space:]]"
p="$p|^[[:space:]]*\"?\\\$\{?[A-Za-z_]+\}?\"?[[:space:]]+-[tAIDNPF]"
v='(ip6?tables|nft)[^[:space:]]*|[0-9.]+(/[0-9]+)?|[0-9a-f]*:[0-9a-f:]*(/[0-9]+)?'
v="$v|(eth|en|br|vmbr|bond|vlan|wg|tun|tap|veth|wl)[a-z0-9.]*"
p="$p|^[[:space:]]*[A-Za-z_][A-Za-z0-9_]*=[\"']?($v)[\"']?[[:space:]]*\$"
p="$p|/proc/sys/|-j (DNAT|SNAT|MASQUERADE|REDIRECT|NETMAP)"
if [ -z "$hs" ]; then :
elif [ "$S" = - ]; then echo "scripts=unknown(needs-root)"
else
  # A hook that names a missing script fails when it runs.
  $S sh -c 'for f; do [ -f "$f" ] || echo "missing=$f"; done' sh $hs
  $S grep -HnE "$p" $hs 2>/dev/null | grep -viE "$x"
fi
if command -v networkctl >/dev/null 2>&1; then
  networkctl list --no-pager --no-legend \
    | grep -vE " ($n)"
  for i in $ups; do
    echo "== $i"
    networkctl status "$i" --no-pager -n0 2>/dev/null \
      | grep -E 'Network File|State:|Address|Gateway|DNS'
  done
fi
if command -v nmcli >/dev/null 2>&1; then
  nmcli -t -f DEVICE,TYPE,STATE,CONNECTION device \
    2>/dev/null | grep -vE "^($n)"
  for i in $ups; do
    c=$(nmcli -g GENERAL.CONNECTION device show "$i" \
      2>/dev/null)
    [ -n "$c" ] && echo "== $i" && nmcli -g \
      ipv4.method,ipv6.method connection show "$c"
  done
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
# Routes outside main and local, and the table names behind them.
for f in 4 6; do
  ip -$f route show table all 2>/dev/null | grep ' table ' \
    | grep -vE ' table (local|main)( |$)' | awk '
      { for (i = 1; i < NF; i++) if ($i == "table") t = $(i + 1)
        if (++n[t] <= 3) print }
      END { for (t in n) if (n[t] > 3) print "table " t ": " n[t] " routes" }'
done
grep -hsvE '^[[:space:]]*(#|$)' /etc/iproute2/rt_tables \
  /etc/iproute2/rt_tables.d/*.conf \
  | grep -vwE 'local|main|default|unspec'

echo "### C sysctl"
echo "ip_forward=$(cat /proc/sys/net/ipv4/ip_forward)"
for i in all $ups; do
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
  l=$(printf '%s|%s|%s' "$up" "${up4:-$up}" "${up6:-$up}")
  resolvectl dns 2>/dev/null \
    | grep -E "^(Global|Link [0-9]+ \(($l)\))"
  resolvectl domain 2>/dev/null \
    | grep -E "^(Global|Link [0-9]+ \(($l)\))"
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

echo "### F bridges and netfilter"
for b in /sys/class/net/*/bridge; do
  [ -d "$b" ] || continue
  b=${b%/bridge}; b=${b##*/}
  printf '%s\n' "$b" | grep -qE '^(docker|br-[0-9a-f]{12}|fwbr)' \
    && continue
  m=$(ls "/sys/class/net/$b/brif" 2>/dev/null)
  echo "bridge $b: ports=$(printf '%s\n' $m | grep -vE "^($n)" \
    | tr '\n' ' ')guests=$(printf '%s\n' $m | grep -E "^($n)" \
    | tr '\n' ' ')"
done
for k in iptables ip6tables; do
  v=$(cat /proc/sys/net/bridge/bridge-nf-call-$k 2>/dev/null)
  echo "bridge-nf-call-$k=${v:-absent}"
done
iv=$(iptables -V 2>/dev/null); echo "iptables=${iv:-none}"
# What restores rules at boot, besides the hooks above.
for u in netfilter-persistent iptables ip6tables nftables; do
  echo "unit $u=$(systemctl is-enabled "$u" 2>/dev/null)"
done
ls /etc/iptables/rules.v* /etc/sysconfig/ip*tables \
  /etc/nftables.conf /etc/rc.local 2>/dev/null
# Chains a container engine or Kubernetes writes are counted.
e='^(DOCKER|KUBE-|CNI-|cali-)'
nf=
if [ "$S" = - ]; then echo "netfilter=unknown(needs-root)"
else
  if ! command -v nft >/dev/null 2>&1; then echo "nft=none"
  elif r=$($S nft list ruleset 2>/dev/null); then
    echo "nft-tables=$(printf '%s\n' "$r" | grep -c '^table')"
    # A table with NAT comes in full, any other with its hooks.
    nf=$(printf '%s\n' "$r" | awk -v e="$e" '
      function flush() { if (t != "") printf "%s", (nat ? b : h)
        t = b = h = ""; nat = 0 }
      /^table/ { flush(); t = $0; b = h = $0 "\n"; next }
      $1 == "chain" { c = $2; s = 0; next }
      / hook / { h = h "  chain " c "\n" $0 "\n" }
      / hook |[^a-z_](dnat|snat|masquerade|redirect|jump|goto)([^a-z_]|$)/ {
        if (/[^a-z_](dnat|snat|masquerade|redirect)([^a-z_]|$)/) nat = 1
        if (c ~ e) { g = c; sub(/-.*/, "", g); k[g]++; next }
        if (!s) { b = b "  chain " c "\n"; s = 1 }; b = b $0 "\n" }
      END { flush(); for (g in k) print "  " g "*: " k[g] " lines" }')
  else echo "nft=unread"; fi
  # Legacy tables only where they exist: the legacy tools load
  # the modules that create them (Mixed frameworks in the
  # security skill's references/firewall-nftables-docker.md).
  case $iv in *nf_tables*) L=-legacy ;; *) L= ;; esac
  for t in ip ip6; do
    tn=$($S cat /proc/net/${t}_tables_names 2>/dev/null)
    [ -n "$tn" ] || continue
    b=${t}tables$L-save
    command -v "$b" >/dev/null 2>&1 \
      || { echo "$b=missing"; continue; }
    for tb in $tn; do
      case $tb in
        nat) r='^(:[A-Z]+ ACCEPT|\[[0-9:]+\] -A )' ;;
        filter) r='^(:[A-Z]+ (ACCEPT|DROP)|\[[0-9:]+\] -A FORWARD )' ;;
        *) continue ;;
      esac
      if o=$($S $b -t $tb -c 2>/dev/null); then
        c=; [ "$tb" = filter ] && c=", input-rules=$(printf \
          '%s\n' "$o" | grep -c ' -A INPUT ')"
        nf="$nf
== $b -t $tb$c
$(printf '%s\n' "$o" | grep -E "$r" | awk -v e="$e" '
  $2 == "-A" && $3 ~ e { g = $3; sub(/-.*/, "", g); k[g]++; next }
  { print }
  END { for (g in k) print g "*: " k[g] " rules" }')"
      else nf="$nf
== $b -t $tb unread"; fi
    done
  done
fi
printf '%s\n' "$nf"
# The route to each NAT target.
for a in $(printf '%s\n' "$nf" \
  | grep -oE '(--to-destination|dnat( ip6?)? to) [^ ]+' \
  | awk '{ a = $NF
      if (a ~ /^\[/) { sub(/^\[/, "", a); sub(/\].*/, "", a) }
      else if (a !~ /:.*:/) sub(/:.*/, "", a)
      sub(/-.*/, "", a); print a }' | sort -u); do
  case $a in *:*) f=6 ;; *) f=4 ;; esac
  echo "route-to $a: $(ip -$f route get "$a" 2>/dev/null | head -1)"
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
- **Hooks** are part of the configuration, and often the
  part that matters most: NAT, policy routing and sysctls
  set in a `post-up` line or a script it calls are
  applied with the interface and appear in no manager's
  view. `scripts:` names each script a hook line calls,
  and each dispatcher script no package installed; the
  lines after it are the ones that change something, with
  the assignments that name a tool, an address or an
  interface. `missing=<path>` is a script a hook line
  names that does not exist: that hook fails when it runs.
  A variable whose assignment is not among them
  is read with an anchored grep on its name
  (`rules/secrets.md`), never by printing the script. A
  script without printed lines changes nothing the profile
  records.

Reading **B (links, addresses, routes)**:

- `uplink4` and `uplink6` are the devices of the two default
  routes, and they differ on a host whose families run over
  different interfaces: judge each family by its own device, and
  the stack by both (`rules/network.md` → Stack). `uplink` is
  the one the rest of the probe keys on, IPv4's where there is
  one. Every other interface that is not a container or VM one is
  listed with its addresses too, so a multihomed host shows all
  of them; `wg*`, `tailscale0`, `zt*` and `tun*` among them are
  overlays.
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
  own rules; name the owner. The routes after the rules
  are what each extra table holds, the first three of
  each and `table <n>: <count> routes` for a longer one,
  and the lines after them the names `rt_tables` gives
  the table numbers.
  Record a rule with its selector and where its table
  sends the traffic: `from 192.0.2.10 to 10.0.0.0/8 →
  table fw, via 10.0.0.2`, and with what sets it: the
  manager's configuration, a hook line, or `wg-quick` and
  Tailscale for their own.
- A default route with `proto ra` and `expires`
  lives only as long as Router Advertisements keep
  arriving.

Reading **C (kernel)**:

- `disable_ipv6=1` on `all` or the uplink: IPv6 is
  off.
- The sysctl block prints `all` and each uplink once, so an IPv6
  setting is read on `uplink6`, which is where RAs arrive.
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

Reading **F (bridges and netfilter)** — the input for the
profile's `## Traffic flow` section (`rules/network.md`):

- `bridge <name>` lists the bridge's ports: `ports=` the
  physical NICs, bonds and VLANs, `guests=` the guest
  interfaces. Proxmox VE names these after the guest's ID
  (`tap105i0`, `veth105i0`, `fwpr105p0` for guest 105);
  elsewhere the guest inventory ties a port to its guest
  (`rules/hypervisors.md` → Inventory). Whether the host
  itself has an address on the bridge is in section B.
- `bridge-nf-call-iptables` and `-ip6tables`: `1` sends
  frames crossing a bridge through the IPv4 or IPv6
  netfilter hooks, iptables and nftables `ip` tables
  alike. `absent` means the `br_netfilter` module
  is not loaded, and loading it sets both to `1`, their
  default (<https://docs.kernel.org/networking/ip-sysctl.html>,
  `/proc/sys/net/bridge/*`). Read `0` and `absent` as the
  same state that can flip.
- `iptables=` names the backend of the `iptables` command:
  `(nf_tables)` or `(legacy)`, where a version without
  either is legacy. The `== …-save` blocks are the legacy
  tables, which `nft` does not show. `unread` is a failed
  read, never an empty rule set.
- The `unit` lines and the files after them are what can
  restore rules at boot besides the hooks:
  `netfilter-persistent` with `/etc/iptables/rules.v4`
  and `rules.v6`, the `iptables` services with
  `/etc/sysconfig/iptables`, `nftables` with
  `/etc/nftables.conf`, and `rc.local`. A firewall
  manager, a hypervisor firewall and a container engine
  write their own rules at start.
- `DOCKER*`, `KUBE*`, `CNI*`, `cali*` count the rules a
  container engine or Kubernetes writes for its
  containers; their jumps from the built-in chains stay
  listed.
- NAT rules come as `[packets:bytes] -A …` from the
  legacy tables, or with `counter packets …` from
  nftables, where a rule without `counter` has none. The
  counters start when the rule is loaded, so `0` means
  no match since then: compare with the uptime and the
  time the hook ran. iptables-nft rules show up in nft
  syntax with `xt` where nft cannot translate a match;
  read that table with `iptables-save -t <table>` instead.
- **A jump** (`-A PREROUTING -i vmbr2 -j FWD`) carries its
  conditions into the chain it calls: read a DNAT in
  `FWD` together with the `-i` and `-d` of the jump.
- `route-to <address>` is the route to each NAT target.
  A DNAT target reached through the interface the rule
  matched on sends the packet back where it came from:
  the rule never delivers.
- The legacy filter lines give each family's `INPUT` and
  `FORWARD` policy, the FORWARD rules and the number of
  INPUT rules. From nftables come the base chains' `hook`
  lines with their policy, and the jumps and NAT rules;
  where the input or forward chains' rules matter, read
  that chain with `nft list chain <family> <table>
  <chain>`. Whether they form a firewall is the
  security audit's call; the profile records per family
  whether inbound traffic to the host is filtered at all.

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

