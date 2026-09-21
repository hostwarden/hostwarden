# Service-Specific Checks

These checks are triggered by services listed in the server's
`memory.md`. Only run checks for services that are actually
present.

## PostgreSQL

Triggered when `memory.md` mentions PostgreSQL.

```bash
pg_isready
sudo -u postgres psql -t -A -c \
  "SELECT datname, pg_size_pretty(pg_database_size(datname))
   FROM pg_database
   WHERE datistemplate = false
   ORDER BY pg_database_size(datname) DESC;"
```

- **CRITICAL** if `pg_isready` reports not accepting connections
- Report database names and sizes

## Backups (autopostgresqlbackup)

Triggered when `memory.md` mentions autopostgresqlbackup or
PostgreSQL backups. (These are *specific* backup checks; the
generic "any backup at all?" presence check lives in
`references/backup-presence.md` and always runs.)

**Check every retention tier separately.** These tools write
`daily/`, `weekly/` and `monthly/` subtrees, each on its own
schedule. A single "newest file anywhere" check is always green
as long as the daily tier runs, so a dead weekly or monthly tier
stays invisible — on one host the monthly tier was dead for five
months behind fresh dailies. Age out each tier against its own
cadence.

Resolve `BACKUPDIR` from the config rather than assuming a path
(`/var/lib/autopostgresqlbackup` is the Debian default;
`/var/backups/postgresql` is *not*). The config is
`/etc/autopostgresqlbackup.conf`, or `/etc/default/
autopostgresqlbackup` — note the script prefers the latter
"compat" file when it exists and then ignores the former.

```bash
CONF=/etc/default/autopostgresqlbackup
[ -f "$CONF" ] || CONF=/etc/autopostgresqlbackup.conf
DEFAULTDIR=/var/lib/autopostgresqlbackup
BACKUPDIR=$(. "$CONF" 2>/dev/null && echo "${BACKUPDIR:-$DEFAULTDIR}")

# Newest dump in EACH tier, with its age in days
for tier in daily weekly monthly; do
  newest=$(find "$BACKUPDIR/$tier" -type f -name '*.sql*' \
    -printf '%T@ %TY-%Tm-%Td %p\n' 2>/dev/null \
    | sort -rn | head -1)
  echo "$tier: ${newest:-NONE}"
done
```

- **WARN** if the newest `daily/` dump is older than 25 hours;
  **CRITICAL** past 48 hours or if the tier is empty.
- **WARN** if the newest `weekly/` dump is older than 8 days;
  **CRITICAL** past 15 days.
- **WARN** if the newest `monthly/` dump is older than 32 days;
  **CRITICAL** past 62 days.
- A tier that exists but whose newest file predates a distro
  major upgrade is the classic signature of this bug — check
  `/var/log/apt/history.log*` for the tool being upgraded around
  that date.

**Known trap — `DOMONTHLY`/`DOWEEKLY` zero-padding.**
autopostgresqlbackup 2.x picks the period with a *string*
compare, `[ "${DNOM}" = "${DOMONTHLY}" ]`, where
`DNOM=$(date '+%d')` is **zero-padded**. So `DOMONTHLY=1` never
matches `01` and monthly backups silently never run; only
`DOMONTHLY="01"` works. Values 10-31 match by accident, and the
weekly gate is unaffected because `date '+%u'` is unpadded. It
fails silently: no error, no mail under
`REPORT_ERRORS_ONLY="yes"`, and daily/weekly keep working. The
Debian 12→13 upgrade (autopostgresqlbackup 1.1 → 2.5) is a
common trigger, because 1.x tolerated the unpadded value. When
this check runs on a v2.x host, read the effective config and
flag any `DOMONTHLY`/`DOWEEKLY` in 1-9 that is not zero-padded,
whether or not the tier looks current.

## Cross-Backup (rsync)

Triggered when `memory.md` mentions cross-backup or rsync backups.

Check the age of the most recent backup pull by looking at the
timestamp of the latest file or log entry. The specific path
depends on the server's backup configuration — check `memory.md`
for details.

- **WARN** if latest pull is older than 25 hours
- **CRITICAL** if older than 48 hours

## Docker

Triggered when `memory.md` mentions Docker.

```bash
docker ps --format \
  "table {{.Names}}\t{{.Status}}\t{{.Ports}}" \
  2>/dev/null
```

- **WARN** for any container not in "Up" state
- Report container names and status

## nginx

Triggered when `memory.md` mentions nginx.

```bash
nginx -t 2>&1
systemctl is-active nginx
```

- **WARN** if config test fails
- **CRITICAL** if nginx is not running

## Ollama

Triggered when `memory.md` mentions Ollama.

```bash
curl -s -o /dev/null -w "%{http_code}" \
  http://localhost:11434/api/tags
```

- **WARN** if API does not respond with 200

## node_exporter

Triggered when `memory.md` mentions node_exporter or Prometheus.

```bash
curl -s -o /dev/null -w "%{http_code}" \
  http://localhost:9100/metrics
```

- **WARN** if metrics endpoint does not respond with 200

## NVIDIA GPU

Triggered when `memory.md` mentions NVIDIA or GPU.

```bash
nvidia-smi \
  --query-gpu=temperature.gpu,utilization.gpu,\
utilization.memory,memory.used,memory.total \
  --format=csv,noheader,nounits 2>/dev/null
```

- **WARN** if GPU temperature > 85°C
- **CRITICAL** if GPU temperature > 95°C
- Report temperature, GPU utilization, memory usage

## MariaDB / MySQL

Triggered when `memory.md` mentions MariaDB or MySQL.

```bash
mysqladmin status 2>/dev/null \
  || mariadb-admin status 2>/dev/null
```

- **CRITICAL** if the database is not responding
- Report uptime and thread count

## WireGuard

Triggered when `memory.md` mentions WireGuard.

```bash
wg show 2>/dev/null
```

Check each peer's latest handshake timestamp.

- **WARN** if any peer's last handshake was > 5 minutes ago (may
  indicate connectivity issues)
- Report interface names and peer handshake ages

## Pi-hole

Triggered when `memory.md` mentions Pi-hole. This covers Pi-hole
v6, the current major version; v6 replaced v5's `setupVars.conf`
and `pihole-FTL.conf` with `/etc/pihole/pihole.toml`, dropped
lighttpd for a web server inside `pihole-FTL`, and removed
`pihole -a`. On a host that still runs v5 (`pihole -v`), report
**WARN** "Pi-hole v5, superseded by v6" and skip the rest — none
of the commands below apply there. Sources: https://docs.pi-hole.net/ftldns/configfile/,
https://github.com/pi-hole/pi-hole (the `pihole` script,
`gravity.sh`, `automated install/basic-install.sh`) and
https://github.com/pi-hole/FTL (`src/config/config.c`).

**Find out how it runs.** Pi-hole is not a distribution package:
`basic-install.sh` puts the `pihole` command in
`/usr/local/bin`, `pihole-FTL` in `/usr/bin`, its scripts in
`/opt/pihole` and its configuration in `/etc/pihole`, and
registers `pihole-FTL.service` under systemd or
`/etc/init.d/pihole-FTL` (OpenRC on Alpine) elsewhere. The
Docker image is `pihole/pihole`.

```bash
command -v pihole pihole-FTL
systemctl is-active pihole-FTL 2>/dev/null \
  || rc-service pihole-FTL status 2>/dev/null
docker ps -a --format '{{.Names}} {{.Image}} {{.Status}}' \
  2>/dev/null | grep -i 'pihole/pihole'
```

In a container, every `pihole` and `pihole-FTL` command below
runs as `docker exec <container> …` instead, and the files under
`/etc/pihole` are the container's.

**Running state and blocking.** Run as root: `pihole status`
reads `/etc/pihole/pihole.toml`, which is `pihole:pihole` mode
0640.

```bash
pihole status
```

It exits 0 even when FTL is down, so read the text, never the
exit code.

- **CRITICAL** if the unit or container is not running, or the
  output says `DNS service is NOT running` or `DNS service is
  NOT listening` — every client using it for DNS has lost name
  resolution
- **WARN** if it says `Pi-hole blocking is disabled`
- Report the port FTL listens on and blocking state

**Version and pending update.** `pihole -v` needs no root. It
prints each component with the latest release the daily
`pihole updatechecker` cron job last saw:
`Core version is vX (Latest: vY)`, likewise Web and FTL. A
container's image version is in `/pihole.docker.tag`.

```bash
pihole -v
docker exec <container> cat /pihole.docker.tag
```

Pi-hole is installed outside the package manager, so it is Tier 1
in `rules/version-check.md`: confirm the latest version with that
file's live lookup against https://github.com/pi-hole/pi-hole/releases,
https://github.com/pi-hole/FTL/releases,
https://github.com/pi-hole/web/releases and, for a container,
https://github.com/pi-hole/docker-pi-hole/releases — the cached
`Latest:` can be a day old.

- **INFO** for each component behind its latest release, with
  the upstream update path: `pihole -up` on a host install; in
  Docker, pulling `pihole/pihole` and recreating the container
  (`pihole -up` refuses to run inside the image —
  https://docs.pi-hole.net/docker/upgrading/). Housekeeping never
  runs either — updating is a separate request.

**Gravity.** `pihole updateGravity`, from `/etc/cron.d/pihole`,
rebuilds the blocklist database once a week. Read its age and
each enabled list's last result from the database as root, with
the SQLite shell built into `pihole-FTL`:

```bash
pihole-FTL sqlite3 -ni /etc/pihole/gravity.db \
  "SELECT property, value FROM info
   WHERE property IN ('updated', 'gravity_restored');
   SELECT id, status, number FROM adlist WHERE enabled = 1;"
```

`updated` is the epoch time of the last successful run; the file
is `/etc/pihole/gravity.db` unless `pihole-FTL --config -q
files.gravity` names another. Leave the `address` column out: a
private list's URL can carry an access token. The `status`
values (https://docs.pi-hole.net/database/domain-database/):
`1` downloaded, `2` unchanged, `3` unavailable and the cached
copy used, `4` unavailable with no cached copy.
`gravity_restored` is set when a run could not build a new
database and fell back to a backup, or to `failed` when no
backup worked.

- **WARN** if `updated` is older than 8 days — the weekly run is
  not completing
- **WARN** if `gravity_restored` is present, or any enabled list
  has status `4`: that list blocks nothing
- **INFO** for lists with status `3`
- Report the gravity age and the number of enabled lists

**Exposure.** Whether DNS or the web interface answers beyond
the LAN, and whether the interface has a password, is read with
the probe in the security skill,
`.agents/skills/hostwarden-security/references/listening-services.md`
→ DNS Resolvers — run it from there, at its severities.

**The password is a secret** (`rules/secrets.md`). Never read a
`webserver.api` key, or run `pihole-FTL --config` without a full
key: `webserver.api.pwhash` and `webserver.api.app_pwhash` are
printed like any other value, and whether a password is set is
answered by the `grep -c` in the security probe. `/etc/pihole/cli_pw` holds a
plain-text password for the local CLI; never read it, and never
run `pihole api`, which sends that password in a `curl` argument.

## AdGuard Home

Triggered when `memory.md` mentions AdGuard Home. Sources:
https://github.com/AdguardTeam/AdGuardHome (README,
`scripts/install.sh`, `internal/home/`, `internal/filtering/`,
`docker/build.Dockerfile`) and its wiki pages Getting-Started,
Configuration and Docker. The wiki marks itself outdated; where
it and the source disagree, the source wins.

**Find out how it runs.** The official `install.sh` puts the
binary and `AdGuardHome.yaml` in `/opt/AdGuardHome` (on macOS
`/Applications/AdGuardHome`), with the filter lists under its
`data/` directory, and registers a service named `AdGuardHome`:
`AdGuardHome.service` under systemd, `/etc/init.d/AdGuardHome`
under OpenRC or SysV, `/usr/local/etc/rc.d/AdGuardHome` on
FreeBSD, `/Library/LaunchDaemons/AdGuardHome.plist` on macOS. The
Snap package is `adguard-home`; the Docker image is
`adguard/adguardhome`, with its configuration in
`/opt/adguardhome/conf` and its data in `/opt/adguardhome/work`.

```bash
command -v AdGuardHome; ls -d /opt/AdGuardHome 2>/dev/null
systemctl is-active AdGuardHome 2>/dev/null \
  || rc-service AdGuardHome status 2>/dev/null
snap list adguard-home 2>/dev/null
docker ps -a --format '{{.Names}} {{.Image}} {{.Status}}' \
  2>/dev/null | grep -i 'adguard/adguardhome'
```

For a container, read the configuration and the filter lists
from the host side of its volumes rather than through
`docker exec`:

```bash
docker inspect -f \
  '{{range .Mounts}}{{.Source}} -> {{.Destination}}{{println}}{{end}}' \
  <container>
```

Where the paths differ from these defaults, record them in
`memory.md`.

**Running state.** The HTTP API needs a login for every status
endpoint, so check the service and DNS itself. AdGuard Home
answers the name `healthcheck.adguardhome.test` with NOERROR and
no records (https://github.com/AdguardTeam/AdGuardHome/wiki/Docker):

```bash
/opt/AdGuardHome/AdGuardHome -s status
dig +time=2 +tries=1 @127.0.0.1 healthcheck.adguardhome.test
```

Use the service manager's state from the probe above where
`-s status` does not apply (Snap, Docker), and `nslookup` where
`dig` is missing. The query comes from `127.0.0.1`, so an
`allowed_clients` list that leaves loopback out refuses it —
check that before calling DNS down.

- **CRITICAL** if the service or container is not running, or
  the query times out or is refused
- Report the service state

**Version and pending update.**

```bash
/opt/AdGuardHome/AdGuardHome --version
```

It prints `AdGuard Home, version vX.Y.Z`; in Docker, run it with
`docker exec <container> /opt/adguardhome/AdGuardHome --version`.
Like Pi-hole it is Tier 1 in `rules/version-check.md`: look up
the latest stable release live at
https://github.com/AdguardTeam/AdGuardHome/releases and ignore
the beta channel.

- **INFO** if a newer stable release exists, with the upstream
  update path: the built-in updater (`AdGuardHome --update`, or
  the web interface) for an `install.sh` install; pulling
  `adguard/adguardhome` and recreating the container for Docker;
  a Snap refresh for the Snap. Docker and Snap run with
  `--no-check-update`, so their web interface offers no update.
  Housekeeping never updates.

**Filter lists.** AdGuard Home refreshes each enabled list every
`filtering.filters_update_interval` hours (default 24) and keeps
it as `data/filters/<id>.txt`. A refresh that fails still resets
the file's modification time (`internal/filtering/filter.go`,
`update`), so a stale file means refreshing has stopped, and a
failure shows only in the log, as an error line
`updating filter`:

```bash
C=/opt/AdGuardHome/AdGuardHome.yaml
grep -A1 'filters_update_interval' "$C"
sed -n '/^filters:/,/^[^ ]/p' "$C" | grep -E 'enabled:|id:'
ls -lt /opt/AdGuardHome/data/filters/
journalctl -u AdGuardHome --since -7d --no-pager 2>/dev/null \
  | grep 'updating filter' | grep -ci error
```

The `sed` keeps only the `enabled` and `id` lines of the
`filters` block and leaves out `url`. In Docker, use
`docker logs --since 168h <container> 2>&1` in place of
`journalctl`; without journald, read the file the `log` section
of `AdGuardHome.yaml` names. Count the lines, never print them:
the line carries the list's URL, which can hold an access token.

- **WARN** if an enabled list's file is older than twice the
  update interval
- **WARN** if refresh errors appear in the last 7 days
- Report the number of enabled lists and the newest file's age

**Exposure.** An instance with no `AdGuardHome.yaml` is still in
its setup wizard, which listens on port 3000 on every interface
and takes its configuration from whoever reaches it first. That,
open DNS and the web interface without a login are read with the
probe in
`.agents/skills/hostwarden-security/references/listening-services.md`
→ DNS Resolvers — run it from there, at its severities.

**The configuration holds secrets** (`rules/secrets.md`).
`AdGuardHome.yaml` carries the `users` password hashes and can
carry the TLS private key inline under `tls.private_key`. Never
`cat` it or print more than the keys the probes name.
