# Listening Services — Linux, FreeBSD and macOS

Audit all listening TCP/UDP ports and flag services that should
not be exposed to all interfaces.

## Linux

```bash
ss -tulnp 2>/dev/null
```

Root is needed for the `-p` flag (process names). If running
unprivileged, omit `-p`:

```bash
ss -tuln
```

Alpine, without `iproute2-ss`:

```bash
netstat -tulnp 2>/dev/null
```

## FreeBSD

```bash
sockstat -46l
```

`*:<port>` is the `0.0.0.0` case below. What `sockstat` misses
without root is in `rules/os/freebsd.md` → Networking; say so in
the report.

## macOS

Without root, `lsof` sees only the current user's processes; call
the list partial when the fallback ran:

```bash
sudo -n lsof -iTCP -sTCP:LISTEN -P -n 2>/dev/null \
  || { echo "partial: current user only"
       lsof -iTCP -sTCP:LISTEN -P -n 2>/dev/null; }
```

Name the Sharing switch behind a port, not only the port
(`rules/os/macos.md` → Sharing).

## Evaluation

On a firewall appliance, sockets on all interfaces are normal: the
firewall decides what is reachable, and `references/firewall.md`
reports that instead. The database and cache ports below are the
exception: where an interface allows by default, as pfSense's LAN
does (`rules/appliance/pfsense.md` → Replace: Firewall), one of
them on all interfaces stays a **WARN** unless that interface's
rules block its port.

Present results as a table of listening addresses, ports, and
process names (when available).

An address is **public** unless it is in `10.0.0.0/8`,
`172.16.0.0/12`, `192.168.0.0/16`, `100.64.0.0/10`, `127.0.0.0/8`,
`169.254.0.0/16`, `fc00::/7`, `fe80::/10` or `::1`. A listener on
`0.0.0.0` or `[::]` listens on every address the host has.

Flag as **WARN** if any of these well-known database or cache
ports listen on `0.0.0.0` or `::` (all interfaces) instead of
`127.0.0.1` or `::1`:

- 3306 (MySQL/MariaDB)
- 5432 (PostgreSQL)
- 6379 (Redis)
- 27017 (MongoDB)
- 11211 (Memcached)

These services should almost always be bound to localhost only.
If the server's `memory.md` shows a legitimate reason for
external binding (e.g. replication), note it as OK with context.

All other listening services: report them for review, no
automatic severity.

## DNS Resolvers

Run this whenever anything listens on port 53 on an address other
than loopback — Pi-hole, AdGuard Home, unbound, dnsmasq, BIND —
whenever `pihole-FTL` or `AdGuardHome` listens on any port beyond
loopback, which is how an unconfigured AdGuard Home with no DNS
listener yet shows up, whenever `docker ps -a` shows a Pi-hole or
AdGuard Home container, whose listeners belong to Docker (the
`docker` line of the probe in `rules/service-class-check.md` →
Installer and container members), and from the housekeeping
skill's Pi-hole and AdGuard Home checks.
A resolver that answers any address on the internet is an open
resolver: it is used to amplify denial-of-service traffic, and
its operator gets the abuse reports.

Take the port 53 rows from the listener table above — from
housekeeping, run that probe first — and the host's addresses
(`ip addr` on Alpine without `iproute2`, `ifconfig` on macOS):

```bash
ip -br addr
```

Judge each address as in Evaluation above. Behind NAT, what a
router forwards is not visible from the host: say so rather than
calling the resolver unexposed.

Then read who the resolver answers, from its own configuration.

**Pi-hole** (v6, as root; in a container through
`docker exec`):

```bash
pihole-FTL --config -q dns.listeningMode
pihole-FTL --config -q dns.interface
ip route show default
pihole-FTL --config -q webserver.port
pihole-FTL --config -q webserver.acl
pihole-FTL --config -q misc.etc_dnsmasq_d
k='local-service|listen-address|interface|except-interface|auth-server'
sed -nE "/^ *dnsmasq_lines = \[\$/,/^ *\]/s/^ *\"(($k)(=[^\"]*)?)\",?\$/\1/p" \
  /etc/pihole/pihole.toml
grep -cE '^ *pwhash = "[^"]' /etc/pihole/pihole.toml
```

`misc.dnsmasq_lines` can hold a `txt-record=` with a token, so only
the lines that decide who is answered come out of it, as
`rules/dns.md` → Reading a DNS server → Pi-hole reads them.

`dns.listeningMode` writes one dnsmasq line of its own: `LOCAL`,
the default, `local-service`; `ALL` `except-interface=nonexisting`;
`SINGLE` and `BIND` `interface=` with `dns.interface`, or where
that is empty the default route's interface (`dev` on the `default`
line of `ip route show default`); `NONE` none. The dnsmasq lines in
`misc.dnsmasq_lines` and, only while `misc.etc_dnsmasq_d` is `true`, the files
in `/etc/dnsmasq.d` join it in every mode:
read those for `local-service`, `listen-address`, `interface`,
`except-interface` or `auth-server`, and judge them together with
the mode's line (FTL's `src/config/dnsmasq_config.c`).
`local-service` answers only the host's own subnets, and only
where none of the other four is set: dnsmasq ignores it otherwise
(dnsmasq(8)). `interface` and `listen-address` limit it to the
interfaces and addresses they name, and `except-interface` to
every interface it does not name: it answers any origin on each
public address (`ip -br addr` above) that is left, so
`except-interface=lo` restricts nothing, and neither does
`listen-address=0.0.0.0` or `::`, which name every address. With
none of them, it answers any origin on every address. `auth-server`
opens the interface it names as well, but only for its own zones,
authoritatively: no open resolver there. The web interface listens
on `webserver.port`, by default
`80o,443os,[::]:80o,[::]:443os` — every address; `webserver.acl`
empty allows every client. The `grep` counts, and never prints,
the password hash line: `0` means the web interface and API take
no password. Source: https://github.com/pi-hole/FTL,
`src/config/config.c` and `src/api/auth.c`.

**AdGuard Home** (as root; for the Snap, `C` is
`/var/snap/adguard-home/current/AdGuardHome.yaml`, for a
container the file on the host side of its `conf` volume):

```bash
C=/opt/AdGuardHome/AdGuardHome.yaml
ls -l "$C"
grep -E '^http:|^  address:' "$C"
sed -n '/^dns:/,/^[^ ]/p' "$C" | grep -A3 -E \
  '^  (bind_hosts|port|allowed_clients|disallowed_clients):'
sed -n '/^users:/,/^[^ ]/p' "$C" | grep -c 'name:'
```

No config file means the setup wizard is running: it listens on
`0.0.0.0:3000` and configures itself for whoever reaches it
first. `http.address` is the web interface, `dns.bind_hosts`
defaults to `0.0.0.0`, and `allowed_clients` is the only list
that restricts who is answered — unless it is empty or holds a
network that covers everything, such as `0.0.0.0/0` or
`::/0`. `users` with no `name`
line means no login. The `sed` ranges keep the `users` password
hashes and `tls.private_key` out of the output. Source:
https://github.com/AdguardTeam/AdGuardHome, `internal/home/` and
the wiki page Configuration.

Last, check whether the firewall restricts port 53 and the web
ports to the LAN: the rules from `references/firewall.md`, and for
a container the published ports from
`references/firewall-nftables-docker.md`, which Docker routes
past ufw and firewalld.

- **CRITICAL** if port 53 answers any origin (Pi-hole whose
  mode and dnsmasq lines, judged as above, leave a public address
  answering; AdGuard Home without an `allowed_clients` that
  restricts; any other resolver without an access list) on a public
  address that the firewall does not restrict — open resolver
- **CRITICAL** if an AdGuard Home setup wizard is reachable
  beyond loopback
- **CRITICAL** if the web interface has no password or login and
  is reachable on a public address; **WARN** if it has none and
  is reachable from the LAN only
- **WARN** if the web interface is reachable on a public address
  with a password — it belongs behind the firewall, a VPN or a
  `webserver.acl`
- OK with context where machine memory records the exposure as
  intended, as for the databases above
