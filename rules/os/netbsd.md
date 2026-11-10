# NetBSD

Rules for NetBSD, every supported release. Which releases those
are is on <https://www.netbsd.org/releases/>
(`rules/version-check.md`).

Sources: the manual pages on <https://man.netbsd.org/> named in
each section, <https://www.netbsd.org/docs/pkgsrc/using.html>,
<https://www.netbsd.org/docs/guide/en/chap-upgrading.html> and
<https://pkgin.net/>.

## Package Manager

The base system is not packaged: it comes as distribution sets
(Automatic Security Updates). Everything else comes from pkgsrc
as binary packages, installed under `/usr/pkg`.

- Use `pkgin` where it is installed (`command -v pkgin`). It is
  itself a package; its repository is the one line in
  `/usr/pkg/etc/pkgin/repositories.conf`. Stick to the repository
  the host already uses: its path names the release and the
  architecture, and a change of either is an upgrade the user
  decides.
- Where it is missing, `pkg_add pkgin` installs it once `PKG_PATH`
  names the binary package directory for this release and
  architecture. Take that URL from the pkgsrc guide, never from
  memory, and ask before installing.
- Update the catalog: `pkgin update`
- Dry-run before upgrading: `pkgin -n upgrade`. `-n` answers no
  and prints what would be done, one line each.
- Non-interactive install: `pkgin -y install <package>`
- Upgrade: `pkgin -y upgrade`
- Search: `pkgin search <pattern>`
- Installed packages: `pkgin list`, or `pkg_info` without pkgin.
- Remove: `pkgin -y remove <package>`.
- Audit for vulnerabilities, as root:
  ```
  pkg_admin fetch-pkg-vulnerabilities
  pkg_admin audit
  ```
  The first refreshes the local list, the second prints every
  installed package the list names. No output from the second
  means none.
- Without pkgin, `pkg_add -u <package>` upgrades one package and
  `pkg_add -n` shows what a call would do without doing it.
- A package's files live under `/usr/pkg`, its configuration
  under `/usr/pkg/etc`. A package that ships an rc script does not
  necessarily put it in `/etc/rc.d`, the one directory `service`
  reads by default (Service Manager): after installing a daemon,
  read what the package printed and `service -l`.
- `/var/db/pkgin/pkg_install-err.log` holds what `pkg_add` and
  `pkg_delete` said during the last pkgin run.

Manual pages: `pkg_add(1)`, `pkg_admin(1)`.

## Version Detection

- Release: `uname -r`
- Machine and CPU architecture: `uname -m`, `uname -p`. The two
  differ on some ports, and the package repository goes by
  `uname -p`.
- Kernel build: `sysctl -n kern.version`
- Hardware: `sysctl hw.model hw.ncpu hw.physmem64`
- NetBSD has no `/etc/os-release`, and the first probe's
  `freebsd-version` and `sw_vers` lines print errors here.
- Nothing on the host marks a pending reboot. A kernel that an
  upgrade replaced runs only after one, so the session that
  upgraded the base system says so in the host's memory.

## Firewall

- **Expected:** NPF, part of the base system. Config:
  `/etc/npf.conf`; control: `npfctl`, as root. The rc variables
  `pf` and `ipfilter` exist too: where one of them is `YES`, that
  one is the firewall, and NPF is not added on top
  (`rules/service-class-check.md`).
- Whether it filters, and whether it survives a reboot:
  ```
  npfctl show | sed -E "${fc:?}"
  grep -E '^(npf|pf|ipfilter)=' /etc/rc.conf
  ```
  (`fc`: `rules/secrets.md` → Commands That Leak.) `npfctl show`
  prints the state and the loaded configuration, in a syntax that
  need not match `npf.conf`. Without root it fails: the firewall
  is then unknown, not off, and none may be reported as missing.
  NPF that filters while `/etc/rc.conf` has no `npf=YES` is gone
  after the next reboot; `/etc/defaults/rc.conf` sets `npf=NO`.
- `npf=YES` loads `/etc/npf.conf` when the network comes up at
  boot.
- Examples to start from are in `/usr/share/examples/npf`.
- **Critical:** a ruleset without a rule that passes SSH locks
  you out. List every port sshd listens on (`AGENTS.md` →
  Critical Safety Rules); the example below passes port 22 only.
- Minimal safe `/etc/npf.conf`:
  ```
  group default {
    block all
    pass final on lo0 all
    pass stateful in final proto tcp to any port 22
    pass in final family inet4 proto udp from any port 67 to any port 68
    pass final family inet6 proto ipv6-icmp all
    pass stateful out final all
  }
  ```
  The last matching rule decides unless a rule says `final`, so
  `block all` comes first. A stateful rule also passes the replies
  of the connection it let in or out. The DHCP line keeps a lease
  renewable, the ICMPv6 line keeps neighbour discovery working:
  without it IPv6 stops within minutes.
- Keep the SSH rule free of an interface. A packet that matches no
  interface group goes to the default group, which every
  configuration must define, so a rule there also covers a login
  that arrives through a tunnel interface (`wg0`, `tun0`). An SSH
  rule in a `group "external" on <interface>` covers that one
  interface only, and what happens to a packet the group does not
  decide is not something to rely on: read `npf.conf(5)` on the
  host before splitting rules across groups.
- Loading or starting NPF over SSH goes through
  `rules/ssh-safety-net.md`.
  - **check:** `npfctl validate /etc/npf.conf`
  - **apply:** `npfctl reload`, which loads `/etc/npf.conf` in one
    step and keeps the tracked connections; then `npfctl start`
    where NPF did not filter before.
  - **revert:** the backed-up `/etc/npf.conf` restored, then
    `npfctl reload` where NPF filtered before, or `npfctl stop`
    where it did not.

  `npf=YES` in `/etc/rc.conf` waits for the fresh login. The
  revert is armed with `at`. The proof that something runs the job
  is cron and a live `atrun` line in root's crontab, as root;
  a commented-out line counts 0 and `grep` then exits 1:
  ```
  pgrep -x cron && crontab -l | grep -cE '^[[:space:]]*[^#[:space:]].*atrun'
  ```
  The stock crontab runs `atrun` every ten minutes, so a revert
  set for five minutes lands five to fifteen minutes later; tell
  the user the longer window. Without that line the change is the
  user's, with console access ready.
- The SSH session that starts NPF was open before NPF tracked
  connections, and a stateful rule matches only the packet that
  opens a connection. Expect that session to hang after
  `npfctl start`: that is what the armed revert and the fresh
  login are for, and the user hears it before the apply.
- After enabling, verify the default: the default group holds a
  `block all`, and no later `pass` without address, port or
  protocol undoes it for incoming traffic.
- Start/stop through rc: `service npf start`, `service npf stop`.

Manual pages: <https://man.netbsd.org/npfctl.8>,
<https://man.netbsd.org/npf.conf.5>.

## Brute-Force Protection

Where the security audit finds a public service that takes a
password (its `references/intrusion-prevention.md`), the
recommendation is the base system's `blocklistd`. Key-only login
and an admin interface behind a VPN come first.

- `blocklistd=YES` in `/etc/rc.conf`, its rules in
  `/etc/blocklistd.conf`, examples in
  `/usr/share/examples/blocklistd`; then `service blocklistd
  start`.
- It blocks through NPF, which needs a `ruleset "blocklistd"` line
  in a group of `/etc/npf.conf`. That is a firewall change:
  Firewall above says how it is made.
- `sshd_config(5)` has no keyword that turns the reporting on or
  off, so there is no line to hand to the user. Whether this
  host's sshd reports shows in the check after a failed login.
- Check, as root:
  ```
  blocklistctl dump -a
  npfctl rule blocklistd list
  ```

Manual pages: <https://man.netbsd.org/blocklistd.8>,
<https://man.netbsd.org/blocklistctl.8>.

## Automatic Security Updates

- **Base system:** NetBSD ships no tool that patches the base
  system in place. A fix arrives with a newer release of the same
  branch, installed as distribution sets: from boot media with
  `sysinst`, or on the running system with `sysupgrade` from
  pkgsrc (`sysutils/sysupgrade`, configured in
  `/usr/pkg/etc/sysupgrade.conf`). `sysupgrade` fetches the kernel
  and the sets, unpacks them and stops for the configuration
  merges; the reboot follows. Both replace the kernel: ask first,
  and treat the reboot as `rules/coordination.md` says. Across a
  major release the kernel and its modules go first, so the
  running kernel is never older than the userland.
- **Packages:** Package Manager above.
- There is no built-in equivalent of `unattended-upgrades`. Flag
  this to the user.
- What is expected is that pending fixes get noticed. `/etc/daily`
  runs every night from root's crontab and runs `/etc/security`,
  which checks the installed packages against the vulnerability
  list (`check_pkg_vulnerabilities=YES` in
  `/etc/defaults/security.conf`). The list itself is refreshed
  only where `/etc/daily.conf` says
  `fetch_pkg_vulnerabilities=YES`; the default leaves it empty.
  Read both:
  ```
  grep -E '^(fetch_pkg_vulnerabilities|run_security)=' \
    /etc/daily.conf /etc/defaults/daily.conf
  grep -E '^check_pkg_vulnerabilities=' \
    /etc/security.conf /etc/defaults/security.conf
  ```
  A file in `/etc` wins over the one in `/etc/defaults`. A host
  with packages and no `fetch_pkg_vulnerabilities=YES` checks
  against a stale list or none: recommend the line.
- The reports are mailed to root, so they reach someone only
  when `/etc/mail/aliases` forwards `root:` to a real address
  (`newaliases` after a change).
- The base system has no such check. Advisories are on
  <https://www.netbsd.org/support/security/>; the release in
  `uname -r` against the releases page is the comparison.
- Unattended upgrades are a **decision for the user**, not a
  default. If the user wants them, warn first: `pkgin -y upgrade`
  upgrades every package, not just the ones with a fix.

Manual pages: <https://man.netbsd.org/daily.conf.5>,
<https://man.netbsd.org/security.conf.5>.

## Service Manager

NetBSD uses `rc.d` scripts and `/etc/rc.conf`. There is no
`sysrc`: a variable is a line in the file, edited as
`rules/backups.md` says.

- Start/stop/restart: `service <name> start|stop|restart`
- Reload, where the script has one: `service <name> reload`
- Run once without enabling: `service <name> onestart`. The `one`
  prefix skips the test of the rc variable and works for the other
  commands as well.
- Enable at boot: `<name>=YES` in `/etc/rc.conf`. `service <name>
  rcvar` prints the variable a script reads.
- Options: `<name>_flags="…"` in `/etc/rc.conf`.
- Defaults are in `/etc/defaults/rc.conf`, which is never edited;
  `/etc/rc.conf` overrides it, and an optional
  `/etc/rc.conf.d/<name>` overrides both for one service.
- **Enabled services:** `service -e` lists the scripts whose
  variable is on, in start order.
- **Service status:** `service <name> status`. A script without a
  process to look for has no `status`.
- All scripts: `service -l`. `service` reads `/etc/rc.d` and what
  `rc_directories` in `/etc/rc.conf` adds.
- `rc_configured=YES` in `/etc/rc.conf` is what lets the host boot
  to multi-user. Never remove the line.

Manual pages: <https://man.netbsd.org/service.8>,
<https://man.netbsd.org/rc.conf.5>,
<https://man.netbsd.org/rc.subr.8>.

## sshd

- The base system's sshd is `/usr/sbin/sshd` with
  `/etc/ssh/sshd_config`; an `Include` without a path is read
  relative to `/etc/ssh`.
- rc script `sshd`, enabled by `sshd=YES`; the default is `NO`.
  `sshd_flags` in `/etc/rc.conf` adds options, where a `-f`, `-o`
  or `-p` can sit.
- The defaults of `sshd_config(5)` here: `PasswordAuthentication
  yes`, `KbdInteractiveAuthentication yes`, `UsePAM no`,
  `PermitRootLogin prohibit-password`. What is in effect is what
  `sshd -T` prints, as root.
- Auth log: `/var/log/authlog`, mode 600, so root reads it.
- Checksum of a file: `sha256 -q <file>`.

Manual page: <https://man.netbsd.org/sshd_config.5>.

## Networking

- Interfaces: `ifconfig -a`; names only: `ifconfig -l`.
- Routes: `route -n show`; the route to one address:
  `route -n get <address>`.
- Listening sockets:
  ```
  sockstat -n -l -p <port>
  ```
  `-p` takes a comma-separated list. Without `-p` it lists every
  listening socket; `-4` and `-6` limit it to one address family.
- Static configuration: `ifconfig_<interface>` in `/etc/rc.conf`,
  or the file `/etc/ifconfig.<interface>`, whose lines are
  `ifconfig` arguments. The default route is `defaultroute` in
  `/etc/rc.conf`, else `/etc/mygate`; for IPv6 `defaultroute6`,
  else `/etc/mygate6`.
- DHCP: `dhcpcd=YES` in `/etc/rc.conf`, configured in
  `/etc/dhcpcd.conf`.
- **Hostname:** `hostname` in `/etc/rc.conf`, else the file
  `/etc/myname`. With neither, dhcpcd sets the name the DHCP
  server gives, and only then. A rename follows
  `rules/host-rename.md`.
- A change to any of these can cut SSH, and this file names no
  command that applies one to a running host and takes it back:
  by `rules/ssh-safety-net.md` the change is the user's, with
  console access ready. Hostwarden prepares the lines.

Manual pages: <https://man.netbsd.org/ifconfig.if.5>,
<https://man.netbsd.org/sockstat.1>,
<https://man.netbsd.org/dhcpcd.8>.

## Logs

NetBSD has no journal. `syslogd` writes plain files, by the stock
`/etc/syslog.conf`:

- `/var/log/messages` — everything from `info` up but
  authentication, cron, mail, kernel and printing
- `/var/log/authlog` — logins and sshd
- `/var/log/cron`, `/var/log/maillog`

`newsyslog` runs every hour from root's crontab and rotates them
by `/etc/newsyslog.conf`: `messages` at 250 KB with ten old files,
`authlog` at 100 KB with five. The old files are compressed.

**The syslog stream** is every line the host still keeps of the log
`logger` writes to, `/var/log/messages`, oldest first. Define it
once in a call that reads it:

```
syslog_stream() {
  for f in $(ls -r /var/log/messages.*.gz 2>/dev/null); do
    gzip -dc "$f" || return
  done
  cat /var/log/messages
}
```

It exits non-zero, with the reason on stderr, when a file could
not be read. `ls -r` sorts `messages.10.gz` between `.2` and
`.1`: on a host that keeps more than ten old files the oldest
lines are out of order, which the count below does not mind.

Hostwarden's journal entries (`rules/changelog.md`) go to syslog and
are read back from it, both tags (`rules/activity-check.md`):

```
syslog_stream | grep -aE "hostwarden|heinzel" | awk "$C"
syslog_stream | head -1
date
```

`$C` is the classifier (`rules/activity-check.md` → Sessions and
watchers). The stream is not cut to seven days: the `head -1` line
and `date` bound it (`rules/activity-check.md` → How far back it
reached). `grep -a` reads the stream as text whatever bytes a line
holds; write journal lines in ASCII, so that they read back the
way they went in.

Manual page: <https://man.netbsd.org/newsyslog.8>.

## Privileges

The base system has neither `sudo` nor `doas`; both are packages,
configured under `/usr/pkg/etc`. What the base system has is `su`,
which lets only members of the group `wheel` become root and asks
for root's password, so it is of no use over non-interactive SSH.

- With `sudo` installed, `rules/privilege-escalation.md` applies
  as written.
- With `doas` installed instead, it stands in for sudo
  (`rules/privilege-escalation.md` → Stand-ins for sudo), which
  has its probe, the line to record and the reading of a refusal.
- With neither, a normal user works unprivileged and root SSH is
  the fallback that file describes. Never install one of them to
  get around that: it is the user's decision.

**PATH.** A non-interactive SSH command may run with a `PATH`
that lacks `/sbin`, `/usr/sbin` and `/usr/pkg/sbin`, where
`npfctl`, `service`, `ifconfig`, `pkg_admin` and `sysctl` live.
Set it at the top of every call, before `LC_ALL=C` matters to
anything:

```
PATH=/sbin:/usr/sbin:/bin:/usr/bin:/usr/pkg/sbin:/usr/pkg/bin
export PATH
```

A "not found" without that line says nothing about the host.

## Storage Maintenance

NetBSD schedules no storage maintenance (`rules/baseline.md` →
Storage Maintenance). What it does on its own: `/etc/daily`
reports a failed RAIDframe component in its nightly mail
(`check_disks=YES` in `/etc/defaults/daily.conf`), which someone
reads only where root's mail is forwarded.

- **ZFS:** no scrub is scheduled. `zpool status -x` names a pool
  with errors, `zpool status` the last scrub. A cron job that runs
  `zpool scrub <pool>` monthly is the recommendation; writing it
  follows `rules/deployed-files.md`.
- **RAIDframe:** status only, as root: `raidctl -s <device>` for
  the components, `raidctl -p <device>` for the parity. Anything
  else `raidctl` does is not run without the user's explicit
  request (`AGENTS.md` → Critical Safety Rules).
- **SMART:** `atactl <device> smart status`, as root, says
  whether SMART is supported and enabled and prints the
  attributes. The base system runs no self-test on a schedule.
- Growing, rebuilding or repairing any of it: `rules/storage.md`.
  The label and partition tools are taboo here as everywhere.

Manual pages: <https://man.netbsd.org/raidctl.8>,
<https://man.netbsd.org/atactl.8>, <https://man.netbsd.org/zpool.8>.

## Directory Conventions

- Base system configuration: `/etc`; its shipped defaults:
  `/etc/defaults`, never edited.
- Packages: `/usr/pkg`, their configuration `/usr/pkg/etc`, their
  daemons `/usr/pkg/sbin`.
- Package database: `/var/db/pkgin`.
- Logs: `/var/log`.
- cron: per-user crontabs, read and written with `crontab`;
  root's holds the system jobs (`atrun`, `newsyslog`,
  `/etc/daily`, `/etc/weekly`). Site additions to the nightly run
  go into `/etc/daily.local`.
- `at` jobs: `/var/at/jobs`.
- Backups the nightly security run keeps: `/var/backups`.

## Housekeeping and Audits

NetBSD runs the `sh -s` bundle, so the skills' references that
are written for `sh` and name no Linux tool run here unchanged,
with the `PATH` line from Privileges at the top. The checks below
take the place of the family baseline, which no reference holds
for NetBSD. A check whose reference has no NetBSD variant is
reported as not covered, never as passed.

### Housekeeping

One call, as root where the host allows it:

```
PATH=/sbin:/usr/sbin:/bin:/usr/bin:/usr/pkg/sbin:/usr/pkg/bin
export PATH LC_ALL=C
uname -r; uptime
df -h -l
swapctl -s -h
sysctl -n hw.physmem64 hw.usermem64
service -e
pkg_admin audit
pkgin -n upgrade | tail -5
```

- A file system over 85% used: **WARN**; over 95%: **CRITICAL**.
- Swap in use beyond half of what is configured: **WARN**.
- Load, from `uptime`, above the CPU count (`sysctl -n hw.ncpu`)
  in all three figures: **WARN**.
- Every line `pkg_admin audit` prints is a vulnerable package:
  **WARN**, **CRITICAL** where the package listens on the network.
  The list's age matters as much (Automatic Security Updates).
- Pending package upgrades: **INFO** with the count.
- A release the releases page no longer lists: **CRITICAL**, as
  `rules/version-check.md` → OS End-of-Life Awareness rates it.
- Automatic Security Updates, Firewall, Storage Maintenance and
  sshd above each name their own check; run them in the same
  call.

### Security audit

The audit's references apply where they are written for `sh`.
What differs here:

- **Firewall:** the checks in Firewall above. NPF not filtering,
  and neither `pf` nor `ipfilter` on: **CRITICAL** "No active
  firewall", weighed by `rules/baseline.md` → Filtering in front
  of the host.
- **Listening services:** `sockstat -n -l`, as root for the
  process names.
- **Accounts:** `/etc/master.passwd` is the file with the
  hashes; it is never printed and never written (`AGENTS.md` →
  Critical Safety Rules). `useradd`, `usermod` and `userdel`
  change accounts (`rules/accounts.md`).
- **Nightly security run:** `run_security` not `YES` in the two
  `daily.conf` files is a **WARN**: it is the base system's own
  check for changed setuid files, accounts and packages.

The fleet audit's probes have no NetBSD variant: it reports a
NetBSD host as not covered.

## Notes

- **No `systemctl`, no `journalctl`, no `ss`, no `ip`.** An
  instruction that names one of them needs its counterpart from
  Service Manager, Logs or Networking above.
- `grep` is GNU grep; `sed -E` and `awk` are the base system's.
- `pgrep` and `pkill` are in base. `-F <pidfile>` limits the
  match to the process a pid file names; `-f` matches the whole
  argument list, which is something else.
- A job that must outlive the SSH session follows
  `rules/ssh-connections.md` → Long jobs.
- The boot configuration is `/boot.cfg` where the port's boot
  loader reads one (`boot.cfg(5)`). It is read, never written
  (`AGENTS.md` → Critical Safety Rules).
- Mail: postfix is in base and on by default; the nightly reports
  rely on it.
- Time: `ntpd=YES` and `ntpdate=YES` in `/etc/rc.conf`; both
  default to `NO`.

## Common Pitfalls

- **A command "not found" that exists.** See PATH under
  Privileges.
- **`npfctl start` without a loaded configuration** enables
  inspection with whatever is loaded, if anything: it does not
  read `/etc/npf.conf`. `npfctl reload` first.
- **`npfctl show` is not the file.** Its syntax may differ from
  `npf.conf`, so a line-by-line `diff` against the file proves
  nothing; compare the rules by meaning.
- **A stale vulnerability list reads as a clean audit.**
  `pkg_admin audit` checks against the local list only.
- **`-y` and `pkgin autoremove`.** `-y` does not confirm it, so a
  non-interactive call stops there. Ask the user, never pipe an
  answer in.
- **An rc script that exists but does not start at boot.** The
  variable in `/etc/rc.conf` is missing, or the script is outside
  the directories `service` reads.
