# Baseline Checks — FreeBSD

Run these on every FreeBSD host.

The commands below are the family defaults. Where the loaded OS file
covers a check — its Package Manager, Automatic Security Updates or
Firewall section — its commands and expectations win, at the same
severities.

**Jails.** In a jail, Time Sync and the kernel lines of Kernel
and Userland: Running vs Installed check what the host owns
(`rules/system-containers.md` → What the Host Owns); the
userland lines stay the jail's own.

## Backup Presence

Run the generic "any backup at all?" check — see
`references/backup-presence.md` → FreeBSD Probes. It runs on every
host, independent of `memory.md` service entries.

## Disk Usage

```bash
df -h -t nodevfs,fdescfs,procfs,tmpfs,nullfs
```

- **WARN** if any filesystem > 85% used
- **CRITICAL** if any filesystem > 95% used

On ZFS, `df` shows each dataset against the pool's free space, so
the pool is the number that counts: its fill level, health, errors
and scrub age, and the pool's settings, are
`references/zfs-btrfs.md`. The disks' own health on bare metal is
`references/smart.md`, and whether scrubs and TRIM are scheduled
`references/storage-maintenance.md`.

## Memory and Swap

```bash
sysctl -n hw.physmem hw.pagesize hw.ncpu \
  vm.stats.vm.v_free_count vm.stats.vm.v_inactive_count
sysctl -n kstat.zfs.misc.arcstats.size \
  kstat.zfs.misc.arcstats.c_min 2>/dev/null
swapinfo -h
```

Available memory is free plus inactive pages, times the page size.
On ZFS, add the ARC above its minimum (`size` − `c_min`): the ARC
gives that back under pressure, and a FreeBSD host with a large ARC
and little free memory is normal, not short.

- **WARN** if available memory < 10% of total
- **WARN** if swap usage > 50% of total swap

## Load, Uptime and Reboots

```bash
uptime
last reboot | head -5
```

Report 1m, 5m, 15m load averages against `hw.ncpu` from above, and
the uptime.

- **WARN** if 15-minute load average > core count
- **INFO** unexpected reboot detected (compare with memory file's
  last known uptime or last connected date)

## Kernel and Userland: Running vs Installed

```bash
freebsd-version -kru
```

The order of the three lines is in `rules/os/freebsd.md` →
Version Detection, and so is why a jail runs `freebsd-version -u`
alone.

- **INFO** if the installed kernel differs from the running one:
  a base update was installed and the reboot is still due
- Userland and kernel patch levels differ in either direction on
  an up-to-date host: an advisory may touch only one of them. Only
  the two kernel lines say whether a reboot is due.

## Release Support

Check the userland release against the supported releases on
<https://www.freebsd.org/security/#sup>, with the severities of
`rules/version-check.md` → OS End-of-Life Awareness.
`freebsd-update fetch` below prints its own warning when the
release nears or has passed its end of life.

## Pending Updates

Which tool updates the base system depends on how it was installed:
`rules/os/freebsd.md` → Packaged base or distribution sets says
how to tell.

**Base system, distribution sets** (needs root; downloads the
patches into `/var/db/freebsd-update` without installing them):

```bash
PAGER=cat freebsd-update --not-running-from-cron fetch
```

`No updates needed to update system to …` means current. Otherwise
it lists the files that `freebsd-update install` would change; report
the patch level it would reach, not the file count.

**Packages, and the base system on packaged base** (needs root;
only where `pkg -N` succeeds — without pkg bootstrapped, these would
install it, so report the package checks as not applicable):

```bash
pkg upgrade -n
pkg audit -F
```

`pkg upgrade -n` refreshes the catalogs itself and lists what an
upgrade would change across every enabled repository, `FreeBSD-base`
included on packaged base. `pkg audit` lists installed packages with
a known vulnerability, and is the security-only subset: report both
numbers, and do not present the total as security updates.

- **WARN** if base patches are pending
- **WARN** if `pkg audit` names any vulnerable package — name them
- Report the pending package count on its own line

## Update Notification

What is expected is in `rules/os/freebsd.md` → Automatic Security
Updates: pending updates get noticed, applying them is the user's
decision.

```bash
sh -c "grep -hE 'freebsd-update|pkg (upgrade|audit|version)' \
  /etc/crontab /etc/cron.d/* /usr/local/etc/cron.d/* \
  /var/cron/tabs/* 2>/dev/null" | grep -v '^[[:space:]]*#' \
  | grep -oE 'freebsd-update[^;|&<>]*|pkg (upgrade|audit|version)( -[a-zA-Z]+)?' \
  | sort | uniq -c
grep -hE '^(daily_status_security|security_status_pkgaudit)_enable=' \
  /etc/periodic.conf /etc/periodic.conf.local 2>/dev/null
grep -cE '^root:[[:space:]]*[^[:space:]]' /etc/mail/aliases
```

The `sh -c` expands the globs in the shell that has the rights:
as a normal user with `sudo`, put `sudo -n` in front of `sh`, since
`/var/cron/tabs` is readable by root only. The periodic `pkg audit`
runs as part of the daily security run, and both switches default
to on. periodic reads `periodic.conf.local` after `periodic.conf`,
so for each variable the last line printed wins; a variable not
printed keeps its default, and `NO` in either turns the audit off.

`pkg audit` covers packages, and the base system too on packaged
base. On distribution sets, base patches get noticed only through a
cron job that runs `freebsd-update cron` (or `fetch`).

- **WARN** if nothing checks for package updates: no cron job and
  the periodic `pkg audit` off
- **WARN** on distribution sets without a `freebsd-update` cron
  job: base security patches go unnoticed
- **INFO** if root's mail is not forwarded (the alias count is
  `0`): the periodic reports go unread on the host. The probe
  counts the alias rather than printing it, since a piped alias
  can carry a token.
- **INFO** if a cron job applies updates unattended (a
  `freebsd-update` job that runs `install`, or `pkg upgrade`):
  report it, it is the user's choice

## Firewall Status

Run the status probe in `rules/os/freebsd.md` → Firewall, which
also says which firewalls count.

Whether the ruleset denies incoming traffic by default is the
security audit's question, not this one.

- **CRITICAL** if none of pf, ipfw and IPFilter is running,
  weighed by `rules/baseline.md` → Filtering in front of the
  host
- **WARN** if one runs but its `_enable` variable is not `YES`:
  the firewall is gone after the next reboot

## Failed Services

FreeBSD has no failed state. Ask every enabled rc script for its
Service status instead (`rules/os/freebsd.md` → Service Manager),
defaults included:

```bash
for svc in $(service -e); do
  out=$("$svc" status 2>&1) || case "$out" in
    *Usage:*|*"unknown directive"*) ;;
    *) echo "$svc: $out" ;;
  esac
done
```

A script prints here when its `status` fails; one that answers
with a usage line has no process of its own to check, and the
`case` skips it.

- **WARN** for each enabled service that is not running — list
  them by name

## Time Sync

```bash
sysrc -n ntpd_enable
ntpq -pn 2>/dev/null
```

How to read `ntpq -pn`, and what to ask instead where `chronyd` or
`openntpd` runs, is in `rules/os/freebsd.md` → Mail and Time.

- **WARN** if no time daemon is enabled
- **WARN** if the daemon runs but has no selected peer

## Network

Run `rules/network.md` → Quick check with its FreeBSD lines, and
judge a difference by the entries in `rules/network.md` →
Findings, as `references/baseline-linux.md` → Network does.

## Log Anomalies

Read the logs the loaded OS file's Logs section names — on an
appliance its own files, on plain FreeBSD the current
`/var/log/messages` and its first rotation, which covers days to
weeks depending on the host. Say which window the numbers cover.

```bash
cat /var/log/messages.0 /var/log/messages 2>/dev/null \
  | grep -oiE 'was killed:|CAM status|g_vfs_done|medium error' \
  | sort | uniq -c
```

`was killed:` is a process the kernel killed for lack of memory;
the other three are disk and controller errors. Failed SSH logins
live in `/var/log/auth.log`, readable by root only:

```bash
grep -cE 'Failed (password|keyboard-interactive)|Invalid user' \
  /var/log/auth.log
```

- **WARN** if any process was killed for lack of memory
- **WARN** if any disk or controller error appears — `zpool
  status` above says whether ZFS had to repair anything
- **INFO** if failed SSH logins exceed 100 a day on average over
  the window

## SSL/TLS Certificate Expiry

Only check if the host runs a web server or any TLS-enabled service
(check `memory.md` for nginx, Apache, etc.). certbot keeps its
certificates under `/usr/local/etc/letsencrypt/` on FreeBSD.

```bash
for cert in /usr/local/etc/letsencrypt/live/*/cert.pem; do
  [ -f "$cert" ] || continue
  domain=$(basename "$(dirname "$cert")")
  openssl x509 -enddate -noout -in "$cert"
  if openssl x509 -checkend 2592000 -noout -in "$cert" >/dev/null; then
    :
  elif openssl x509 -checkend 604800 -noout -in "$cert" >/dev/null; then
    echo "$domain: expires within 30 days"
  else
    echo "$domain: expires within 7 days"
  fi
done
```

`-checkend` does the date arithmetic, which FreeBSD's `date` cannot
do with GNU options. Without certbot certificates, ask the listening
port:

```bash
echo | openssl s_client -connect localhost:443 \
  -servername "$(hostname)" 2>/dev/null \
  | openssl x509 -enddate -noout 2>/dev/null
```

- **CRITICAL** if any cert expires in < 7 days
- **WARN** if any cert expires in < 30 days

## Critical Services: Running Binary vs Installed

An update replaces the file on disk while the running daemon keeps
the old one mapped in memory until it restarts. `freebsd-update
install` does not restart base daemons such as `sshd`, and
`pkg upgrade` does not restart the daemons it updates. Compare the
binary's modification time with the process's start:

```bash
now=$(date +%s)
for svc in sshd nginx httpd postgres mysqld dovecot \
           ntpd unbound; do
  pid=$(pgrep -o -x "$svc" 2>/dev/null) || continue
  bin=$(procstat -h -b "$pid" 2>/dev/null | awk '{print $NF}')
  [ -f "$bin" ] || continue
  bin_time=$(stat -f %m "$bin")
  start=$(( now - $(ps -o etimes= -p "$pid") ))
  if [ "$bin_time" -gt "$start" ]; then
    echo "$svc: on-disk binary newer than running process"
  fi
done
```

- **WARN** for each service whose on-disk binary is newer than the
  running process. The fix is installed but not active; a restart
  of that service activates it, a new kernel needs a reboot.
