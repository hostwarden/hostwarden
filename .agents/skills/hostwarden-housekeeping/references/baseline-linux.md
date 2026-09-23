# Baseline Checks — Linux

Run these on every Linux server.

The commands below are the family defaults. Where the loaded OS file
covers a check — its Package Manager, Automatic Security Updates,
Firewall or Updates section — its commands and expectations win, at
the same severities: a mechanism the OS file says is not expected is
not a finding.

On Alpine, the checks without an **Alpine** variant below run
unchanged; the others would fail on OpenRC or busybox
(`rules/os/alpine.md` → Service Manager, `rules/busybox.md`).
Run `rc-status -a` and `rc-status --crashed` once, in the first
call: failed services and time sync read from that output.

**Containers.** In a container, NTP / Time Sync, Kernel: Running
vs Installed, Livepatch, needrestart's kernel lines and CPU
Microcode check what the host owns
(`rules/system-containers.md` → What the Host Owns). Memory and
Swap runs only its `/proc/meminfo` line there, and swap is
`SwapTotal` − `SwapFree`, judged against `SwapTotal` by the disk
swap limit.

## Backup Presence

Run the generic "any backup at all?" check — see
`references/backup-presence.md`. It runs on every host,
independent of `memory.md` service entries.

## Disk Usage

```bash
df -h --output=target,pcent,size,used,avail \
  -x tmpfs -x devtmpfs -x overlay
```

**Alpine:**

```bash
df -Ph | grep -vE '^(tmpfs|devtmpfs|overlay|shm|none) '
```

- **WARN** if any filesystem > 85% used
- **CRITICAL** if any filesystem > 95% used

## Memory and Swap

```bash
grep -E '^(MemTotal|MemAvailable|SwapTotal|SwapFree|Zswap|Zswapped):' \
  /proc/meminfo
cat /proc/swaps
f=/proc/spl/kstat/zfs/arcstats
if [ -e $f ]; then grep -E '^(size|c_min) ' $f; fi
for f in /sys/module/zswap/parameters/enabled \
  /sys/block/zram*/comp_algorithm /sys/block/zram*/mm_stat \
  /proc/pressure/memory; do
  if [ -e "$f" ]; then grep -H . "$f"; fi
done
true
```

None of it needs root. `/proc/meminfo` and `/proc/swaps` count in
KiB, `mm_stat` in bytes. A file that is missing prints nothing and
is an answer, not a failed check: no `enabled` line, a kernel
without zswap; no `Zswapped:` line, one older than that counter; no
pressure lines, one without pressure stall information or booted
with it off; no ARC lines, no ZFS. A file that exists but cannot be
read prints `grep`'s error instead: that part did not run, and the
report says so rather than reading it as absent. An unreadable ARC
means available memory is unknown, and the available-memory
finding is not raised on `MemAvailable:` alone. The closing `true`
keeps such an error from failing the call.

Available memory is `MemAvailable:`, plus, on ZFS, the ARC above
its minimum (`size` − `c_min`, in bytes, 0 when negative). The
kernel does not count the ARC as available, though ZFS gives that
part back under pressure, so a ZFS host with a large ARC and
little available memory is normal, not short. Report the ARC's
size beside it.

Report total and available memory, then what swap is made of:

- **Disk swap** — a partition or file in `/proc/swaps`. Pages
  there are on disk, and a task that needs one back waits for it.
- **zram** — a `/dev/zram<n>` line in `/proc/swaps`: a compressed
  block device in RAM. Its `Used` counts pages at their original
  size. The first three `mm_stat` fields are the data stored, its
  compressed size and the RAM the device takes in all; the first
  two give the compression ratio, and the third is already part of
  the used memory above. A zram device missing from `/proc/swaps`
  is unused when its `mm_stat` reads all 0, and otherwise a RAM
  disk for `/tmp` or logs, whose memory is used memory. Neither is
  reported as swap.
- **zswap** — `enabled` reads `Y`: a compressed cache in RAM in
  front of the swap devices. A page it holds still reserves its
  slot on the device behind it. `Zswapped:` is what zswap holds at
  original size, `Zswap:` the RAM that costs. With no swap device,
  zswap does nothing.

Swap in use on disk is the `Used` column of the disk swap devices,
less `Zswapped:`, which also counts pages zswap still holds after
it was turned off. The share on disk is unknown where zswap is on
and the kernel has no `Zswapped:` line, and where zswap is on while
a zram device is swap too, since then `Zswapped:` mixes pages bound
for both: the report says so and raises no disk swap finding.

- **WARN** if available memory < 10% of total
- **WARN** if swap in use on disk > 50% of the disk swap devices'
  size. Never judge the total swap figure: zram and zswap both
  fill it with pages that are still in RAM.
- **WARN** if a zram swap device is > 90% full by either limit —
  `Used` against its `Size`, and, where the fourth `mm_stat` field
  (`mem_limit`) is not 0, the third field against it. Once it
  reaches either, its next pages go to a disk swap device of lower
  priority or to the OOM killer.
- **WARN** if zswap is on while a zram device is swap: zswap
  compresses pages on their way into zram, which compresses them
  again. The fix is `zswap.enabled=0` on the kernel command line.
- **WARN** if `/proc/pressure/memory` shows `some avg300` > 10 or
  `full avg300` > 1: tasks waited on memory for that share of the
  last five minutes.
- **INFO** if a disk swap device has a priority (last column of
  `/proc/swaps`) equal to or above a zram swap device's: the kernel
  fills the higher one first and alternates between equal ones, so
  pages go to disk while zram still has room.

The report's `Swap` line names each kind the host has, used against
size: zram with its algorithm and compression ratio, disk swap with
only what is on disk, and zswap `off` or `on` with what it holds
and the RAM that costs (`zswap 900 MB in 250 MB`).

## System Load

```bash
uptime
nproc
```

Report 1m, 5m, 15m load averages and core count.

- **WARN** if 15-minute load average > core count

## Uptime and Reboot Detection

```bash
uptime -s
last reboot | head -5
```

**Alpine:** `uptime` alone.

Report uptime. If the server rebooted since the last housekeeping
or last session, flag it:

- **INFO** unexpected reboot detected (compare with memory file's
  last known uptime or last connected date)

## Pending Security Updates

Use the distro-specific command from the loaded `rules/os/<family>.md`
file. Report two numbers where cheap: total pending upgrades and
the security-only subset. Do not present the total as "security
updates" — that overstates the finding.

The security-filter syntax varies by distro release. Per "Verify
Before Running" in `AGENTS.md`, verify the flags with `--help` on
the target before relying on them.

**Debian/Ubuntu:**

```bash
apt-get update -qq 2>/dev/null

inst=$(apt-get --just-print upgrade 2>/dev/null | grep "^Inst")

# Total pending upgrades.
printf '%s\n' "$inst" | grep -c .

# Security-only subset: filter the Inst lines for
# security origins (Debian-Security on older
# releases, <codename>-security on newer ones,
# <codename>-security on Ubuntu, and the ESM
# pockets <codename>-apps-security and
# <codename>-infra-security once Pro is attached).
printf '%s\n' "$inst" | grep -ciE "debian-security|[a-z]+-security"
```

**Ubuntu:** fixes that apt cannot see because they wait
on Pro are counted under **Ubuntu Release and Support**.

**RHEL/CentOS/Fedora:**

```bash
# Total pending updates.
dnf check-update --quiet 2>/dev/null \
  | grep -c "^\S"

# Security-only subset.
dnf check-update --security --quiet 2>/dev/null \
  | grep -c "^\S"
```

**SUSE:**

```bash
# Total pending updates.
zypper --quiet list-updates 2>/dev/null \
  | grep -c "^v"

# Security-only subset.
zypper list-patches --category security 2>/dev/null
```

- **WARN** if any security updates are pending
- Report both counts (total pending and security-only)

## Automatic Security Updates

Verify that auto-updates are actually installing security
updates, not just that the unit is enabled. A unit can be
"active" while the daily run does nothing. Real-world failure
modes that the simple `is-active` check misses:

- `/etc/apt/apt.conf.d/20auto-upgrades` missing or zeroed
  out: the timer fires but `APT::Periodic::Unattended-Upgrade`
  is `0`, so the daily run exits after one second.
- `Origins-Pattern` missing the `${distro_codename}-security`
  codename on Debian Trixie or later: `security.debian.org`
  publishes there with the `-security` codename, so security
  packages fail the filter even though
  `apt-cache policy` shows them as the install candidate.
- No `Mail` or `MailReport` set: UA errors never surface.
- Timer alive but only installing third-party packages
  (e.g. `mise`): the Debian security archive is unreachable
  for some reason and nobody knows.

**Debian/Ubuntu:**

```bash
uu=$(apt-config dump 2>/dev/null)

# 1. Package present.
dpkg -l unattended-upgrades 2>/dev/null \
  | grep -q "^ii" && echo "pkg=ok" || echo "pkg=MISSING"

# 2. Daily timer enabled.
systemctl is-enabled apt-daily-upgrade.timer 2>/dev/null

# 3. APT::Periodic actually turns the runs on.
echo "$uu" \
  | grep -E "^APT::Periodic::(Update-Package-Lists|Unattended-Upgrade) "

# 4. The allowed origins cover the codename-security
#    archive. Debian uses Origins-Pattern (Trixie+
#    publishes Codename: <release>-security), Ubuntu
#    uses Allowed-Origins ("<distro>:<codename>-security").
codename=$(. /etc/os-release && echo "$VERSION_CODENAME")
pattern="(codename=|archive=|[an]=|:)(\\\$\{distro_codename\}|${codename})-security"
origins=$(echo "$uu" \
  | grep -E "^Unattended-Upgrade::(Origins-Pattern|Allowed-Origins)::")
echo "origins.count=$(printf '%s\n' "$origins" | grep -c .)"
printf '%s\n' "$origins" | grep -qE "$pattern" \
  && echo "origins=ok" \
  || echo "origins=MISSING ${codename}-security pattern"

# 5. Notification destination set (else failures are silent),
#    and the reboot and kernel clean-up policy.
echo "$uu" | grep -E \
  -e "^Unattended-Upgrade::(Mail|MailReport|MailOnlyOnError) " \
  -e "^Unattended-Upgrade::Automatic-Reboot(-WithUsers|-Time)? " \
  -e "^Unattended-Upgrade::Remove-Unused-Kernel-Packages "

# 6. Recent real activity: did a Debian package upgrade run
#    in the last 30 days, not just no-op runs?
zgrep -h "Pakete, welche aktualisiert werden\|Packages that will be upgraded" \
  /var/log/unattended-upgrades/unattended-upgrades.log* \
  2>/dev/null | tail -5
```

Severity rules (Debian and Ubuntu):

- **CRITICAL** if `20auto-upgrades` is missing or any of its
  values is `0`. The timer fires but does nothing — silent
  total failure.
- **CRITICAL** if `Origins-Pattern` is missing the
  `${distro_codename}-security` entry on Trixie or later.
  Every Debian security update is silently skipped.
- **CRITICAL** (Ubuntu) if `Allowed-Origins` is missing
  `${distro_id}:${distro_codename}-security`, for the
  same reason.
- On Ubuntu, a missing package or a zeroed value keeps
  its severity; `rules/os/debian.md` → Automatic Security
  Updates says how to handle it.
- **WARN** if neither `Mail` nor `MailReport` is set. UA
  errors will be invisible.
- **WARN** if the log shows no package upgrade lines in
  the last 30 days despite the timer running daily. UA is
  alive but accomplishing nothing for the distribution
  archive.
- **INFO** if `Automatic-Reboot-Time` is set to a fixed
  HH:MM: this defers the post-kernel reboot to that time
  the next day, leaving the new userland on the old kernel
  for up to ~24 hours (vulnerability window plus risk of
  userland/kernel ABI mismatch). Prefer the default ("now")
  so reboot follows the apt-daily-upgrade morning slot.

**RHEL/CentOS/Fedora:**

```bash
systemctl is-active dnf-automatic-install.timer 2>/dev/null \
  || systemctl is-active dnf-automatic.timer 2>/dev/null \
  || systemctl is-active yum-cron.service 2>/dev/null
```

**SUSE:**

Check if `zypper-patch` or equivalent auto-update timer is
configured.

- **WARN** if auto-update mechanism is not active

## Firewall Status

Check that the firewall is still active.

**Debian/Ubuntu (ufw):**

```bash
ufw status
```

On Ubuntu, `rules/os/debian.md` → Firewall says how to
word an inactive ufw.

**RHEL/CentOS/Fedora (firewalld):**

```bash
firewall-cmd --state
```

**SUSE (firewalld):**

```bash
firewall-cmd --state
```

**Native nftables** (Debian installs it, with its unit
off; check it when neither ufw nor firewalld is active;
needs root).

The probe and what counts as default deny are the security
skill's, in
`.agents/skills/hostwarden-security/references/firewall-nftables-docker.md`
— run it from there rather than from a copy here. It carries
the reason the grep is shaped the way it is, which a copy
loses the first time someone tidies it: input chains that
fail2ban or Docker add with `policy accept;` are not a
firewall, and neither is the stock config's empty chain.

What housekeeping does with the answer is below.

- **WARN** if ufw or firewalld is active and
  `systemctl is-enabled nftables` says `enabled`: the
  stock `/etc/nftables.conf` flushes their rules.

**Docker** (when `command -v docker` finds it): run the probe
from the same reference → Docker published ports, and judge
it by the severities there. Housekeeping adds one exception: a
port that server memory records as meant to be public is OK.
When the user confirms that for a port, add it there so the
next run stays quiet.

- **CRITICAL** if the firewall is inactive or not installed

## Failed systemd Units

```bash
systemctl --failed --no-pager --no-legend
```

**Alpine:** from the `rc-status` output of the first call.
`rc-status --crashed` exits non-zero when nothing crashed; a
service in the `sysinit`, `boot` or `default` runlevel shown as
`stopped` was enabled but is not running. Services of the runlevel
OpenRC enters to power down are stopped by design.

- **WARN** for each failed unit, crashed service, or enabled
  service that is stopped — list them by name

## NTP / Time Sync

```bash
timedatectl show \
  --property=NTPSynchronized --property=Timezone
```

**Alpine:** the default, busybox `ntpd`, reports no sync state,
so the `rc-status` output of the first call shows whether
`ntpd`, `chronyd` or `openntpd` runs. With chrony,
`chronyc tracking` reports `Leap status : Normal` when
synchronised.

- **WARN** if NTP is not synchronized, or on Alpine if no time
  service runs
- **INFO** if `Timezone` differs from the one an override of
  `rules/baseline.md` → Timezone names, on a server

## Journal

On a server with systemd: whether the journal survives a reboot
(`rules/baseline.md` → Journal). A workstation is not held to it
(`rules/role/workstation.md`).

```bash
systemd-analyze cat-config systemd/journald.conf \
  | grep -E '^Storage='
ls -d /var/log/journal
```

The last `Storage=` wins; none means `auto`. Persistent is
`persistent`, or `auto` with `/var/log/journal` there.

- **WARN** if the journal is not persistent

## Network

Run `rules/network.md` → Quick check, on every host: it needs no
root and no profile.

- A global IPv6 address without a default route → the `no v6
  route` entry in `rules/network.md` → Findings, at its severity
- `/etc/resolv.conf` written by hand where the host has a
  profile that records a manager as its owner → the resolv.conf
  entry there
- Everything as the profile records it, or no profile and
  nothing from the list → OK, one line

A difference is reported, never repaired here, and the full
profile is offered rather than rebuilt inside the inspection.

## Log Anomalies

Check for recent critical events:

```bash
# OOM kills and disk errors in the last 7 days, one pass
journalctl --since "7 days ago" -k \
  --grep="Out of memory|I/O error" --no-pager -q 2>/dev/null \
  | grep -oE "Out of memory|I/O error" | sort | uniq -c

# Failed SSH auth in the last 24 hours
journalctl --since "24 hours ago" -u ssh -u sshd \
  --grep="Failed password" --no-pager -q 2>/dev/null \
  | wc -l
```

**Alpine** (syslog, `rules/os/alpine.md` → Logs, which says who
may read it):

```bash
dmesg | grep -oE "Out of memory|I/O error" | sort | uniq -c
grep -h "Failed password" /var/log/auth.log \
  /var/log/messages 2>/dev/null | wc -l
```

`dmesg` holds only what the kernel buffer still has, and the log
files only what rotation kept: report the counts as recent, not
as 7 days or 24 hours.

- **WARN** if any OOM kills found
- **WARN** if any disk I/O errors found
- **INFO** if > 100 failed SSH logins in 24 hours (may indicate
  brute-force attempts)

## SSL/TLS Certificate Expiry

Only check if the server runs a web server or any TLS-enabled
service (check `memory.md` for nginx, Apache, etc.).

```bash
for cert in /etc/letsencrypt/live/*/cert.pem; do
  [ -r "$cert" ] || { echo "$cert: not readable"; continue; }
  domain=$(basename "$(dirname "$cert")")
  echo "$domain: $(openssl x509 -enddate -noout -in "$cert")"
  openssl x509 -checkend 2592000 -noout -in "$cert" \
    >/dev/null && continue
  if openssl x509 -checkend 604800 -noout -in "$cert" \
    >/dev/null; then echo "$domain: expires within 30 days"
  elif openssl x509 -checkend 0 -noout -in "$cert" \
    >/dev/null; then echo "$domain: expires within 7 days"
  else echo "$domain: expired"; fi
done
```

`-checkend` does the date arithmetic, so the loop needs no GNU
`date` and runs on Alpine's busybox as well; the `notAfter=` line
gives the date the report counts the days to.

If no Let's Encrypt certs exist, try checking via the listening
port:

```bash
echo | openssl s_client -connect localhost:443 \
  -servername "$(hostname -f)" 2>/dev/null \
  | openssl x509 -enddate -noout 2>/dev/null
```

- **CRITICAL** if any cert has expired or expires in < 7 days
- **WARN** if any cert expires in < 30 days

## Kernel: Running vs Installed

Check whether a reboot is needed for a kernel update.

**Debian/Ubuntu:**

```bash
running=$(uname -r)
installed=$(dpkg -l 'linux-image-*' 2>/dev/null \
  | grep "^ii" | awk '{print $2}' \
  | sed 's/linux-image-//' | sort -V | tail -1)
echo "Running: $running"
echo "Installed: $installed"
```

**RHEL/CentOS/Fedora:**

```bash
running=$(uname -r)
installed=$(rpm -q kernel --qf '%{VERSION}-%{RELEASE}.%{ARCH}\n' \
  | sort -V | tail -1)
echo "Running: $running"
echo "Installed: $installed"
```

**Alpine:** a kernel upgrade replaces the running kernel's
modules, so a missing directory means a newer kernel waits for a
reboot:

```bash
uname -r
ls /lib/modules
```

- **INFO** if running kernel differs from installed (reboot
  recommended)

## CPU Microcode

Physical x86 hardware only, decided from the `Virtualization:`
and `Arch:` lines in server memory, which the pipeline has
settled before any check runs. Where one of the three
conditions does not hold, run nothing and report nothing:

- `Virtualization:` names bare metal, whether or not the user
  set it. In a VM the hypervisor loads the microcode and in a
  container the host kernel does.
- `Arch:` names an x86 architecture — `x86_64`, `amd64` or
  `i686`. Every other architecture takes its CPU firmware from
  the platform, and has no microcode package.
- The second part of `Arch:` names Intel or AMD, whatever the
  brand string around it, and picks the package below. Where
  it names neither, report the line as recorded and stop.

Run the package query together with the two commands under
"what the running CPU carries" as one call.

**Debian/Ubuntu:**

```bash
LC_ALL=C apt-cache policy intel-microcode amd64-microcode \
  2>/dev/null | grep -E '^[a-z0-9.-]+:$|Installed:|Candidate:'
```

Expected: `intel-microcode` on Intel, `amd64-microcode` on
AMD. `LC_ALL=C` keeps the labels English: apt translates
`Installed:` and `Candidate:` wherever the host has a locale
for them. `apt-cache` answers from the local lists alone, so a
`Candidate: (none)` on Debian says the package is in no list
this host has, not yet why. Read the configured components
before naming one — the usual cause is that the component
carrying firmware is not among them, and which component that
is follows the release (`rules/os/debian.md` → Package
Sources) — and report an `apt-get update` that failed
earlier as the cause instead, since it leaves the same
answer behind.

**RHEL/CentOS/Fedora:**

```bash
rpm -q microcode_ctl amd-ucode-firmware linux-firmware 2>&1
```

Expected on Intel: `microcode_ctl`. On AMD the microcode ships
with the kernel firmware instead — `amd-ucode-firmware` on
RHEL 10 and Fedora 43 and newer, `linux-firmware` itself on
RHEL 9 and older. There `amd-ucode-firmware` is absent by
design and `rpm` says so; the expectation on such a host is
`linux-firmware` alone.

**SUSE:**

```bash
rpm -q ucode-intel ucode-amd 2>&1
```

Expected: `ucode-intel` on Intel, `ucode-amd` on AMD.

**Alpine:** `apk info -e intel-ucode amd-ucode`, which prints
the names that are installed.

Where the host's own file names no microcode package — another
family, or an appliance with `Base: none` — the check ends
here: an image-based system ships microcode inside the image
and has none to install.

What the running CPU carries:

```bash
grep -m1 '^microcode' /proc/cpuinfo
journalctl -k -b --grep=microcode --no-pager -q | tail -3
```

**Alpine:** `dmesg | grep -i microcode | tail -3` for the
second command. The same form serves a `journalctl` without
`--grep`, which systemd gained in 237: on RHEL and CentOS 7
the option errors out instead of filtering.

Read the log lines by name rather than by the word microcode,
which every x86 kernel prints at least once: `Updated early
from: 0x…` (or `updated early to revision 0x…` before kernel
6.7) is the package's blob reaching the CPU, `revision: 0x… ->
0x…` is a late load, and `Current revision: 0x…` or the
`Microcode Update Driver` banner alone says only that the
driver ran.

- **WARN** if the maker's package is not installed, with the
  revision from `/proc/cpuinfo` beside it: the operating
  system has no way to deliver a CPU errata fix to this host.
  Say that much and no more — the BIOS, UEFI or BMC may carry
  its own microcode updates, and whether this machine gets
  them is a question for its vendor, not something the probe
  answers.
- **INFO** the loaded revision, and whether a line names an
  early or late update. A kernel that names none has not said
  the package is unloaded — before 6.7 it prints nothing when
  the CPU already carries the packaged revision. What does
  follow an install is an initramfs rebuild and a reboot,
  without which the new blob waits.

Sources: https://packages.debian.org/trixie/intel-microcode,
https://packages.debian.org/trixie/amd64-microcode,
https://launchpad.net/ubuntu/noble/+source/intel-microcode,
https://packages.fedoraproject.org/pkgs/microcode_ctl/microcode_ctl/,
https://packages.fedoraproject.org/pkgs/linux-firmware/amd-ucode-firmware/,
https://pkgs.alpinelinux.org/packages?name=*ucode*&branch=edge

## Ubuntu Release and Support

Ubuntu only. The release comes from OS detection; what
the Pro states mean is in `rules/os/debian.md` → Ubuntu
Pro and ESM. Run it as one call; the filters keep a per-package
list out of the report:

```bash
grep -i '^Prompt' /etc/update-manager/release-upgrades \
  2>/dev/null
if command -v pro >/dev/null 2>&1; then
pro status --format json 2>/dev/null | python3 -c '
import json, sys
s = json.load(sys.stdin)
print("attached=%s" % s["attached"])
for v in s["services"]:
    print("%s=%s" % (v["name"], v.get("status", "not-attached")))'
pro security-status 2>/dev/null | grep -i universe
pro api u.pro.packages.updates.v1 2>/dev/null | python3 -c '
import json, sys, collections
a = json.load(sys.stdin)["data"]["attributes"]
print(a["summary"])
print(dict(collections.Counter(
    "%s/%s" % (u["provided_by"], u["status"])
    for u in a["updates"] if u["status"].startswith("pending_"))))'
else
  echo "pro=absent"
fi
canonical-livepatch status 2>/dev/null
```

- Release support as `rules/version-check.md` → OS
  End-of-Life Awareness says, with the ESM date only when
  `esm-infra` is enabled.
- **INFO** attached or not, and which of `esm-infra`,
  `esm-apps` and `livepatch` are enabled. `pro=absent` means
  the Pro client is not installed: report Pro coverage as
  unknown, never as not attached.
- **INFO** the number of installed `universe` packages
  when `esm-apps` is not enabled: they have no guaranteed
  security coverage.
- **WARN** for any `pending_attach` or `pending_enable`
  update, with the count per service: a known fix this
  host cannot install as it is.
- **WARN** if Livepatch's `kernel state` shows a coverage
  end date within 30 days, or is not covered.
- **WARN** if `Prompt` is not `lts` on an LTS release.

## Critical Services: Running Binary vs Installed Package

A package upgrade installs new bytes on disk, but the
already-running master keeps the old binary mapped in
memory until the service is reloaded or restarted. After
a package upgrade, `needrestart` may also defer some
services because restarting them is risky (notably
`docker.service`, `dbus.service`, `getty@*`,
`systemd-logind`). The result: the security fix is
installed but not active, and nothing complains.

**Alpine:** no needrestart; use the manual fallback
below, which works with busybox.

**Debian/Ubuntu** (Ubuntu Server installs needrestart;
on Debian it is an optional package):

```bash
if command -v needrestart >/dev/null 2>&1; then
  needrestart -b -p 2>&1
fi
```

`needrestart -b` (batch) emits machine-readable
`NEEDRESTART-VER`, `NEEDRESTART-KCUR`, `NEEDRESTART-KEXP`,
`NEEDRESTART-KSTA`, `NEEDRESTART-UCSTA`, and one
`NEEDRESTART-SVC:` line per service that wants a restart.
Exit code: 0 = nothing, 1 = containers, 2 = services,
3 = kernel.

Manual fallback (any Linux), works without needrestart by
comparing the on-disk binary's mtime against the running
process's start time via `/proc/<pid>/exe`:

```bash
for svc in nginx postfix sshd postgres docker ollama \
           opendkim dovecot mariadbd; do
  pid=$(pgrep -o -x "$svc" 2>/dev/null) || continue
  bin=$(readlink -f "/proc/$pid/exe" 2>/dev/null) \
    || continue
  bin_time=$(stat -c %Y "$bin" 2>/dev/null) || continue
  proc_time=$(stat -c %Y "/proc/$pid" 2>/dev/null) \
    || continue
  if [ "$bin_time" -gt "$proc_time" ]; then
    echo "$svc: on-disk binary newer than running \
process (pkg installed after process started)"
  fi
done
```

- **WARN** for each critical service whose on-disk binary
  is newer than the running master. The security patch is
  installed but the running process has not picked it up.
- **INFO** if `needrestart` reports kernel or services
  that want a reboot/restart (`NEEDRESTART-KSTA` not 1, or
  any `NEEDRESTART-SVC:` line). For deferred services,
  reload is usually enough; for the kernel, only a reboot
  helps.
