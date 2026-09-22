# Fleet Audit Probes

The probe commands run on each audited host. All are
read-only. Group them into a single SSH invocation per host
to minimise round-trips:

```bash
ssh <standard options from AGENTS.md → SSH Options> USER@HOST '
<privilege prefix>
echo "###ua###"; <ua probe>
echo "###sshd###"; <sshd probe>
echo "###fw###"; <firewall probe>
echo "###mta###"; <mta probe>
echo "###time###"; <time probe>
echo "###reboot###"; <reboot probe>
'
```

Then split the output on `###<key>###` markers to fill the
comparison table.

The commands below are the family defaults. Where the loaded
OS file covers a category — its Automatic Security Updates,
Firewall or Logs section — its commands and expectations win:
a mechanism it says is not expected is `n/a`, not drift and
not a warning.

On Alpine, the probes without an **Alpine** variant below run
unchanged; the others would fail on OpenRC or busybox
(`rules/os/alpine.md` → Notes). Run `rc-status -a` once, under
its own `###rc###` marker: it lists every runlevel with each
service's state, and the Alpine variants read services and
runlevels from it rather than calling OpenRC again. It also
answers whether a syslog daemon runs, which decides whether the
audit-trail line was written (`rules/os/alpine.md` → Logs).

On macOS, every probe below has a **macOS** variant that
replaces it. The privilege prefix below applies unchanged, but
the root account is disabled on a Mac and sudo usually asks for
a password, so `$SUDO` is often `-`: expect
`unknown(needs-root)` cells rather than a partial row. A key
only the other families have is `n/a (macOS)`.

On FreeBSD, every probe below has a **FreeBSD** variant that
replaces it, and `rules/os/freebsd.md` is the reference for what
the commands print. Open the FreeBSD bundle with the privilege
prefix below, so `$SUDO` is set for every probe, and with
`SVC=$(service -e)`, which the variants grep instead of calling
`service -e` again. On an appliance, `service -e` misses the
services the vendor starts itself: take the time daemon and the
MTA from its `## Housekeeping and Audits` section instead. A key
only the other family has is `n/a (FreeBSD)`
(`references/output-format.md`). Rows and verdicts match the
housekeeping baseline,
`.agents/skills/hostwarden-housekeeping/references/baseline-freebsd.md`.

**Privilege handling.** The sshd and firewall probes need
root. Work out the prefix once, at the top of the bundle —
never an interactive prompt, BatchMode allows none; `doas` is
Alpine's default (`rules/os/alpine.md` → Privileges):

```bash
if [ "$(id -u)" = "0" ]; then
  SUDO=""
elif sudo -n true 2>/dev/null; then
  SUDO="sudo -n"
elif doas -n true 2>/dev/null; then
  SUDO="doas -n"
else
  SUDO="-"
fi
```

(`$SUDO` is intentionally unquoted below so an empty value
disappears; `-` marks "no privilege path".) Without one, a
probe must emit the sentinel `unknown(needs-root)` instead of
a degraded answer — an active ufw must never be reported as
`none` just because the probe lacked permission to read its
state. See `references/output-format.md` for how the sentinel
is rendered and why it is excluded from drift detection.

## 1. Unattended-upgrades (Debian/Ubuntu)

```bash
apt-config dump 2>/dev/null | grep \
  -e '^APT::Periodic::Update-Package-Lists ' \
  -e '^APT::Periodic::Unattended-Upgrade ' \
  -e '^Unattended-Upgrade::Origins-Pattern::' \
  -e '^Unattended-Upgrade::Allowed-Origins::' \
  -e '^Unattended-Upgrade::Mail ' \
  -e '^Unattended-Upgrade::MailReport ' \
  -e '^Unattended-Upgrade::Automatic-Reboot ' \
  -e '^Unattended-Upgrade::Automatic-Reboot-WithUsers ' \
  -e '^Unattended-Upgrade::Automatic-Reboot-Time ' \
  -e '^Unattended-Upgrade::Remove-Unused-Kernel-Packages ' \
  -e '^Unattended-Upgrade::Remove-Unused-Dependencies '
# Ubuntu: Pro coverage decides what the security runs can
# install (rules/os/debian.md → Ubuntu Pro and ESM).
if command -v pro >/dev/null 2>&1; then
  pro status --format json 2>/dev/null | python3 -c '
import json, sys
s = json.load(sys.stdin)
print("pro.attached=%s" % s["attached"])
for v in s["services"]:
    print("pro.%s=%s" % (v["name"], v.get("status", "not-attached")))'
else
  echo "pro=n/a"
fi
```

Row keys to extract for the table:

- `APT::Periodic::Update-Package-Lists`
- `APT::Periodic::Unattended-Upgrade`
- Origins count (number of `Origins-Pattern::` plus
  `Allowed-Origins::` entries)
- Origins cover the security archive (yes/no): Debian
  lists it in `Origins-Pattern` as
  `codename=${distro_codename}-security`, Ubuntu in
  `Allowed-Origins` as
  `${distro_id}:${distro_codename}-security`
- `Mail`
- `MailReport` (or legacy `MailOnlyOnError`)
- `Automatic-Reboot`
- `Automatic-Reboot-WithUsers`
- `Automatic-Reboot-Time` (present/absent — absent is the
  preferred fleet policy)
- `Remove-Unused-Kernel-Packages`
- Pro attached, and esm-infra, esm-apps, livepatch
  enabled (Ubuntu; `n/a` elsewhere or without `pro`)

Highlight as drift: Pro attached on some Ubuntu hosts but
not others, or different ESM services enabled.

**Alpine** has no unattended-upgrades. Run the probe from
`rules/os/alpine.md` → Automatic Security Updates, and take
`crond` from the `###rc###` block. Every key above is
`n/a (Alpine)`; the Alpine rows are

- `apk upgrade job` — the script or crontab line that runs it,
  or `none`
- `crond` — `started` or `stopped`

A root crontab line is what usually runs it, and `crontab -l`
shows only the caller's: run it as `$SUDO crontab -l`. When
`$SUDO` is `-` and no `/etc/periodic` script runs
`apk upgrade`, `apk upgrade job` is `unknown(needs-root)`, not
`none`. The verdict is the OS file's, judged on this host
alone: a warning, worded as a gap Alpine ships no mechanism
for — never raised from an `unknown(needs-root)` cell.

**macOS** has no unattended-upgrades. Software Update's
settings are the policy, read and judged as `rules/os/macos.md`
→ Automatic Security Updates says, the managed file included:

```bash
echo "--local"
defaults read /Library/Preferences/com.apple.SoftwareUpdate 2>&1
echo "--managed"
defaults read "/Library/Managed Preferences/com.apple.SoftwareUpdate" 2>&1
```

The rows are `AutomaticCheckEnabled`, `AutomaticDownload`,
`CriticalUpdateInstall`, `ConfigDataInstall` and
`AutomaticallyInstallMacOSUpdates`, each marked `managed` where
the profile sets it. Hosts whose keys differ are drift.

**FreeBSD** has no unattended-upgrades. Run the probe from the
baseline named above,
`.agents/skills/hostwarden-housekeeping/references/baseline-freebsd.md`
→ Update Notification, with `$SUDO` in front
of its `sh -c` so root's crontab is read; when `$SUDO` is `-`, the
cron row is `unknown(needs-root)`. The rows are

- Update cron job — the command it runs (the probe prints only
  that, never the line), or `none`
- Periodic `pkg audit` — on, or off when either switch reads
  `NO` (the last line per variable wins)
- `freebsd-update` cron job, on distribution sets
- Root mail alias — set or `none` (the probe counts it, never
  prints its target)

Highlight: nothing notices updates (no cron job and the periodic
`pkg audit` off); a cron job that applies updates on some hosts
only.

## 2. sshd effective config

`sshd -T` needs root (it reads host keys). Run it with the
privilege prefix, and emit the sentinel when there is none:

```bash
if [ "$SUDO" = "-" ]; then
  echo "unknown(needs-root)"
else
  $SUDO sshd -T 2>/dev/null | grep -i \
    -e '^permitrootlogin ' \
    -e '^passwordauthentication ' \
    -e '^pubkeyauthentication ' \
    -e '^kbdinteractiveauthentication ' \
    -e '^challengeresponseauthentication ' \
    -e '^x11forwarding ' \
    -e '^allowtcpforwarding ' \
    -e '^maxauthtries ' \
    -e '^logingracetime ' \
    -e '^usepam ' \
    -e '^port '
fi
```

Row keys: each line is `key value`. Since OpenSSH 10.4
the keys are mixed case (`PermitRootLogin`), so compare
them without regard to case. Compare column-by-column.
A host whose sshd column is `unknown(needs-root)` is
reported as such, never as "defaults".

On Alpine the probe runs unchanged. Alpine's default
`openssh-server` is built without PAM, so the `usepam` line may
be missing there: a missing line is `n/a (Alpine)`, not `no`.

Highlight as drift:

- Any host with `passwordauthentication yes` while others
  have `no`.
- Any host with `permitrootlogin yes` while others use
  `prohibit-password` or `forced-commands-only`.
- Mismatched `port` values across the fleet.

**macOS** runs the probe unchanged
(`.agents/skills/hostwarden-security/references/ssh.md` →
SSH Password Authentication — macOS), plus one row: who Remote
Login admits, which it keeps outside `sshd_config`:

```bash
if dscl . -read /Groups/com.apple.access_ssh RecordName >/dev/null 2>&1; then
  echo "access_ssh=restricted"
  dscl . -read /Groups/com.apple.access_ssh \
    | grep -E '^(GroupMembership|NestedGroups):'
else
  echo "access_ssh=all users"
fi
```

`all users`, or the members and nested groups (Administrators
is a nested group). Hosts that differ are drift.

**FreeBSD** runs the probe with `sshd` replaced by the full path
of the one `rules/os/freebsd.md` → sshd says is enabled
(`/usr/local/sbin/sshd` when `$SVC` lists
`/usr/local/etc/rc.d/openssh`). A FreeBSD host that
accepts passwords by `.agents/skills/hostwarden-security/references/ssh.md`
next to hosts that do not is drift.

## 3. Firewall posture

Reading firewall state needs root (`ufw status`,
`firewall-cmd` and `nft list` all refuse for normal users).
Detect the *tools* via `command -v` (no root needed), but
only report their *state* with a privilege prefix —
otherwise emit the sentinel. Never let a
permission error degrade to `tool=none`: that fabricates
"no firewall" on a host whose firewall is simply unreadable.

Classify the tool in this order, first match wins:

1. `ufw` when `ufw status` says `Status: active`
2. `firewalld` when `firewall-cmd --state` says `running`
3. `nftables` when `nftables.service` is `active`, or an
   input chain in the `--nft` block drops by default
4. `none` — nothing of the above. The `nft` binary alone
   is not a firewall, nor are input chains that fail2ban,
   Docker or kube-proxy add with `policy accept;`.

Default deny for `nftables`, and what `legacy4` and
`legacy6` in the `--legacy` block mean: the security skill's
`firewall-nftables-docker` reference,
`.agents/skills/hostwarden-security/references/firewall-nftables-docker.md`.
No count means no legacy table.

```bash
# Prefer ufw on Debian/Ubuntu; firewall-cmd on RHEL family.
TOOLS=""
for t in ufw firewall-cmd nft; do
  command -v "$t" >/dev/null 2>&1 && TOOLS="$TOOLS $t"
done
echo "tools=${TOOLS:- none}"
echo "nftables.service=$(systemctl is-active nftables 2>/dev/null)"
echo "nftables.enabled=$(systemctl is-enabled nftables 2>/dev/null)"
if [ -n "$TOOLS" ] && [ "$SUDO" = "-" ]; then
  echo "state=unknown(needs-root)"
elif [ -n "$TOOLS" ]; then
  for t in $TOOLS; do
    echo "--$t"
    case $t in
      ufw) $SUDO ufw status verbose ;;
      firewall-cmd) $SUDO firewall-cmd --state
                    $SUDO firewall-cmd --list-all ;;
      nft) $SUDO nft list chains \
             | grep -B1 -e ^table -e "hook input" ;;
    esac 2>&1
  done
  echo "--legacy"
  iptables -V 2>/dev/null
  if iptables -V 2>/dev/null | grep -q nf_tables; then
    $SUDO grep -q . /proc/net/ip_tables_names 2>/dev/null &&
      echo "legacy4=$($SUDO iptables-legacy -S | grep -vc ^-P)"
    $SUDO grep -q . /proc/net/ip6_tables_names 2>/dev/null &&
      echo "legacy6=$($SUDO ip6tables-legacy -S | grep -vc ^-P)"
  fi
fi
```

**Alpine** runs the script above as well — its `systemctl`
lines print nothing there — and then classifies and judges
default deny as `rules/os/alpine.md` → Firewall → Checks says,
with `$SUDO` in front of the reads that need root. That adds
`awall` and saved `iptables` rules to the tools above. When
`$SUDO` is `-`, the runlevels still name the tool, but its
state and default policy are `unknown(needs-root)` — the
generic script's sentinel does not cover them, because it
runs only when it found a tool itself. Take
the runlevels from the `###rc###` block instead of
`rc-update show`: a runlevel that lists `nftables` is what
`nftables.enabled=enabled` means below.

Row keys for the table:

- Tool in use (`ufw` / `firewalld` / `nftables` / `none`;
  on Alpine also `awall` / `iptables`)
- State — `unknown(needs-root)` when a tool exists but
  its status is unreadable without root
- Legacy iptables rules next to nf_tables (count; > 0 is
  a WARN — `nft` does not show them)
- Default policy (deny incoming required)
- Number of open ports / services
- Whether the SSH port is open (must be yes: 22, or each
  `port` from section 2)
- `nftables.enabled=enabled` next to an active ufw or
  firewalld, or on Alpine awall (WARN: the unit flushes their
  rules; Alpine's `/etc/nftables.nft` starts with
  `flush ruleset` too)

Highlight as drift:

- Different firewall tool across the fleet.
- Different default policy.
- Different exposure of admin ports (5432, 27017, 3306,
  9100 to 0.0.0.0).
- Any host with legacy iptables rules while the others
  have none.

**macOS** — the Application Firewall
(`rules/os/macos.md` → Firewall), and pf where it has rules:

```bash
FW=/usr/libexec/ApplicationFirewall/socketfilterfw
$FW --getglobalstate
$FW --getblockall
$FW --getstealthmode
if [ "$SUDO" = "-" ]; then
  echo "pf=unknown(needs-root)"
else
  $SUDO pfctl -s info 2>/dev/null | grep -m1 '^Status'
fi
```

Tool in use is `appfw`, `pf`, both or `none`; pf counts only
when its status is enabled. Default policy is `deny` with
block-all on, and `per-app` otherwise.

**FreeBSD** — run the status probe from `rules/os/freebsd.md` →
Firewall with `$SUDO` in front of `pfctl` (`unknown(needs-root)`
when it is `-`), then read the rules of whichever runs:

```bash
if [ "$SUDO" = "-" ]; then
  echo "state=unknown(needs-root)"
else
  echo "--pf"
  $SUDO pfctl -s rules 2>/dev/null
  echo "--ipf"
  $SUDO ipfstat -i 2>/dev/null
  echo "--ipfw"
  $SUDO ipfw list 2>/dev/null
fi
```

Tool in use is `pf`, `ipfw`, `ipf` or `none`; default policy is read as
the OS file describes. Also highlight a running firewall whose
`_enable` variable is not `YES`.

## 4. MTA

```bash
# Detect installed MTA package + active unit.
for pkg in postfix sendmail msmtp-mta nullmailer dma \
           opensmtpd exim4; do
  dpkg -l "$pkg" 2>/dev/null \
    | awk -v p=$pkg "/^ii  /{print \"pkg=\" p; exit}"
done
ls -l /usr/sbin/sendmail 2>/dev/null | awk "{print \"sendmail=\" \$NF}"
for unit in postfix opensmtpd exim4; do
  state=$(systemctl is-active "$unit" 2>/dev/null)
  [ "$state" = "active" ] && echo "active=$unit"
done
hostname -f
```

**Alpine** (no `dpkg`, no `systemctl`):

```bash
apk info | grep -x -e postfix -e exim -e opensmtpd \
  -e msmtp -e dma | sed "s/^/pkg=/"
ls -l /usr/sbin/sendmail 2>/dev/null | awk "{print \"sendmail=\" \$NF}"
hostname -f
```

The package names are the MTA class of
`rules/service-class-check.md` → Phase 1 — Already-installed
probe, Alpine. For `active=`, look for `postfix`, `smtpd`
(OpenSMTPD's service on Alpine) or `exim` as `started` in the
`###rc###` block.

Put the MTA's name in the row, not the distribution's package
or service name: `exim` for `exim4`, `msmtp` for `msmtp-mta`,
`opensmtpd` for the `smtpd` service. Otherwise a Debian and an
Alpine host running the same MTA read as drift.

Row keys:

- Installed MTA package
- Sendmail symlink target
- Active SMTP unit
- FQDN (sanity)

Highlight as drift:

- One host with no MTA while others have one.
- Different MTAs in use without a documented reason in
  the per-host `memory.md`.

**macOS** ships Postfix, run by launchd on demand. `launchctl
print` output is not a stable interface; take only the
`state =` line.

```bash
ls -l /usr/sbin/sendmail 2>/dev/null | awk "{print \"sendmail=\" \$NF}"
postconf -h relayhost 2>/dev/null | sed "s/^/relayhost=/"
if [ "$SUDO" = "-" ]; then
  echo "active=unknown(needs-root)"
else
  $SUDO launchctl print system/com.apple.postfix.master 2>&1 \
    | grep -m1 -e 'state =' -e 'Could not find'
fi
hostname -f
```

Installed MTA is `postfix` on every Mac; a relay host is what
tells one that sends mail from one that cannot. Never propose
installing an MTA on a Mac
(`.agents/skills/hostwarden-email/references/transport-remote.md`).

**FreeBSD** — the MTA is named in `/etc/mail/mailer.conf`
(`rules/os/freebsd.md` → Mail and Time):

```bash
awk '$1 == "sendmail" {print $2}' /etc/mail/mailer.conf
echo "$SVC" | grep -E '/(sendmail|postfix|smtpd|exim)$' \
  | while read -r s; do "$s" status; done
hostname -f
```

The `mailer.conf` target — the program path only, never the
arguments, which can carry a credential — stands in for the
package and the symlink. An enabled rc script is the active unit only when its
`status` says it is running; enabled but stopped is drift.

## 5. Time sync

```bash
timedatectl show \
  --property=NTPSynchronized \
  --property=NTP \
  --property=TimeUSec \
  --property=Timezone 2>/dev/null
systemctl is-active systemd-timesyncd chronyd ntp \
  ntpd openntpd 2>&1 | head -5
```

Row keys:

- `NTPSynchronized` (yes required)
- Active timesync unit name
- Timezone (typically all `Europe/Berlin`)

Highlight as drift:

- `NTPSynchronized=no` on any host.
- Different timesync daemons across the fleet.
- Different timezones.

**Alpine** has no `timedatectl`. The time service comes from the
`###rc###` block: busybox `ntpd` (the default) reports no sync
state, chrony does. Run `chronyc tracking` only when `chronyd`
is started there, and read the timezone directly:

```bash
readlink /etc/localtime
cat /etc/timezone 2>/dev/null
date +%Z
```

Row keys on an Alpine host:

- `NTPSynchronized` — `yes` when `chronyc tracking` reports
  `Leap status : Normal`, `no` for any other leap status, and
  `n/a (busybox ntpd)` or `n/a (openntpd)` under those, which
  this probe does not read a sync state from
- Active time service — its name and state in `###rc###`
- Timezone — the zone name after `zoneinfo/` in the link
  target: `setup-timezone` links `/etc/localtime` into
  `/etc/zoneinfo/` or `/usr/share/zoneinfo/`, and only the
  name compares with `timedatectl`'s. Where `/etc/localtime`
  is a copied file, `/etc/timezone`; the abbreviation `date`
  prints only when neither names the zone

Judge on the host alone: no time service started is a warning,
except in LXC (`openrc --sys` prints `LXC`), whose clock is the
hypervisor's.

**macOS** has no `timedatectl`. `systemsetup` needs an admin:

```bash
if [ "$SUDO" = "-" ]; then
  echo "ntp=unknown(needs-root)"
else
  $SUDO systemsetup -getusingnetworktime
  $SUDO systemsetup -getnetworktimeserver
fi
readlink /etc/localtime
```

Rows: network time on or off in place of `NTPSynchronized`,
the time server, and the zone name after `zoneinfo/` in the
link target. The clock offset is housekeeping's
(`.agents/skills/hostwarden-housekeeping/references/baseline-macos.md`
→ Time Sync).

**FreeBSD** has no `timedatectl`:

```bash
echo "$SVC" | grep -E '/(ntpd|chronyd|openntpd)$'
ntpq -pn 2>/dev/null | grep '^\*'
chronyc tracking 2>/dev/null | grep '^Leap status'
ntpctl -s status 2>/dev/null
cat /var/db/zoneinfo 2>/dev/null
```

The line of the daemon that runs stands for `NTPSynchronized`:
a selected peer in `ntpq`, `Leap status : Normal` from chronyd,
`clock synced` from openntpd (`rules/os/freebsd.md` → Mail and
Time). Without `/var/db/zoneinfo`, report the zone `date +%Z`
prints.

## 6. Auto-reboot behaviour (cross-check with UA)

```bash
test -f /var/run/reboot-required && echo "pending=yes" \
  || echo "pending=no"
uptime -s
# needrestart: the restart mode that wins — the last one set, in
# needrestart's order: needrestart.conf, then conf.d/*.conf sorted.
if command -v needrestart >/dev/null 2>&1; then
  M=$(grep -hs '^[[:space:]]*\$nrconf{restart}' \
    /etc/needrestart/needrestart.conf \
    /etc/needrestart/conf.d/*.conf | tail -n 1)
  echo "${M:-needrestart=default}"
else
  echo "needrestart=absent"
fi
```

Row keys:

- `/var/run/reboot-required` present? (kernel waiting for
  reboot)
- Boot time / uptime
- needrestart restart mode: the value `$nrconf{restart}`
  sets, `default`, or `absent`.
  `default` on Ubuntu 24.04 and later means the apt hook
  restarts services itself (`rules/os/debian.md` →
  Non-interactive apt runs)

Highlight as drift / warning:

- Any host with `pending=yes` but uptime > 7d — auto-reboot
  has not fired despite a pending kernel.
- Hosts with uptime > 90d — even without a pending reboot,
  worth a heads-up.
- Different needrestart restart modes: one host restarts
  services after every apt run, another only lists them.

**Alpine** has no `/var/run/reboot-required`, and busybox
`uptime` takes no options. A kernel upgrade removes the running
kernel's modules, so a missing directory for `uname -r` is a
kernel waiting for a reboot (`rules/os/alpine.md` → Common
Pitfalls). In LXC the kernel is the hypervisor's, and the check
does not apply:

```bash
if [ "$(openrc --sys 2>/dev/null)" = "LXC" ]; then
  echo "pending=n/a(container)"
elif [ -d "/lib/modules/$(uname -r)" ]; then
  echo "pending=no"
else
  echo "pending=yes"
fi
uptime
```

The row keys and the criteria above apply, with the uptime read
from the `up …` part of the line. The needrestart row is
`n/a (Alpine)`: there is no needrestart and no apt hook.

**macOS** — the boot time only:

```bash
sysctl -n kern.boottime
```

A pending restart is housekeeping's, since only `softwareupdate
--list` knows and it asks Apple's servers; that row and
needrestart are `n/a (macOS)`.

**FreeBSD** has no `reboot-required` file and no `uptime -s`:

```bash
freebsd-version -kru
sysctl -n kern.boottime
```

An installed kernel that differs from the running one counts as
`pending=yes` (`rules/os/freebsd.md` → Version Detection).
