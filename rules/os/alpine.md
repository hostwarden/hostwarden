# Alpine Linux

Rules for Alpine Linux: apk, OpenRC, busybox and musl.

Sources unless noted: the release table,
<https://alpinelinux.org/releases/>, the wiki,
<https://wiki.alpinelinux.org/>, the package definitions in
<https://gitlab.alpinelinux.org/alpine/aports>, and the apk and
OpenRC manuals.

## Package Manager

- Use `apk`. It is non-interactive unless `/etc/apk/interactive`
  exists; when it does, never answer a prompt over SSH.
- Refresh the index before installing or upgrading: `apk update`,
  or `-U` on the command itself (`apk -U upgrade`).
- Dry-run before upgrading: `apk upgrade --simulate` (`-s`), after
  `apk update` — a simulation does not refresh the index.
- List pending upgrades: `apk list --upgradable`. apk has no
  security-only view: report the total, and say no subset exists.
  Which fixes a package carries is on
  <https://security.alpinelinux.org/>.
- Install: `apk add <package>`. Remove: `apk del <package>`.
- `/etc/apk/world` lists what was asked for; `apk add` and
  `apk del` edit it. Never remove `alpine-base` or a `linux-*`
  entry from it.
- `/etc/apk/repositories` lists the repositories, one per line.
- An upgrade that would overwrite an edited file in `/etc` writes
  `<file>.apk-new` next to it instead. List them with
  `update-conf -l` after every upgrade and merge by hand; never
  accept the new version of `passwd`, `shadow`, `doas.conf` or
  `hosts` wholesale.
- `apk upgrade` restarts no service. A daemon keeps running the old
  binary until it is restarted (`rules/service-reload.md`).

### Repositories

- **main** — base system, maintained by the core team, supported
  for about two years per branch.
- **community** — contributed packages, supported only until the
  next stable branch (about six months). A host that uses it has
  to follow the stable branches to keep getting fixes.
- **testing** — edge only, unsupported.

During installation only main is enabled. Enabling community is a
change to `/etc/apk/repositories`: back the file up first
(`rules/backups.md`).

## Stable Branch Only

**Always install packages from the stable `vX.Y` branch the host
runs.** Never add `edge` or `testing` repositories unless there is
absolutely no other option and the user explicitly requests it.

A stable host's `/etc/apk/repositories` names `vX.Y/main` and
`vX.Y/community` with the same `X.Y` as `/etc/alpine-release`.
`latest-stable` in place of the version moves the host to the next
release on an ordinary `apk upgrade`; flag it and ask whether that
is intended.

### Why This Matters

The wiki warns against enabling main or community from a stable
branch and from edge at the same time: it can break the system.
Packages from testing are built for edge only and often need
libraries a stable branch does not carry.

### Preferred Alternatives (in order)

Alpine has no backports. Before reaching for edge or testing:

1. **Upgrade the host to the latest stable branch**, if it is
   behind. It carries newer packages and restores community
   support. Ask first, and follow the release notes.
2. **Upstream project repository or static binary**, installed to
   `/usr/local/` or `/opt/`. Check that the binary is built for
   musl or statically linked: a glibc build does not run.
3. **mise**, for language runtimes. See the `hostwarden-runtimes`
   skill.
4. **Build from source**, into `/usr/local/`.

### Last Resort: One Tagged Package

If none of the above work and the user explicitly confirms, add
the repository **tagged**, so apk uses it only for packages named
with the tag:

```
@testing https://dl-cdn.alpinelinux.org/alpine/edge/testing
```

Then install the one package with the tag: `apk add <package>@testing`.
Run it with `--simulate` first: every dependency the plan takes
from the tagged repository is a finding to show the user before
anything is installed. Check with `apk policy <package>` which
repository each version comes from.

A package from testing receives no security support. Record it in
server memory:

```markdown
- apk-tagged: <package>@testing (reason: <why stable was
  insufficient>)
```

and log it with `logger -t hostwarden`.

### What to Check on Existing Servers

```
cat /etc/alpine-release /etc/apk/repositories
```

- An untagged `edge` line, or one naming a different `vX.Y` than
  the release → **WARN**.
- A tagged `edge` or `testing` line → **INFO**, with the packages
  that use the tag (`grep @ /etc/apk/world`).
- `apk list --orphaned` lists installed packages that no
  repository offers any more; they block upgrades that depend on
  them → **INFO**.

## Version Detection

- `/etc/alpine-release` — the version, e.g. `3.24.1`. The branch
  is its first two parts.
- `/etc/os-release` — `ID=alpine`, `VERSION_ID`, `PRETTY_NAME`.
- **Support period:** `rules/version-check.md` → OS End-of-Life
  Awareness, per branch. On top of it, a branch that is not the
  latest stable while community packages are installed → **INFO**:
  community stops receiving fixes with the next release.

## Firewall

Alpine installs none. What it packages:

- **nftables** (main) — the wiki's documented setup, and what to
  recommend. `rc-service nftables start` loads `/etc/nftables.nft`,
  which includes `/etc/nftables.d/*.nft`; `rc-update add nftables
  boot` keeps it across reboots.
- **awall** (main) — Alpine's own front end, which generates
  iptables rules from the policies in `/etc/awall/`; the
  `iptables` and `ip6tables` services load them at boot
  (<https://gitlab.alpinelinux.org/alpine/awall>).
- **ufw** (community) — works, but carries community's short
  support period.

`awall translate --verify` tests a change. `awall activate` rolls
back unless Return is pressed within 10 seconds, which a
non-interactive SSH call cannot be relied on to do; ask before
`-f`, which skips that. Never run `awall flush` or
`rc-service nftables panic`: both drop every packet, SSH included.

Never add a second manager on top of one that is active
(`rules/service-class-check.md`).

**Critical — the stock ruleset locks you out.** Alpine's
`/etc/nftables.nft` sets the input policy to `drop` and opens no
port but loopback, established connections and ICMP. Starting the
service as shipped cuts the SSH session. Before
`rc-service nftables start`:

1. Read the ports sshd listens on (`AGENTS.md` → Critical Safety
   Rules).
2. Allow each of them in a file under `/etc/nftables.d/`. The
   packaged rule, `/usr/share/nftables.avail/50_sshd.nft` from
   `openssh-nftrules`, opens port 22 only.
3. Test the ruleset: `rc-service nftables checkconfig`.
4. Start it through `rules/ssh-safety-net.md`, with
   `nft flush ruleset` as the revert. Alpine ships no
   `at` and no systemd, so without `at` installed the
   start is the user's, with console access ready.

Discuss all of it with the user first (`rules/firewall-changes.md`).

Checks, for housekeeping and the security audit alike:

```
rc-update show boot default
ufw status verbose
```

A runlevel that lists `nftables` means nftables; one that lists
`iptables` means awall when `/etc/awall/` holds policies, and saved
iptables rules otherwise. Judge default deny for nftables with
`.agents/skills/hostwarden-security/references/firewall-nftables-docker.md`,
for iptables as root with `iptables -S INPUT` and
`ip6tables -S INPUT` (`-P INPUT DROP`, or a final `DROP` or
`REJECT` rule). The nftables service loads the rules and exits, so
`rc-status` may not show it as running: the runlevel entry and the
ruleset count. Neither service in a runlevel and ufw inactive →
**CRITICAL** "No active firewall".

## Automatic Security Updates

Alpine has none built in, and apk cannot select security updates
only. `apk-autoupdate` exists only in edge/testing and is not an
option on a stable host (Stable Branch Only above).

Look for one the user set up — a script under `/etc/periodic/*/`
or a crontab line that runs `apk upgrade`, which busybox `crond`
runs only while its service does:

```
grep -l "apk.*upgrade" /etc/periodic/*/* 2>/dev/null
crontab -l | grep "apk.*upgrade"
rc-service crond status
```

A script name says nothing; only a script or crontab line that
runs `apk upgrade` counts.

- No such job, or `crond` not started → the finding the standing
  expectation in `AGENTS.md` asks for. Present it as a gap Alpine
  ships no mechanism for, not as a broken setup.
- If the user wants one, it upgrades the whole branch, not just
  security fixes, and restarts nothing. Agree on both before
  writing it.

## Service Manager

- OpenRC, started from busybox `init`. There is no `systemctl`.
- Status: `rc-service <service> status`. Overview of the current
  runlevel: `rc-status`. Services that crashed: `rc-status
  --crashed`.
- Start, stop, restart: `rc-service <service> start|stop|restart`.
- Enable at boot: `rc-update add <service> default` (`boot` for
  filesystems, logging and the firewall). Disable:
  `rc-update del <service> <runlevel>`. List: `rc-update show`.
- Scripts live in `/etc/init.d/`, their settings in
  `/etc/conf.d/<service>`. A script owned by a package is replaced
  on upgrade: change the `conf.d` file, not the script.
- **Reload exists only where the script defines it.**
  `rc-service <service> reload` works when the script lists
  `reload` in `extra_started_commands` (nginx, sshd and nftables
  do). Check with `grep extra /etc/init.d/<service>` before
  relying on it. Where a script also has `checkconfig`, that is
  the config test for `rules/service-reload.md`:
  `rc-service <service> checkconfig`.
- **Restart also restarts what depends on the service.** OpenRC
  stops and starts the dependents with it, so the question in
  `rules/service-reload.md` names them. `rc-service --debug`
  shows why a service fails to start.

## Logs

Alpine logs through syslog, to `/var/log/messages`:

- **busybox `syslogd`** (the `syslog` service) by default. It
  rotates at 200 KB and keeps one old file, `messages.0`, so the
  file may cover less than a week on a busy host. With `-C` in
  `SYSLOGD_OPTS` (`/etc/conf.d/syslog`) it writes to a memory
  buffer instead: read it with `logread`. The file is
  `root:wheel`, mode 0640.
- **syslog-ng** or **rsyslog** where installed. Alpine's
  syslog-ng writes `/var/log/messages` as `root:adm` 0640, plus
  `auth.log`, `kern.log` and others; logrotate compresses older
  files.

Kernel messages: `dmesg`.

Hostwarden's journal entries (`rules/changelog.md`) are read back
from there, both tags (`rules/activity-check.md`), in one call
that also shows whether a syslog daemon runs:

```
rc-status -a | grep syslog
if grep -q "^SYSLOGD_OPTS=.*-C" /etc/conf.d/syslog 2>/dev/null
then logread | grep -E "hostwarden|heinzel" | tail -20
elif [ -r /var/log/messages ]; then
  grep -hE "hostwarden|heinzel" /var/log/messages.0 \
    /var/log/messages 2>/dev/null | tail -20
else echo "messages: not readable"; fi
```

This shows the last 20 matches, not a strict 7-day window.
`messages: not readable` means the check has not run: as a user
outside `wheel` (busybox) or `adm` (syslog-ng), run it through
`doas -n` or `sudo -n`, and otherwise tell the user the activity
check could not see the log.

**`logger` succeeds even when nothing is listening.** Busybox
`logger` exits 0 whether or not a syslog daemon runs, and the
entry is lost. When no `rc-status` line shows a syslog daemon as
`started`, log to the local changelog only and tell the user.

## Directory Conventions

- Config files: `/etc/`
- Service scripts: `/etc/init.d/`; their settings:
  `/etc/conf.d/`
- Scripts run by the `local` service: `/etc/local.d/*.start` and
  `*.stop`
- Periodic jobs: `/etc/periodic/{15min,hourly,daily,weekly,monthly}/`
- Crontabs: `/etc/crontabs/<user>` — busybox `crond`'s
- Web roots: `/var/www/`
- nginx: `/etc/nginx/http.d/*.conf` — no `sites-available/`
- Logs: `/var/log/`
- apk: `/etc/apk/repositories`, `/etc/apk/world`,
  `/var/log/apk.log` (from 3.23, apk v3 logs every change
  there)

## Notes

### doas and sudo

Alpine's default is `doas` (main); `sudo` is in community. Probe
the one that is installed (`rules/privilege-escalation.md`).
`doas -n` fails unless the matching rule in `/etc/doas.conf` or
`/etc/doas.d/*.conf` says `nopass`; a `persist` rule does not help
over non-interactive SSH. `doas` takes `-u <user>` and `-s`; it has
no `-i` or `-E`.

### Busybox userland

Most commands are busybox applets, with fewer flags than GNU. Which
ones break common checks, and what to use instead:
`rules/busybox.md`.

### musl

Alpine's C library is musl, not glibc. Binaries built for glibc —
most vendor downloads labelled "Linux x86_64" — do not run, and
fail with a misleading "not found" for the binary itself. Look for
a musl or static build, or an Alpine package.

### Containers are not hosts

- **Alpine in LXC** (on Proxmox VE, among others) is a host to
  administer like any other, with limits: the kernel is the
  hypervisor's, so kernel updates, `sysctl` changes and most
  firewall work happen on the hypervisor. `openrc --sys` prints
  `LXC` there.
- **Alpine as a Docker or Podman image** is not a host. It has no
  init, no sshd and no syslog by design, and it is rebuilt from
  its image rather than administered. If SSH lands in one
  (`/.dockerenv` exists, or `openrc --sys` prints `DOCKER` or
  `PODMAN` where OpenRC is installed at all), tell the user and
  administer the container host instead. Changes belong in the
  image's build.

### Diskless mode

When `/` is a `tmpfs`, Alpine runs from RAM (diskless or data-disk
mode), and every change is lost at the next reboot unless
committed with `lbu commit`. Tell the user before the first change,
and ask before committing.

## Common Pitfalls

- Upgrading to a new branch: back up `/etc/apk/repositories`,
  replace the version in it, `apk update`, `apk add --upgrade
  apk-tools`, then `apk upgrade --available`, simulated first.
  Read the release notes and ask before starting; a new kernel
  needs a reboot, which is the user's call.
- A kernel upgrade removes the running kernel's modules: when
  `ls /lib/modules` has no directory for `uname -r`, the next
  module load fails until the host reboots.
- A service enabled with `rc-update add` but never started is not
  running; `rc-update` does not start it.
