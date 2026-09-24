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
- List pending upgrades: `apk list --upgradeable` (`-u`); apk 3,
  from Alpine 3.23 on, rejects `--upgradable`. apk has no
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
cat /etc/alpine-release
# per line its tag and branch, never the URL, whose user info or
# path can hold a token
t='(@[^[:space:]]+[[:space:]]+)?'; br='edge|latest-stable|v[0-9.]+'
b="s#^[[:space:]]*$t.*/(($br)/[a-z]+)/*[[:space:]]*\$#\\1\\2#p"
sed -nE -e '/^[[:space:]]*(#|$)/d' -e "$b" -e t -e 's/.*/(other)/p' \
  /etc/apk/repositories
```

- An untagged `edge` line, or one naming a different `vX.Y` than
  the release → **WARN**.
- A `latest-stable` line → flag it and ask (Stable Branch
  Only).
- `(other)`: a repository whose path names no branch, a local
  or a vendor's one → **INFO**, for the user to name.
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
3. Start it, and make every later ruleset change, through
   `rules/ssh-safety-net.md`:
   - **check:** the command below, which passes with `rc=0`; an
     error quotes the rule it failed on (`fc`: `rules/secrets.md`
     → Commands That Leak).
     ```
     { rc-service nftables checkconfig 2>&1; echo "rc=$?"; } \
       | sed -E "${fc:?}"
     ```
   - **apply:** `rc-service nftables start`, or `reload` once it
     runs.
   - **revert:** the backups restored, then
     `rc-service nftables reload || nft flush ruleset` where the
     service ran before, or `nft flush ruleset; rc-service nftables
     zap` where it did not. `zap` marks the service stopped without
     running its `stop`, which can save the live ruleset over the
     file (`save_on_stop` in `/etc/conf.d/nftables`).

   `rc-update add` waits for the fresh login. Alpine ships no `at`
   and no systemd, so without `at` installed the change is the
   user's, with console access ready.
   Sources:
   <https://github.com/alpinelinux/aports/blob/master/main/nftables/nftables.initd>,
   <https://github.com/OpenRC/openrc/blob/master/man/openrc-run.8>.

Discuss all of it with the user first (`rules/firewall-changes.md`).

Checks, for housekeeping and the security audit alike (`fc`:
`rules/secrets.md` → Commands That Leak):

```
rc-update show boot default
ufw status verbose | sed -E "${fc:?}"
```

A runlevel that lists `nftables` means nftables; one that lists
`iptables` means awall when `/etc/awall/` holds policies, and saved
iptables rules otherwise. Judge default deny for nftables and for iptables with
`.agents/skills/hostwarden-security/references/firewall-nftables-docker.md`
(Native nftables, iptables without a manager).
The nftables service loads the rules and exits, so
`rc-status` may not show it as running: the runlevel entry and the
ruleset count. Neither service in a runlevel and ufw inactive →
**CRITICAL** "No active firewall", weighed by `rules/baseline.md`
→ Filtering in front of the host.

## Automatic Security Updates

Alpine has none built in, and apk cannot select security updates
only. `apk-autoupdate` exists only in edge/testing and is not an
option on a stable host (Stable Branch Only above).

Look for one the user set up — a script under `/etc/periodic/*/`
or a crontab line that runs `apk upgrade`, which busybox `crond`
runs only while its service does:

```
# apk's own options that make it only simulate
sm="[[:space:]](-[A-Za-z]*s[A-Za-z]*|--simulate(=yes)?)([[:space:]\"']|\$)"
# per periodic script that names it: how many of its apk lines
# simulate, never the lines
for f in $(grep -l "apk.*upgrade" /etc/periodic/*/* 2>/dev/null); do
  a=$(grep 'apk.*upgrade' "$f" | sed -nE 's/.*apk[[:space:]]/ /p')
  echo "$f: $(printf '%s\n' "$a" | grep -cE "$sm") of \
$(printf '%s\n' "$a" | grep -c .) simulate"
done
# per crontab line: the schedule and each command's first word,
# "[apk -s]" after one whose apk only simulates, never the
# arguments
crontab -l | awk -v sm="$sm" '/^[[:space:]]*#/ || !/apk.*upgrade/ { next }
  { l = $0; sub(/^[[:space:]]+/, "", l); k = l ~ /^@/ ? 1 : 5; s = ""
    for (i = 1; i <= k; i++) { match(l, /^[^[:space:]]+[[:space:]]*/)
      s = s substr(l, 1, RLENGTH); l = substr(l, RLENGTH + 1) }
    gsub(/[0-9]*>&[0-9-]*/, "", l); n = split(l, g, /[;&|]+/); c = ""
    for (i = 1; i <= n; i++) { w = g[i]; sub(/^[[:space:](]+/, "", w)
      a = " " w; m = ""
      if (sub(/.*[[:space:]\/"\047]apk[[:space:]]/, " ", a) && a ~ sm)
        m = " [apk -s]"
      sub(/[[:space:]=].*/, "", w)
      if (w != "") c = c (c == "" ? "" : "; ") w m }
    print s c }'
rc-service crond status
```

A script name says nothing; only a script or crontab line that
runs `apk upgrade` counts, and `-s` (`--simulate`) only reports:
`[apk -s]` after a crontab command, a script whose every apk line
simulates.
A crontab line that names it shows as its schedule and the first
word of each command, since the rest can carry a token, such as
a monitoring ping's URL (`rules/secrets.md` → Commands That
Leak). `apk`, or a wrapper that runs one (`nice`, `chronic`,
`timeout`, `sh`), counts; a line whose commands are only others,
such as `logger` or a notifier, may only mention it: ask the
user.

- No such job, or `crond` not started → the finding the standing
  expectation in `AGENTS.md` asks for. Present it as a gap Alpine
  ships no mechanism for, not as a broken setup.
- If the user wants one, it upgrades the whole branch, not just
  security fixes, and restarts nothing. Agree on both before
  writing it.

## Service Manager

- OpenRC, started from busybox `init`. There is no `systemctl`.
- **Enabled services:** `rc-update show sysinit boot default`
  prints each service that starts at boot with the runlevels it
  starts in; the three names keep a custom or shutdown runlevel out,
  since only these start at boot. It reads the runlevel directories
  and is cheap enough for every connection;
  `rc-status` is not, since it writes a dependency cache on the way.
- **Service status:** `rc-service <service> status` prints
  `status: started` and exits 0 while the service runs, 3 when it is
  stopped, and 1 with `does not exist` for an unknown name.
  `status: crashed`, `inactive`, `starting` and `stopping` go to
  stderr, with exit codes 32, 16, 8 and 4, so read both. A script
  that only loads something and exits, such as `nftables`, reads
  `started` once it has run.
- Overview of the current runlevel: `rc-status`. Services that
  crashed: `rc-status --crashed`.
- Start, stop, restart: `rc-service <service> start|stop|restart`.
- Enable at boot: `rc-update add <service> default` (`boot` for
  filesystems, logging and the firewall). Disable:
  `rc-update del <service> <runlevel>`.
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

## sshd

- OpenRC service `sshd`, from `openssh-server-common-openrc`.
  `/etc/conf.d/sshd` can set `cfgfile`, which the script passes as
  `-f`, and `command_args` (`-o`, `-p`); `SSHD_CONFIG` and
  `SSHD_OPTS` are their older names, `SSHD_CONFDIR` moves the
  default directory and `SSHD_BINARY` names the binary.
- Three binaries: `/usr/sbin/sshd`, and `sshd.pam` or `sshd.krb5`
  from their packages. The script starts `sshd.krb5` when the
  configuration turns on Kerberos or GSSAPI authentication,
  `sshd.pam` when it says `UsePAM yes`. Plain `sshd` has no PAM: it
  warns `Unsupported option UsePAM`, succeeds, and prints no
  `usepam` line. So read the configuration with the binary that
  runs, and with no daemon running, with `sshd.pam` where it is
  installed and the configuration says `UsePAM yes`.
- Configuration: `/etc/ssh/sshd_config`, readable by every account,
  which includes `sshd_config.d/*.conf` near its top.
- Auth log: syslog, as Logs below describes — `/var/log/messages`,
  or `/var/log/auth.log` under syslog-ng.
- Checksum of a file: `sha256sum <file>`, which busybox provides.

## Networking

- **Hostname:** `/etc/hostname` holds it for the next boot,
  which `setup-hostname <name>` writes where `alpine-conf` is
  installed, and `hostname -F /etc/hostname` sets the running
  system from it; a change needs both.

## Logs

Alpine logs through syslog, to `/var/log/messages`:

- **busybox `syslogd`** (the `syslog` service) by default. It
  rotates at 200 KB and keeps one old file, `messages.0`, so the
  two files may cover less than a week on a busy host. The file is
  `root:wheel`, mode 0640. With `-C` in `SYSLOGD_OPTS`
  (`/etc/conf.d/syslog`) it writes to a ring buffer in RAM instead,
  which does not survive a reboot: read it with `logread`. The
  buffer holds 16 KB unless `-C<size_kb>` says otherwise, so on a
  busy host it may reach back minutes rather than to the boot:
  the read-back below prints its oldest line.
- **syslog-ng** or **rsyslog** where installed. Alpine's
  syslog-ng writes `/var/log/messages` as `root:adm` 0640, plus
  `auth.log`, `kern.log` and others; logrotate compresses older
  files.

In diskless mode `/var/log` sits on the tmpfs root and does not
survive a reboot either (see Diskless mode below); `df /var/log`
then names `tmpfs`.

Kernel messages: `dmesg`.

**The syslog stream** is every line the host still keeps of the log
`logger` writes to, oldest first. Define it once in a call that
reads it:

```
syslog_stream() {
  if grep -q "^SYSLOGD_OPTS=.*-C" /etc/conf.d/syslog 2>/dev/null
  then logread
  else set -- /var/log/messages.0 /var/log/messages
    [ -e "$1" ] || shift
    cat "$@"
  fi
}
```

It exits non-zero, with the reason on stderr, when it could not read
the log: `logread` without a buffer, or `cat` refused a file.

Hostwarden's journal entries (`rules/changelog.md`) are read back
from it, both tags (`rules/activity-check.md`), in one call that
also shows whether a syslog daemon runs:

```
rc-status -a | grep syslog
syslog_stream | head -1
syslog_stream | grep -E "hostwarden|heinzel" | awk "$C"
date
```

`$C` is the classifier (`rules/activity-check.md` → Sessions and
watchers). The stream is not cut to seven days: the `head -1` line
and `date` bound it (`rules/activity-check.md` → How far back it
reached).
An error from `logread` or `cat` means the check has not run: as a
user outside `wheel` (busybox) or `adm` (syslog-ng), send the call
through `doas -n sh -s` or `sudo -n sh -s`, and otherwise tell the
user the activity check could not see the log.

**`logger` succeeds even when nothing is listening.** Busybox
`logger` exits 0 whether or not a syslog daemon runs, and the
entry is lost. When no `rc-status` line shows a syslog daemon as
`started`, log to the local changelog only and tell the user.

## Privileges

Alpine's default is `doas` (main); `sudo` is in community.
`doas` stands in for sudo (`rules/privilege-escalation.md` →
Stand-ins for sudo). Its probe line goes into the call of that
file's sudo probe:

```
command -v doas && doas -n true && echo doas=ok
```

`doas=ok` → record `- Doas: passwordless`, otherwise
`- Doas: requires password (unusable)`, next to the sudo line.
doas prints no listing, so the probe sees only whether `true` runs:
a `nopass` rule for other commands only reads as unusable, and one
that lets `true` alone run, or a `deny` rule after a `nopass` one,
reads as passwordless. doas has no mixed mode here; a doas refusal
at run time adds `except (refused) <command>` to the Doas line, as
`rules/privilege-escalation.md` → Mixed Mode does for sudo. A doas
refusal is exactly `doas: Authentication required` or
`doas: Operation not permitted`. Any other `doas:` line, such as
`doas: nft: command not found`, is an error of the call, and the
same words without the prefix are the command's own error.

`doas -n` fails unless the matching rule in `/etc/doas.conf` or
`/etc/doas.d/*.conf` says `nopass`; a `persist` rule does not help
over non-interactive SSH. `doas` takes `-u <user>` and `-s`; it has
no `-i` or `-E`.

## Storage Maintenance

Alpine schedules no storage maintenance (`rules/baseline.md` →
Storage Maintenance). busybox `crond` runs the scripts in
`/etc/periodic/{15min,hourly,daily,weekly,monthly}`, and no package
puts a TRIM, RAID check or scrub there
([crontab](https://git.alpinelinux.org/aports/plain/main/alpine-baselayout/crontab)).
A weekly TRIM is a script in `/etc/periodic/weekly/` that runs
`fstrim -a` from the `fstrim` package (util-linux); busybox's
`fstrim` takes one mount point and has no `-a`. `smartd` comes as
an OpenRC service in `smartmontools-openrc`, and the md monitor
as `mdadm` in `mdadm-openrc`.

## Directory Conventions

- Config files: `/etc/`
- Service scripts: `/etc/init.d/`; their settings:
  `/etc/conf.d/`
- Scripts run by the `local` service: `/etc/local.d/*.start` and
  `*.stop`
- Periodic jobs: `/etc/periodic/{15min,hourly,daily,weekly,monthly}/`
- Crontabs: `/etc/crontabs/<user>`, the per-user files busybox
  `crond` reads
- Web roots: `/var/www/`
- nginx: `/etc/nginx/http.d/*.conf` — no `sites-available/`
- Logs: `/var/log/`
- apk: `/etc/apk/repositories`, `/etc/apk/world`,
  `/var/log/apk.log` (from 3.23, apk v3 logs every change
  there)

## Notes

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
