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
echo "###net###"; <network probe>
echo "###time###"; <time probe>
echo "###reboot###"; <reboot probe>
echo "###meshvpn###"; <mesh VPN probe>
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

On macOS, every probe below but section 8 has a **macOS**
variant that replaces it. The privilege prefix applies unchanged, but
the root account is disabled on a Mac and sudo usually asks for
a password, so `$SUDO` is often `-`: expect
`unknown(needs-root)` cells for what sudo does not cover,
rather than a partial row. A key
only the other families have is `n/a (macOS)`.

On FreeBSD, every probe below but section 8 has a **FreeBSD**
variant that replaces it, and `rules/os/freebsd.md` is the reference for what
the commands print. Open the FreeBSD bundle with the privilege
prefix, so `$SUDO` is set for every probe, and with the loaded OS
file's Service Manager → Enabled services, kept for the variants to
grep:

```bash
P='^(openssh|ntpd|chronyd|openntpd|sendmail|postfix|smtpd|exim)_enable$'
SVC=$(<Enabled services listing>)
```

A key only the other family has is `n/a (FreeBSD)`
(`references/output-format.md`). Rows and verdicts match the
housekeeping baseline,
`.agents/skills/hostwarden-housekeeping/references/baseline-freebsd.md`.

**Privilege handling.** The sshd and firewall probes need
root. Open the bundle with the privilege prefix from
`rules/privilege-escalation.md` → Stand-ins for sudo: it sets
`$SUDO` once, with `doas`, Alpine's default, as a stand-in.
Where `$SUDO` is `-`, a probe emits the sentinel
`unknown(needs-root)` instead of a degraded answer — an active
ufw must never be reported as `none` just because the probe
lacked permission to read its state. A cell keeps the sentinel
only after the reruns that file requires where `$SUDO` is `-`:
each section sudo covers is sent again whole, with
`SUDO="sudo -n"`, and the probes appended on its answers with
it. See
`references/output-format.md` for how the sentinel is rendered
and why it is excluded from drift detection.

**Containers.** In a container, the active time service and
`NTPSynchronized` (section 6), and a pending reboot read from
the kernel and the boot time and uptime (section 7) are what
the host owns (`rules/system-containers.md` → What the Host
Owns), so the uptime criteria do not apply there.

## 1. Unattended-upgrades (Debian/Ubuntu)

Run the Debian/Ubuntu probe from the housekeeping baseline,
`.agents/skills/hostwarden-housekeeping/references/baseline-linux.md`
→ Automatic Security Updates, and on Ubuntu the probe from its
Ubuntu Release and Support section too. Their output carries
the rows; the baseline's verdicts are housekeeping's, not the
audit's:

- `APT::Periodic::Update-Package-Lists`
- `APT::Periodic::Unattended-Upgrade`
- Origins count — the `origins.count=` line
- Origins cover the security archive — `yes` for
  `origins=ok`, `no` for `origins=MISSING …`
- `Mail`
- `MailReport` (or legacy `MailOnlyOnError`)
- `Automatic-Reboot`
- `Automatic-Reboot-WithUsers`
- `Automatic-Reboot-Time` (present/absent — absent is the
  preferred fleet policy)
- `Remove-Unused-Kernel-Packages`
- Pro attached, and esm-infra, esm-apps, livepatch
  enabled — the `attached=` line and the service lines
  (Ubuntu; `n/a` elsewhere and where the probe prints
  `pro=absent`)

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
privilege prefix. Without one, `sshd -G` prints the same without
the host keys (OpenSSH 9.3 and newer) where sshd's configuration
files are readable; emit a sentinel when a run fails. The daemon
is picked as the security audit's SSH reference picks it: a root
process whose parent is PID 1 and whose program is an sshd, run as
its own binary with its own `-f`, and `ps` runs with the privilege
prefix and, on FreeBSD, with `-J 0` to leave jails out. Every
daemon's command line goes into the row. Where several run, the row
reads the one on the default file, or else the first `-f` one:

```bash
PATH=$PATH:/usr/sbin:/usr/local/sbin
case $(uname -s) in FreeBSD) J='-J 0' ;; *) J= ;; esac
PFX=$SUDO; [ "$PFX" != "-" ] || PFX=
C=$($PFX ps ax $J -o user=,ppid=,args= | sed -n 's/^root  *1  *//p' \
  | sed -e 's/^[^ ]*sshd[^ /]*: //' -e 's/ \[listener\].*//' \
  | grep -e '^[^ ]*sshd[^ /]* ' -e '^[^ ]*sshd[^ /]*$' \
  | LC_ALL=C sort -u)
printf '%s\n' "$C" | grep . | sed 's/^/sshd-cmd /'
L=$(printf '%s\n' "$C" \
  | sed -e 's/^\([^ ]*\) \(.* \)\{0,1\}-[46DdeGiqRrTt]*f *\([^ ]*\).*/\1 \3/' \
    -e t -e 's/^\([^ ]*\).*/\1 default/' | LC_ALL=C sort -u)
D=$(printf '%s\n' "$L" | grep ' default$' | head -n 1)
[ -n "$D" ] || D=$(printf '%s\n' "$L" | head -n 1)
set -- ${D:-sshd default}
B=$1; F=$2; set --
N=$(printf '%s\n' "$C" | grep -c .)
[ "$N" -gt 0 ] || echo "sshd-daemons none visible, row reads $B"
[ "$N" -le 1 ] || echo "sshd-daemons $N, row reads $B"
[ "$F" = default ] || { set -- -f "$F"; echo "sshd-f $F"; }
if [ "$SUDO" = "-" ]; then
  OUT=$("$B" "$@" -G 2>/dev/null) || { echo "unknown(needs-root)"; OUT=; }
else
  OUT=$($SUDO "$B" "$@" -T 2>/dev/null) \
    || { echo "unknown(sshd-failed)"; OUT=; }
fi
printf '%s\n' "$OUT" | grep -i \
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
    -e '^authenticationmethods ' \
    -e '^port '
```

After it, in the same section, run the Host Certificate probe
of `rules/ssh-ca.md` and, where `$SUDO` is not `-`, its User CA
Trust probe, which reuses `OUT`. Their `hostcert`, `clientca`,
`userca` and `krl` lines, and the
`trustedusercakeys`, `authorizedprincipals…` and `revokedkeys`
values, are rows of the same table; for a host certificate, its
signing CA and the end of its `Valid:` line. The host certificate
and client CA rows need no root and are filled on a host whose
sshd column is `unknown(needs-root)`; after
`unknown(sshd-failed)` the CA rows read the same, never
"defaults" or "no user CA". What these rows find stays in the
report: the fleet audit writes no memory.

Row keys: each line is `key value`. Since OpenSSH 10.4
the keys are mixed case (`PermitRootLogin`), so compare
them without regard to case. Compare column-by-column.
`sshd-f` names the file a daemon started with `-f` reads; the
values of a host that has one come from that file.
`sshd-daemons` says the host runs more than one sshd and which
binary the row read; its other daemons are the security audit's
to read, and the report names the host as reading one of several.
`sshd-daemons none visible` means no listener runs (launchd, a
socket unit) or, without root, that the process list hides it;
the row then reads the default file, and without root the report
says a `-f` could not be seen. `sshd-cmd` is a daemon's command
line: a `-p` or `-o Port=` there overrides `port` for that
daemon, and hosts whose command lines differ are drift.
A host whose sshd column is `unknown(needs-root)` or
`unknown(sshd-failed)` is reported as such, never as "defaults".

On Alpine the probe runs unchanged; it reads the configuration
with the binary that runs, `sshd.pam` where PAM is on. Alpine's
default `openssh-server` is built without PAM, so the `usepam`
line may be missing there: a missing line is `n/a (Alpine)`, not
`no`.

Highlight as drift:

- Any host with `passwordauthentication yes` while others
  have `no`. An `authenticationmethods` that requires
  `publickey` in every one of its lists means the host
  accepts no password alone, whatever the other lines say.
- Any host with `permitrootlogin yes` while others use
  `prohibit-password` or `forced-commands-only`.
- Mismatched `port` values across the fleet.
- A different `userca` fingerprint, principals setup or
  `revokedkeys` path on hosts that should admit the same
  people, and a host with no user CA among hosts that
  have one.
- A different `krl` checksum on hosts that trust the same
  user CA: a revocation did not reach every host, and a
  revoked certificate still works on the others. A host
  whose `krl` line is an error has the lockout of
  `rules/ssh-ca.md` → User CA Trust: **CRITICAL**.
  Hosts that trust a user CA without `revokedkeys`
  cannot revoke at all; list them too.
- Host certificates on some hosts but not others, or
  signed by different CAs. One that ends much earlier
  than the rest usually has a renewal job that stopped.
- A different `clientca`, or none, on hosts whose memory
  says they open SSH connections to others.

During a CA rotation two fingerprints show on some hosts;
that is drift only until the rotation is done, as the CA's
line in `memory/network.md` says.

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

**FreeBSD** runs the probe unchanged: it takes the binary from
the running daemon. Where none is visible, it replaces the `sshd`
in `${D:-sshd default}` with the full path of the one
`rules/os/freebsd.md` → sshd says is enabled
(`/usr/local/sbin/sshd` when `$SVC` has
`openssh_enable="YES"`). A FreeBSD host that
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
4. `iptables` when the `--legacy` block shows the legacy
   backend and a family's INPUT drops by default
5. `none` — nothing of the above. The `nft` binary alone
   is not a firewall, nor are input chains that fail2ban,
   Docker or kube-proxy add with `policy accept;`.

Default deny for `nftables` and `iptables`, and what `legacy4`
and `legacy6` in the `--legacy` block mean: the security skill's
`firewall-nftables-docker` reference,
`.agents/skills/hostwarden-security/references/firewall-nftables-docker.md`
(Native nftables, iptables without a manager, Mixed frameworks).
No count means no legacy table. Where `--legacy` shows the legacy
backend and neither ufw nor firewalld is active, append that
reference's iptables without a manager probe to this script,
with `$SUDO` in front of its reads; its output decides row 4.

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
fi
echo "--legacy"
v=$(iptables -V 2>/dev/null); echo "${v:-iptables=none}"
if [ -n "$v" ] && [ "$SUDO" = "-" ]; then
  echo "legacy=unknown(needs-root)"
elif printf '%s' "$v" | grep -q nf_tables; then
  $SUDO grep -q . /proc/net/ip_tables_names 2>/dev/null &&
    echo "legacy4=$($SUDO iptables-legacy -S | grep -vc ^-P)"
  $SUDO grep -q . /proc/net/ip6_tables_names 2>/dev/null &&
    echo "legacy6=$($SUDO ip6tables-legacy -S | grep -vc ^-P)"
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

- Tool in use (`ufw` / `firewalld` / `nftables` / `iptables` /
  `none`; on Alpine also `awall`)
- Upstream firewall — the host's `Upstream firewall:` line
  from memory, or `not recorded`, shown as it stands
- State — `unknown(needs-root)` when a tool exists but
  its status is unreadable without root
- Legacy iptables rules next to nf_tables (count; > 0 is
  a WARN — `nft` does not show them)
- Default policy (deny incoming required)
- Number of open ports / services
- Whether the SSH port is open (must be yes: 22, or each
  `port` from section 2, and each `-p` or `-o Port=` of an
  `sshd-cmd` line)
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
when its status is enabled. Default policy is `none` while
the global state is disabled, whatever block-all says; with
it enabled, `deny` with block-all on and `per-app` otherwise.

**FreeBSD** — run the status probe from `rules/os/freebsd.md` →
Firewall with `$SUDO` in front of `pfctl` and `ipf`
(`unknown(needs-root)` when it is `-`), then read the rules of
whichever runs:

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

**macOS** ships Postfix, which launchd starts on demand, so
compare whether its job is loaded, not whether it runs; only the
exit status of `launchctl print` counts, its output is not a
stable interface. The read needs no root (`rules/os/macos.md` →
Service Manager). An empty relay host means direct delivery.

```bash
ls -l /usr/sbin/sendmail 2>/dev/null | awk "{print \"sendmail=\" \$NF}"
postconf -h relayhost 2>/dev/null | sed "s/^/relayhost=/"
if launchctl print system/com.apple.postfix.master >/dev/null 2>&1; then
  echo "loaded=yes"
else
  echo "loaded=no"
fi
hostname -f
```

Installed MTA is `postfix` on every Mac; `loaded` is the active
unit. Never propose installing an MTA on a Mac
(`.agents/skills/hostwarden-email/references/transport-remote.md`).

**FreeBSD** — the MTA is named in `/etc/mail/mailer.conf`
(`rules/os/freebsd.md` → Mail and Time):

```bash
awk '$1 == "sendmail" {print $2}' /etc/mail/mailer.conf
echo "$SVC" \
  | sed -nE 's/^(sendmail|postfix|smtpd|exim)_enable="[Yy][Ee][Ss]"$/\1/p' \
  | while read -r s; do <Service status> "$s"; done
hostname -f
```

The `mailer.conf` target — the program path only, never the
arguments, which can carry a credential — stands in for the
package and the symlink. An enabled MTA is the active unit only
when its Service status (`<Service status>`, from the loaded OS
file's Service Manager) says it is running; enabled but stopped is
drift.

## 5. Network

The per-host profile stays with `rules/network.md`; this
compares. Run its Quick check, in the family's form, and in the
same call the lines a comparison needs beyond it:

```bash
cat /proc/sys/net/ipv6/conf/all/forwarding 2>/dev/null \
  || echo "forwarding=n/a (no ipv6)"
if grep -q '^nameserver 127\.0\.0\.53$' /etc/resolv.conf; then
  resolvectl dns 2>/dev/null | grep -vE "\(($c)[^)]*\)" \
    | cut -d: -f2- | tr ' ' '\n' | grep . | sort -u | wc -l
else grep -c '^nameserver' /etc/resolv.conf; fi
```

Behind systemd-resolved's stub the file names only
`127.0.0.53`, so the count comes from the servers resolved itself
uses, global and per link, without the overlay links the Quick
check's `c` excludes.

**FreeBSD** and **macOS** replace the first with
`sysctl -n net.inet6.ip6.forwarding`. On macOS the nameservers
are those of the resolver in use, the first one in the unscoped
section whose `flags` do not say `Supplemental` — a VPN's scoped
resolvers come before it and repeat their own servers:

```bash
scutil --dns | awk '/^DNS configuration \(/ {exit}
  /^resolver #/ {n = 0; s = 0} /nameserver\[/ {n++}
  /flags.*Supplemental/ {s = 1}
  /^$/ && n && !s {print n; exit}'
```

Row keys:

- Stack: `dual-stack`, `v4-only`, `v6-only` or `v4 + ULA`
  (`rules/network.md` → Stack)
- Default route per family, and the device it uses
- IPv6 forwarding on or off
- Who writes `/etc/resolv.conf`, and how many nameservers

Highlight as drift:

- A host with no IPv6 where the others have it, or the reverse.
- A global IPv6 address without a default route on one host.
- A different resolver owner, or a host with one nameserver
  where the rest have two.
- Forwarding on where the others have it off. Whether it is
  acceptable on that host is the security audit's call
  (`.agents/skills/hostwarden-security/references/kernel-os.md`
  → IP Forwarding), not this table's.

## 6. Time sync

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
except in a container (Containers above).

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
echo "$SVC" | grep -E '^(ntpd|chronyd|openntpd)_enable="[Yy][Ee][Ss]"'
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

## 7. Auto-reboot behaviour (cross-check with UA)

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
Pitfalls). Where `Virtualization:` names a container, none of
this runs (Containers above). Everywhere else:

```bash
if [ -d "/lib/modules/$(uname -r)" ]; then
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

## 8. Mesh VPNs and tunnels

Which hosts are in which mesh VPN, whether each is connected,
when its login expires, and the SSH servers Tailscale and NetBird
bring, a way in the sshd rows do not show. Run both blocks of
`rules/mesh-vpn.md` → Probe (no root) unchanged, on every family.
Where they printed `"RunSSH": true`, or NetBird runs without an
`SSH Server` line that says `Disabled` (an older client prints
none, and counts as on), add the Tailscale or NetBird part of
`.agents/skills/hostwarden-security/references/vpn-ssh.md` →
Probe (root), unchanged and as root: a quoted here-document fed
to `$SUDO sh -s`, since NetBird's file globs expand only for
root. Where `$SUDO` is `-`, print `tailscale-root:
unknown(needs-root)` or `netbird-flags: unknown(needs-root)`
instead. Read what they print as that file's Tailscale and
NetBird paragraphs say.

No output: no agent on the host, unless a `hidepid=` or
`see_other_uids=0` line says `ps` saw only the user's own
processes, which makes the row `unchecked (hidden processes)`. An
agent inside a container shows only its process; its row reads
`unchecked (container)`.

Row keys:

- Agents running, overlay interfaces, and on macOS the apps
  active (`rules/mesh-vpn.md` → Probe (no root)); an app read as
  off counts as no membership, one whose state could not be read
  as `unchecked`
- Per agent: connected (`BackendState` and `Online`, `Daemon
  status` and `Management`) and login expiry (`KeyExpiry`,
  `Session expires`), as `rules/mesh-vpn.md` → Per agent reads
  them
- SSH server on or off (`RunSSH`, `SSH Server`); Newt's reads
  `unchecked`, since only the security audit reads it
- Tailscale control server (`ControlURL`)
- Root admitted by the agent's SSH server, and by accept or by
  check (Tailscale); `EnableSSHRoot` and `DisableSSHAuth`
  (NetBird)

Highlight as drift:

- A host outside the VPN the others are in.
- An SSH server on some hosts only.
- Different Tailscale control servers.
- A login expiry on some hosts only: those drop out of the VPN
  when it runs out (`rules/mesh-vpn.md` → What cuts a host off).
- Root admitted on some hosts only, by accept on some and by
  check on others, or `EnableSSHRoot` or `DisableSSHAuth`
  differing across hosts.

Judge on the host alone, a warning: a way in its `network.md`
does not record, as `rules/mesh-vpn.md` → Memory defines it.
The audit records nothing: the report names the host for a
security audit, which asks the user and records the answer.

Who may be admitted, and what it takes to fix, is the security
audit's (`.agents/skills/hostwarden-security/references/vpn-ssh.md`
→ Findings); this table compares.
