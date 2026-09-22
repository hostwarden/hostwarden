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
  "table {{.Names}}\t{{.Status}}\t{{.Ports}}" 2>&1
```

- **CRITICAL** if the daemon does not answer — that says nothing
  about the containers, never that there are none. Permission
  denied on its socket is not this: the check needs the access
  from `rules/privilege-escalation.md`, or is reported as skipped
- **WARN** for any container not in "Up" state
- Report container names and status

## CasaOS

Triggered when `memory.md` mentions CasaOS, or when the selection
step of the housekeeping skill finds `/etc/casaos` on a Linux host
that is no appliance; record `CasaOS` in `memory.md` then. ZimaOS,
which grew out of CasaOS, never counts: an os-release `ID` of
`zimaos`, quoted or not, or an `Appliance:` line in memory. CasaOS
is IceWhale's web UI and app store on top of an ordinary
distribution, which keeps its family file, package manager,
firewall and updater (https://github.com/IceWhaleTech/CasaOS). What
CasaOS adds is below. As root, in one call:

```bash
casaos -v
systemctl is-active casaos casaos-gateway casaos-message-bus \
  casaos-user-service casaos-local-storage casaos-app-management
grep -E '^port *=' /etc/casaos/gateway.ini
grep -E '^(AppsPath|appstore) *=' /etc/casaos/app-management.conf
docker ps -a --format \
  '{{.Names}}\t{{.Status}}\t{{.Label "com.docker.compose.project.working_dir"}}'
```

The six units are the ones the installer starts
(https://get.casaos.io).

- **WARN** for each unit that is not active: without the gateway
  the web UI is down, without app management the apps cannot be
  changed from it.
- **WARN**: the web UI answers plain HTTP on every address, on the
  gateway's `port`, 80 by default in the installer. The gateway
  listens with an empty host and no TLS
  (https://github.com/IceWhaleTech/CasaOS-Gateway, `main.go`), and
  the CasaOS units set no `User=`, so they run as root (`CasaOS`,
  `build/sysroot/usr/lib/systemd/system/casaos.service`).
  **CRITICAL** if the user says a port forward reaches it from the
  internet.
- **CRITICAL** for a version up to 0.4.15, as `rules/version-check.md`
  rates a known vulnerability: CVE-2025-34171 lets anyone
  who reaches the UI read files and debug data without logging in
  (https://www.vulncheck.com/advisories/casaos-unauthenticated-file-and-debug-data-exposure).
  Name the newest release from
  https://github.com/IceWhaleTech/CasaOS/releases and its date only
  through `rules/version-check.md`, its cooldown included; while no
  release fixes the CVE, that is the finding.
- **INFO** for each `appstore` source outside `IceWhaleTech`: a
  third-party store whose apps run with whatever the compose file
  grants them.
- Report the apps: each App Store app is a compose project in its
  own directory under `AppsPath`, `/var/lib/casaos/apps` by default
  (https://github.com/IceWhaleTech/CasaOS-AppManagement,
  `build/sysroot/etc/casaos/app-management.conf.sample`); the last
  `docker ps` column shows it. Report a container that is not "Up"
  once, here or under Docker.

Hand any change to an app to the user as steps in the CasaOS web
UI, never as `docker` or compose commands: the app service lists
the compose projects Docker reports, and an update from the UI
merges its settings into the store's compose file and applies it
again, recreating the containers
(https://github.com/IceWhaleTech/CasaOS-AppManagement). A change
made beside the UI is lost at the next update or shown wrongly.
Updating CasaOS itself is the UI's Settings → Update, or the
README's script from
`https://get.casaos.io/update` piped into a root shell: ask first,
and name the script.

## Home Assistant

Triggered when `memory.md` mentions Home Assistant. This section
covers Home Assistant on a normal Linux host. On Home Assistant OS,
where `memory.md` records `Appliance: Home Assistant OS`, skip it:
`rules/appliance/haos.md` → Housekeeping and Audits covers that.

`memory.md` records the install type and what the checks need:
the container name, or for Core the systemd unit, the virtual
environment, the config directory and the account it runs as.
Detect only what is missing or no longer matches, and record it:

```bash
command -v docker && docker ps -a \
  --format '{{.Names}}\t{{.Image}}\t{{.Status}}' \
  | grep -i -E 'home-?assistant|hassio_supervisor'
command -v ha
systemctl list-unit-files --type=service --no-legend \
  | grep -i -E 'home-?assistant|hass'
```

No `docker` on the host means no containers: go on with the Core
unit search. A Docker daemon that does not answer is the Docker
section's finding, not an empty list. Where `memory.md` records
Container or Supervised, keep that type, and ask Home Assistant
itself at the URL `memory.md` records, `http://127.0.0.1:8123/`
when it records none:

```bash
curl -sk -m 5 <url>manifest.json | grep -c '"name": *"Home Assistant"'
```

`1` means Home Assistant answers and runs: live restore keeps
containers up while the daemon is down
(https://docs.docker.com/engine/daemon/live-restore/); its
frontend serves that manifest
(https://github.com/home-assistant/core/blob/dev/homeassistant/components/frontend/__init__.py).
Anything else — no answer, a proxy's 502, another service's page
— proves nothing either way: report Home Assistant's state as
unknown, with the daemon named, never as stopped or running. With
nothing recorded, go on with the Core search and say Docker could
not be asked. Permission denied on the Docker socket is different — the
containers are there but unseen, so get the access through
`rules/privilege-escalation.md` or report the check as skipped,
never conclude Core from it.

- **Container** — a container runs a Home Assistant image,
  usually `ghcr.io/home-assistant/home-assistant`, and there is
  no `hassio_supervisor` container. The container name varies;
  take it from the output above, never assume `homeassistant`.
  Another image, such as `lscr.io/linuxserver/homeassistant`, is
  still a Container install; confirm the commands below work in
  it before relying on them.
- **Supervised** — a `hassio_supervisor` container runs, and the
  host has the `ha` CLI. The grep also lists the Supervisor's
  other containers and add-ons; Home Assistant itself is the one
  named `homeassistant`.
- **Core** — no Home Assistant container, and a unit the search
  above found (`hassio-*` units belong to Supervised). Home
  Assistant runs from a Python virtual environment under that
  unit, with neither a Supervisor nor an `ha` CLI. The unit's
  `ExecStart` holds the path to `hass` and its `-c` argument,
  `User=` the account; without `-c`, the config directory is
  `~/.homeassistant` of that account.

Read the running version:

```bash
# Container
docker exec <container> python -m homeassistant --version
# Supervised
ha core info
# Core, as the unit's User=
sudo -u <service-user> <venv>/bin/hass --version
```

`--version` is a flag of Home Assistant's entry point:
https://github.com/home-assistant/core/blob/dev/homeassistant/__main__.py

Run the config check for the install type from
`rules/service-reload.md` → Config Test Before Reload, the same
check that gates a restart the user asks for.

- **CRITICAL** if Home Assistant is not running: its container
  is not "Up" (on Supervised, `homeassistant` or
  `hassio_supervisor`), or
  `systemctl is-active <unit>` fails on Core. Report a stopped
  container here, not again under Docker.
- **WARN** if the config check reports errors; quote them
- Report the running version, and on Container the image tag
  (`stable`, a pinned version, `beta` or `dev`); a newer release
  is named only through `rules/version-check.md`
- **INFO**, once per report, on Supervised and Core: the install
  type is unsupported since Home Assistant 2025.12,
  https://www.home-assistant.io/blog/2025/05/22/deprecating-core-and-supervised-installation-methods-and-32-bit-systems/
  The install method is unsupported, not the version, so this is
  no EOL finding under `rules/version-check.md`. Migrating to
  Home Assistant OS or Container is the user's decision.

## nginx

Triggered when `memory.md` mentions nginx.

```bash
nginx -t 2>&1
systemctl is-active nginx 2>/dev/null \
  || rc-service nginx status 2>/dev/null
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

## Pi-hole and AdGuard Home

Triggered when `memory.md` mentions Pi-hole or AdGuard Home. What
applies to both:

- **Detection:** the probe in `rules/service-class-check.md` →
  Installer and container members. Each section says which of
  its commands go through `docker exec <container>`.
- **Versions:** both are Tier 1 in `rules/version-check.md`, which
  grades the result. Report the update path upstream gives for
  the install type; housekeeping never runs it.
- **Exposure** — open DNS, a reachable setup wizard, a web
  interface without a password — is the probe in
  `.agents/skills/hostwarden-security/references/listening-services.md`
  → DNS Resolvers. Run it from there, at its severities.
- **Secrets** (`rules/secrets.md`): the admin password hash and
  any token in a blocklist URL never reach the output.

## Pi-hole

Pi-hole v6 only (https://docs.pi-hole.net). If `pihole -v` shows
v5, grade it per `rules/version-check.md` and skip the rest. Run
as root, in one call; in a container, send all but the first
command to `docker exec -i <container> sh -s`:

```bash
systemctl is-active pihole-FTL 2>/dev/null \
  || rc-service pihole-FTL status 2>/dev/null
pihole status
pihole -v
G=$(pihole-FTL --config -q files.gravity)
pihole-FTL sqlite3 -ni "$G" \
  "SELECT property, value FROM info
   WHERE property IN ('updated', 'gravity_restored');
   SELECT id, status, number FROM adlist WHERE enabled = 1;"
```

`pihole status` exits 0 even when FTL is down: read the text.
`files.gravity` is where Pi-hole keeps the blocklist database,
read the same way `gravity.sh` reads it.
`pihole -v` prints `Core version is vX (Latest: vY)`, likewise
Web and FTL; `Latest` is up to a day old, so confirm it live at
https://github.com/pi-hole/pi-hole/releases and the FTL and web
repos beside it, and for a container read `/pihole.docker.tag`
against https://github.com/pi-hole/docker-pi-hole/releases.
Update path: `pihole -up` on a host install; in Docker, pull
`pihole/pihole` and recreate the container, since `pihole -up`
refuses to run there (https://docs.pi-hole.net/docker/upgrading/).

Gravity, the blocklist database, is rebuilt weekly from
`/etc/cron.d/pihole`. `updated` is the epoch time of the last
successful run; `gravity_restored` is set when a run fell back to
a backup, or to `failed`. List `status`
(https://docs.pi-hole.net/database/domain-database/): `1`
downloaded, `2` unchanged, `3` unavailable and cached copy used,
`4` unavailable with no copy. The query leaves out `address`,
which can carry a token.

- **CRITICAL** if the unit or container is not running, or
  `pihole status` says `DNS service is NOT running` or `NOT
  listening`
- **WARN** if it says `Pi-hole blocking is disabled`
- **WARN** if `updated` is older than 8 days, `gravity_restored`
  is present, or an enabled list has status `4`
- **INFO** for lists with status `3`
- Report the gravity age and the number of enabled lists

Never run `pihole-FTL --config` without a full key, never read a
`webserver.api` key or `/etc/pihole/cli_pw`, and never run
`pihole api`, which puts that password on a `curl` command line.

## AdGuard Home

Sources: https://github.com/AdguardTeam/AdGuardHome, its source
under `internal/` and the wiki; where the two disagree, the
source wins. `install.sh` installs to `/opt/AdGuardHome`, with
`AdGuardHome.yaml` and a `data/` directory beside the binary
(`/Applications/AdGuardHome` on macOS). Set the three paths by
install type before the call:

- **Snap:** the service runs `AdGuardHome -w $SNAP_DATA`
  (`snap/snap.tmpl.yaml`), so `C` and `D` sit in
  `/var/snap/adguard-home/current`, snapd's `$SNAP_DATA`; run the
  binary as `snap run adguard-home`, which takes the same flags.
- **Docker:** the image runs `/opt/adguardhome/AdGuardHome` with
  the configuration in its `conf` volume and the data in
  `work/data`. Run only the binary through `docker exec`; set `C`
  and `D` to the host side of the volumes, which `docker inspect`
  names, and run everything else on the host.

Record paths that differ in `memory.md`. Run as root, in one
call:

```bash
A=/opt/AdGuardHome; C=$A/AdGuardHome.yaml; D=$A/data
$A/AdGuardHome -s status
$A/AdGuardHome --version
sed -n -e '/^filtering:/,/^[^ ]/p' -e '/^filters:/,/^[^ ]/p' "$C" \
  | grep -E 'filters_update_interval|- enabled:|^ +id:'
sed -n '/^dns:/,/^[^ ]/p' "$C" \
  | grep -A3 -E '^  (bind_hosts|port|allowed_clients):'
ls -lt "$D/filters/"
journalctl -u AdGuardHome --since -7d --no-pager 2>/dev/null \
  | grep 'updating filter' | grep -ci error
```

`-s status` applies to the `install.sh` service; for Snap and
Docker use the state from detection. Then ask DNS itself, on the
host, at an address from `bind_hosts` and on `port`. For a
container that publishes its port 53, take both from where
`docker ps` shows it published. Use `127.0.0.1` wherever the
address is `0.0.0.0`, and `nslookup` where `dig` is missing:

```bash
dig +time=2 +tries=1 -p <port> @<bind-host> \
  healthcheck.adguardhome.test
```

AdGuard Home answers that name with NOERROR and no records
(https://github.com/AdguardTeam/AdGuardHome/wiki/Docker). When
`allowed_clients` is set and does not cover the address the query
comes from, a refusal is the access list working: judge the
service by its state alone.

Compare `--version` with the latest stable release at
https://github.com/AdguardTeam/AdGuardHome/releases. Update path:
the built-in updater (`AdGuardHome --update`, or the web
interface) for `install.sh`; pull `adguard/adguardhome` and
recreate the container for Docker; refresh the Snap. Docker and
Snap run with `--no-check-update`.

Each enabled list is refreshed every `filters_update_interval`
hours (default 24) into `data/filters/<id>.txt`. A failed refresh
still resets the file's time (`internal/filtering/filter.go`,
`update`), so a stale file means refreshing stopped and a failure
shows only as an error line `updating filter` in the log. That
line carries the list URL: count it, never print it. For the
Snap, the unit is `snap.adguard-home.adguard-home`, snapd's
`snap.<snap>.<app>` name for the service. In Docker,
`docker logs --since 168h <container> 2>&1` replaces
`journalctl`; without journald, read the file the `log` section
of `AdGuardHome.yaml` names. Print nothing else from that file:
it holds the `users` password hashes and can hold
`tls.private_key`.

- **CRITICAL** if the service or container is not running, or
  the query times out or is refused
- **WARN** if an enabled list's file is older than twice the
  interval, or refresh errors appear in the last 7 days. An
  interval of `0` turns automatic refresh off: report the list
  ages as **INFO** instead
- Report the number of enabled lists and the newest file's age
