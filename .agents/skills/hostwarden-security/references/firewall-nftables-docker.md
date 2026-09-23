# Firewall: native nftables, legacy rules, Docker

Four checks that `references/firewall.md` points to: a host
that filters with native nftables instead of ufw or
firewalld, one that filters with iptables on the legacy
backend, iptables-legacy rules hidden next to nf_tables, and
ports Docker publishes past any of them. Linux only.

## Native nftables

Needs root or `sudo -n`; `nft` refuses to list for a normal
user. In one call: the loaded OS file's Service Manager → Service
status for `nftables`, its Enabled services listing filtered for
`nftables` and `netfilter-persistent`, and the chains. The grep
keeps every table header and, for each input chain, its name and
`type` line:

```bash
nft list chains | grep -B1 -e ^table -e "hook input"
```

For the service, *active* below is what that Service status says
about `nftables`, and *enabled* is a service the listing shows as
starting at boot.

A packet has to pass every input chain of its family, so one
chain that drops is enough — an `accept` policy in another
table does not undo it. Default deny means one of:

- the input chain has `policy drop;`, or
- it has `policy accept;` but its last rule is an
  unconditional `drop` or `reject`. Check with:

  ```bash
  nft list chain <family> <table> <chain> | tail -3
  ```

A table of family `ip` covers IPv4 only, `ip6` IPv6 only and
`inet` both. Rules added through `iptables` land in `table ip
filter`, those through `ip6tables` in `table ip6 filter`.
Default-deny input chains only in family `ip` are the IPv6 gap
that `references/firewall.md` → IPv6 weighs.

Native nftables is *active* when `nftables.service` is
active or an input chain is default deny. Input chains that
fail2ban, Docker or kube-proxy add with `policy accept;`
filter nothing on their own.

- Not active → not a firewall: **CRITICAL** "No active
  firewall" when ufw, firewalld and iptables without a manager
  are inactive too
- Service active, not default deny → **WARN** "nftables
  input policy is not deny". But if its input chains hold
  no rules at all (Debian's stock `/etc/nftables.conf`),
  nothing is filtered: **CRITICAL** "No active firewall",
  unless another variant drops by default
  (`references/firewall.md` → Linux)
- Default deny, but `nftables.service` inactive and nothing
  enabled reloads it → **WARN** "nftables rules will
  not survive a reboot"
- Default deny, service active → OK

## iptables without a manager

Rules written with `iptables` and restored by a service or a
hook script, with no ufw or firewalld on top. Where `iptables -V`
says `nf_tables`, Native nftables above judges them. Where it
says `legacy`, or names no backend, `nft` shows nothing of them,
and this check reads them. As root, or with `$SUDO` from
`rules/privilege-escalation.md` → Stand-ins for sudo in front of
each read; a family whose `filter` table the proc file does not
list has no rules and is not read, so that nothing loads the
module:

```bash
v=$(iptables -V 2>/dev/null); echo "iptables=${v:-none}"
case $v in
  ''|*nf_tables*) ;;
  *) for f in ip ip6; do
       grep -qx filter /proc/net/${f}_tables_names 2>/dev/null \
         || { echo "$f: no filter table"; continue; }
       r=$(${f}tables -S INPUT) || { echo "$f: unread"; continue; }
       printf '%s\n' "$r" | sed -n -e "1s/^/$f /p" \
         -e "1!{\$s/^/$f last /p;}"
       echo "$f input-rules=$(printf '%s\n' "$r" | grep -c '^-A')"
     done
     for u in netfilter-persistent iptables ip6tables; do
       echo "unit $u=$(systemctl is-enabled "$u" 2>/dev/null)"
     done
     # Each saved rule file's filter INPUT: policy and last rule.
     for s in /etc/iptables/rules* /etc/sysconfig/ip*tables; do
       [ -f "$s" ] || continue
       awk -v s="$s" '/^\*/ { t = $1 }
         t == "*filter" && /^:INPUT / { print s, $1, $2 }
         t == "*filter" && /^(\[[0-9:]+\] )?-A INPUT / { l = $0 }
         END { if (l != "") print s, "last", l }' "$s"
     done
     ls /etc/rc.local /etc/local.d/*.start 2>/dev/null || true ;;
esac
```

The `unit` lines and files are the ones the network probe reads
(`rules/network-probe.md`, Reading F), where OpenRC's runlevels
take the place of the `systemctl` line. `<family>: unread` is a
failed read, never an empty chain.

Default deny for a family is `-P INPUT DROP`, or a last rule
that drops or rejects unconditionally (`-A INPUT -j DROP`,
`-A INPUT -j REJECT …`)
(<https://man7.org/linux/man-pages/man8/iptables.8.html>). A last
rule that jumps to a chain of its own (`-A INPUT -j fw-in`) takes
that chain's verdict: read it with `iptables -S <chain>` and judge
its last rule the same way. The variant is *active* when a
family is default deny; INPUT rules that fail2ban or Docker add
under `-P INPUT ACCEPT` filter nothing on their own.

- Not active, whatever INPUT rules fail2ban or others added →
  not a firewall: **CRITICAL** "No active firewall" when none of
  the four variants drops by default (`references/firewall.md`
  → Linux)
- Default deny, but nothing restores it at boot → **WARN**
  "iptables rules will not survive a reboot". Restored means a
  loader and its source together, for that family: an enabled
  `netfilter-persistent` with `/etc/iptables/rules.v4` or
  `rules.v6`; an enabled `iptables` or `ip6tables` service, or
  runlevel entry, with `/etc/sysconfig/iptables`,
  `/etc/sysconfig/ip6tables` or Alpine's `rules-save` and
  `rules6-save`; a hook line in the host's network profile
  (`rules/network.md`) or an `rc.local` or `/etc/local.d`
  script that loads rules. The source's filter INPUT must be
  default deny as the live one is: a saved file whose policy
  and last rule differ, a unit without its file, or a file
  without an enabled unit restores something else, or
  nothing.
- Default deny in one family only → the IPv6 gap that
  `references/firewall.md` → IPv6 weighs
- Default deny and restored at boot → OK

## Mixed frameworks

On a host where `iptables` writes to nf_tables, rules loaded
through `iptables-legacy` still filter packets, but `nft` and
`iptables` do not show them. `iptables-legacy` loads its
kernel modules on demand, so calling it on a clean host
creates the tables it is meant to look for; the proc files
decide first whether it runs at all. Run as root: the proc
files are readable by root only.

Each family gets its own gate, so a legacy IPv4 table does
not load the IPv6 module:

```bash
iptables -V
if iptables -V 2>/dev/null | grep -q nf_tables; then
  grep -q . /proc/net/ip_tables_names 2>/dev/null &&
    echo "legacy4=$(iptables-legacy -S | grep -vc ^-P)"
  grep -q . /proc/net/ip6_tables_names 2>/dev/null &&
    echo "legacy6=$(ip6tables-legacy -S | grep -vc ^-P)"
fi
```

- Either count > 0 → **WARN** "iptables-legacy rules active
  next to nf_tables, invisible to nft". List them with
  `iptables-legacy -S` and report which tool loads them.
- No count printed, or both 0 → OK

ufw or firewalld active while `nftables` is enabled
→ **WARN** "nftables.service will
flush the firewall's rules": the stock
`/etc/nftables.conf` starts with `flush ruleset`, so every
start, reload or stop of that unit wipes them.

## Docker published ports

Docker rewrites the destination of published ports in the
`nat` table, before packets reach the INPUT chain that ufw
and firewalld filter
(https://docs.docker.com/engine/network/packet-filtering-firewalls/).
`-p 8080:80` is reachable from the internet even behind
`ufw default deny incoming`. Check whenever `command -v
docker` finds it; `docker ps` needs root or the `docker`
group:

```bash
docker info --format '{{.FirewallBackend.Driver}}'
docker ps --format '{{.Names}} {{.Ports}}'
for c in iptables ip6tables; do $c -S DOCKER-USER; done
```

A published port (an entry with `->`) is public unless bound
to `127.0.0.1:` or `[::1]:`. `ss` shows the same ports as
`docker-proxy` (`references/listening-services.md`); report
them once, here.

In `DOCKER-USER`, anything beyond `-N DOCKER-USER` (older
engines add a `-j RETURN` as well) is a user rule; read it
to see which ports and sources it covers.

`docker info` prints `iptables` or `nftables`; an engine
without that field predates the nftables backend. That
backend came with Docker Engine 29, is still experimental
and not available in Swarm mode
(https://docs.docker.com/engine/network/firewall-nftables/).
It has no DOCKER-USER chain; restrictions live in a separate
table with a base chain on Docker's hooks, visible in
`nft list chains`.

- Public port not covered by a DOCKER-USER rule (or its
  nftables equivalent) → **WARN** "Docker publishes
  <container> <port> past the firewall". Suggest binding it
  to `127.0.0.1` behind a reverse proxy, or a DOCKER-USER
  rule that limits the sources.
- All published ports local or restricted → OK
