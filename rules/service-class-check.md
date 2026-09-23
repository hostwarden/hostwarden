# Service Class Conflict Check

Before installing any package, verify that the
install would not add a second member of a service
class already present on the host (for example,
installing Apache when Nginx is already running).
**This check is mandatory — do not skip it.**

This rule complements `rules/port-check.md`. Port
check catches *runtime* binding collisions; this
rule catches the *install-time* case where two
services of the same class land on the same host
and fight for the same role.

## When to Check

- A user asks to install a class-member package
  directly (`apt-get install apache2`).
- A user asks to install a higher-level package
  whose dependencies may include a class member
  (e.g. a webmail suite, a monitoring dashboard,
  a PHP stack).
- A user asks to enable a package already on disk
  that would start a second service in the class.
- Creating a systemd or rc unit that would start a
  class member.
- Running a vendor installer script or a
  `docker run` that starts a class member. Phase 2
  has no dry-run for these; Phase 1 still applies.

**Do not trigger on:**

- Read-only commands (`dpkg -l`, `rpm -qa`,
  `systemctl status`).
- Housekeeping and security-audit runs — they do
  not install software.
- Upgrades of an *already-installed* class member
  to a newer version of the same package.

## Service Classes

- **Web server:** apache2, httpd, nginx, caddy,
  lighttpd
- **Database:** postgresql, mariadb-server,
  mysql-server
- **MTA:** postfix, exim4, sendmail, opensmtpd,
  msmtp-mta, nullmailer, dma. The last three are
  lightweight MTAs that claim `/usr/sbin/sendmail`
  via Debian's alternatives system and play the
  same role as the full servers above.
- **Time sync:** chrony, ntp (provides ntpd),
  openntpd, systemd-timesyncd, and Pi-hole while any
  of `ntp.sync.active`, `ntp.ipv4.active` or
  `ntp.ipv6.active` is `true` — all three by default:
  the first makes FTL set the system clock from
  `pool.ntp.org`, the other two make it answer NTP on
  port 123 (https://github.com/pi-hole/FTL,
  `src/config/config.c`)
- **DNS resolver:** unbound, bind9 (RPM: `bind`),
  dnsmasq, pdns-recursor, knot-resolver,
  systemd-resolved, Pi-hole and AdGuard Home.
  Pi-hole's resolver, `pihole-FTL`, is built on
  dnsmasq (https://docs.pi-hole.net/ftldns/), so a
  host with Pi-hole already runs dnsmasq although no
  `dnsmasq` package is installed.
- **Firewall manager:** ufw, firewalld, and native
  nftables — the last only when the loaded OS file's
  Service Manager → Enabled services shows `nftables`
  enabled (the package sits unused on most Debian
  hosts). Debian's stock
  `/etc/nftables.conf` starts with `flush ruleset`, so
  starting, reloading or stopping that unit wipes
  ufw's or firewalld's rules. Raw `iptables` is a
  backend, not a member. On Alpine, awall is a
  member. FreeBSD's pf and ipfw are in base, no frontend
  packages compete.
- **Container runtime:** docker.io, docker-ce,
  moby-engine, podman, containerd.io

Extensions live in
`memory/custom-rules/service-class-check.md` using
the repo's standard `## Add:`, `## Replace:`, and
`## Remove:` heading prefixes. Per-host overrides
live in `memory/servers/<hostname>/rules.md`.

## Detection Procedure

Run both phases in order. If either phase flags a
class member, halt and apply the prompt from
"If a Conflict Is Found" below.

### Phase 1 — Already-installed probe

For the detected OS, query the package database
for every class member listed above.

**Debian / Ubuntu**

```bash
dpkg-query -W \
  -f='${db:Status-Status} ${Package}\n' \
  apache2 nginx caddy lighttpd httpd \
  postgresql mariadb-server mysql-server \
  postfix exim4 sendmail opensmtpd \
  msmtp-mta nullmailer dma \
  chrony ntp openntpd \
  unbound bind9 dnsmasq pdns-recursor \
  knot-resolver \
  ufw firewalld \
  docker.io docker-ce podman containerd.io \
  2>/dev/null | awk '$1=="installed"{print $2}'
```

Then, for the firewall class, the Enabled services
listing filtered for `nftables`.

**Alpine**

`apk info` lists installed package names; PostgreSQL
carries its major version in the name:

```bash
apk info | grep -x \
  -e apache2 -e nginx -e caddy -e lighttpd \
  -e 'postgresql[0-9]*' -e mariadb \
  -e postfix -e exim -e opensmtpd \
  -e msmtp -e dma \
  -e chrony -e openntpd \
  -e unbound -e bind -e dnsmasq -e pdns-recursor \
  -e knot-resolver \
  -e ufw -e awall -e nftables \
  -e docker -e podman -e containerd
```

Busybox `ntpd`, the default time sync, is no
package: its Service status shows whether it runs.
`nftables` counts as a firewall manager only when the
Enabled services listing shows it.

**RHEL / Fedora / SUSE**

```bash
rpm -q httpd nginx caddy lighttpd \
       postgresql-server mariadb-server \
       postfix exim sendmail opensmtpd \
       msmtp nullmailer \
       chrony ntp openntpd \
       unbound bind dnsmasq pdns-recursor \
       knot-resolver \
       firewalld \
       docker-ce podman moby-engine containerd.io \
       2>/dev/null | grep -v 'is not installed'
```

**FreeBSD**

```bash
pkg info -E 'apache*' 'nginx*' 'caddy*' \
            'postgresql*-server' 'mariadb*-server' \
            'mysql*-server' \
            'postfix*' 'exim*' 'sendmail*' \
            'opensmtpd*' \
            'msmtp*' 'nullmailer*' 'dma*' \
            'chrony*' 'openntpd*' \
            'unbound*' 'bind9*' 'dnsmasq*' \
            'knot-resolver*' \
            'podman*' 'containerd*' \
            2>/dev/null
```

Note: on FreeBSD, `ntpd` and `local_unbound` ship in
base, not as packages — check the Enabled services
listing with `P='ntpd|local_unbound'` as well.

**macOS (Homebrew, best-effort)**

```bash
members=(httpd nginx caddy lighttpd
         postgresql mariadb mysql
         postfix exim opensmtpd msmtp
         chrony unbound bind dnsmasq
         podman containerd)
brew list --formula \
  | grep -Fxf <(printf '%s\n' "${members[@]}")
```

macOS installs are user-scoped rather than
system-wide, so this phase is advisory on macOS.
Still run it; still warn.

### Systemd-provided members

Two class members ship inside systemd itself and are
not visible to the package DB:

- `systemd-timesyncd` (time sync)
- `systemd-resolved` (DNS resolver)

On most Debian/Ubuntu hosts they are present but
only count as a real conflict when the unit is
actually running. Probe the unit state:

```bash
systemctl is-active systemd-timesyncd 2>/dev/null
systemctl is-active systemd-resolved 2>/dev/null
```

Treat the member as "installed" only when the
output is `active`. A unit that is `inactive`,
`masked`, or absent is not a conflict — the user
already disabled it (often when they installed
chrony or unbound the first time).

### Installer and container members

Pi-hole and AdGuard Home are installed by their own
scripts or run as containers, so no package database
lists them. Probe for them on every OS:

```bash
command -v pihole-FTL AdGuardHome
ls -d /etc/pihole /opt/AdGuardHome \
  /Applications/AdGuardHome 2>/dev/null
snap list adguard-home 2>/dev/null
docker ps -a --format '{{.Names}} {{.Image}} {{.Status}}' \
  2>/dev/null | grep -iE 'pihole/pihole|adguard/adguardhome'
```

Any hit is an installed DNS resolver. For Pi-hole,
`pihole-FTL --config -q` on each of the three `ntp`
keys above decides its time sync membership — through
`docker exec` for a container. When they cannot be
read, a stopped container for one, count Pi-hole as a
member: all three are on by default. When Pi-hole is the
existing time sync member, option (b) below means
setting `ntp.sync.active`, `ntp.ipv4.active` and
`ntp.ipv6.active` to `false` — the first stops it
setting the clock, the other two free port 123 for
the new daemon — a change to confirm like any
other, never removing Pi-hole.

### Phase 2 — Pending-install dry-run

Before executing the real install, run the package
manager in simulate mode against the user's
request and scan the resolved plan for class
members. This is the step that catches transitive
pulls — the exact scenario this rule exists for.

**Debian / Ubuntu**

```bash
apt-get install --simulate -y <pkg> 2>/dev/null \
  | awk '/^Inst /{print $2}'
```

Match the resulting package list against the class
table.

**RHEL / Fedora**

```bash
dnf install --assumeno <pkg> 2>&1 \
  | awk '/^ [a-z]/{print $1}'
```

**SUSE**

```bash
zypper --non-interactive install --dry-run <pkg>
```

**Alpine**

```bash
apk update -q && apk add --simulate <pkg>
```

Each `Installing <package> (<version>)` line is one
package of the plan.

**FreeBSD**

```bash
pkg install -n <pkg>
```

**macOS (Homebrew)**

```bash
brew deps --include-build <pkg>
```

Homebrew rarely pulls a full web server as a
transitive dependency, so this is best-effort.

## If a Conflict Is Found

1. **Never run the install.** Stop before any
   state-changing command.
2. Report to the user in one line:
   *"Installing `<requested>` would add
   `<class-member>`, but `<existing-member>` is
   already installed as the host's
   `<class>`."*
3. Present four options:
   - **(a) Keep the existing service.** Look for
     an install variant of the user's target that
     works with the already-installed member
     (e.g. the `-nginx` flavour of a package, or
     a reverse-proxy config that fronts it).
   - **(b) Remove the existing service first.**
     Treat as a destructive action — confirm
     separately, back up its config per
     `rules/backups.md`, and close any ports it
     owned.
   - **(c) Run both side by side.** Hand off to
     `rules/port-check.md` for a non-default port
     or a Unix socket; the new service must not
     bind to the port the existing one uses.
   - **(d) Abort.**
4. **Do not proceed without an explicit choice.**
   Silence, "go ahead", or "do what you think is
   best" all require one more round of
   confirmation — name the option the user is
   picking.

**Option (c) does not apply to every class.** For
classes where only one member can reasonably own
the role on a host, "run both side by side" is not
a real option and must be refused:

- **Time sync** — only one daemon can own the
  system clock. Two running at once either race
  or one silently wins.
- **Firewall manager** — two frontends stomp each
  other's rules and can cut off SSH. Listed in
  AGENTS.md's "Firewall & network" warning for
  exactly this reason.

For those two classes, present only options (a),
(b), and (d).

Log the outcome per `rules/changelog.md`:

```bash
logger -t hostwarden \
  "[<operator> as <unix-user>] Declined <pkg> install on <host>: \
<existing> already serves <class>"
```

or, on acceptance of option (b) or (c):

```bash
logger -t hostwarden \
  "[<operator> as <unix-user>] Added <new> alongside <existing> as <class> \
on <host> (user choice: <option>)"
```

## If Clear

No class member is installed and the dry-run does
not add one, **or** the only class member the
dry-run adds is the one the user explicitly asked
for (no conflict): proceed with the install.

After the install completes, record the canonical
class member in
`memory/servers/<hostname>/memory.md`:

```markdown
- Web server: nginx
- Database: postgresql
- MTA: postfix
- Time sync: chrony
- DNS resolver: unbound
- Firewall manager: ufw
- Container runtime: podman (rootless: alice)
```

For the container runtime, add `(rootful)` or
`(rootless: <owners>)` (`rules/containers.md` →
Detect the Runtime).

If an entry already exists for the class, leave
it; only the rootless owners in parentheses are
kept current. If option (b) replaced the existing member,
update the entry. If option (c) added a second
member, record both on one line with a note:

```markdown
- Web server: nginx (primary), apache2 (on :8080)
```

## Changelog

Log the install decision per `rules/changelog.md`
as shown above under "If a Conflict Is Found". For
the clear path, the regular install log line is
enough — no extra entry is required from this
rule.
