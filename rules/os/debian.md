# Debian & Ubuntu

Rules for Debian, Ubuntu, and derivatives.

`ID` in `/etc/os-release` says which one a host is. Where
Ubuntu behaves differently, the section says so; what only
Ubuntu has is under **Ubuntu** below.

## Package Manager

- Use `apt-get` (not `apt`) — it's more reliable for
  non-interactive/scripted use.
- Always run `apt-get update` before installing or upgrading.
- Dry-run before upgrading: `apt-get --dry-run upgrade`
- Every install and upgrade runs non-interactively, in
  the form under **Non-interactive apt runs**.

### Non-interactive apt runs

Hostwarden's SSH calls have no terminal, so nothing in an
apt run may wait for an answer. Run every install and
upgrade like this:

```bash
env DEBIAN_FRONTEND=noninteractive NEEDRESTART_MODE=l \
  apt-get -y \
  -o Dpkg::Options::=--force-confdef \
  -o Dpkg::Options::=--force-confold \
  upgrade
```

As a normal user, put `sudo` in front of `env`. `sudo`
resets the environment, so variables set before `sudo`
never reach apt; `env` after it sets them for root.

- `DEBIAN_FRONTEND=noninteractive` makes debconf take the
  default answer to every question (debconf(7)).
- `--force-confdef --force-confold` keep a locally
  changed config file when the package ships a new one,
  instead of stopping at the conffile prompt (dpkg(1)).
  The package's version lands next to it as
  `<file>.dpkg-dist`: report each one, because the local
  file may now lack a setting the new version needs.
- `NEEDRESTART_MODE=l` makes needrestart, which apt calls
  after every run, list the services that use the old
  libraries instead of restarting them. On Ubuntu 24.04
  and later, needrestart restarts them itself, in
  non-interactive runs too — a service restart nobody
  asked for (`AGENTS.md` → Critical Safety Rules). An
  explicit restart mode switches that off; elsewhere
  needrestart already lists when there is no terminal.
  Without needrestart the variable changes nothing.
  Afterwards, take the listed services through
  `rules/service-reload.md`.

The daily unattended-upgrades run is not affected: on
Ubuntu it keeps restarting services on its own, which is
the host's policy, not a Hostwarden change.

Sources: https://manpages.debian.org/trixie/debconf-doc/debconf.7.en.html,
https://manpages.debian.org/trixie/dpkg/dpkg.1.en.html,
https://manpages.ubuntu.com/manpages/noble/man1/needrestart.1.html,
https://documentation.ubuntu.com/release-notes/24.04/,
https://discourse.ubuntu.com/t/needrestart-changes-in-ubuntu-24-04-service-restarts/44671

## Stable Branch Only

**Always install packages from the stable branch.**
Never add `testing`, `unstable`, `sid`, or
`experimental` sources unless there is absolutely
no other option and the user explicitly requests it.

### Why This Matters

Mixing releases breaks dependency chains. A single
package from `testing` can pull in dozens of
dependencies that replace stable libraries, leading
to a partially upgraded system that is difficult to
maintain and may break on the next `apt-get upgrade`.

### Preferred Alternatives (in order)

Before reaching for `testing` or `unstable`:

1. **Stable backports.** Check if the package is in
   `<codename>-backports`. Backports are rebuilt from
   testing for the stable release and receive security
   support.
   ```
   apt-get -t <codename>-backports install <package>
   ```
2. **Upstream project repository.** Many projects
   provide their own Debian repos with current
   packages built for stable (e.g. PostgreSQL,
   Docker, Node.js, nginx). These are purpose-built
   and do not pull in unrelated testing dependencies.
3. **Flatpak or AppImage.** For desktop applications
   on workstations (not servers), sandboxed formats
   avoid polluting the system.
4. **Build from source or use a static binary.** For
   CLI tools or services, install to `/usr/local/` or
   `/opt/` to keep the package manager untouched.
5. **mise.** For language runtimes, use mise instead
   of any Debian package. See the `hostwarden-runtimes` skill.

### Last Resort: Pinned Single Package

If none of the above work and the user explicitly
confirms, install a **single pinned package** from
testing — never add testing as a general source.

**Step 1 — Add testing as a secondary source with
low priority:**

```
echo "deb http://deb.debian.org/debian testing main" \
  > /etc/apt/sources.list.d/testing.list

cat > /etc/apt/preferences.d/99-testing-low << 'EOF'
Package: *
Pin: release a=testing
Pin-Priority: 100
EOF
```

Priority 100 means testing packages are never
installed automatically — only when explicitly
requested with `-t testing`.

**Warning:** a package pinned at priority 100 is
frozen — it stops receiving updates, including
security fixes, and must be tracked manually. See
`rules/version-check.md`.

**Step 2 — Install the specific package:**

```
apt-get update
apt-get -t testing install <package>
```

**Step 3 — Verify no collateral upgrades:**

```
apt-cache policy <package>
```

The line marked `***` shows the installed version;
check which repo it came from. Repeat for any
dependencies the install pulled in. If more than
the intended package came from testing, flag this
to the user immediately.

**Step 4 — Document in server memory:**

```markdown
- apt-pinning: <package> from testing (reason:
  <why stable/backports was insufficient>)
```

**Step 5 — Log the override:**

```bash
logger -t hostwarden \
  "[<operator> as <unix-user>] Installed <package> from testing (pinned, \
user override: stable had no option)"
```

### What to Check on Existing Servers

During housekeeping, verify the sources list:

```
for f in /etc/apt/sources.list /etc/apt/sources.list.d/*; do
  grep -v '^[[:space:]]*#' "$f" 2>/dev/null \
    | grep -owE "testing|unstable|sid|experimental" | sed "s|^|$f:|"
done | sort | uniq -c
```

The file and the suite are enough, never the line, whose URL can
hold a token (`rules/secrets.md` → Commands That Leak). If
non-stable sources are found without pinning,
flag as **WARN** in the housekeeping report.

### Ubuntu Equivalent

On Ubuntu, the same principle applies: use the
release the server was installed with. Do not mix
in packages from a newer Ubuntu release. Prefer
PPAs from the upstream project over random
third-party PPAs. The check above becomes one for
any codename other than the host's own
(`VERSION_CODENAME` in `/etc/os-release`) in the
`Suites:` and `deb` lines, printing the suites
alone, never the URL: the one-line format's third
word (`sed -E 's/\[[^]]*\]//' <file> | awk '$1 ~
/^deb/ {print $3}'`) and what follows `Suites:`.

## Package Sources

Two formats exist, and apt reads both:

- **One-line format** — `deb <uri> <suite> <component>…`
  in `/etc/apt/sources.list` and `*.list` files under
  `/etc/apt/sources.list.d/`.
- **deb822 format** — stanzas of `Types:`, `URIs:`,
  `Suites:`, `Components:` and `Signed-By:` in `*.sources`
  files under `/etc/apt/sources.list.d/`.

Since 24.04, Ubuntu keeps its own archive in
`/etc/apt/sources.list.d/ubuntu.sources` (deb822), and
`/etc/apt/sources.list` is left with at most a comment
pointing there. Read both locations before concluding a
source is missing, and add a new source in the format
the host already uses. A backup of a `.sources` or `.list` file
never stays in `sources.list.d/` (`rules/backups.md`).

Debian 12 and newer publish firmware in a component of its
own, `non-free-firmware`, which the installer enables; a host
upgraded from an older release carries it only where someone
added it. Debian 11 has no such component and publishes the
same packages in `non-free`, so the component to look for
follows the release. Where it is absent, `apt-cache policy`
answers `Candidate: (none)` for a package that does exist,
the CPU microcode packages `intel-microcode` and
`amd64-microcode` among them. Ubuntu keeps both in `main`, in
the release, security and updates pockets alike.

Sources: https://documentation.ubuntu.com/release-notes/24.04/,
https://manpages.ubuntu.com/manpages/noble/man5/sources.list.5.html,
https://www.debian.org/releases/bookworm/amd64/release-notes/ch-whats-new.en.html

## Version Detection

- `/etc/os-release` — full distro info; on Ubuntu the
  only reliable one (`VERSION_ID`, `VERSION_CODENAME`)
- `/etc/debian_version` — Debian version number. On
  Ubuntu it names the Debian development suite the
  release was based on, not the Ubuntu version.
- `lsb_release -a` — if `lsb-release` is installed

## Firewall

- **Expected:** `ufw` (Uncomplicated Firewall)
- Check status: `ufw status verbose`
- **Debian** does not install `ufw`. If neither `ufw`
  nor native nftables (below) is active, flag it to
  the user.
- **Ubuntu** installs `ufw` and leaves it inactive:
  `Status: inactive` is the stock state, not a
  firewall someone switched off. It is still no
  firewall — report it, and offer to enable `ufw`
  rather than to install anything. `ufw` comes with
  the `standard` package set, so a minimized Ubuntu
  install can lack it; only then is it missing.
- **Critical:** before enabling `ufw`, always allow SSH
  first: `ufw allow OpenSSH` (or `ufw allow 22/tcp`).
  Enabling `ufw` without an SSH rule locks you out of
  the server immediately. The safe sequence is:
  `ufw allow OpenSSH && ufw enable`. Both cover
  port 22 only: allow every other port sshd listens
  on as well (`AGENTS.md` → Critical Safety Rules).
- Enabling `ufw` or changing its rules over SSH goes
  through `rules/ssh-safety-net.md`. Check:
  `ufw --dry-run <command>`; revert: `ufw disable` for
  enabling it, and for a rule change the backed-up
  `/etc/ufw/user.rules` and `user6.rules` restored,
  then `ufw reload`.
- After enabling, verify the default policy:
  `ufw status verbose` — look for
  `Default: deny (incoming)`. If incoming is set to
  `allow`, fix with `ufw default deny incoming`.
- **Native nftables** is installed on Debian with
  its unit off, and counts as a firewall once
  enabled: `nftables.service` loads
  `/etc/nftables.conf`, whose stock version starts
  with `flush ruleset`, so starting, reloading or
  stopping it wipes ufw's rules. A host that runs it
  needs no ufw on top. Checks:
  `.agents/skills/hostwarden-security/references/firewall-nftables-docker.md`.
  A change to it goes through `rules/ssh-safety-net.md`.
  Check: `nft -c -f /etc/nftables.conf`; revert: the
  backed-up file restored, then `nft -f /etc/nftables.conf`
  where the unit ran before, or `systemctl stop nftables`
  (its `ExecStop` is `nft flush ruleset`) where it did not.

Sources: https://documentation.ubuntu.com/security/security-features/network/firewall/,
https://git.launchpad.net/~ubuntu-core-dev/ubuntu-seeds/+git/platform/tree/standard?h=resolute

## Automatic Security Updates

- **Expected:** `unattended-upgrades`
- Config: `/etc/apt/apt.conf.d/50unattended-upgrades`
- Activation also requires
  `APT::Periodic::Unattended-Upgrade "1";` — usually
  set in `/etc/apt/apt.conf.d/20auto-upgrades`.
- Check if active: `systemctl status unattended-upgrades`
  and `systemctl status apt-daily-upgrade.timer`
- **Debian:** if not installed, flag it to the user and
  offer to install it.
- **Ubuntu** installs and enables it on every server
  install, minimized included, with daily runs in
  `20auto-upgrades`. Missing or switched off there means
  someone removed it or set a value to `0` on purpose:
  flag it, ask why, and record the answer in server
  memory before changing anything.
- On Ubuntu, `50unattended-upgrades` also allows the
  ESM origins (`${distro_id}ESMApps:…-apps-security`,
  `${distro_id}ESM:…-infra-security`). They only
  deliver anything once Ubuntu Pro is attached (see
  **Ubuntu Pro and ESM**).

Sources: https://ubuntu.com/server/docs/how-to/software/automatic-updates/,
https://git.launchpad.net/~ubuntu-core-dev/ubuntu-seeds/+git/ubuntu/tree/server-minimal?h=resolute

## Service Manager

- `systemctl` (systemd)
- **Enabled services:** `systemctl list-unit-files --no-legend`
  prints every unit file with its state in the second column;
  `enabled` there marks one that starts at boot. The third column,
  where systemd prints one, is the vendor preset, which says what
  the distribution would choose and nothing about this host:
  `nftables.service disabled enabled` is off. It reads unit files,
  not services, and is cheap enough for every connection.
- **Service status:** `systemctl is-active <unit>` prints `active`
  and exits 0 while the unit runs.
- Check service: `systemctl status <service>`
- Logs: `journalctl -u <service>`

## Networking

Find out which tool owns the network before touching it,
on Ubuntu as on Debian — the apply and revert commands
follow from the answer:

```bash
ls /etc/netplan/ 2>/dev/null
grep -v '^[[:space:]]*#' /etc/network/interfaces 2>/dev/null
ls /etc/network/interfaces.d/ 2>/dev/null
systemctl is-active systemd-networkd NetworkManager networking
```

- **Ubuntu** installs **netplan**: YAML files in
  `/etc/netplan/`, rendered for systemd-networkd on
  servers. A host upgraded from an old release, or set up
  by hand, can still run ifupdown or NetworkManager
  profiles instead; then netplan is not the tool, and
  `netplan apply` changes nothing on the path you mean.
- **Debian** servers use ifupdown and
  `/etc/network/interfaces` unless netplan or
  NetworkManager is installed.

The procedure below is for netplan. For ifupdown or
NetworkManager, the change goes through
`rules/ssh-safety-net.md` only with a revert the user and
you have agreed on; otherwise it is the user's, with
console access ready.

### Changing netplan safely

Over SSH, a netplan change goes through
`rules/ssh-safety-net.md` with `/etc/netplan/` backed up
as a whole:

- Check: `netplan generate`.
- Apply: `netplan apply`.
- Revert:
  `rm -rf /etc/netplan && cp -a <backup-dir> /etc/netplan && netplan apply`.

`netplan try` is netplan's own safe apply: it rolls the
change back unless ENTER confirms it within 120 seconds.
Hostwarden's calls have no terminal, and with stdin at
end-of-file it rolls back at once, so it is for the user
to run in a terminal of their own:

```bash operator
ssh -t root@<production-host> netplan try
```

Bonds and other virtual devices are not always reverted
by either path: say so before changing one, and check the
result instead of trusting the revert.

Sources: https://ubuntu.com/server/docs/explanation/networking/configuring-networks/,
https://netplan.readthedocs.io/en/stable/netplan-try/

## cloud-init

Cloud and VM images of Ubuntu, and Debian's cloud images,
run cloud-init at boot. It can own things Hostwarden
would otherwise edit directly:

- **Network:** on Ubuntu it writes
  `/etc/netplan/50-cloud-init.yaml` from the provider's
  metadata. The file says so in its
  header, and changes to it do not survive a reboot.
- **Hostname:** with `preserve_hostname: false` (the
  default) it sets the hostname from the metadata and
  updates it on boot.
- **SSH:** it can write
  `/etc/ssh/sshd_config.d/50-cloud-init.conf`, for example
  `PasswordAuthentication` from `ssh_pwauth`. sshd takes
  the first value it reads, so this file wins over any
  later drop-in. Hostwarden never edits it (Critical
  Safety Rules); name it as the source when an sshd
  finding comes from there.

Tell whether it is active:

```bash
cloud-init status --long 2>/dev/null || echo "no cloud-init"
test -f /etc/cloud/cloud-init.disabled && echo "disabled"
ls /etc/cloud/cloud.cfg.d/ 2>/dev/null
head -5 /etc/netplan/50-cloud-init.yaml 2>/dev/null
```

To take the network over from it, with the user's
agreement: copy `50-cloud-init.yaml` to a file of its own
in `/etc/netplan/` (for example `60-static.yaml`), then
write `/etc/cloud/cloud.cfg.d/99-disable-network-config.cfg`
containing:

```yaml
network: {config: disabled}
```

Remove `50-cloud-init.yaml` only after that, and apply as
under **Changing netplan safely**. For the hostname, set
`preserve_hostname: true` in a drop-in in the same
directory before changing it. Disabling cloud-init as a
whole (`/etc/cloud/cloud-init.disabled`) is a bigger step
than either: it also stops SSH key and user provisioning
from the provider — ask first.

Sources: https://docs.cloud-init.io/en/latest/reference/network-config.html,
https://docs.cloud-init.io/en/latest/howto/disable_cloud_init.html,
https://docs.cloud-init.io/en/latest/howto/status.html

## Ubuntu

### Ubuntu Pro and ESM

Standard security updates cover the `main` and
`restricted` components for five years of an LTS release.
Everything beyond that needs an attached Ubuntu Pro
subscription:

- **esm-infra** — `main` for another five years after
  standard support ends.
- **esm-apps** — security updates for `universe` (and
  `multiverse`) for the whole ten years. Without Pro,
  `universe` packages get fixes only from community
  effort, on no schedule.
- **livepatch** — see **Livepatch**.

What to read, none of it needs root:

- `pro status` — attached or not, and whether esm-infra,
  esm-apps and livepatch are enabled.
- `pro security-status` — installed packages counted by
  origin (main/restricted, universe/multiverse, third
  party, no longer available).
- `pro api u.pro.packages.updates.v1` — one entry per
  pending update. `pending_attach` or `pending_enable` in
  its `status` is a security fix that exists but cannot
  be installed until Pro is attached or the service is
  enabled. The output lists every package; the
  housekeeping baseline has a probe that counts them.

A `universe` package on a host without esm-apps has no
guaranteed security coverage, and an LTS past standard
support is covered only with esm-infra enabled. The
severities are housekeeping's
(`.agents/skills/hostwarden-housekeeping/references/baseline-linux.md`
→ Ubuntu Release and Support).

Attaching (`pro attach`) takes a token — a secret
(`rules/secrets.md`), and a subscription decision that is
the user's. Hostwarden never attaches on its own.

Sources: https://ubuntu.com/pro/docs/services-overview/,
https://ubuntu.com/pro-client/docs/en/latest/references/commands/,
https://ubuntu.com/pro-client/docs/en/latest/references/api/

### Releases and upgrades

- **LTS** releases come every two years in April
  (`XX.04`, even years) with five years of standard
  support and ESM through Pro after that.
- **Interim** releases get nine months of updates and no
  ESM. On a server that is a short fuse: an interim
  release past its end of life gets no security updates
  at all.

End-of-life dates come from
https://ubuntu.com/about/release-cycle at the time you
report them, never from memory (`rules/version-check.md`).

`/etc/update-manager/release-upgrades` decides which
release the upgrader offers: `Prompt=lts` (the default on
an LTS), `Prompt=normal` (the next release, interim
included) or `Prompt=never`. A server on an LTS belongs
on `lts`; report anything else.

`do-release-upgrade` upgrades one release at a time;
LTS to LTS is offered only after the new release's first
point release (`.1`). `do-release-upgrade -c` checks
whether an upgrade is offered and changes nothing.

A release upgrade is not a Hostwarden command run. It is
interactive, disables third-party sources, and replaces
most of the system. Over SSH the upgrader starts a
second sshd on port 1022 as a fallback, which a firewall
may block. Prepare it with the user instead:

1. A backup that is confirmed restorable.
2. All current updates installed, and free space for
   several gigabytes of packages.
3. Third-party sources and PPAs listed, so they can be
   re-enabled for the new release afterwards.
4. The operator runs it at a terminal, inside `tmux` or
   `screen` so a dropped connection does not kill it:
   ```bash operator
   ssh -t root@<production-host> tmux new -s upgrade do-release-upgrade
   ```
5. Afterwards Hostwarden verifies services, sources and
   the running kernel, and records the release in server
   memory.

Sources: https://ubuntu.com/about/release-cycle,
https://ubuntu.com/server/docs/how-to/software/upgrade-your-release/,
https://git.launchpad.net/ubuntu/+source/ubuntu-release-upgrader/tree/data/release-upgrades?h=ubuntu/noble-updates

### Livepatch

Livepatch applies fixes for high and critical kernel
vulnerabilities to the running kernel. It comes with Pro
and is enabled when Pro is attached on an LTS.

```bash
canonical-livepatch status 2>/dev/null
```

It does not remove the need to reboot:

- It patches only a kernel series Canonical still
  covers. `kernel state` with a date means coverage ends
  then, and the host has to boot a newer kernel before
  it.
- A kernel installed by apt still waits for a reboot;
  `/var/run/reboot-required` and the running-vs-installed
  check stay valid. While `patch state` shows all
  patches applied, that pending reboot is not an open
  vulnerability.

Sources: https://ubuntu.com/security/livepatch/docs/,
https://ubuntu.com/security/livepatch/docs/client/how-to-guides/operations/check-client-status/

### Snaps

Ubuntu Server can carry snaps (`lxd`, `canonical-livepatch`
and others). Prefer `apt-get` for new software unless the
user wants a snap. Snaps update themselves, outside apt
and unattended-upgrades:

- `snapd` checks for updates four times a day by default.
  `snap refresh --time` shows the schedule and the next
  run.
- A refresh restarts the snap's services. For a snap that
  serves production, suggest a window:
  `snap set system refresh.timer=<window>`.
- `snap refresh --hold=<duration> <snap>` (or
  `--hold=forever`) holds one snap; without a name it
  holds automatic refreshes of all snaps. A snap held
  forever gets no security fixes — record every hold in
  server memory and report it.
- `snap list` names what is installed and from which
  channel.

Sources: https://snapcraft.io/docs/how-to-guides/manage-snaps/manage-updates/

## Storage Maintenance

What Debian and Ubuntu schedule by themselves
(`rules/baseline.md` → Storage Maintenance):

- **TRIM:** `fstrim.timer`, weekly, enabled with util-linux
  ([debian/rules](https://salsa.debian.org/debian/util-linux/-/raw/debian/trixie/debian/rules)).
- **md RAID:** the mdadm package enables `mdcheck_start.timer`
  (the first Sunday of the month, 01:00), `mdcheck_continue.timer`
  (daily, resuming a check in slices of six hours) and
  `mdmonitor-oneshot.timer` (a daily scan that mails root). No
  cron job runs a check; `checkarray` is shipped and nothing
  schedules it
  ([mdadm](https://sources.debian.org/src/mdadm/4.4-11/debian/rules/)).
  Ubuntu Server installs mdadm.
- **ZFS:** `/etc/cron.d/zfsutils-linux` trims the first Sunday of
  the month and scrubs the second. The pool's root dataset opts
  out with `org.debian:periodic-trim` or `org.debian:periodic-scrub`
  set to `disable`; trim's default, `auto`, trims only pools of
  NVMe disks. OpenZFS's `zfs-scrub-monthly@<pool>.timer` and
  `zfs-trim-monthly@<pool>.timer` are installed and not enabled.
- **btrfs:** `btrfsmaintenance` is packaged and installed
  disabled; its settings are in `/etc/default/btrfsmaintenance`.
- **SMART:** smartmontools is not part of a default install. Its
  unit is `smartmontools.service`, with `smartd.service` as an
  alias: enable it by the real name, since systemd enables no
  unit by an alias. The default `DEVICESCAN` line schedules no
  self-tests.

## Directory Conventions

- Config files: `/etc/`
- Web roots: `/var/www/`
- Logs: `/var/log/`
- Sites config (nginx): `/etc/nginx/sites-available/` and
  `/etc/nginx/sites-enabled/`
- Sites config (Apache): `/etc/apache2/sites-available/` and
  `/etc/apache2/sites-enabled/`

## Notes

- Debian and Ubuntu use the same package manager and mostly
  the same conventions, but package names and available
  versions may differ.

## Common Pitfalls

- Use `apt-get` not `apt` — `apt` is for interactive
  use and its output format is unstable.
- `systemctl restart` vs `systemctl reload` — prefer
  `reload` when the service supports it (e.g. nginx)
  to avoid downtime. See `rules/service-reload.md`
  for the auto-proceed policy and the
  `memory/service-policy.md` opt-out / opt-in lists.
- Before enabling `ufw`, allow SSH first — see the
  lockout warning in the Firewall section above.
- `ufw` must be enabled (`ufw enable`) — installing
  alone does nothing.
- Prefer `apt-get upgrade` for routine updates.
  `apt-get dist-upgrade` (or `full-upgrade`) may
  remove packages — always dry-run with `-s` first
  and ask the user.
- Debian's `nginx` uses `sites-available/` +
  `sites-enabled/` symlinks. Ubuntu follows the same
  pattern. Do not put configs directly in `conf.d/`
  unless there is no `sites-available/` directory.
- `unattended-upgrades` needs three things: the
  package, `APT::Periodic::Unattended-Upgrade "1";`
  (usually `/etc/apt/apt.conf.d/20auto-upgrades`),
  and an active `apt-daily-upgrade.timer` — check
  all three.
