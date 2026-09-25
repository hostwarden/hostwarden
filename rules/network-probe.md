# Network Probes

The read-only probes behind `rules/network.md`, one call per
family, and how to read what they print. Load this file only
when that rule says to build or refresh a profile, or when
`rules/network-topology.md` → Uplinks asks for the path hint.

Nothing needs root except the netplan grep, the hook scripts and
the netfilter reads in section F. Where the probe says
`<privilege prefix>`, put the snippet from
`rules/privilege-escalation.md` → Stand-ins for sudo: it sets
`$SUDO`, and without a privilege path those reads print
`unknown(needs-root)`, or nothing, until the reruns that file
requires send each section sudo covers again whole, with its
variables and filters.

The probe reads hook scripts and never runs them, and it prints
only the lines of a script that change routes, rules, filters or
kernel settings. Such a line can carry a secret, so it keeps
only the arguments the reading needs (`rules/secrets.md` →
Commands That Leak): a command other than a network tool is cut
to its name (`curl ...`), `ip` on anything but an address, a
route, a rule, a neighbour, a link or a next hop to its object
(`ip x ...` for an IPsec key), and an assignment whose value is
not an address, a netfilter tool or one of the host's interfaces
to its name. A network tool keeps its options, and a quoted
string or the value of a free-text option shows as `...`: a
comment, a log prefix, a match string, a description, an alias,
options matched by prefix as the tools read them, and a shell
comment is dropped. As the backstop, a command that names a
password, a secret, a token or a key is cut to its name
whatever it is.

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
<privilege prefix>

echo "### A manager"
if [ -d /run/systemd/system ]; then
  for u in systemd-networkd NetworkManager networking \
           network wicked systemd-resolved resolvconf \
           dhcpcd connman; do
    printf '%s=%s\n' "$u" \
      "$(systemctl is-active "$u" 2>/dev/null)"
  done
elif command -v rc-update >/dev/null 2>&1; then
  # OpenRC: the runlevels say what starts the network.
  rc-update show boot default 2>/dev/null | grep -E \
    '^[[:space:]]*(networking|dhcpcd|connman|NetworkManager|iwd) '
fi
ls -d /etc/netplan/*.yaml /etc/network/interfaces \
  /etc/network/interfaces.d/* /etc/systemd/network/* \
  /etc/sysconfig/network-scripts/ifcfg-* \
  /etc/sysconfig/network/ifcfg-* 2>/dev/null
ifs='/etc/network/interfaces /etc/network/interfaces.d/*'
grep -hE '^[[:space:]]*(auto|allow-hotplug|iface) ' $ifs 2>/dev/null
# Hooks: the stanza lines, the scripts they name, and the
# dispatcher scripts no package installed.
h='^[[:space:]]*(pre-up|up|post-up|down|pre-down|post-down)[[:space:]]'
# What of a hook line is printed: the top of this file. The rest
# is cut, since it can carry a credential (`ip x s add ... 0x<key>`).
t='^(ip6?tables(-legacy)?(-restore)?|nft|sysctl|ebtables|arptables'
t="$t|bridge|brctl|tc|ipset|route|firewall-cmd|ufw|conntrack)\$"
# An assignment's value printed whole: an address or a netfilter
# tool ($vs), or an interface this host has ($il); $v also selects
# numbers and names that look like an interface, shown withheld.
vs='[0-9]+[.][0-9]+[.][0-9]+[.][0-9]+(/[0-9]+)?|(ip6?tables|nft)(-[a-z]+)*'
vs="$vs|[0-9a-f]*:[0-9a-f]*:[0-9a-f:]*(/[0-9]+)?"
v="$vs|[0-9]+|0x[0-9a-f]+(/0x[0-9a-f]+)?"
v="$v|(eth|en|br|vmbr|bond|vlan|wg|tun|tap|veth|wl)[a-z0-9.]*"
il=$(ls /sys/class/net 2>/dev/null | tr '\n' ' ')
rd='BEGIN { split(il, f, " "); for (k in f) isif[f[k]]
  x = "pass(word|wd|phrase)|secret|token|psk|apikey|(^|[^a-z])key([^a-z]|$)"
  split("comment log-prefix nflog-prefix ulog-prefix string hex-string" \
    " set-description set-short", fo, " ")
  fw = "^(comment|alias|sdata|description)$" }
# an option or word whose value is free text; options match by
# prefix, as iptables and firewall-cmd read them
function ftx(s,   q, i) { if (s ~ fw) return 1
  if (s !~ /^--/) return 0; q = s; sub(/^--/, "", q); sub(/=.*/, "", q)
  if (q == "") return 0
  for (i in fo) if (index(fo[i], q) == 1) return 1
  return 0 }
{ pre = ""; l = $0
  if (match(l, /^[^:]*:[0-9]+:/)) {
    pre = substr(l, 1, RLENGTH); l = substr(l, RLENGTH + 1) }
  sub(/^[[:space:]]+/, "", l); hk = ""
  if (l ~ /^(pre-up|up|post-up|down|pre-down|post-down)[[:space:]]/) {
    hk = l; sub(/[[:space:]].*/, "", hk)
    sub(/^[^[:space:]]+[[:space:]]+/, "", l); hk = hk " " }
  # a quoted string stays only where it is an address, a port or
  # range, an interface of this host or a variable, before the
  # line is split: a separator inside quotes is text. An escaped
  # character is text too; a quote still left marks a command
  # whose quoting was not followed, and cuts it to its name
  gsub(/\\./, "_", l)
  q = ""; while (match(l, /"[^"]*"|\047[^\047]*\047/)) {
    a = substr(l, RSTART + 1, RLENGTH - 2)
    q = q substr(l, 1, RSTART - 1) (a ~ ("^(" vs ")$") \
      || a ~ /^[0-9.:\/,-]+$/ || (a in isif) \
      || a ~ /^\$\{?[A-Za-z_][A-Za-z0-9_]*\}?$/ ? a : "...")
    l = substr(l, RSTART + RLENGTH) }
  l = q l
  # a shell comment is free text; a lone & starts a command too
  sub(/(^|[[:space:];&|])#.*/, "", l); gsub(/[0-9]*>&[0-9-]*/, "", l)
  if (l ~ /["\047]/) { w = l; sub(/[[:space:]].*/, "", w)
    print pre hk w " ..."; next }
  n = split(l, sg, /[[:space:]]*[;&|]+[[:space:]]*/); o = ""
  for (i = 1; i <= n; i++) {
    c = sg[i]; w = c; sub(/[[:space:]].*/, "", w)
    sub(/=.*/, "=", w); b = w; sub(/.*\//, "", b); ok = 0
    if (b == "ip") {
      k = split(c, tk, /[[:space:]]+/); j = 2
      while (j < k && tk[j] ~ /^-/) {
        # ip reads options by prefix; these four take an argument
        op = tk[j]; sub(/^--?/, "", op)
        if (op != "" && (index("family", op) == 1 || index("netns", op) == 1 \
          || index("loops", op) == 1 \
          || (index("rcvbuf", op) == 1 && length(op) > 1))) w = w " " tk[j++]
        w = w " " tk[j++] }
      if (j <= k) { w = w " " tk[j]; ok = tk[j] != "" && index(\
        " address route rule neighbor neighbour link nexthop", " " tk[j]) }
    } else if (w ~ /=$/) {
      a = c; sub(/^[^=]*=/, "", a); gsub(/["\047]/, "", a)
      ok = a ~ ("^(" vs ")$") || (a in isif)
    } else ok = b ~ t \
      || c ~ /^"?\$\{?[A-Za-z_]+\}?"?[[:space:]]+-[tAIDNPF]/ \
      || (b == "echo" && c ~ />[[:space:]]*\/proc\/sys\//)
    if (!ok || c ~ /[$<>]\(|`|["\047]/ || tolower(c) ~ x) c = w " ..."
    else if (b != "echo") {
      # a network tool keeps its options, never free text
      r = c; sub(/^[^[:space:]]+/, "", r)
      c = substr(c, 1, length(c) - length(r))
      k = split(r, tk, /[[:space:]]+/)
      for (m = 1; m <= k; m++) if (tk[m] != "") {
        v2 = tk[m]; o2 = v2; sub(/=.*/, "", o2)
        if (m > 1 && tk[m - 1] !~ /=/ && ftx(tk[m - 1]) \
          && tk[m - 2] != "-m") v2 = "..."
        else if (v2 ~ /=/ && ftx(o2)) v2 = o2 "=..."
        c = c " " v2 } }
    o = o (i > 1 ? "; " : "") c }
  print pre hk o }'
hl=$(grep -HnE "$h" $ifs 2>/dev/null)
echo "## hooks"
[ -n "$hl" ] && printf '%s\n' "$hl" \
  | awk -v t="$t" -v vs="$vs" -v il="$il" "$rd"
# the scripts a hook line runs: a path in command position, and
# any other path word that is a script here: executable, a #!
# line or a script's extension (one behind env, timeout or
# python3); an argument that is neither can be a token or a key.
# Tested with the privilege path; one a user cannot test counts
T=$SUDO; [ "$T" = - ] && T=
r='((\.|source|exec|([a-z/]*/)?(sh|bash|dash))[[:space:]]+)?'
hc=$(printf '%s\n' "$hl" | cut -d: -f3- \
  | sed -E 's/^[[:space:]]*[a-z-]+[[:space:]]+//' | tr ';&|' '\n\n\n')
hs=$({ printf '%s\n' "$hc" | sed -nE "s#^[[:space:]]*$r(/[^[:space:]]+).*#\\5#p"
  printf '%s\n' "$hc" | grep -oE "(^|[[:space:]=])/[^[:space:]\"']+" \
    | sed 's|^[^/]*||' | while IFS= read -r w; do
      $T test -f "$w" || { [ "$SUDO" = - ] && ! LC_ALL=C ls -d "$w" 2>&1 \
        | grep -q 'No such file' && echo '(unread)'; continue; }
      case $w in *.sh|*.bash|*.py|*.pl) echo "$w"; continue ;; esac
      { $T test -x "$w" || [ "$($T head -c 2 "$w" 2>/dev/null)" = '#!' ]; } \
        && echo "$w"; done
  } | grep -vE '^/(usr/)?s?bin/|^/(proc|sys|dev)/')
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
hu=$(printf '%s\n' $hs | grep -c '^(unread)$')
hs=$(printf '%s\n' $hs | grep -v '^(unread)$' | sort -u)
echo "scripts: $(printf '%s ' $hs)"
[ "$hu" -gt 0 ] && echo "scripts-unread=$hu(needs-root)"
# Commands that change something, and assignments whose value is
# a netfilter tool, an address, a number or an interface name ($v).
p='^[[:space:]]*([a-z/]*/)?(ip6?tables(-legacy)?(-restore)?|nft|ip'
p="$p|sysctl|ebtables|arptables|bridge|brctl|tc|ipset|route"
p="$p|firewall-cmd|ufw|conntrack|wg|wg-quick)[[:space:]]"
p="$p|^[[:space:]]*((\\.|source|sh|bash|exec)[[:space:]]+)?/[A-Za-z0-9_./-]+"
p="$p|^[[:space:]]*\"?\\\$\{?[A-Za-z_]+\}?\"?[[:space:]]+-[tAIDNPF]"
p="$p|^[[:space:]]*[A-Za-z_][A-Za-z0-9_]*=[\"']?($v)[\"']?[[:space:]]*\$"
p="$p|/proc/sys/|-j (DNAT|SNAT|MASQUERADE|REDIRECT|NETMAP)"
if [ -z "$hs" ]; then :
elif [ "$SUDO" = - ]; then echo "scripts=unknown(needs-root)"
else
  # Per script, the first word of every line that is a command,
  # a path or a variable; any other word is counted, not shown.
  q='set -f; for f; do
    [ -f "$f" ] || { echo "missing=$f"; continue; }
    w=; o=0
    for c in $(grep -vE "^[[:space:]]*(#|\$)" "$f" | sed -e "s/^[[:space:]]*//" \
      -e "s/[[:space:];].*//" -e "s/^\([A-Za-z_][A-Za-z0-9_]*\)=[^=].*/\1=@/" \
      | sort -u); do
      # NAME= only with a value after it (a padded key ends in =),
      # $ only before a name, a path only one that exists here
      case $c in
        *=@) w="$w ${c%@}" ;;
        /*[+=]*) o=$((o + 1)) ;;
        /*) if [ -e "$c" ]; then w="$w $c"; else o=$((o + 1)); fi ;;
        \$[A-Za-z_{]*|\"\$[A-Za-z_{]*) w="$w $c" ;;
        *) if command -v "$c" >/dev/null 2>&1; then w="$w $c"
           else o=$((o + 1)); fi ;;
      esac
    done
    echo "$f:$w (other: $o)"
  done'
  $SUDO sh -c "$q" sh $hs
  $SUDO grep -HnE "$p" $hs 2>/dev/null \
    | awk -v t="$t" -v vs="$vs" -v il="$il" "$rd"
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
  if [ "$SUDO" = - ]; then echo "netplan=unknown(needs-root)"
  else $SUDO grep -HE \
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
# Policy routing that a manager restores.
grep -HsE '^[[:space:]]*(\[RoutingPolicyRule\]|Table=)' \
  /etc/systemd/network/*.network /run/systemd/network/*.network
ls /etc/sysconfig/network-scripts/rule*-* \
  /etc/sysconfig/network/ifrule-* 2>/dev/null
if ls /etc/netplan/*.yaml >/dev/null 2>&1 && [ "$SUDO" != - ]; then
  $SUDO grep -HnE '^[[:space:]]*(routing-policy|table):' /etc/netplan/*.yaml
fi
if command -v nmcli >/dev/null 2>&1; then
  nmcli -g NAME connection show 2>/dev/null | while IFS= read -r c; do
    r=$(nmcli -g ipv4.routing-rules,ipv6.routing-rules \
      connection show "$c" 2>/dev/null | grep .)
    [ -n "$r" ] && echo "nm $c: $r"
  done
fi
# Main-table routes beyond the default and the connected ones,
# with a count; over 50, the count alone. `proto` names what wrote
# each; a host route prints no prefix length and is left out. A
# multipath (ECMP) route splits its prefix and each `nexthop` onto
# its own line; they are kept as one route.
for f in 4 6; do
  ip -$f route show table main 2>/dev/null \
    | grep -vE " dev (lo( |$)|($n)[^ ]*( |$))| proto kernel " \
    | awk -v f="$f" '
      /^[^[:space:]]/ { if (p != "") l[++c] = p; p = ($1 ~ /\//) ? $0 : ""
        next }
      p != "" { p = p " | " $0 }
      END { if (p != "") l[++c] = p
            if (c <= 50) for (i = 1; i <= c; i++) print "route" f " " l[i]
            print "routes" f "=" c + 0 }'
done
# The host's own tagged interfaces: name@parent and `vlan … id`,
# or the kernel's table where BusyBox ip has no `type`.
{ ip -d link show type vlan 2>/dev/null \
  || cat /proc/net/vlan/config 2>/dev/null; } \
  | grep -E '^[0-9]+: |vlan protocol|^[^ |]+ +\| +[0-9]+ +\| '
# Each default gateway's neighbour entry, one line per gateway
# and device; an empty one means none.
for f in 4 6; do
  ip -$f route show default 2>/dev/null | awk '/ via / {
      for (i = 1; i < NF; i++) { if ($i == "via") g = $(i + 1)
        if ($i == "dev") d = $(i + 1) }
      print g, d }' | sort -u | while read -r g d; do
    echo "gw$f $g $d: $(ip -$f neigh show to "$g" dev "$d" 2>/dev/null)"
  done
done
# Routing daemons, by program name; hidepid says whether ps saw
# other users' processes.
r='watchfrr|zebra|bgpd|ospf6?d|isisd|ripd|ripngd|babeld|bird6?|keepalived|vrrpd'
echo "## routing daemons"
[ "$(id -u)" != 0 ] && grep -o 'hidepid=[a-z0-9]*' /proc/mounts
ps -Ao comm= 2>/dev/null | sed 's|.*/||' | sort -u | grep -xE "$r"

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
  resolvectl mdns 2>/dev/null \
    | grep -E "^(Global|Link [0-9]+ \(($l)\))"
  resolvectl status --no-pager 2>/dev/null \
    | grep -E 'resolv.conf mode|Protocols' | sort -u
fi
grep '^hosts:' /etc/nsswitch.conf
ss -lnu 'sport = :53' | tail -n +2
ss -lnt 'sport = :53' | tail -n +2
# mDNS: who listens, and the name avahi announces
# (resolved's view is the resolvectl mdns lines above).
ss -lnu 'sport = :5353' | tail -n +2
ps -eo args | grep -E '^avahi-daemon: [a-z]+ \['
grep -sE '^[[:space:]]*(disable-publishing|publish-addresses)[[:space:]]*=' \
  /etc/avahi/avahi-daemon.conf
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
  | grep -oE 'https?://[^/ "]+' | sed 's|//.*@|//|' \
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
if [ -d /run/systemd/system ]; then
  for u in netfilter-persistent iptables ip6tables nftables; do
    echo "unit $u=$(systemctl is-enabled "$u" 2>/dev/null)"
  done
elif command -v rc-update >/dev/null 2>&1; then
  rc-update show boot default 2>/dev/null \
    | grep -E '^[[:space:]]*(iptables|ip6tables|nftables) ' \
    | sed 's/^[[:space:]]*/unit /'
fi
ls /etc/iptables/rules* /etc/sysconfig/ip*tables \
  /etc/nftables.conf /etc/nftables.nft /etc/rc.local \
  /etc/local.d/*.start 2>/dev/null
# Chains a container engine or Kubernetes writes are counted.
e='^(DOCKER|KUBE-|CNI-|cali-)'
# Rule comments, labels, log prefixes and match strings show as
# `...` (rules/secrets.md → Commands That Leak, one filter).
fc='s/(^|[^-])comment ".*"$/\1comment "..."/
s/((comment|label|prefix|match|string)"?:?[ =!]*)"([^"\\]|\\.)*"/\1"..."/g
s/(--comment|--(hex-)?string|-?-?(log|nflog|ulog)-prefix)([ =]+)[^ "]+/\1\4.../g
s#/\*.*\*/#/* ... */#
s/(^|[[:space:]])#.*/\1# .../
s|[[:space:]]//.*| // ...|'
nf=
if [ "$SUDO" = - ]; then echo "netfilter=unknown(needs-root)"
else
  if ! command -v nft >/dev/null 2>&1; then echo "nft=none"
  elif r=$($SUDO nft list ruleset 2>/dev/null); then
    r=$(printf '%s\n' "$r" | sed -E "${fc:?}")
    echo "nft-tables=$(printf '%s\n' "$r" | grep -c '^table')"
    # A table with NAT comes in full, any other with its hooks.
    nf=$(printf '%s\n' "$r" | awk -v e="$e" '
      function flush() { if (t != "") printf "%s", (nat ? b : h)
        t = b = h = ""; nat = 0 }
      /^table/ { flush(); t = $0; b = h = $0 "\n"
        q = ($3 == "kube-proxy"); if (q) t = b = h = ""; next }
      q { if ($0 ~ /[^a-z_](dnat|snat|masquerade)/) k["kube-proxy"]++
          next }
      $1 == "set" || $1 == "map" { m = 1 }
      m { b = b $0 "\n"; if ($1 == "}") m = 0; next }
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
    tn=$($SUDO cat /proc/net/${t}_tables_names 2>/dev/null)
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
      if o=$($SUDO $b -t $tb -c 2>/dev/null); then
        c=; [ "$tb" = filter ] && c=", input-rules=$(printf \
          '%s\n' "$o" | grep -c ' -A INPUT ')"
        nf="$nf
== $b -t $tb$c
$(printf '%s\n' "$o" | grep -E "$r" | sed -E "${fc:?}" | awk -v e="$e" '
  $2 == "-A" && $3 ~ e { g = $3; sub(/-.*/, "", g); k[g]++; next }
  { print }
  END { for (g in k) print g "*: " k[g] " rules" }')"
      else nf="$nf
== $b -t $tb unread"; fi
    done
  done
fi
printf '%s\n' "$nf"
# The ipsets NAT rules match on.
if [ "$SUDO" != - ]; then
  for m in $(printf '%s\n' "$nf" | grep -oE -- '--match-set [^ ]+' \
    | cut -d' ' -f2 | sort -u); do
    echo "== ipset $m"; $SUDO ipset list "$m" 2>&1 | head -20
  done | sed -E "${fc:?}"
fi
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
- On OpenRC (Alpine) the runlevel lines name the manager:
  `networking` is ifupdown-ng reading `/etc/network/interfaces`,
  `dhcpcd`, `connman`, `NetworkManager` or `iwd` their own. A
  host with none of them in a runlevel has no network manager
  at boot; record that, not `unknown`.
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
  view. `scripts:` names each script a hook line runs as
  a command, each other path in it that is a script here
  (behind `env`, `timeout` or an interpreter; never a key
  or password file it names), with `scripts-unread=<n>`
  for those a session without root could not test,
  and each dispatcher script no package installed. Then,
  per script, the first words of its lines that are a
  command, a path or a variable, with `other:` counting
  the rest (heredoc text, a function the script defines),
  which can be data and is not shown; and `missing=<path>`
  for a script a hook line names that does not exist: that
  hook fails when it runs. The lines after that are the ones
  that change something, with the assignments that name a
  tool, an address, a number or an interface, cut as the
  top of this file says. A command among the
  first words whose lines are not printed — another tool,
  a function, a program the pattern does not know — is
  read with an anchored grep on that word, and so is a
  variable whose assignment is missing; that grep prints
  what the reading needs of the line, an option name, a
  path or a count, never the line itself
  (`rules/secrets.md`), and never the script. A withheld
  assignment the reading needs (`TABLE= ...`, a `DEV=`
  naming an interface the hook creates) is read by its name with an
  anchored grep, as `rules/secrets.md` reads a key's
  value: only where the name holds no credential.
  Only a script whose words are all accounted for is
  fully read.

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
  the lines after them the names `rt_tables` gives the
  table numbers, and then what a manager restores:
  networkd's `[RoutingPolicyRule]` and `Table=`, netplan's
  `routing-policy` and `table:`, the ifcfg `rule-*` and
  `ifrule-*` files, and NetworkManager's `routing-rules`
  per connection.
  Record a rule with its selector and where its table
  sends the traffic: `from 192.0.2.10 to 10.0.0.0/8 →
  table fw, via 10.0.0.2`, and with what sets it: the
  manager's configuration, a hook line, or `wg-quick` and
  Tailscale for their own.
- A default route with `proto ra` and `expires`
  lives only as long as Router Advertisements keep
  arriving.
- **The `route4`/`route6` lines** are the main table beyond the
  default route, connected routes, host routes, routes on `lo` or
  a container interface, and every route whose first field is not
  a prefix (`local`, `blackhole`, `unreachable` and the other
  types). `routes<f>=<n>` counts them; over 50 it stands alone.
  They are read as `rules/network-topology.md` → Edges and
  Dynamic routing say. A multipath (ECMP) route's `nexthop` lines
  stay joined to its prefix as one `| `-separated route, one edge
  per next hop (Edges). BusyBox `ip` prints no `proto`: there, a
  route without `via` whose prefix the address listing gives on
  that device is a connected route, left out.
- **The VLAN lines** name each tagged interface of the host's own
  with its parent and tag: `eth0.10@eth0` then `vlan protocol
  802.1Q id 10`, or the kernel table's `eth0.10 | 10 | eth0`.
- **The `gw4`/`gw6` lines** give each default gateway's neighbour
  entry. An `lladdr` with `REACHABLE`, `STALE`, `DELAY`, `PROBE`,
  `PERMANENT` or `NOARP` is a known MAC, recorded on the profile's
  `Default:` line (`rules/network.md` → Where it goes); `FAILED`,
  `INCOMPLETE`, no `lladdr` or an empty entry is not known.
- **The routing-daemon lines** name each routing program that
  runs, one per line, read as `rules/network-topology.md` →
  Dynamic routing says; `comm` is the program, never its command
  line. A `hidepid=` line other than `hidepid=0` or `hidepid=off`
  means `ps` saw only this user's processes: an empty list is then
  `unchecked`, never none.

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
- A listener on UDP 5353 is an mDNS responder, or a
  program that only asks there, such as a media
  server or a browser. Name it:
  - **avahi** by its `avahi-daemon: running
    [<name>.local]` line, with the name it announces,
    and only beside a listener: `ps` also shows the
    avahi of a container, which is not the host's.
    `disable-publishing=yes` or
    `publish-addresses=no` in its configuration
    means it announces no address for the host.
  - **systemd-resolved** by the `resolvectl mdns`
    lines, where both `Global` and the uplink's
    `Link` say `yes`; `resolve` on either only asks.
  - **A name conflict:** an announced name that is
    the host's own (`hostname -f` up to the first
    dot) with `-2` or higher appended. Another
    machine on the link held the name first.

  Record `mDNS responder:` in the profile's DNS
  section (`rules/network.md`): each responder named
  above, avahi with its name and `publishes no
  address` where so configured. Any other listener is
  `UDP 5353: unnamed, may only ask`: without `-p`,
  a socket of resolved in `resolve` mode, a
  program's that only asks and one that answers look
  alike. `none` only where nothing listens. It is a
  note, not a finding.
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
  `/etc/sysconfig/iptables` or, on Alpine,
  `/etc/iptables/rules-save` and `rules6-save` (awall's
  output too), `nftables` with `/etc/nftables.conf` or
  Alpine's `/etc/nftables.nft`, and `rc.local` or
  `/etc/local.d`. On OpenRC a `unit` line is a runlevel
  entry. A firewall
  manager, a hypervisor firewall and a container engine
  write their own rules at start.
- `DOCKER*`, `KUBE*`, `CNI*`, `cali*` count the rules a
  container engine or Kubernetes writes for its
  containers; their jumps from the built-in chains stay
  listed.
- A rule's comment, label, log prefix or match string
  shows as `...` (`rules/secrets.md` → Commands That
  Leak): read what the rule matches and where it sends
  the packet, never what it says about itself.
- NAT rules come as `[packets:bytes] -A …` from the
  legacy tables, or with `counter packets …` from
  nftables, where a rule without `counter` has none. The
  counters start when the rule is loaded, so `0` means
  no match since then: compare with the uptime and the
  time the hook ran. iptables-nft rules show up in nft
  syntax with `xt` where nft cannot translate a match;
  read that table with
  `iptables-save -t <table> | sed -E "${fc:?}"` instead.
- A table with NAT comes with its `set` and `map`
  declarations, and a rule that matches an ipset
  (`--match-set`) with the first lines of `ipset list`: a
  NAT rule limited to a set of the host's own addresses is
  limited to the host.
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
  that chain with
  `nft list chain <family> <table> <chain> | sed -E "${fc:?}"`.
  Whether they form a firewall is the security audit's
  call; the profile records per family whether inbound
  traffic to the host is filtered at all.

## Route filter

The FreeBSD and macOS probes put this where they say
`<route filter>`: `bf`, the `awk` program their route lines run
through.

```bash
bf='NF >= 4 && $1 != "Destination" && $4 != "lo0" && $3 !~ /I/ \
  && $1 !~ /^(fe80|ff[0-9a-f][0-9a-f]):/ \
  && $1 !~ /^(169\.254|22[4-9]|23[0-9]|255\.255\.255\.255)([.\/]|$)/ {
    if ($1 == "default") { print "default-" f " " $2 " " $3 " " $4; next }
    if ($3 ~ /G/ || ($3 ~ /S/ && $3 !~ /H/ && $2 ~ /^link#/ \
      && $1 !~ /\/(32|128)$/)) l[++c] = $0 }
  END { if (c <= 50) for (i = 1; i <= c; i++) print "route-" f " " l[i]
        print "routes-" f "=" c + 0 }'
```

- **Kept:** every default route, as one `default-<family>` line with
  its gateway, flags and device; the routes through a gateway (flag
  `G`), static host routes included; and the static routes set on
  an interface (`S` with a `link#` gateway, not a host), such as
  the routes a tunnel's peers get. `route-<family>` lines, and a
  count line that stands alone over 50, as on Linux.
- **Left out:** `lo0`; interface-scoped copies (flag `I`), which
  macOS lists for many interfaces, often ahead of the real
  default; the link-local, multicast and broadcast scope routes
  every interface carries; and host entries. On FreeBSD a
  connected route is left out too: `S` (`RTF_STATIC`) means
  "manually added", and a kernel-created connected route isn't,
  so it never matches the kept `S` + `link#` branch. On a router
  nearly every entry is one of these.
- **macOS only:** its connected routes carry `S` with a `link#`
  gateway too, the same pattern a tunnel's peer route uses, so
  this filter cannot tell the two apart by flags alone there, and
  a connected network can still print as a `route-<family>` line.
  Telling them apart needs `ifconfig`: see "Probe — macOS" below.

## Probe — FreeBSD

```bash
sysrc -a | grep -E \
  -e '^(ifconfig_|ipv6_|defaultrouter|rtsold|gateway_enable)' \
  -e '^(resolv|local_unbound|dhclient|cloudinit|nuageinit)'
ifconfig -a | grep -E '^[a-z]|inet6? |ether |vlan: |nd6 options|status:'
<route filter>
# Each default gateway's neighbour entry, per gateway and device.
for f in inet inet6; do
  o=$(netstat -rn -f $f | awk -v f="$f" "$bf")
  printf '%s\n' "$o"
  printf '%s\n' "$o" | awk '/^default-/ && $2 !~ /^link#/ { print $2, $4 }' \
    | sort -u | while read -r g d; do
    echo "== gw-$f $g $d"
    case $f in inet) arp -n "$g" 2>&1 ;; *) ndp -n "$g" 2>&1 ;; esac
  done
done
sysctl net.inet.ip.forwarding net.inet6.ip6.forwarding \
  net.inet6.ip6.accept_rtadv
r='watchfrr|zebra|bgpd|ospf6?d|isisd|ripd|ripngd|babeld|bird6?|keepalived|vrrpd'
ps -Ao comm= 2>/dev/null | sed 's|.*/||' | sort -u | grep -xE "$r"
grep -E '^(nameserver|search|domain|options)' \
  /etc/resolv.conf
hostname
sysctl -n security.bsd.see_other_uids
sockstat -4 -6 -l | grep -E ':5353\b'
ps -ax -J 0 -o args \
  | grep -E '^(avahi-daemon: [a-z]+ \[|(/usr/local/sbin/)?mdnsd)'
grep -sE '^[[:space:]]*(disable-publishing|publish-addresses)[[:space:]]*=' \
  /usr/local/etc/avahi/avahi-daemon.conf
```

- `rc.conf` is the source of truth, except on an appliance whose
  file replaces Networking (OPNsense, pfSense, TrueNAS CORE):
  `sysrc -a` prints nothing of the network there, and that file
  names the source.
  `ifconfig_<if>="DHCP"` (or `SYNCDHCP`) is DHCP;
  `ifconfig_<if>_ipv6="inet6 accept_rtadv"` together
  with `rtsold_enable="YES"` is SLAAC.
- `nd6 options` on each interface: `ACCEPT_RTADV`
  accepts RAs, `IFDISABLED` means IPv6 is off.
- `ether` is each interface's MAC, and `vlan: <tag> … parent
  interface: <if>` a tagged interface's tag and parent. Both
  serve `rules/network-topology.md`: an appliance built on
  FreeBSD gives its own interface MACs here for Range identity.
- The `default-`, `route-` and count lines read as Route filter
  says. Each default gateway's neighbour entry follows under
  `== gw-<family> <gateway> <device>`; a default whose gateway is
  `link#<n>` goes out an interface with no next hop, and has no
  neighbour entry and no MAC.
- `arp -n` and `ndp -n` give each gateway's link-layer address:
  `at <mac>` and the `Linklayer Address` column are a known MAC;
  `-- no entry`, `(incomplete)`, or a header with no row under it
  is not known. `ndp -n` writes `-- no entry` to stderr, which the
  probe joins to stdout.
  The routing-daemon lines read as on Linux; where
  `see_other_uids` is `0` and the probe ran without root, an empty
  list is `unchecked`, as for mDNS below.
- With `ip6.forwarding=1` FreeBSD ignores RAs by
  default. Check `sysctl -d net.inet6.ip6.rfc6204w3`
  on the host before relying on that knob.
- The last lines give the mDNS responder, read as on
  Linux (Reading D), with `hostname` as the host's
  own name. `ps -J 0` lists the host's processes
  alone, not a jail's; `sockstat` names the command
  on the port. `mdnsd` is Apple's mDNSResponder, the
  responder of TrueNAS CORE: record it by that name.
  Any other command `sockstat` names is recorded in
  place of `unnamed`. Where `see_other_uids` is `0`
  and the probe ran without root, both lines miss
  other users' processes (`rules/os/freebsd.md` →
  Networking): nothing found there is
  `unchecked (needs root)`, not `none`.

## Probe — macOS

```bash
networksetup -listnetworkserviceorder
scutil --nwi
ifconfig | grep -E '^[a-z]|inet6? |ether |vlan: '
route -n get default 2>/dev/null \
  | grep -E 'gateway|interface'
route -n get -inet6 default 2>/dev/null \
  | grep -E 'gateway|interface'
<route filter>
for f in inet inet6; do
  o=$(netstat -rn -f $f | awk -v f="$f" "$bf")
  printf '%s\n' "$o"
  printf '%s\n' "$o" | awk '/^default-/ && $2 !~ /^link#/ { print $2, $4 }' \
    | sort -u | while read -r g d; do
    echo "== gw-$f $g $d"
    case $f in
      inet) arp -n "$g" 2>&1 ;;
      # macOS ndp has no single-host query: -an dumps every entry.
      *) ndp -an | awk -v g="${g%%%*}" -v d="$d" \
           '$1 ~ "^" g "(%|$)" && $3 == d' ;;
    esac
  done
done
scutil --dns | grep -E '^resolver|nameserver|search domain|if_index' \
  | head -40
sysctl net.inet.ip.forwarding net.inet6.ip6.forwarding
r='watchfrr|zebra|bgpd|ospf6?d|isisd|ripd|ripngd|babeld|bird6?|keepalived|vrrpd'
ps -Ao comm= 2>/dev/null \
  | grep -vE '^/(System|usr/(bin|sbin|libexec)|bin|sbin)/|[.](app|framework)/' \
  | sed 's|.*/||' | sort -u | grep -xE "$r"
scutil --get LocalHostName
scutil --get ComputerName
defaults read /Library/Preferences/com.apple.mDNSResponder \
  NoMulticastAdvertisements 2>/dev/null
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
- `ether`, `vlan:`, the route, default and count lines and the
  routing-daemon lines read as on FreeBSD; macOS shows every
  user's processes. A connected route carries `S` here, as
  in `192.168.1 link#12 UCS en0`: a `link#` route whose prefix
  `ifconfig` gives an address in, on that device, is connected and
  no edge. A trailing mark some entries carry in the `Expire`
  column is not that signal — it tracks ARP or ND cache state, not
  whether the route is connected — so never use it as a shortcut
  for this check. `arp -n` reads the same. macOS `ndp` has no
  `ndp -n <address>` query, unlike FreeBSD's: `ndp -an` lists
  every neighbour, matched here to the gateway's address with its
  `%<zone>` suffix stripped and to the default's device. A
  matching line's second column is the link-layer address,
  `(incomplete)` where none is known; no line is no entry.
- `comm` is the full path of each process on macOS, so the
  routing-daemon check first leaves out what Apple ships — the
  system directories and anything inside an app or framework
  bundle — and then matches the program's name: Apple ships no
  routing daemon, and its iCloud Drive daemon is called `bird`.
- mDNSResponder always runs and answers for
  `<LocalHostName>.local`: record
  `mDNS responder: mDNSResponder (<name>.local)`.
  `NoMulticastAdvertisements` `1` stops it
  advertising services; add `no service adverts`.
  A `LocalHostName` ending in `-2` or higher that
  the `ComputerName` does not end in is a name
  conflict: another machine on the link held the
  name first, and macOS renamed this one.

## Egress test

One request per address family to a host the machine
already talks to, so the test adds no new third
party: on Linux the first answering repository host
(section E of the probe), on FreeBSD the host of the
`pkg` repository (its host as `rules/os/freebsd.md`
→ Package Manager reads it: `pkg.FreeBSD.org`),
on macOS Apple's update host `swscan.apple.com`. On
FreeBSD use `fetch -4` / `fetch -6` with
`-q -T 5 -o /dev/null`; on macOS `curl` as in the
Linux probe.

Hosts behind an internal mirror or a strict egress
filter override the target (`rules/overrides.md`): a
`## Replace: Egress test target` section in
`memory/custom-rules/network-probe.md` (fleet-wide) or in
`memory/machines/<hostname>/rules.md`. On Linux, set
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
external echo service. Do that only as
`rules/network-topology.md` → Uplinks allows it.

## Path hint

At most three hops towards the IPv4 egress target, run only when
`rules/network-topology.md` → Uplinks asks for it. It installs
nothing: with no tool below on the host, there is no hint. `h` is
the host of the target the egress test used, without its scheme or
port, and `o` the overlay pattern of `rules/mesh-vpn.md` → Probe
(no root).

Linux:

```bash
h=<target host>
o='(wg|tailscale|ts|zt|nebula|netmaker|wt|utun|tun)[0-9a-z.-]*'
a=$(getent ahostsv4 "$h" | awk 'NR == 1 { print $1 }')
i=$(ip -4 route get "$a" 2>/dev/null | sed -n 's/.* dev \([^ ]*\).*/\1/p')
echo "via=$i"
if [ -z "$i" ] || printf '%s\n' "$i" | grep -qxE "$o"; then
  echo "path=skipped"
elif command -v tracepath >/dev/null 2>&1; then tracepath -4 -n -m 3 "$a"
elif command -v traceroute >/dev/null 2>&1; then
  traceroute -4 -n -m 3 -q 1 -w 2 "$a"
else echo "path=no-tool"; fi
```

FreeBSD and macOS, whose `traceroute` is IPv4 only and takes no
`-4`:

```bash
h=<target host>
o='(wg|tailscale|ts|zt|nebula|netmaker|wt|utun|tun)[0-9a-z.-]*'
i=$(route -n get "$h" 2>/dev/null | awk '/interface:/ { print $2 }')
echo "via=$i"
if [ -z "$i" ] || printf '%s\n' "$i" | grep -qxE "$o"; then
  echo "path=skipped"
else traceroute -n -m 3 -q 1 -w 2 "$h" 2>&1; fi
```

- `path=skipped`: the route to the target leaves through an
  overlay, such as an exit node, or there is none. That path
  measures someone else's uplink, so there is no hint.
- A hop that is private (`10.0.0.0/8`, `172.16.0.0/12`,
  `192.168.0.0/16`) or in `100.64.0.0/10`, after the first, is a
  hint that another NAT sits upstream — a router of the user's in
  front of their own, or the provider's CGNAT — and no more:
  providers number their own routers from those ranges too.
- `*` for a hop, BusyBox's `traceroute` refusing to run without
  root, and `path=no-tool` are no hint, never a finding.

## Public DNS view

Run on the **workstation**, not on the server: it
shows what clients see. Use the address-only filters
from `rules/dns-aliases.md` (a bare `dig +short` can
return a CNAME target):

```bash
dig +short A <hostname> | grep -E '^[0-9.]+$'
dig +short AAAA <hostname> | grep ':'
dig +short -x <each public address>
grep '^nameserver' /etc/resolv.conf
resolvectl domain 2>/dev/null
```

`dig` asks the server the `nameserver` line names; on
macOS that is the primary resolver alone, whatever
`scutil --dns` lists for a domain. Where it is
resolved's stub (`127.0.0.53` or `127.0.0.54`),
resolved sends a name under a domain the last line
lists, routing (`~`) or search, to that link's
server, and a local forwarder such as dnsmasq, or a
mesh VPN's resolver such as `100.100.100.100`, can
split the same way. An answer that came through such
a route is that network's view, not the public one:
record it as such.

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

